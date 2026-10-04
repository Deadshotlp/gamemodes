--[[
    Naval - Hyperraum (Server).

    Ablauf (Zeitpunkte als Naval.Now(), ueberstehen Neustarts):
      SPOOLING   Antrieb faehrt hoch (Klassenwert spool), abbrechbar
      JUMPING    Eintritt: Schiff schiesst nach vorn (jump_anim_time)
      HYPERSPACE im Tunnel, Dauer nach Strecke (Naval.JumpDuration)
      EXITING    Austritt im Zielsystem (exit_anim_time)
      NORMAL

    Voraussetzungen fuer einen Sprung (Naval.CanJump):
      - Zustand NORMAL, Zielsystem existiert und ist anspringbar
      - ausserhalb jedes Massenschattens (mass_shadow_factor * Radius)
      - Bug auf den Sprungvektor ausgerichtet (jump_align_tolerance Grad)
    Die Kursberechnung am Navcomputer (Stufe 1, Konsolen) legt die Loesung
    in ship.nav ab; fuer KI-Schiffe rechnet der Server sie direkt.

    Ereignisse: hook "PD.Naval.Event"(ship, kind, data) mit kind =
    jump_spool, jump_abort, jump_start, jump_tunnel, jump_exit, jump_done.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3, Q = Naval.V3, Naval.Q
local S = Naval.State

function Naval.Event(ship, kind, data)
    hook.Run("PD.Naval.Event", ship, kind, data or {})
end

-- Naval.JumpVector (Richtung zum Einstieg in die Route) steht in sv_naval_routing.lua.

-- Naechster Massenschatten (Koerper, Abstand, erlaubter Mindestabstand)
function Naval.MassShadow(ship)
    local factor = Naval.Settings.mass_shadow_factor or 4

    for _, body in ipairs(Naval.BodiesBySystem[ship.systemId] or {}) do
        if body.type == "star" or body.type == "planet" or body.type == "moon" then
            local pos = Naval.BodyPos(body, Naval.Bodies)
            local dist = V3.Dist(ship.pos, pos)
            local limit = body.radius * factor

            if dist < limit then return body, dist, limit end
        end
    end
end

function Naval.AlignmentError(ship, toSystemId)
    local from, to = Naval.Systems[ship.systemId], Naval.Systems[toSystemId]
    if not from or not to then return 180 end

    return Naval.AngleBetween(Q.Forward(ship.rot), Naval.JumpVector(from, to))
end

function Naval.CanJump(ship, toSystemId)
    if ship.state ~= S.NORMAL then return false, "Antrieb nicht bereit (" .. tostring(ship.state) .. ")" end

    local to = Naval.Systems[toSystemId]
    if not to then return false, "Unbekanntes Ziel" end
    if not to.jumpable then return false, "Ziel ist gesperrt" end
    if toSystemId == ship.systemId then return false, "Bereits im Zielsystem" end

    local body, dist, limit = Naval.MassShadow(ship)
    if body then
        return false, ("Im Massenschatten von %s (%.0f von %.0f km)"):format(body.name, dist / 1000, limit / 1000)
    end

    local err = Naval.AlignmentError(ship, toSystemId)
    local tol = Naval.Settings.jump_align_tolerance or 2
    if err > tol then
        return false, ("Nicht auf Kurs ausgerichtet (%.1f° Abweichung, erlaubt %.1f°)"):format(err, tol)
    end

    return true
end

-- Ankunftspunkt: am Hauptkoerper auf der Seite, aus der man kommt. Schiffe
-- aus derselben Richtung kommen so nahe beieinander an.
function Naval.ArrivalFrom(toSystemId, fromSystem)
    local to = Naval.Systems[toSystemId]
    local main = Naval.MainBody(Naval.BodiesBySystem[toSystemId] or {})
    if not to or not main or not fromSystem then return Naval.ArrivalPoint(toSystemId, math.random()) end

    local center = Naval.BodyPos(main, Naval.Bodies)
    local dir = V3.Sub(fromSystem.g, to.g)
    dir.z = dir.z * 0.2
    if V3.LenSqr(dir) < 1e-6 then dir = {x = 1, y = 0, z = 0} end

    return V3.Add(center, V3.Scale(V3.Normalize(dir), main.radius * 8 + 50000))
end

-- opts.arriveNear = Schiffs-ID: Austritt in der Naehe dieses Schiffs, falls
-- es beim Austritt im Zielsystem ist (z. B. Verstaerkung zum Map-Schiff).
function Naval.StartJump(ship, toSystemId, by, opts)
    local ok, reason = Naval.CanJump(ship, toSystemId)
    if not ok then return false, reason end

    local from, to = Naval.Systems[ship.systemId], Naval.Systems[toSystemId]
    local now = Naval.Now()
    local settings = Naval.Settings

    local spool = ship:Stat("spoolTime")
    local jumpAnim = settings.jump_anim_time or 3
    local exitAnim = settings.exit_anim_time or 3
    local travel = Naval.JumpDuration(from, to, ship:Stat("hyperRating"), settings)

    -- Ankunft: am Rand des Zielsystems, Blick in Flugrichtung
    local dir = Naval.JumpVector(from, to)
    local arrive = Naval.ArrivalFrom(toSystemId, from)
    local scatter = settings.arrival_scatter or 20000
    arrive = V3.Add(arrive, {x = (math.random() - 0.5) * scatter, y = (math.random() - 0.5) * scatter, z = (math.random() - 0.5) * scatter * 0.3})

    ship.hyper = {
        from = ship.systemId,
        to = toSystemId,
        by = by,
        tSpool = now,
        tJump = now + spool,
        tTunnel = now + spool + jumpAnim,
        tExit = now + spool + jumpAnim + travel,
        tDone = now + spool + jumpAnim + travel + exitAnim,
        arrive = arrive,
        arriveRot = Q.Copy(ship.rot),
        dir = dir,
        arriveNear = opts and opts.arriveNear or nil,
    }

    ship.ctrl.autopilot = {dir = dir}
    ship.state = S.SPOOLING
    ship.dirty = true

    Naval.Event(ship, "jump_spool", {to = toSystemId, duration = travel, spool = spool})
    ship:Log("nav", by or "", ("Hyperraumsprung nach %s eingeleitet (%.0f s)"):format(to.name, travel))
    Naval.SaveShip(ship)

    return true, travel
end

function Naval.AbortJump(ship, by)
    if ship.state ~= S.SPOOLING then return false, "Sprung laeuft bereits" end

    ship.state = S.NORMAL
    ship.hyper = {}
    ship.ctrl.autopilot = nil
    ship.dirty = true

    Naval.Event(ship, "jump_abort", {})
    ship:Log("nav", by or "", "Hyperraumsprung abgebrochen")

    return true
end

-- Uebergaenge pruefen (aus dem Simulationstakt)
function Naval.HyperspaceTick()
    local now = Naval.Now()

    for _, ship in pairs(Naval.Ships) do
        local h = ship.hyper
        local state = ship.state

        if state == S.SPOOLING and h.tJump and now >= h.tJump then
            ship.state = S.JUMPING
            Naval.Event(ship, "jump_start", {to = h.to})
        elseif state == S.JUMPING and h.tTunnel and now >= h.tTunnel then
            ship.state = S.HYPERSPACE
            ship.vel = V3.New()
            ship.angVel = V3.New()
            ship.ctrl.autopilot = nil
            ship.ctrl.throttle = 0
            Naval.Event(ship, "jump_tunnel", {to = h.to, exitAt = h.tExit})
            Naval.SaveShip(ship)
        elseif state == S.HYPERSPACE and h.tExit and now >= h.tExit then
            ship.state = S.EXITING
            ship.systemId = h.to
            ship.pos = V3.Copy(h.arrive)
            ship.rot = Q.Copy(h.arriveRot)

            local near = h.arriveNear and Naval.Ships[h.arriveNear]
            if near and near ~= ship and near.systemId == h.to and near.state == S.NORMAL then
                -- 15-30 km seitlich/hinter dem Schiff, gleiche Blickrichtung
                local side = (math.random() < 0.5 and -1 or 1) * (15000 + math.random() * 15000)
                local back = -(5000 + math.random() * 15000)
                ship.pos = V3.Add(near.pos, V3.Add(V3.Scale(Q.Left(near.rot), side), V3.Scale(Q.Forward(near.rot), back)))
                ship.rot = Q.Copy(near.rot)
            end

            ship.vel = V3.Scale(Q.Forward(ship.rot), ship:Stat("maxSpeed") * 0.3)
            Naval.Event(ship, "jump_exit", {from = h.from, to = h.to})
            Naval.SaveShip(ship)
        elseif state == S.EXITING and h.tDone and now >= h.tDone then
            ship.state = S.NORMAL
            ship.ctrl.throttle = 0
            local to = Naval.Systems[h.to]
            ship:Log("nav", "", "Austritt aus dem Hyperraum: " .. (to and to.name or "?"))
            Naval.Event(ship, "jump_done", {to = h.to})
            ship.hyper = {}
            ship.nav = nil
            ship.dirty = true
        end
    end
end
