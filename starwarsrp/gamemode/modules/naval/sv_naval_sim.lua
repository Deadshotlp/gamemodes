--[[
    Naval - Simulation (Server).

    Takt per Timer (nicht Think: hook.Call bricht ab, sobald ein anderer Hook
    einen Wert zurueckgibt), jeder Schritt per xpcall geschuetzt. Schiffe im
    System des Map-Schiffs werden jeden Takt simuliert, alle anderen jeden
    10. Takt mit entsprechend groesserem dt.

    Bewegung liest nur ship.ctrl - egal ob Steuerkonsole, KI oder Admin
    steuern:
      throttle  -0.25..1   Anteil der Hoechstgeschwindigkeit (vorwaerts)
      rate p/y/r  -1..1    Drehrate (Nicken: + = Nase runter, wie Source)
      thrust x/y/z -1..1   Manoevrierduesen (vor/links/oben)
      autopilot  {dir = V3}  Bug auf diese Richtung drehen (ueberschreibt rate)
    Traegheit (Einstellung ship_inertia, Standard 0 = aus): ohne sie folgt die
    Fahrt sofort dem Bug (kein Rutschen nach dem Drehen) und Drehungen
    stoppen ohne Nachlaufen. Beschleunigen und Bremsen dauern weiterhin
    (accel/decel der Klasse).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3, Q = Naval.V3, Naval.Q

local TICK = 0.1
local FAR_EVERY = 10

local function approach(current, target, step)
    if current < target then return math.min(current + step, target) end
    return math.max(current - step, target)
end

-- Autopilot: Drehraten-Befehl, um den Bug auf dir auszurichten.
function Naval.FaceRates(ship, dir, keepRollLevel)
    local d = Q.RotateVec(Q.Conj(ship.rot), V3.Normalize(dir))

    local yawErr = math.deg(math.atan2(d.y, d.x))
    local pitchErr = -math.deg(math.atan2(d.z, math.sqrt(d.x * d.x + d.y * d.y)))

    -- Daempfung: nahe am Ziel langsamer, damit nichts ueberschiesst
    local p = math.Clamp(pitchErr / 12, -1, 1)
    local y = math.Clamp(yawErr / 12, -1, 1)
    local r = 0

    if keepRollLevel then
        -- Rolle zurueck in die Galaxieebene (Oben = +z)
        local up = Q.Up(ship.rot)
        local left = Q.Left(ship.rot)
        r = math.Clamp(-math.deg(math.atan2(left.z, up.z)) / 20, -1, 1)
    end

    return p, y, r, math.max(math.abs(yawErr), math.abs(pitchErr))
end

local function Step(ship, dt)
    local state = ship.state

    if state == Naval.State.HYPERSPACE or state == Naval.State.DESTROYED then
        return
    end

    local ctrl = ship.ctrl
    local disabled = state == Naval.State.DISABLED

    -- Drehung
    local maxRate, angAccel = ship:Rates()
    local rp, ry, rr = ctrl.rate.p, ctrl.rate.y, ctrl.rate.r

    if ctrl.autopilot and ctrl.autopilot.dir then
        local p, y, r, err = Naval.FaceRates(ship, ctrl.autopilot.dir, true)
        rp, ry, rr = p, y, r
        ctrl.autopilot.error = err
    end

    if disabled then rp, ry, rr = 0, 0, 0 end

    local target = {x = rr * maxRate.x, y = rp * maxRate.y, z = ry * maxRate.z}
    -- Ohne Traegheit (ship_inertia 0): Drehrate sofort wie befohlen, kein
    -- Nachlaufen/Ueberschiessen
    local inertia = (tonumber(Naval.Settings.ship_inertia) or 0) ~= 0
    if inertia then
        ship.angVel = {
            x = approach(ship.angVel.x, target.x, angAccel.x * dt),
            y = approach(ship.angVel.y, target.y, angAccel.y * dt),
            z = approach(ship.angVel.z, target.z, angAccel.z * dt),
        }
    else
        ship.angVel = target
    end

    if V3.LenSqr(ship.angVel) > 1e-12 then
        ship.rot = Q.Integrate(ship.rot, ship.angVel, dt)
    end

    -- Geschwindigkeit im Schiffssystem
    local vb = Q.RotateVec(Q.Conj(ship.rot), ship.vel)
    local maxSpeed = ship:Stat("maxSpeed")
    local throttle = disabled and 0 or math.Clamp(ctrl.throttle or 0, -0.25, 1)

    -- Waehrend Hochfahren/Eintritt beschleunigt der Hyperantrieb selbst.
    if state == Naval.State.JUMPING then
        throttle = 1
    end

    local targetX = throttle * maxSpeed
    local rateX = (math.abs(targetX) > math.abs(vb.x) and targetX * vb.x >= 0) and ship:Stat("accel") or ship:Stat("decel")
    vb.x = approach(vb.x, targetX, rateX * dt)

    local thr = disabled and 0 or ship:Stat("thrusterSpeed")
    if inertia then
        vb.y = approach(vb.y, (ctrl.thrust.y or 0) * thr, thr * 0.5 * dt + 1e-9)
        vb.z = approach(vb.z, (ctrl.thrust.z or 0) * thr, thr * 0.5 * dt + 1e-9)
    else
        -- Kein seitliches Rutschen: die Fahrt zeigt immer in Bugrichtung,
        -- seitlich/vertikal bewegen nur die Manoevrierduesen
        vb.y = (ctrl.thrust.y or 0) * thr
        vb.z = (ctrl.thrust.z or 0) * thr
    end
    if math.abs(ctrl.thrust.x or 0) > 0 then
        vb.x = vb.x + (ctrl.thrust.x or 0) * thr * 0.5 * dt
    end

    ship.vel = Q.RotateVec(ship.rot, vb)
    ship.pos = V3.Add(ship.pos, V3.Scale(ship.vel, dt))

    if V3.LenSqr(ship.vel) > 0.01 or V3.LenSqr(ship.angVel) > 1e-8 then
        ship.dirty = true
    end
end

Naval.StepShip = Step

local tickCount = 0
local lastTime = SysTime()

function Naval.Tick()
    -- Zeitstempel des Simulationsstands (auch pausiert, damit die Uhr der
    -- Clients weiterlaeuft); der Snapshot traegt genau diese Zeit.
    Naval.SimTime = Naval.Now()
    if Naval.Paused then return end

    local now = SysTime()
    local dt = math.min(now - lastTime, 0.5) * (Naval.TimeScale or 1)
    lastTime = now
    tickCount = tickCount + 1

    local mapShip = Naval.GetMapShip()
    local focusSystem = mapShip and mapShip.systemId

    for _, ship in pairs(Naval.Ships) do
        if ship.systemId == focusSystem or ship:IsPlayerShip() then
            Step(ship, dt)
        elseif (tickCount + ship.id) % FAR_EVERY == 0 then
            Step(ship, dt * FAR_EVERY)
        end
    end

    if Naval.HyperspaceTick then Naval.HyperspaceTick() end
end

local function SafeTick()
    local ok, err = xpcall(Naval.Tick, debug.traceback)
    if not ok then ErrorNoHalt("[Naval] Fehler im Takt: " .. tostring(err) .. "\n") end

    -- Snapshot im selben Takt: jeder Snapshot ist genau ein Simulationsschritt
    if Naval.AfterTick then Naval.AfterTick() end
end

local function SafeAI()
    if Naval.Paused or not Naval.AITick then return end
    local ok, err = xpcall(Naval.AITick, debug.traceback)
    if not ok then ErrorNoHalt("[Naval] Fehler in der KI: " .. tostring(err) .. "\n") end
end

--------------------------------------------------------------------------------
-- Start: Schiffe laden, Map-Schiff sicherstellen, Takte starten
--------------------------------------------------------------------------------

function Naval.EnsureMapShip()
    local profile = Naval.GetProfile()
    if not profile then return nil end

    local ship = Naval.GetMapShip()
    if ship then return ship end

    local systemId = Naval.StartSystemId()
    ship = Naval.CreateShip({
        classId = profile.classId,
        name = profile.defaultName,
        factionId = profile.factionId,
        systemId = systemId,
        pos = Naval.ArrivalPoint(systemId, 0.25),
        flags = {player = true, profile = profile.key, invulnerable = true},
    })

    if ship then
        Naval.SaveShip(ship)
        Naval.Log("Map-Schiff angelegt: " .. ship.name .. " im System " .. tostring((Naval.Systems[systemId] or {}).name))
    end

    return ship
end

local function StartSimulation()
    Naval.LoadShips(function(count)
        Naval.Log(count .. " Schiffe geladen")

        if Naval.IsNavalMap() then
            Naval.EnsureMapShip()
        end

        timer.Create("PD.Naval.Tick", TICK, 0, SafeTick)
        timer.Create("PD.Naval.AI", 0.5, 0, SafeAI)
        timer.Create("PD.Naval.Autosave", math.max(10, tonumber(Naval.Settings.autosave_interval) or 60), 0, function()
            local saved = Naval.SaveDirty()
            if saved > 0 then Naval.DebugLog(saved .. " Schiffe gespeichert") end
        end)

        Naval.SimRunning = true
        hook.Run("PD.Naval.SimStarted")
    end)
end

-- Simulation nur auf Naval-Maps; das Web-Panel braucht sie sonst nicht.
hook.Add("PD.Naval.Ready", "PD.Naval.Sim", function()
    if not Naval.IsNavalMap() then return end

    -- Lua-Refresh: vorher Gespeichertes nicht verlieren
    if Naval.SimRunning then Naval.SaveDirty() end

    StartSimulation()
end)

hook.Add("ShutDown", "PD.Naval.Save", function()
    if Naval.SimRunning then Naval.SaveDirty(true) end
end)
