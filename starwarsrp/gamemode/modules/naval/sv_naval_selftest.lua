--[[
    Naval - Simulations-Selbsttest (Server): pd_naval_simtest

    Prueft Flugphysik, Autopilot, KI-Anflug, Sprungzeiten und die Groesse
    der Netzwerkdaten mit einem Testschiff, das weder gespeichert noch
    gesendet wird. Laeuft auch ohne pd_naval_active.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3, Q = Naval.V3, Naval.Q

local function TestShip(classId)
    local class = Naval.Classes[classId]
    if not class then return nil end

    return setmetatable({
        id = 0, name = "Test", classId = classId, factionId = class.faction, systemId = "",
        pos = V3.New(), rot = Q.Identity(), vel = V3.New(), angVel = V3.New(),
        ctrl = {throttle = 0, rate = {p = 0, y = 0, r = 0}, thrust = {x = 0, y = 0, z = 0}},
        state = Naval.State.NORMAL, hyper = {}, orders = {queue = {}}, flags = {},
    }, Naval.ShipMeta)
end

local function Simulate(ship, seconds, dt, each)
    dt = dt or 0.1
    for _ = 1, math.floor(seconds / dt) do
        if each then each(ship) end
        Naval.StepShip(ship, dt)
    end
end

function Naval.SimSelfTest()
    local results = {}
    local function check(name, ok, detail)
        results[#results + 1] = {name = name, ok = ok and true or false, detail = detail}
    end

    if not Naval.Classes.venator then
        check("Klasse venator geladen", false)
        return results
    end

    -- 1. Volle Fahrt voraus
    local ship = TestShip("venator")
    ship.ctrl.throttle = 1
    local maxSpeed = ship:Stat("maxSpeed")
    Simulate(ship, 200)
    check("Erreicht Hoechstgeschwindigkeit", math.abs(ship:Speed() - maxSpeed) < 1, ("%.0f / %.0f m/s"):format(ship:Speed(), maxSpeed))
    check("Fliegt geradeaus (+x)", ship.pos.x > 0 and math.abs(ship.pos.y) < 1 and math.abs(ship.pos.z) < 1,
        ("x=%.0f y=%.2f z=%.2f"):format(ship.pos.x, ship.pos.y, ship.pos.z))

    -- 2. Gieren nach links (+)
    ship = TestShip("venator")
    ship.ctrl.rate.y = 1
    Simulate(ship, 20)
    local yaw = math.deg(math.atan2(Q.Forward(ship.rot).y, Q.Forward(ship.rot).x))
    check("Gieren dreht nach links", yaw > 10, ("%.1f Grad nach 20 s"):format(yaw))

    -- 3. Autopilot auf Richtung schraeg oben/hinten
    ship = TestShip("venator")
    local target = V3.Normalize({x = -0.3, y = 0.7, z = 0.4})
    ship.ctrl.autopilot = {dir = target}
    Simulate(ship, 240)
    local err = Naval.AngleBetween(Q.Forward(ship.rot), target)
    check("Autopilot richtet aus (< 1 Grad)", err < 1, ("%.2f Grad Rest"):format(err))
    local up = Q.Up(ship.rot)
    check("Autopilot haelt die Lage waagerecht", up.z > 0.5, ("Oben z=%.2f"):format(up.z))

    -- 4. Bremsen aus voller Fahrt
    ship = TestShip("venator")
    ship.vel = V3.Scale(Q.Forward(ship.rot), maxSpeed)
    ship.ctrl.throttle = 0
    Simulate(ship, 120)
    check("Bremst auf 0", ship:Speed() < 1, ("%.1f m/s"):format(ship:Speed()))

    -- 5. KI-Anflug 400 km mit Ankunft
    ship = TestShip("arquitens")
    local goal = {x = 300000, y = 250000, z = 20000}
    local order = {type = "move", pos = goal}
    ship.orders.queue = {order}
    local arrived = false
    local t = 0
    -- KI 2 Hz (Handler direkt, ohne Naval.Ships), Physik 10 Hz
    while t < 1200 and not arrived do
        arrived = Naval.AIHandlers.move(ship, order)
        Simulate(ship, 0.5, 0.1)
        t = t + 0.5
    end
    check("KI-Anflug kommt an", arrived, ("%.0f s, Rest %.1f km, %.0f m/s"):format(t, V3.Dist(ship.pos, goal) / 1000, ship:Speed()))

    -- 6. Sprungzeiten
    local cor = Naval.FindSystem and Naval.FindSystem("Coruscant")
    local tat = Naval.FindSystem and Naval.FindSystem("Tatooine")
    if cor and tat then
        local dur = Naval.JumpDuration(cor, tat, 1)
        check("Sprungzeit Coruscant -> Tatooine 45-300 s", dur >= 45 and dur <= 300,
            ("%.0f s, %.0f pc%s"):format(dur, Naval.SystemDistance(cor, tat),
                Naval.PlanJump and (" ueber " .. table.concat(Naval.PlanJump(cor, tat).routes, " -> ")) or ""))
    else
        check("Coruscant und Tatooine gefunden", false)
    end

    -- 7. Netzwerk: Groesse der festen Daten
    if Naval.BuildStaticForTest then
        local payload = Naval.BuildStaticForTest()
        local bytes = #(util.Compress(util.TableToJSON(payload)) or "")
        check("Feste Daten < 4 Teile (240 KB)", bytes < 240000, ("%.0f KB komprimiert"):format(bytes / 1024))
    end

    return results
end

local function Run()
    if not Naval.Ready then
        print("[Naval] Simtest: Daten noch nicht geladen")
        return
    end

    local results = Naval.SimSelfTest()
    local passed = 0
    for _, r in ipairs(results) do if r.ok then passed = passed + 1 end end

    print(("[Naval] Simulations-Selbsttest: %s (%d/%d)"):format(passed == #results and "PASS" or "FAIL", passed, #results))
    for _, r in ipairs(results) do
        print("  " .. (r.ok and "ok   " or "FEHL ") .. r.name .. (r.detail and (" - " .. r.detail) or ""))
    end
end

concommand.Add("pd_naval_simtest", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    Run()
end)

hook.Add("PD.Naval.Ready", "PD.Naval.SimTest", function()
    timer.Simple(1, Run)
end)
