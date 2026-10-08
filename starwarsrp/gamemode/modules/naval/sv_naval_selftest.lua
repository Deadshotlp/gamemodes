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

    -- 7. Testgefecht Venator gegen Munificent auf 30 km, Bug an Bug
    if Naval.CombatFire and Naval.Classes.munificent then
        local a, b = TestShip("venator"), TestShip("munificent")
        a.id, b.id = 64001, 64002
        a.flags.test, b.flags.test = true, true
        b.pos = {x = 30000, y = 0, z = 0}
        b.rot = Q.FromAngle(0, 180, 0)
        Naval.Combat(a).roe = "free"
        Naval.Combat(b).roe = "free"

        local tc, firstHull = 0, nil
        local hullA, hullB = a.hull, b.hull
        while tc < 1800 and a.hull > 0 and b.hull > 0 do
            local sink = {}
            Naval.CombatRegen(a, 0.5)
            Naval.CombatRegen(b, 0.5)
            Naval.CombatFire(a, b, 0.5, sink)
            Naval.CombatFire(b, a, 0.5, sink)
            for _, hit in ipairs(sink) do
                local hitTarget = hit.target == a.id and a or b
                local attacker = hit.attacker == a.id and a or b
                Naval.ApplyHit(hitTarget, attacker, hit.type, hit.amount)
            end
            if not firstHull and (a.hull < hullA or b.hull < hullB) then firstHull = tc end
            tc = tc + 0.5
        end

        local loser = a.hull <= 0 and a or (b.hull <= 0 and b or nil)
        local damagedSubs = 0
        for id, hp in pairs(loser and loser.subs.hp or {}) do
            local max = 1
            for _, s in ipairs(loser:Class().subsystems or {}) do if s.id == id then max = s.hp end end
            if hp < max then damagedSubs = damagedSubs + 1 end
        end

        check("Schilde halten zuerst", (firstHull or 0) >= 10, ("erster Hüllenschaden nach %.0f s"):format(firstHull or -1))
        check("Gefecht dauert 1-15 min", loser ~= nil and tc >= 60 and tc <= 900,
            ("%.0f s, %s verliert (Hülle %d / %d)"):format(tc, loser and loser.classId or "keiner", math.Round(a.hull), math.Round(b.hull)))
        check("Verlierer zerstört, Subsysteme beschädigt", loser ~= nil and loser.state == Naval.State.DESTROYED and damagedSubs > 0,
            damagedSubs .. " Subsysteme beschädigt")
    end

    -- 10. Autopilot: Anflug auf 150 km bremst rechtzeitig, kein Ueberschiessen
    if Naval.AutoSteer then
        local probe = TestShip("venator")
        local approachPoint = {x = 150000, y = 0, z = 0}
        local tol = probe:Class().lengthM * 2 + 1000
        local arrivedAt, overshoot, tt = nil, 0, 0
        while tt < 900 and not arrivedAt do
            if Naval.AutoSteer(probe, approachPoint, tol) then arrivedAt = tt end
            Naval.StepShip(probe, 0.1)
            overshoot = math.max(overshoot, probe.pos.x - approachPoint.x)
            tt = tt + 0.1
        end
        check("Autopilot hält am Ziel ohne Überschießen", arrivedAt ~= nil and overshoot < tol,
            ("angekommen nach %s s, %.0f m über das Ziel hinaus"):format(arrivedAt and math.Round(arrivedAt) or "-", overshoot))
    end

    -- 11. Flotte: drei Begleitschiffe starten ueber Kreuz zu ihren Plaetzen im
    -- Keil hinter einem fahrenden Flaggschiff; jedes soll den naechsten Platz
    -- nehmen, keines durch ein anderes fliegen
    if Naval.FleetStep and Naval.FormationSlot then
        local flag = TestShip("venator")
        flag.id = 64011
        flag.flags = {test = true, hidden = true}
        flag.systemId = "__test__"
        flag.ctrl.throttle = 0.3

        local fleet = {id = 64000, name = "Test", flagshipId = flag.id, formation = "wedge", mode = "formation"}
        flag.fleetId = fleet.id
        Naval.Ships[flag.id] = flag
        Naval.Fleets[fleet.id] = fleet

        -- Platz 1 liegt links hinten, Platz 2 rechts hinten: Schiff mit der
        -- kleinsten ID startet rechts, das zweite links (ueber Kreuz)
        local starts = {{x = -8000, y = -9000, z = 0}, {x = -8000, y = 9000, z = 0}, {x = -15000, y = 0, z = 2000}}
        local escorts = {}
        for i, p in ipairs(starts) do
            local e = TestShip("arquitens")
            e.id = 64011 + i
            e.flags = {test = true, hidden = true}
            e.systemId = "__test__"
            e.pos = p
            e.fleetId = fleet.id
            Naval.Ships[e.id] = e
            escorts[i] = e
        end

        local all = {flag, unpack(escorts)}
        local minGap = math.huge
        local ok, runErr = pcall(function()
            for _ = 1, 1200 do -- 600 s
                for _, e in ipairs(escorts) do Naval.FleetStep(e) end
                for _ = 1, 5 do
                    for _, sh in ipairs(all) do Naval.StepShip(sh, 0.1) end
                end
                for i = 1, #all do
                    for j = i + 1, #all do minGap = math.min(minGap, V3.Dist(all[i].pos, all[j].pos)) end
                end
            end
        end)

        local worst = 0
        if ok then
            for _, e in ipairs(escorts) do worst = math.max(worst, V3.Dist(e.pos, Naval.FormationSlot(fleet, e, flag))) end
        end
        for _, sh in ipairs(all) do Naval.Ships[sh.id] = nil end
        Naval.Fleets[fleet.id] = nil

        local len = flag:Class().lengthM
        check("Flotte: drei Begleitschiffe in Formation", ok and worst < 3000,
            ok and ("schlechtester Platz %.1f km, Flaggschiff %.0f m/s"):format(worst / 1000, flag:Speed()) or tostring(runErr))
        check("Flotte: kein Schiff fliegt durch ein anderes", ok and minGap > len * 0.6,
            ok and ("kleinster Abstand %.0f m"):format(minGap) or tostring(runErr))
    end

    -- 13. Geschuetzstellungen: Bogen nach vorn erfasst vorn, nicht hinten;
    -- zerstoerte Stellung feuert nicht
    if Naval.HardpointsInArc then
        local probe = TestShip("venator")
        local list = {
            {group = "Bug", type = "turbolaser", count = 2, x = 0.3, y = 0, z = 0.05, yaw = 0, pitch = 0, arcH = 60, arcV = 40},
            {group = "Heck", type = "laser", count = 4, x = -0.4, y = 0, z = 0.05, yaw = 180, pitch = 0, arcH = 70, arcV = 40},
        }
        local cc = Naval.ClassCombat(probe:Class(), list)
        probe.subs = {hphp = {}}
        local front, back = {x = 20000, y = 2000, z = 0}, {x = -20000, y = 0, z = 0}
        local bugFront = Naval.HardpointsInArc(probe, cc, cc.weapons[1], front)
        local bugBack = Naval.HardpointsInArc(probe, cc, cc.weapons[1], back)
        local heckBack = Naval.HardpointsInArc(probe, cc, cc.weapons[2], back)
        probe.subs.hphp[1] = 0
        local bugDead = Naval.HardpointsInArc(probe, cc, cc.weapons[1], front)

        check("Geschützstellungen: Feuerbögen", #cc.weapons == 2 and bugFront == 2 and bugBack == 0 and heckBack == 4 and bugDead == 0,
            ("Bug vorn %d, Bug hinten %d, Heck hinten %d, Bug zerstört %d"):format(bugFront, bugBack, heckBack, bugDead))
    end

    -- 15. Traktorstrahl und Entern: kapituliertes Schiff heranziehen und uebernehmen
    if Naval.TractorTick and Naval.BoardingStepForTest then
        local holder, prize = TestShip("venator"), TestShip("munificent")
        holder.id, prize.id = 64031, 64032
        holder.flags = {test = true, hidden = true}
        prize.flags = {test = true, hidden = true}
        holder.systemId, prize.systemId = "__test__", "__test__"
        prize.pos = {x = 3000, y = 500, z = 0}
        Naval.Ships[holder.id], Naval.Ships[prize.id] = holder, prize
        Naval.Combat(holder)
        Naval.Combat(prize)
        local fromFaction = prize.factionId

        local ok, runErr = pcall(function()
            prize.flags.surrendered = true
            prize.shields.up = false
            local locked, why = Naval.TractorLock(holder, prize)
            if not locked then error("Greifen: " .. tostring(why)) end
            holder.subs.tractor.pull = true
            for _ = 1, 400 do -- 40 s
                Naval.StepShip(holder, 0.1)
                Naval.StepShip(prize, 0.1)
                Naval.TractorTick(0.1)
            end
            local boarded, why2 = Naval.Board(holder, prize)
            if not boarded then error("Entern: " .. tostring(why2)) end
            holder.subs.boarding.done = os.time() - 1
            Naval.BoardingStepForTest(holder)
        end)

        local dist = V3.Dist(holder.pos, prize.pos)
        Naval.TractorRelease(holder)
        Naval.Ships[holder.id], Naval.Ships[prize.id] = nil, nil
        Naval.TractorHeld[prize.id] = nil

        check("Traktorstrahl und Entern: herangezogen und übernommen", ok and prize.factionId == holder.factionId and prize.factionId ~= fromFaction,
            ok and ("Abstand %.0f m, Fraktion %s -> %s"):format(dist, fromFaction, prize.factionId) or tostring(runErr))
    end

    -- 16. Asteroidenfeld: zu schnell -> Einschlaege, sichere Fahrt -> keine
    if Naval.FieldStepForTest and Naval.FieldCache then
        local fship = TestShip("venator")
        fship.id = 64041
        fship.flags = {test = true, hidden = true}
        fship.systemId = "__test__"
        Naval.FieldCache.__test__ = {{id = "t1", kind = "cluster", name = "Testfeld", pos = {x = 0, y = 0, z = 0}, radius = 50000, density = 1}}
        Naval.Ships[fship.id] = fship
        Naval.Combat(fship)
        local hull0 = fship.hull
        local fmax = fship:Stat("fmax")

        local ok, runErr = pcall(function()
            fship.vel = {x = fmax, y = 0, z = 0}
            for _ = 1, 60 do Naval.FieldStepForTest(fship) end
            fship.fastHull = fship.hull
            fship.hull = hull0
            fship.vel = {x = fmax * 0.2, y = 0, z = 0}
            for _ = 1, 60 do Naval.FieldStepForTest(fship) end
        end)

        local limit = Naval.FieldSpeedLimit(fship)
        Naval.Ships[fship.id] = nil
        Naval.FieldCache.__test__ = nil

        check("Asteroidenfeld: Einschläge nur bei zu hoher Fahrt, Autopilot bremst",
            ok and fship.fastHull < hull0 and fship.hull == hull0 and limit < fmax,
            ok and ("Hülle schnell %d -> %d, langsam %d -> %d, Autopilot max %.0f von %.0f m/s"):format(hull0, fship.fastHull, hull0, fship.hull, limit, fmax) or tostring(runErr))
    end

    -- 17. Nachschub: Torpedos ins Magazin, Ersatzteile bis zur Grenze
    if Naval.SupplyApplyForTest and Naval.Classes.venator then
        local sship = TestShip("venator")
        sship.id = 64051
        sship.flags = {test = true, hidden = true}
        local ssubs, _, scc = Naval.Combat(sship)
        local tIdx
        for i, b in ipairs(scc.weapons) do
            if b.type == "torpedo" or b.type == "missile" then ssubs.ammo[i] = 0 tIdx = tIdx or i end
        end
        local hullMax = sship:Class().hull
        sship.hull = hullMax * 0.5

        local ok, runErr = pcall(function()
            local kind = tIdx and scc.weapons[tIdx].type or "torpedo"
            sship.ammoText = Naval.SupplyApplyForTest(sship, kind)
            for _ = 1, 40 do Naval.SupplyApplyForTest(sship, "parts") end
        end)
        local ammoAfter = tIdx and ssubs.ammo[tIdx] or 0
        local capPct = tonumber(Naval.Settings.supply_parts_max) or 80

        check("Nachschub: Munition verbucht, Ersatzteile nur bis zur Grenze",
            ok and (not tIdx or ammoAfter > 0) and math.abs(sship.hull - hullMax * capPct / 100) < 1,
            ok and ("Magazin %d (%s), Hülle %d %% (Grenze %d %%)"):format(ammoAfter, tostring(sship.ammoText), sship.hull / hullMax * 100, capPct) or tostring(runErr))
    end

    -- 12. Moral: schwer beschaedigtes Schiff will fliehen
    if Naval.MoraleTarget then
        local probe = TestShip("munificent")
        probe.systemId = "__test__"
        probe.hull = probe:Class().hull * 0.08
        probe.subs = {hp = {}}
        local moraleTarget = Naval.MoraleTarget(probe)
        check("Moral: bei 8 % Hülle unter der Fluchtschwelle", moraleTarget < (tonumber(Naval.Settings.morale_flee) or 30),
            ("Zielmoral %d"):format(moraleTarget))
    end

    -- 9. Autopilot: Weg quer durch den Hauptplaneten fuehrt aussen herum
    if Naval.AvoidPath then
        local sysId = Naval.StartSystemId()
        local main = Naval.MainBody(Naval.BodiesBySystem[sysId] or {})
        if main and (main.radius or 0) > 0 then
            local c = Naval.BodyPos(main, Naval.Bodies)
            local r = main.radius
            local from = V3.Add(c, {x = -r * 12, y = r * 0.1, z = 0})
            local to = V3.Add(c, {x = r * 12, y = 0, z = 0})
            local path = Naval.AvoidPath(sysId, from, to)

            local closest = math.huge
            for i = 2, #path do
                local a, b = path[i - 1], path[i]
                local d = V3.Sub(b, a)
                local tt = math.Clamp(V3.Dot(V3.Sub(c, a), d) / math.max(V3.LenSqr(d), 1), 0, 1)
                closest = math.min(closest, V3.Dist(V3.Add(a, V3.Scale(d, tt)), c))
            end

            check("Autopilot umfliegt " .. main.name, #path > 2 and closest >= r * 1.1,
                ("%d Wegpunkte, nächster Abstand %.1f Radien"):format(#path, closest / r))

            -- Aus dem Orbit (knapp ausserhalb des Sicherheitsabstands) auf die andere Seite
            local clear = Naval.AutopilotClearance(main)
            local from2 = V3.Add(c, {x = -clear * 1.03, y = 0, z = 0})
            local path2 = Naval.AvoidPath(sysId, from2, V3.Add(c, {x = clear * 3, y = 0, z = 0}))
            local closest2 = math.huge
            for i = 2, #path2 do
                local a, b = path2[i - 1], path2[i]
                local d = V3.Sub(b, a)
                local t2 = math.Clamp(V3.Dot(V3.Sub(c, a), d) / math.max(V3.LenSqr(d), 1), 0, 1)
                closest2 = math.min(closest2, V3.Dist(V3.Add(a, V3.Scale(d, t2)), c))
            end
            check("Autopilot aus dem Orbit nicht durch " .. main.name, closest2 >= r * 1.1,
                ("%d Wegpunkte, nächster Abstand %.1f Radien"):format(#path2, closest2 / r))

            -- Echter Flug: volle Fahrt genau auf den Planeten zu, Ziel dahinter
            local probe = TestShip("venator")
            probe.systemId = sysId
            probe.pos = V3.Add(c, {x = -clear * 3, y = 0, z = 0})
            probe.vel = {x = probe:Stat("maxSpeed"), y = 0, z = 0}
            local goal3 = V3.Add(c, {x = clear * 3, y = 0, z = 0})
            local tol3 = probe:Class().lengthM * 2 + 1000
            local minDist, done, flown = math.huge, false, 0
            while flown < 30000 and not done do
                done = Naval.AutoSteer(probe, goal3, tol3)
                Naval.StepShip(probe, 0.5)
                minDist = math.min(minDist, V3.Dist(probe.pos, c))
                flown = flown + 0.5
            end
            check("Autopilot bei voller Fahrt um " .. main.name .. " herum", done and minDist >= clear * 0.9,
                ("%s nach %.0f s, nächster Abstand %.2f Sicherheitsabstände"):format(done and "angekommen" or "nicht angekommen", flown, minDist / clear))
        end
    end

    -- 8. Netzwerk: Groesse der festen Daten
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
