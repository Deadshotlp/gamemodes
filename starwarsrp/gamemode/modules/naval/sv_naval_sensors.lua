--[[
    Naval - Sensoren des Map-Schiffs (Server).

    Erkennungsstufe je Kontakt (Naval.IdentLevel):
      0  unbekannt      nur Position und Groesse
      1  identifiziert  Name, Klasse, Fraktion, Huelle
      2  genau gescannt Schilde und Subsysteme; Waffenleitstand kann
                        Subsysteme gezielt beschiessen
    Eigene und verbuendete Schiffe (Transponder) sowie Kontakte naeher als
    sensor_ident_range sind automatisch Stufe 1. Jeder Scan an der
    Sensor-Konsole hebt die Stufe um eins; Dauer sensor_scan_time,
    laenger mit Entfernung, kuerzer mit Sensorenergie.

    Hyperraum-Austritte im System werden gemeldet (Ereignis
    contact_arrival, Logbuch).

    Gespeichert in ship.subs.ident = {[id] = Stufe}.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3 = Naval.V3
local S = Naval.State

local function Setting(key, default)
    return tonumber(Naval.Settings and Naval.Settings[key]) or default
end

local function Stored(observer, id)
    local ident = observer.subs and observer.subs.ident
    if not istable(ident) then return 0 end
    return tonumber(ident[id] or ident[tostring(id)]) or 0
end

function Naval.IdentLevel(observer, target)
    if not observer or not target then return 0 end
    if not observer:IsPlayerShip() then return 2 end

    local level = Stored(observer, target.id)
    if level >= 1 then return level end

    if Naval.GetRelation(observer.factionId, target.factionId) == Naval.Relation.ALLY then return 1 end
    if target.systemId == observer.systemId and V3.Dist(target.pos, observer.pos) <= Setting("sensor_ident_range", 15000) then
        return 1
    end

    return 0
end

local function SetIdent(observer, id, level)
    observer.subs.ident = istable(observer.subs.ident) and observer.subs.ident or {}
    observer.subs.ident[tostring(id)] = nil
    observer.subs.ident[id] = level
    observer.dirty = true
end

Naval.SetIdentLevel = SetIdent

local function ScanDuration(ship, target)
    local factor = Naval.PowerFactors and Naval.PowerFactors(ship).sensors or 1
    local dist = V3.Dist(ship.pos, target.pos)
    return Setting("sensor_scan_time", 8) * (1 + dist / 100000) / math.max(factor, 0.2)
end

--------------------------------------------------------------------------------
-- Takt
--------------------------------------------------------------------------------

local pruneAcc = 0

timer.Create("PD.Naval.Sensors", 0.5, 0, function()
    if not Naval.SimRunning or Naval.Paused or not Naval.Combat then return end
    local ship = Naval.GetMapShip()
    if not ship then return end

    local subs = Naval.Combat(ship)
    local range = ship:Stat("sensorRange")

    -- Automatisch erkannt: merken, damit es beim Wegfliegen bleibt
    for _, other in pairs(Naval.Ships) do
        if other ~= ship and other.systemId == ship.systemId and Stored(ship, other.id) == 0
            and Naval.IdentLevel(ship, other) >= 1 and other.state ~= S.HYPERSPACE then
            SetIdent(ship, other.id, 1)
        end
    end

    -- Laufender Scan
    local scan = subs.scan
    if istable(scan) then
        local target = Naval.Ships[scan.id or -1]
        if not target or target.systemId ~= ship.systemId or target.state == S.HYPERSPACE
            or V3.Dist(target.pos, ship.pos) > range or Naval.SubFactor(ship, "sensors") <= 0 then
            subs.scan = nil
            ship:Log("contact", "", "Scan abgebrochen - Kontakt verloren")
        elseif Naval.Now() >= scan.finish then
            local level = math.min(2, Naval.IdentLevel(ship, target) + 1)
            SetIdent(ship, target.id, level)
            subs.scan = nil
            ship:Log("contact", scan.by or "", level >= 2 and ("Genauer Scan: " .. target.name)
                or ("Kontakt identifiziert: " .. target.name .. " (" .. ((target:Class() or {}).name or target.classId) .. ")"))
        end
    end

    -- Alte Eintraege entfernen
    pruneAcc = pruneAcc + 1
    if pruneAcc >= 60 and istable(subs.ident) then
        pruneAcc = 0
        for id in pairs(subs.ident) do
            if not Naval.Ships[tonumber(id) or -1] then subs.ident[id] = nil end
        end
    end
end)

-- Hyperraum-Austritt im System des Map-Schiffs
hook.Add("PD.Naval.Event", "PD.Naval.Sensors", function(ship, kind)
    if kind ~= "jump_exit" or ship:IsPlayerShip() then return end

    local mapShip = Naval.GetMapShip()
    if not mapShip or mapShip.systemId ~= ship.systemId or mapShip.state ~= S.NORMAL then return end
    if ship.flags and ship.flags.hidden then return end

    local dist = V3.Dist(ship.pos, mapShip.pos)
    if dist > mapShip:Stat("sensorRange") then return end

    local known = Naval.IdentLevel(mapShip, ship) >= 1
    Naval.Event(mapShip, "contact_arrival", {id = ship.id, dist = math.Round(dist), name = known and ship.name or nil})
    mapShip:Log("contact", "", ("Hyperraum-Austritt erkannt: %s in %.0f km"):format(known and ship.name or "unbekannter Kontakt", dist / 1000))
end)

--------------------------------------------------------------------------------
-- Konsole
--------------------------------------------------------------------------------

Naval.CombatCommands = Naval.CombatCommands or {}
Naval.CombatCommands.sensors = Naval.CombatCommands.sensors or {}

Naval.CombatCommands.sensors.scan = function(ply, ship, args)
    local target = Naval.Ships[tonumber(args.id) or -1]
    if not target or target == ship or target.systemId ~= ship.systemId then return end

    if V3.Dist(target.pos, ship.pos) > ship:Stat("sensorRange") then
        Naval.Feedback(ply, "Außerhalb der Sensorreichweite")
        return
    end
    if Naval.SubFactor(ship, "sensors") <= 0 then
        Naval.Feedback(ply, "Sensoren ausgefallen")
        return
    end
    if Naval.IdentLevel(ship, target) >= 2 then
        Naval.Feedback(ply, "Kontakt ist bereits genau gescannt")
        return
    end

    local now = Naval.Now()
    ship.subs.scan = {id = target.id, start = now, finish = now + ScanDuration(ship, target), by = ply:Nick()}
end

Naval.CombatCommands.sensors.cancel = function(ply, ship)
    ship.subs.scan = nil
end

-- Status: Erkennungsstufen und Details der sichtbaren Kontakte
Naval.StatusExtras = Naval.StatusExtras or {}
Naval.StatusExtras.sensors = function(ship)
    local subs = ship.subs or {}
    local range = ship:Stat("sensorRange")
    local contacts = {}

    for id, other in pairs(Naval.Ships) do
        if other ~= ship and other.systemId == ship.systemId and other.state ~= S.HYPERSPACE
            and not (other.flags and other.flags.hidden) and V3.Dist(other.pos, ship.pos) <= range
            and not (Naval.Concealed and Naval.Concealed(ship, other)) then
            local level = Naval.IdentLevel(ship, other)
            local c = {level = level, surrendered = other.flags and other.flags.surrendered or nil}

            if level >= 2 and Naval.Combat then
                local osubs, osh, occ = Naval.Combat(other)
                local shield, cap = 0, 0
                for _, z in ipairs(Naval.Zones) do
                    shield = shield + osh.zones[z].e + osh.zones[z].m
                    cap = cap + occ.shields.perZone * (osh.dist[z] or 1)
                end
                c.shield = math.Round(shield / math.max(cap, 1) * 100)
                c.up = osh.up
                c.morale = osubs.morale and math.Round(osubs.morale) or nil
                c.interdictor = other.flags and other.flags.interdictor or nil

                local list = {}
                for _, s in ipairs((other:Class() or {}).subsystems or {}) do
                    list[#list + 1] = {id = s.id, pct = math.Round((osubs.hp[s.id] or 0) / math.max(s.hp or 1, 1) * 100)}
                end
                c.subs = list
            end

            contacts[tostring(id)] = c
        end
    end

    local scan = istable(subs.scan) and {id = subs.scan.id, start = subs.scan.start, finish = subs.scan.finish} or nil
    return {range = math.Round(range), contacts = contacts, scan = scan}
end
