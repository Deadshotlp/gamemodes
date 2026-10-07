--[[
    Naval - Hangar und Staffeln (Server, Stufe 4e).

    Traegerschiffe haben Staffeln (Naval.ClassHangar): Jaeger und Bomber zu
    je 12 Maschinen. Bereit im Hangar: ship.subs.hangar = {fighter = n,
    bomber = n} (Maschinen); draussen: Naval.Squadrons (im Speicher).

    Staffel: {id, carrierId, factionId, systemId, kind, craft (Kommazahl),
    state = launching|active|returning, pos, task = escort|attack|intercept,
    targetId}
      escort     beim Traeger bleiben, Staffeln in 15 km Umkreis abfangen
      attack     Schiff angreifen (Bomber mit Torpedos, Jaeger mit Lasern)
      intercept  feindliche Staffeln im System jagen
    Verluste durch Punktverteidigung der Schiffe in 5 km und feindliche
    Jaeger. Zurueckgerufen landen sie beim Traeger wieder.

    KI-Traeger starten im Gefecht selbst (Jaeger Begleitschutz, Bomber auf
    das Ziel) und holen ihre Staffeln zurueck, wenn 60 s kein Feind da ist.
    Das Map-Schiff steuert der Hangar-Leitstand; springen geht erst, wenn
    alle Staffeln gelandet sind.

      PD.Naval.Squadrons   Server -> Client (2 Hz, unzuverlaessig): Staffeln
                           im System des Map-Schiffs
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3 = Naval.V3
local S = Naval.State

util.AddNetworkString("PD.Naval.Squadrons")

Naval.Squadrons = Naval.Squadrons or {}
Naval.NextSquadronId = Naval.NextSquadronId or 1

local TICK = 0.5
local ENGAGE = 4000   -- m: Kampfentfernung
local PD_RANGE = 5000 -- m: Punktverteidigung der Schiffe

--------------------------------------------------------------------------------
-- Hangar eines Schiffs
--------------------------------------------------------------------------------

function Naval.Hangar(ship)
    ship.subs = ship.subs or {}
    local cap = Naval.ClassHangar(ship:Class())
    local h = istable(ship.subs.hangar) and ship.subs.hangar or nil
    if not h then
        h = {fighter = (cap.fighter or 0) * 12, bomber = (cap.bomber or 0) * 12}
        ship.subs.hangar = h
    end
    ship.subs.hangarOut = istable(ship.subs.hangarOut) and ship.subs.hangarOut or {fighter = 0, bomber = 0}
    return h, cap
end

local function Hostile(a, b)
    return Naval.GetRelation(a, b) == Naval.Relation.HOSTILE
end

local function Out(ship, kind, delta)
    local _ = Naval.Hangar(ship)
    ship.subs.hangarOut[kind] = math.max(0, (ship.subs.hangarOut[kind] or 0) + delta)
    ship.dirty = true
end

function Naval.LaunchSquadron(ship, kind, task, targetId)
    local h = Naval.Hangar(ship)
    local def = Naval.SquadronTypes[kind]
    if not def or (h[kind] or 0) < 1 or ship.state ~= S.NORMAL then return nil end

    local craft = math.min(def.craft, h[kind])
    h[kind] = h[kind] - craft
    Out(ship, kind, craft)

    local id = Naval.NextSquadronId
    Naval.NextSquadronId = id + 1
    local sq = {
        id = id, carrierId = ship.id, factionId = ship.factionId, systemId = ship.systemId, kind = kind,
        craft = craft, state = "launching", t = CurTime() + 8, pos = V3.Copy(ship.pos), vel = V3.New(),
        task = task or "escort", targetId = targetId, launched = craft,
    }
    Naval.Squadrons[id] = sq
    return sq
end

local function Dock(sq, carrier)
    local h = Naval.Hangar(carrier)
    local craft = math.ceil(sq.craft - 0.01)
    h[sq.kind] = (h[sq.kind] or 0) + craft
    Out(carrier, sq.kind, -(sq.launched or craft))
    Naval.Squadrons[sq.id] = nil
end

local function Lose(sq, why)
    local carrier = Naval.Ships[sq.carrierId]
    if carrier then Out(carrier, sq.kind, -(sq.launched or 12)) end
    Naval.Squadrons[sq.id] = nil
    if carrier and carrier:IsPlayerShip() then
        carrier:Log("combat", "", (Naval.SquadronTypes[sq.kind] or {}).name .. " " .. sq.id .. " " .. why)
    end
end

function Naval.RecallSquadron(sq)
    if sq.state ~= "returning" then sq.state = "returning" end
end

--------------------------------------------------------------------------------
-- Takt
--------------------------------------------------------------------------------

local function PDCount(ship)
    local n = 0
    for _, b in ipairs(Naval.ClassCombat(ship:Class(), Naval.HardpointsFor and Naval.HardpointsFor(ship)).weapons) do
        if b.type == "pd" then n = n + (b.count or 0) elseif b.type == "laser" then n = n + (b.count or 0) * 0.3 end
    end
    return n
end

local function ValidShip(s, systemId)
    return s and s.systemId == systemId and s.state ~= S.DESTROYED and s.state ~= S.HYPERSPACE
end

local function NearestEnemySquadron(sq, center, range)
    local best, bestD
    for _, o in pairs(Naval.Squadrons) do
        if o ~= sq and o.systemId == sq.systemId and o.state == "active" and Hostile(sq.factionId, o.factionId) then
            local d = V3.Dist(o.pos, center)
            if d <= range and (not bestD or d < bestD) then best, bestD = o, d end
        end
    end
    return best
end

local function MoveTowards(sq, goal, speed, standoff, dt)
    local rel = V3.Sub(goal, sq.pos)
    local d = V3.Len(rel)
    if d <= (standoff or 0) then
        -- Umkreisen statt stehen
        local side = V3.Cross(V3.Normalize(rel), {x = 0, y = 0, z = 1})
        sq.vel = V3.Scale(side, speed * 0.5)
    else
        sq.vel = V3.Scale(V3.Normalize(rel), math.min(speed, (d - (standoff or 0)) / dt))
    end
    sq.pos = V3.Add(sq.pos, V3.Scale(sq.vel, dt))
end

local function Attacker(sq, carrier)
    -- Fuer Naval.ApplyHit: Lage der Staffel, Rest vom Traeger
    return setmetatable({pos = sq.pos, systemId = sq.systemId, id = sq.carrierId, subs = {}}, {__index = carrier})
end

local function Step(sq, dt)
    local def = Naval.SquadronTypes[sq.kind]
    local carrier = Naval.Ships[sq.carrierId]
    local home = ValidShip(carrier, sq.systemId) and carrier or nil

    if sq.state == "launching" then
        if not home then Lose(sq, "beim Start verloren") return end
        sq.pos = V3.Copy(home.pos)
        if CurTime() >= sq.t then sq.state = "active" end
        return
    end

    -- Ohne Traeger: noch eine Weile weiterkaempfen, dann verloren
    if not home then
        sq.stranded = sq.stranded or CurTime()
        if CurTime() - sq.stranded > 90 then Lose(sq, "ohne Träger verloren") return end
        if sq.state == "returning" then sq.state = "active" sq.task = "intercept" end
    end

    -- Ziel bestimmen
    local goal, standoff, enemySq, targetShip = nil, 0, nil, nil
    if sq.state == "returning" and home then
        goal = home.pos
        if V3.Dist(sq.pos, home.pos) < 1500 then Dock(sq, home) return end
    else
        if sq.task == "attack" then
            local t = Naval.Ships[sq.targetId or -1]
            if ValidShip(t, sq.systemId) and t.state ~= S.DISABLED then targetShip = t else sq.task = "escort" end
        end
        if sq.task == "intercept" then
            enemySq = NearestEnemySquadron(sq, sq.pos, 300000)
            if not enemySq then sq.task = "escort" end
        end
        if sq.task == "escort" then
            enemySq = NearestEnemySquadron(sq, home and home.pos or sq.pos, 15000)
        end

        if targetShip then
            goal, standoff = targetShip.pos, 2000
        elseif enemySq then
            goal, standoff = enemySq.pos, 800
        elseif home then
            goal, standoff = home.pos, 3000
        else
            goal = sq.pos
        end
    end

    MoveTowards(sq, goal, def.speed, standoff, dt)

    if sq.state ~= "active" then return end
    local mult = Naval.Settings.combat_damage_mult or 0.5

    -- Gegen Staffeln
    local foe = enemySq or NearestEnemySquadron(sq, sq.pos, ENGAGE)
    if foe and V3.Dist(foe.pos, sq.pos) <= ENGAGE then
        foe.craft = foe.craft - sq.craft * def.vsCraft * dt * (0.6 + math.random() * 0.8)
    end

    -- Gegen das Zielschiff
    if targetShip and V3.Dist(targetShip.pos, sq.pos) <= ENGAGE and carrier then
        Naval.ApplyHit(targetShip, Attacker(sq, carrier), def.dmgType, sq.craft * def.vsShip * dt * mult)
    end

    -- Verluste durch Punktverteidigung feindlicher Schiffe in der Naehe
    for _, ship in pairs(Naval.Ships) do
        if ValidShip(ship, sq.systemId) and Hostile(sq.factionId, ship.factionId)
            and not (ship.flags and ship.flags.surrendered) and V3.Dist(ship.pos, sq.pos) <= PD_RANGE then
            sq.craft = sq.craft - PDCount(ship) * 0.004 * def.pdHit * dt * (0.5 + math.random())
        end
    end
end

Naval.SquadronStepForTest = Step

-- KI-Traeger: im Gefecht starten, ohne Feind zurueckholen
local function CarrierAI(ship)
    if ship:IsPlayerShip() or ship.state ~= S.NORMAL or (ship.flags and (ship.flags.surrendered or ship.flags.aiOff)) then return end
    local _, cap = Naval.Hangar(ship)
    if (cap.fighter or 0) + (cap.bomber or 0) == 0 then return end

    local target = ship.subs and ship.subs.target and Naval.Ships[ship.subs.target]
    local inCombat = ValidShip(target, ship.systemId) or (ship.lastAttacked or 0) > CurTime() - 30

    if inCombat then
        ship.hangarIdle = nil
        local h = Naval.Hangar(ship)
        if (h.fighter or 0) >= 6 then Naval.LaunchSquadron(ship, "fighter", "escort") end
        if (h.bomber or 0) >= 6 and ValidShip(target, ship.systemId) then Naval.LaunchSquadron(ship, "bomber", "attack", target.id) end
    else
        ship.hangarIdle = ship.hangarIdle or CurTime()
        if CurTime() - ship.hangarIdle > 60 then
            for _, sq in pairs(Naval.Squadrons) do
                if sq.carrierId == ship.id then Naval.RecallSquadron(sq) end
            end
        end
    end
end

local aiAcc = 0
local function Tick()
    for _, sq in pairs(Naval.Squadrons) do
        Step(sq, TICK)
        if Naval.Squadrons[sq.id] and sq.craft <= 0 then
            local carrier = Naval.Ships[sq.carrierId]
            if carrier then Naval.Event(carrier, "squadron_lost", {id = sq.id, kind = sq.kind}) end
            Lose(sq, "vernichtet")
        end
    end

    aiAcc = aiAcc + TICK
    if aiAcc >= 2 then
        aiAcc = 0
        for _, ship in pairs(Naval.Ships) do CarrierAI(ship) end
    end

    -- An die Spieler: Staffeln im System des Map-Schiffs
    local mapShip = Naval.GetMapShip()
    if not mapShip then return end
    local list = {}
    for _, sq in pairs(Naval.Squadrons) do
        if sq.systemId == mapShip.systemId and sq.state ~= "launching" and #list < 120 then list[#list + 1] = sq end
    end

    local recipients = {}
    for _, ply in ipairs(player.GetHumans()) do
        if ply.PD_NavalReady then recipients[#recipients + 1] = ply end
    end
    if #recipients == 0 then return end

    net.Start("PD.Naval.Squadrons", true)
        net.WriteUInt(#list, 8)
        for _, sq in ipairs(list) do
            local rel = V3.Sub(sq.pos, mapShip.pos)
            net.WriteUInt(sq.id, 16)
            net.WriteBool(sq.kind == "bomber")
            net.WriteString(sq.factionId or "")
            net.WriteUInt(math.Clamp(math.ceil(sq.craft), 0, 63), 6)
            net.WriteFloat(rel.x) net.WriteFloat(rel.y) net.WriteFloat(rel.z)
            net.WriteFloat(sq.vel.x) net.WriteFloat(sq.vel.y) net.WriteFloat(sq.vel.z)
        end
    net.Send(recipients)
end

timer.Create("PD.Naval.Hangar", TICK, 0, function()
    if not Naval.SimRunning or Naval.Paused then return end
    local ok, err = xpcall(Tick, debug.traceback)
    if not ok then ErrorNoHalt("[Naval] Hangar: " .. tostring(err) .. "\n") end
end)

-- Nach einem Neustart sind draussen gewesene Staffeln wieder im Hangar
hook.Add("PD.Naval.SimStarted", "PD.Naval.Hangar", function()
    if next(Naval.Squadrons) then return end
    for _, ship in pairs(Naval.Ships) do
        if ship.subs and istable(ship.subs.hangarOut) and istable(ship.subs.hangar) then
            for kind, n in pairs(ship.subs.hangarOut) do
                ship.subs.hangar[kind] = (ship.subs.hangar[kind] or 0) + n
            end
            ship.subs.hangarOut = {fighter = 0, bomber = 0}
        end
    end
end)

hook.Add("PD.Naval.Repaired", "PD.Naval.Hangar", function(ship)
    for id, sq in pairs(Naval.Squadrons) do
        if sq.carrierId == ship.id then Naval.Squadrons[id] = nil end
    end
    if ship.subs then ship.subs.hangar = nil ship.subs.hangarOut = nil end
    Naval.Hangar(ship)
end)

-- Map-Schiff springt erst, wenn alle Staffeln gelandet sind
Naval.JumpBlockers = Naval.JumpBlockers or {}
Naval.JumpBlockers.hangar = function(ship)
    if not ship:IsPlayerShip() then return end
    for _, sq in pairs(Naval.Squadrons) do
        if sq.carrierId == ship.id then return "Staffeln sind noch draußen (Hangar-Leitstand: zurückrufen)" end
    end
end

--------------------------------------------------------------------------------
-- Hangar-Leitstand
--------------------------------------------------------------------------------

Naval.CombatCommands = Naval.CombatCommands or {}
Naval.CombatCommands.hangar = Naval.CombatCommands.hangar or {}
local HC = Naval.CombatCommands.hangar

local TASKS = {}
for _, t in ipairs(Naval.SquadronTasks) do TASKS[t.id] = true end

HC.launch = function(ply, ship, args)
    local kind = Naval.SquadronTypes[args.kind or ""] and args.kind
    local task = TASKS[args.task or ""] and args.task or "escort"
    if not kind then return end
    local target = task == "attack" and ship.subs and ship.subs.target or nil
    if task == "attack" and not target then
        PD.Notify("Kein Ziel aufgeschaltet (Waffenleitstand)", Color(255, 90, 90), false, ply)
        return
    end
    local sq = Naval.LaunchSquadron(ship, kind, task, target)
    if not sq then
        PD.Notify("Keine Maschinen bereit", Color(255, 90, 90), false, ply)
        return
    end
    ship:Log("combat", ply:Nick(), Naval.SquadronTypes[kind].name .. " " .. sq.id .. " startet")
end

HC.task = function(ply, ship, args)
    local sq = Naval.Squadrons[tonumber(args.id) or -1]
    if not sq or sq.carrierId ~= ship.id or not TASKS[args.task or ""] then return end
    if args.task == "attack" then
        local target = ship.subs and ship.subs.target
        if not target then PD.Notify("Kein Ziel aufgeschaltet (Waffenleitstand)", Color(255, 90, 90), false, ply) return end
        sq.targetId = target
    end
    sq.task = args.task
    if sq.state == "returning" then sq.state = "active" end
end

HC.recall = function(ply, ship, args)
    for _, sq in pairs(Naval.Squadrons) do
        if sq.carrierId == ship.id and (args.all or sq.id == tonumber(args.id)) then Naval.RecallSquadron(sq) end
    end
end

Naval.StatusExtras = Naval.StatusExtras or {}
Naval.StatusExtras.hangar = function(ship)
    local h, cap = Naval.Hangar(ship)
    if (cap.fighter or 0) + (cap.bomber or 0) == 0 then return nil end

    local active = {}
    for _, sq in pairs(Naval.Squadrons) do
        if sq.carrierId == ship.id then
            local target = sq.targetId and Naval.Ships[sq.targetId]
            active[#active + 1] = {id = sq.id, kind = sq.kind, craft = math.ceil(sq.craft), state = sq.state, task = sq.task,
                target = target and target.name or nil, dist = math.Round(V3.Dist(sq.pos, ship.pos))}
        end
    end
    table.sort(active, function(a, b) return a.id < b.id end)

    return {ready = {fighter = h.fighter or 0, bomber = h.bomber or 0},
        max = {fighter = (cap.fighter or 0) * 12, bomber = (cap.bomber or 0) * 12}, active = active}
end
