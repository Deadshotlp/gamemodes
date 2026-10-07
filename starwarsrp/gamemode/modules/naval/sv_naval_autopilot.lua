--[[
    Naval - Autopilot innerhalb eines Systems (Server).

    Kurs um Himmelskoerper herum: jeder Stern, Planet und Mond hat einen
    Sicherheitsabstand (Radius x autopilot_clearance + autopilot_margin).
    Schneidet die Strecke zum Ziel eine solche Kugel, fliegt das Schiff einen
    Umweg ueber einen Punkt seitlich daneben. Der Weg wird jeden Takt neu
    berechnet, das Schiff gleitet so an der Kugel entlang. Gebremst wird nach
    der Restlaenge des ganzen Wegs.

    Map-Schiff (Navigationscomputer -> Systemkarte), ship.auto:
      {kind = "body"|"point"|"ship"|"jumppoint", id, pos, mode = "stop"|"orbit",
       alt (m ueber der Oberflaeche bzw. Abstand zum Schiff), speed 0.1..1,
       via (Zwischenziel: durchfliegen statt anhalten), queue = {weitere Ziele}}
    Wegpunkt-Kette: Shift+Klick auf der Systemkarte haengt Ziele an; nur das
    letzte bestimmt "halten" oder "Orbit".

    Gespeichert in ship.orders (Spalte orders, das Map-Schiff hat keine
    KI-Befehle): orders.navPlan = geplanter Kurs der Systemkarte (fuer jeden,
    der die Konsole oeffnet), orders.auto = laufender Autopilot (uebersteht
    Code-Updates und Neustarts).
    Steuereingaben an der Steuerkonsole schalten ihn ab.

    NPC-Befehle move/patrol nutzen dieselbe Ausweichlogik (Naval.AutoSteer).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3 = Naval.V3
local S = Naval.State

local function Setting(key, default)
    return tonumber(Naval.Settings and Naval.Settings[key]) or default
end

--------------------------------------------------------------------------------
-- Hindernisse und Weg
--------------------------------------------------------------------------------

local function Clearance(body)
    return (body.radius or 0) * Setting("autopilot_clearance", 1.6) + Setting("autopilot_margin", 5000)
end
Naval.AutopilotClearance = Clearance

local function Obstacles(systemId, from)
    local list = {}
    for _, body in ipairs(Naval.BodiesBySystem[systemId] or {}) do
        if (body.radius or 0) > 0 then
            local c = Naval.BodyPos(body, Naval.Bodies)
            local r = Clearance(body)
            -- Schon im Sicherheitsabstand: nur noch dem Koerper selbst ausweichen
            if V3.Dist(from, c) < r then r = body.radius * 1.1 end
            if V3.Dist(from, c) > r then list[#list + 1] = {body = body, c = c, r = r} end
        end
    end
    return list
end

-- Erstes Hindernis auf der Strecke a -> b (nach Abstand von a)
local function Blocking(a, b, obstacles)
    local d = V3.Sub(b, a)
    local lenSqr = V3.LenSqr(d)
    if lenSqr < 1 then return nil end

    local best, bestT
    for _, o in ipairs(obstacles) do
        if V3.Dist(b, o.c) > o.r then
            local t = math.Clamp(V3.Dot(V3.Sub(o.c, a), d) / lenSqr, 0, 1)
            local p = V3.Add(a, V3.Scale(d, t))
            if V3.Dist(p, o.c) < o.r and (not bestT or t < bestT) then
                best, bestT = {o = o, p = p}, t
            end
        end
    end
    return best
end

-- Punkte von "from" nach "to" um alle Hindernisse herum
function Naval.AvoidPath(systemId, from, to)
    local obstacles = Obstacles(systemId, from)
    local points = {from}
    local cur = from

    for _ = 1, 4 do
        local hit = Blocking(cur, to, obstacles)
        if not hit then break end

        local o = hit.o
        local side = V3.Sub(hit.p, o.c)
        if V3.LenSqr(side) < 1 then
            -- Strecke geht genau durch die Mitte: seitlich (in der Ebene) vorbei
            local d = V3.Normalize(V3.Sub(to, cur))
            side = {x = -d.y, y = d.x, z = 0}
            if V3.LenSqr(side) < 1e-6 then side = {x = 0, y = 0, z = 1} end
        end

        local wp = V3.Add(o.c, V3.Scale(V3.Normalize(side), o.r * 1.2))
        points[#points + 1] = wp
        cur = wp
    end

    points[#points + 1] = to
    return points
end

--[[
    Geschwindigkeitsplanung ueber den ganzen Weg (points[1] = Schiff):
    An jedem Knick darf das Schiff nur so schnell sein, dass es die Drehung
    mit seiner Drehrate schafft, ohne weiter als 2 x Toleranz aus der Bahn
    zu tragen: v = Drehrate x 2 x Toleranz / (1 - cos Knickwinkel). Am letzten
    Punkt 0. Erlaubt ist jetzt das Minimum aus sqrt(v_k^2 + 2 x Bremsung x
    Abstand bis Punkt k) ueber alle folgenden Punkte - so wird rechtzeitig
    vor Kurven und vor dem Ziel gebremst.
]]
local function CornerSpeeds(ship, points, tolerance, finalSpeed)
    local rates = ship:Rates()
    local omega = math.max(math.min(rates.y, rates.z), 1e-3)
    local maxSpeed = math.max(ship:Stat("maxSpeed"), 1)
    local speeds = {}

    for i = 2, #points - 1 do
        local a = V3.Normalize(V3.Sub(points[i], points[i - 1]))
        local b = V3.Normalize(V3.Sub(points[i + 1], points[i]))
        local bend = 1 - math.Clamp(V3.Dot(a, b), -1, 1)
        speeds[i] = math.Clamp(omega * tolerance * 2 / math.max(bend, 1e-4), 80, maxSpeed)
    end
    speeds[#points] = finalSpeed or 0

    return speeds
end

local function PlannedSpeed(ship, points, speeds)
    local decel = math.max(ship:Stat("decel"), 1) * 0.85
    local allowed = math.huge
    local along = 0

    for k = 2, #points do
        along = along + V3.Dist(points[k - 1], points[k])
        if speeds[k] then
            allowed = math.min(allowed, math.sqrt(speeds[k] * speeds[k] + 2 * decel * along))
        end
    end

    return allowed, along
end

-- Auf den naechsten Punkt zu, mit geplanter Geschwindigkeit. Gibt true
-- zurueck, wenn das Schiff am letzten Punkt steht.
local function Steer(ship, points, speeds, tolerance, speedCap)
    local speed = ship:Speed()
    speedCap = math.Clamp(speedCap or 1, 0.05, 1)

    local allowed, remaining = PlannedSpeed(ship, points, speeds)
    if remaining <= tolerance then
        ship.ctrl.throttle = 0
        ship.ctrl.autopilot = nil
        return speed < 50
    end

    local toAim = V3.Sub(points[2], ship.pos)
    ship.ctrl.autopilot = {dir = toAim}

    local _, _, _, err = Naval.FaceRates(ship, toAim)
    local maxSpeed = math.max(ship:Stat("maxSpeed"), 1)

    local throttle = math.Clamp(allowed / maxSpeed, 0.02, speedCap)
    -- Bug zeigt noch nicht zum Punkt: erst drehen, kaum Fahrt
    if err > 25 then throttle = math.min(throttle, 0.1) end

    ship.ctrl.throttle = throttle
    return false
end

-- Fuer KI-Befehle: true, wenn angekommen
function Naval.AutoSteer(ship, target, tolerance, speedCap)
    tolerance = tolerance or (((ship:Class() or {}).lengthM or 300) * 3 + 1000)
    local path = Naval.AvoidPath(ship.systemId, ship.pos, target)
    return Steer(ship, path, CornerSpeeds(ship, path, tolerance, 0), tolerance, speedCap), path
end

--------------------------------------------------------------------------------
-- Map-Schiff
--------------------------------------------------------------------------------

-- Punkt ausserhalb aller Massenschatten entlang des Sprungvektors
local function JumpPoint(ship)
    local nav = ship.nav
    local from, to = Naval.Systems[ship.systemId], nav and Naval.Systems[nav.target or ""]
    if not from or not to then return nil end

    local dir = V3.Normalize(Naval.JumpVector(from, to))
    local factor = Setting("mass_shadow_factor", 4)
    local p = V3.Copy(ship.pos)

    for _ = 1, 40 do
        local step = 0
        for _, body in ipairs(Naval.BodiesBySystem[ship.systemId] or {}) do
            if body.type == "star" or body.type == "planet" or body.type == "moon" then
                local limit = body.radius * factor
                local dist = V3.Dist(p, Naval.BodyPos(body, Naval.Bodies))
                if dist < limit then step = math.max(step, limit - dist + 2000) end
            end
        end
        if step <= 0 then break end
        p = V3.Add(p, V3.Scale(dir, step))
    end

    return V3.Add(p, V3.Scale(dir, 3000)), dir
end

-- Zielpunkt des Autopiloten (oder nil, wenn das Ziel weg ist)
local function AutoTarget(ship, auto)
    if auto.kind == "body" then
        local body = Naval.Bodies[auto.id or ""]
        if not body or body.systemId ~= ship.systemId then return nil end
        local c = Naval.BodyPos(body, Naval.Bodies)
        local r = math.max(body.radius + (auto.alt or body.radius * 0.6), Clearance(body) * 1.02)
        local away = V3.Sub(ship.pos, c)
        if V3.LenSqr(away) < 1 then away = {x = 1, y = 0, z = 0} end
        -- Anflugpunkt einmal festlegen (sonst wandert er mit dem Schiff)
        auto.dir = auto.dir or V3.Normalize(away)
        return V3.Add(c, V3.Scale(auto.dir, r)), r, body
    elseif auto.kind == "ship" then
        local other = Naval.Ships[auto.id or -1]
        if not other or other.systemId ~= ship.systemId or other.state == S.HYPERSPACE or other.state == S.DESTROYED then return nil end
        local rel = V3.Sub(ship.pos, other.pos)
        if V3.LenSqr(rel) < 1 then rel = {x = 1, y = 0, z = 0} end
        return V3.Add(other.pos, V3.Scale(V3.Normalize(rel), auto.alt or 5000))
    elseif auto.kind == "jumppoint" then
        if not auto.pos then
            local p, dir = JumpPoint(ship)
            if not p then return nil end
            auto.pos, auto.jumpDir = p, dir
        end
        return auto.pos
    elseif auto.kind == "point" and auto.pos then
        return auto.pos
    end
end

-- Zielpunkt eines spaeteren Ziels der Kette, angeflogen von "from"
local function PreviewTarget(ship, leg, from)
    if leg.kind == "body" then
        local body = Naval.Bodies[leg.id or ""]
        if not body then return nil end
        local c = Naval.BodyPos(body, Naval.Bodies)
        local r = math.max(body.radius + (leg.alt or body.radius * 0.6), Clearance(body) * 1.02)
        local dir = leg.dir or V3.Sub(from, c)
        if V3.LenSqr(dir) < 1 then dir = {x = 1, y = 0, z = 0} end
        return V3.Add(c, V3.Scale(V3.Normalize(dir), r))
    elseif leg.kind == "ship" then
        local other = Naval.Ships[leg.id or -1]
        return other and other.pos
    end
    return leg.pos
end

-- Ganzer Weg: aktuelles Ziel und alle weiteren der Kette, mit Umwegen
local function RoutePoints(ship, auto, target)
    local points = Naval.AvoidPath(ship.systemId, ship.pos, target)
    local legEnd = #points
    local last = target

    for _, leg in ipairs(auto.queue or {}) do
        local p = PreviewTarget(ship, leg, last)
        if not p then break end
        local seg = Naval.AvoidPath(ship.systemId, last, p)
        for i = 2, #seg do points[#points + 1] = seg[i] end
        last = p
    end

    return points, legEnd
end

local function Stop(ship, reason)
    ship.auto = nil
    if ship.orders then ship.orders.auto = nil end
    ship.ctrl.autopilot = nil
    ship.dirty = true
    if reason then ship:Log("nav", "", "Autopilot: " .. reason) end
end
Naval.StopAutopilot = Stop

local function TickMapShip(ship)
    local auto = ship.auto
    if not auto then return end

    if ship.state ~= S.NORMAL then Stop(ship) return end

    local target, orbitR, body = AutoTarget(ship, auto)
    if not target then Stop(ship, "Ziel verloren") return end

    -- Angekommen
    if auto.arrived then
        if auto.mode == "orbit" and body then
            Naval.AIHandlers.orbit(ship, {bodyId = body.id, radius = orbitR})
            ship.ctrl.throttle = math.min(ship.ctrl.throttle, 0.4 * (auto.speed or 1))
        elseif auto.kind == "ship" then
            -- Folgen: wieder los, sobald das Schiff wegfliegt
            if V3.Dist(ship.pos, target) > (auto.alt or 5000) * 0.5 + 3000 then auto.arrived = nil end
            ship.ctrl.throttle = 0
        elseif auto.kind == "jumppoint" and auto.jumpDir then
            ship.ctrl.throttle = 0
            ship.ctrl.autopilot = {dir = auto.jumpDir}
        else
            ship.ctrl.throttle = 0
            ship.ctrl.autopilot = nil
        end
        auto.path = {ship.pos}
        return
    end

    local tolerance = ((ship:Class() or {}).lengthM or 300) * 2 + 1000

    -- Ganzer restlicher Weg mit Geschwindigkeit je Knick: vor Kurven und
    -- vor dem letzten Ziel rechtzeitig bremsen
    local points, legEnd = RoutePoints(ship, auto, target)
    local speeds = CornerSpeeds(ship, points, tolerance, 0)
    auto.path = {unpack(points, 1, legEnd)}

    -- Zwischenziel: durchfliegen, dann das naechste Ziel
    if auto.via and auto.queue and #auto.queue > 0 and V3.Dist(ship.pos, target) <= tolerance * 2 then
        local nextLeg = table.remove(auto.queue, 1)
        nextLeg.queue = auto.queue
        ship.auto = nextLeg
        ship:Log("nav", "", "Autopilot: " .. (auto.label or "?") .. " passiert, weiter nach " .. (nextLeg.label or "?"))
        return
    end

    local arrived = Steer(ship, points, speeds, tolerance, auto.speed)
    if auto.via then arrived = false end

    if arrived then
        auto.arrived = true
        ship:Log("nav", "", "Autopilot: Ziel erreicht - " .. (auto.label or "?"))
    end
end

timer.Create("PD.Naval.Autopilot", 0.25, 0, function()
    if not Naval.SimRunning or Naval.Paused then return end
    local ship = Naval.GetMapShip()
    if not ship or not ship.auto then return end

    local ok, err = xpcall(TickMapShip, debug.traceback, ship)
    if not ok then
        ship.auto = nil
        ErrorNoHalt("[Naval] Autopilot: " .. tostring(err) .. "\n")
    end

    ship.orders = ship.orders or {queue = {}}
    ship.orders.auto = ship.auto
end)

-- Nach Neustart / Code-Update: laufenden Autopiloten wieder aufnehmen
hook.Add("PD.Naval.SimStarted", "PD.Naval.Autopilot", function()
    local ship = Naval.GetMapShip()
    if ship and ship.orders and istable(ship.orders.auto) and ship.state == S.NORMAL then
        ship.auto = ship.orders.auto
        if istable(ship.auto.queue) then
            -- JSON macht aus leeren Listen ggf. Objekte
            local list = {}
            for _, leg in SortedPairs(ship.auto.queue) do list[#list + 1] = leg end
            ship.auto.queue = list
        end
    end
end)

-- Geplanter Kurs (noch nicht gestartet oder laufend) fuer die Systemkarte
function Naval.SetNavPlan(ship, args)
    local legs = {}
    for i, leg in ipairs(istable(args.legs) and args.legs or {}) do
        if i > 12 then break end
        if istable(leg) and (leg.kind == "body" or leg.kind == "point" or leg.kind == "ship") then
            local entry = {kind = leg.kind, name = string.sub(tostring(leg.name or ""), 1, 40)}
            if leg.kind == "point" and istable(leg.pos) then
                entry.pos = {x = tonumber(leg.pos.x) or 0, y = tonumber(leg.pos.y) or 0, z = tonumber(leg.pos.z) or 0}
            else
                entry.id = leg.kind == "ship" and tonumber(leg.id) or tostring(leg.id or "")
            end
            legs[#legs + 1] = entry
        end
    end

    ship.orders = ship.orders or {queue = {}}
    ship.orders.navPlan = #legs > 0 and {
        legs = legs,
        mode = args.mode == "orbit" and "orbit" or "stop",
        speed = math.Clamp(tonumber(args.speed) or 1, 0.1, 1),
        alt = tonumber(args.alt),
    } or nil
    ship.dirty = true
end

-- Ein Ziel aus den Angaben der Systemkarte
local function BuildLeg(ship, args, by)
    local auto = {
        kind = args.kind, mode = args.mode == "orbit" and "orbit" or "stop",
        speed = math.Clamp(tonumber(args.speed) or 1, 0.1, 1), by = by,
    }

    if args.kind == "body" then
        local body = Naval.Bodies[tostring(args.id or "")]
        if not body or body.systemId ~= ship.systemId then return nil, "Unbekannter Himmelskörper" end
        auto.id = body.id
        auto.label = body.name
        if tonumber(args.alt) then auto.alt = math.Clamp(tonumber(args.alt), 0, body.radius * 50 + 1e7) end
    elseif args.kind == "ship" then
        local other = Naval.Ships[tonumber(args.id) or -1]
        if not other or other == ship or other.systemId ~= ship.systemId then return nil, "Unbekanntes Schiff" end
        auto.id = other.id
        auto.label = (not Naval.IdentLevel or Naval.IdentLevel(ship, other) >= 1) and other.name or "Unbekannter Kontakt"
        auto.alt = math.Clamp(tonumber(args.alt) or 5000, 1000, 500000)
        auto.mode = "stop"
    elseif args.kind == "point" then
        local p = istable(args.pos) and {x = tonumber(args.pos.x), y = tonumber(args.pos.y), z = tonumber(args.pos.z) or ship.pos.z}
        if not p or not p.x or not p.y then return nil, "Ungültiger Punkt" end

        -- Punkt in einem Sicherheitsabstand: nach aussen schieben
        for _, body in ipairs(Naval.BodiesBySystem[ship.systemId] or {}) do
            local c = Naval.BodyPos(body, Naval.Bodies)
            local r = Clearance(body)
            if (body.radius or 0) > 0 and V3.Dist(p, c) < r then
                local dir = V3.Sub(p, c)
                if V3.LenSqr(dir) < 1 then dir = {x = 1, y = 0, z = 0} end
                p = V3.Add(c, V3.Scale(V3.Normalize(dir), r * 1.05))
            end
        end

        auto.pos = p
        auto.label = "Wegpunkt"
        auto.mode = "stop"
    elseif args.kind == "jumppoint" then
        local valid, reason = Naval.NavValid(ship)
        if not valid then return nil, reason end
        auto.label = "Sprungpunkt " .. ((Naval.Systems[ship.nav.target] or {}).name or "?")
        auto.mode = "stop"
    else
        return nil, "Unbekanntes Ziel"
    end

    return auto
end

-- Vom Navigationscomputer (sv_naval_stations.lua, Aktion "auto"):
-- ein Ziel oder args.legs = Liste von Zielen (Wegpunkt-Kette)
function Naval.StartAutopilot(ship, args, by)
    if ship.state ~= S.NORMAL then return false, "Nur im Normalflug" end

    local list = istable(args.legs) and args.legs or {args}
    if #list == 0 then return false, "Kein Ziel" end

    local legs = {}
    for i = 1, math.min(#list, 12) do
        local a = istable(list[i]) and list[i] or {}
        a.speed = a.speed or args.speed
        local leg, reason = BuildLeg(ship, a, by)
        if not leg then return false, ("Ziel %d: %s"):format(i, reason or "?") end
        legs[#legs + 1] = leg
    end

    -- Alle ausser dem letzten werden durchflogen
    local names = {}
    for i, leg in ipairs(legs) do
        if i < #legs then
            leg.via = true
            leg.mode = "stop"
        end
        names[#names + 1] = leg.label
    end

    local first = table.remove(legs, 1)
    first.queue = legs
    ship.auto = first
    ship.dirty = true
    ship:Log("nav", by or "", "Autopilot: Kurs auf " .. table.concat(names, " -> "))
    return true
end

Naval.StatusExtras = Naval.StatusExtras or {}
Naval.StatusExtras.navPlan = function(ship)
    return ship.orders and ship.orders.navPlan or nil
end

Naval.StatusExtras.auto = function(ship)
    local auto = ship.auto
    if not auto then return nil end

    local path = {}
    for _, p in ipairs(auto.path or {}) do
        path[#path + 1] = {math.Round(p.x), math.Round(p.y), math.Round(p.z)}
    end

    local remaining = 0
    for i = 2, #(auto.path or {}) do remaining = remaining + V3.Dist(auto.path[i - 1], auto.path[i]) end
    local speed = math.max(ship:Speed(), ship:Stat("maxSpeed") * (auto.speed or 1) * 0.5, 1)

    -- Weitere Ziele der Kette (fuer Anzeige und Restweg)
    local queue = {}
    local last = auto.path and auto.path[#auto.path]
    for _, leg in ipairs(auto.queue or {}) do
        local p = leg.pos
        if leg.kind == "body" and Naval.Bodies[leg.id or ""] then p = Naval.BodyPos(Naval.Bodies[leg.id], Naval.Bodies)
        elseif leg.kind == "ship" and Naval.Ships[leg.id or -1] then p = Naval.Ships[leg.id].pos end
        if p then
            queue[#queue + 1] = {label = leg.label, mode = leg.mode, p = {math.Round(p.x), math.Round(p.y), math.Round(p.z)}}
            if last then remaining = remaining + V3.Dist(last, p) end
            last = p
        end
    end

    local finalMode = auto.mode
    if #(auto.queue or {}) > 0 then finalMode = auto.queue[#auto.queue].mode end

    return {
        label = auto.label, kind = auto.kind, mode = finalMode, arrived = auto.arrived == true,
        path = path, remaining = math.Round(remaining), eta = auto.arrived and 0 or math.Round(remaining / speed),
        speed = auto.speed, queue = queue,
    }
end
