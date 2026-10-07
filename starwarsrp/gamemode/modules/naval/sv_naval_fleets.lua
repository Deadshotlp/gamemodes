--[[
    Naval - Flotten, Formationen, Abfangfeld (Server, Stufe 3).

    Flotte (pd_naval_fleets): Name, Fraktion, Flaggschiff, Formation und in
    der Spalte slots (JSON) Modus und Abstand. Mitglieder: ship.fleetId.

    Mitglieder ohne eigenen Befehl folgen dem Flaggschiff (Naval.FleetStep,
    aus der KI aufgerufen):
      - anderes System: hinterherspringen (Austritt beim Flaggschiff)
      - Flaggschiff faehrt den Hyperantrieb hoch: mitspringen
      - Modus formation: Platz in der Formation halten (gleiche Fahrt und
        Richtung wie das Flaggschiff) und auf dessen Ziel feuern
      - Modus engage: ausschwaermen und angreifen (Ziel des Flaggschiffs,
        sonst naechster Feind)
      - Modus hold: an Ort und Stelle halten
    Das Map-Schiff kann Flaggschiff sein: Begleitschiffe fliegen dann mit der
    Venator und feuern auf das Ziel des Waffenleitstands. Gesteuert ueber die
    Konsole Flottenfuehrung.

    Faellt das Flaggschiff aus, uebernimmt das groesste Schiff der Flotte im
    selben System; alle Mitglieder verlieren Moral.

    Abfangfeld: Schiffe mit flags.interdictor (subs.interdict ~= false)
    verhindern Spruenge feindlicher Schiffe im Umkreis interdict_range und
    ziehen feindliche Spruenge in ihr System zu sich.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3, Q = Naval.V3, Naval.Q
local S = Naval.State
local esc = function(value) return PD.SQL.EscapeString(tostring(value == nil and "" or value)) end

Naval.Fleets = Naval.Fleets or {}

local FORMATION = {}
for _, f in ipairs(Naval.Formations or {}) do FORMATION[f.id] = true end
local MODE = {}
for _, m in ipairs(Naval.FleetModes or {}) do MODE[m.id] = true end

local function Setting(key, default)
    return tonumber(Naval.Settings and Naval.Settings[key]) or default
end

--------------------------------------------------------------------------------
-- Speichern / Laden
--------------------------------------------------------------------------------

function Naval.SaveFleet(fleet)
    local extra = util.TableToJSON({mode = fleet.mode, spacing = fleet.spacing}) or "{}"
    PD.SQL.Query("REPLACE INTO `pd_naval_fleets` (`id`, `server_key`, `name`, `faction_id`, `flagship_id`, `formation`, `slots`) VALUES ("
        .. fleet.id .. ", " .. esc(Naval.DB.ServerKey()) .. ", " .. esc(fleet.name) .. ", " .. esc(fleet.factionId) .. ", "
        .. (tonumber(fleet.flagshipId) or 0) .. ", " .. esc(fleet.formation) .. ", " .. esc(extra) .. ")")
end

function Naval.LoadFleets(callback)
    PD.SQL.FetchAll("SELECT * FROM `pd_naval_fleets` WHERE `server_key` = " .. esc(Naval.DB.ServerKey()), function(rows)
        Naval.Fleets = {}
        for _, row in ipairs(rows or {}) do
            local extra = util.JSONToTable(row.slots or "") or {}
            local fleet = {
                id = tonumber(row.id), name = row.name, factionId = row.faction_id,
                flagshipId = tonumber(row.flagship_id) or 0, formation = FORMATION[row.formation] and row.formation or "line",
                mode = MODE[extra.mode] and extra.mode or "formation", spacing = tonumber(extra.spacing),
            }
            Naval.Fleets[fleet.id] = fleet
        end
        if callback then callback(table.Count(Naval.Fleets)) end
    end)
end

hook.Add("PD.Naval.SimStarted", "PD.Naval.Fleets", function()
    Naval.LoadFleets(function(count)
        if count > 0 then Naval.Log(count .. " Flotten geladen") end
    end)
end)

--------------------------------------------------------------------------------
-- Verwaltung
--------------------------------------------------------------------------------

function Naval.FleetMembers(fleet, includeFlagship)
    local list = {}
    for _, ship in pairs(Naval.Ships) do
        if ship.fleetId == fleet.id and (includeFlagship or ship.id ~= fleet.flagshipId) then list[#list + 1] = ship end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function Naval.CreateFleet(name, flagship)
    local id = 1
    for fid in pairs(Naval.Fleets) do id = math.max(id, fid + 1) end

    local fleet = {id = id, name = (name and name ~= "") and name or ("Flotte " .. id), factionId = flagship.factionId,
        flagshipId = flagship.id, formation = "wedge", mode = "formation"}
    Naval.Fleets[id] = fleet

    if flagship.fleetId and flagship.fleetId > 0 then Naval.FleetRemove(flagship) end
    flagship.fleetId = id
    flagship.dirty = true
    Naval.SaveFleet(fleet)
    Naval.SaveShip(flagship)
    return fleet
end

function Naval.FleetAdd(fleet, ship)
    if ship.fleetId == fleet.id then return end
    if ship.fleetId and ship.fleetId > 0 then Naval.FleetRemove(ship) end

    ship.fleetId = fleet.id
    if not ship:IsPlayerShip() then Naval.SetOrders(ship, {}, "Flotte") end
    ship.dirty = true
    Naval.SaveShip(ship)
end

local function PickFlagship(fleet, near)
    local best, bestHull
    for _, ship in ipairs(Naval.FleetMembers(fleet, true)) do
        if ship.id ~= fleet.flagshipId and ship.state ~= S.DESTROYED and not (ship.flags and ship.flags.surrendered) then
            local hull = ((ship:Class() or {}).hull or 0) + ((near and ship.systemId == near.systemId) and 1e9 or 0)
            if ship:IsPlayerShip() then hull = hull + 1e12 end
            if not bestHull or hull > bestHull then best, bestHull = ship, hull end
        end
    end
    return best
end

function Naval.DeleteFleet(fleet)
    for _, ship in ipairs(Naval.FleetMembers(fleet, true)) do
        ship.fleetId = 0
        ship.dirty = true
    end
    Naval.Fleets[fleet.id] = nil
    PD.SQL.Query("DELETE FROM `pd_naval_fleets` WHERE `server_key` = " .. esc(Naval.DB.ServerKey()) .. " AND `id` = " .. fleet.id)
end

function Naval.FleetRemove(ship)
    local fleet = Naval.Fleets[ship.fleetId or 0]
    ship.fleetId = 0
    ship.fleetJump = nil
    ship.dirty = true
    if not fleet then return end

    if fleet.flagshipId == ship.id then
        local nextFlag = PickFlagship(fleet, ship)
        if nextFlag then
            fleet.flagshipId = nextFlag.id
            Naval.SaveFleet(fleet)
        else
            Naval.DeleteFleet(fleet)
        end
    end
end

function Naval.SetFlagship(fleet, ship)
    Naval.FleetAdd(fleet, ship)
    fleet.flagshipId = ship.id
    Naval.SaveFleet(fleet)
end

--------------------------------------------------------------------------------
-- Formation
--------------------------------------------------------------------------------

local function Spacing(fleet, members, flag)
    if tonumber(fleet.spacing) and fleet.spacing > 0 then return fleet.spacing end
    local len = ((flag:Class() or {}).lengthM or 300) * 0.5
    for _, m in ipairs(members) do len = math.max(len, (m:Class() or {}).lengthM or 300) end
    return len * Setting("fleet_spacing", 2.5)
end

-- Platz k (1..n) der Formation, Schiffsachsen des Flaggschiffs
local function SlotOffset(formation, k, n, s)
    local side = (k % 2 == 1) and 1 or -1
    local rank = math.ceil(k / 2)

    if formation == "column" then
        return {x = -k * s, y = 0, z = 0}
    elseif formation == "wedge" then
        return {x = -rank * s, y = side * rank * s, z = 0}
    elseif formation == "wall" then
        -- Raster quer zur Flugrichtung, Flaggschiff in der Mitte
        local cols = math.max(3, math.ceil(math.sqrt(n + 1)))
        local idx = k
        if idx >= math.floor(cols * cols / 2) + 1 then idx = idx + 1 end -- Mitte freilassen
        local col = (idx - 1) % cols - (cols - 1) / 2
        local row = math.floor((idx - 1) / cols) - (cols - 1) / 2
        return {x = 0, y = col * s, z = -row * s}
    elseif formation == "sphere" then
        -- Fibonacci-Kugel um das Flaggschiff
        local golden = math.pi * (3 - math.sqrt(5))
        local y = 1 - (k - 0.5) / n * 2
        local r = math.sqrt(1 - y * y)
        local a = golden * k
        return {x = math.cos(a) * r * s * 1.5, y = math.sin(a) * r * s * 1.5, z = y * s * 1.5}
    end

    -- line: nebeneinander
    return {x = 0, y = side * rank * s, z = 0}
end

--[[
    Platzvergabe: jedes Schiff bekommt einen moeglichst nahen Platz. Alle
    Paare (Schiff, Platz) nach Abstand sortiert, die kuerzesten zuerst
    vergeben. Neu verteilt wird, wenn sich Mitglieder, Formation oder Abstand
    aendern, sonst alle 5 s - und nur, wenn die neue Verteilung den Gesamtweg
    um mehr als 15 % verkuerzt (sonst springen Schiffe zwischen Plaetzen hin
    und her).
]]
local function SlotPositions(fleet, flag, members)
    local s = Spacing(fleet, members, flag)
    local list = {}
    for k = 1, #members do
        list[k] = V3.Add(flag.pos, Q.RotateVec(flag.rot, SlotOffset(fleet.formation, k, #members, s)))
    end
    return list, s
end

local function TotalDistance(members, slots, assign)
    local total = 0
    for _, m in ipairs(members) do
        local slot = slots[assign[m.id] or 0]
        total = total + (slot and V3.Dist(m.pos, slot) or 1e12)
    end
    return total
end

local function GreedyAssign(members, slots)
    local pairs_ = {}
    for _, m in ipairs(members) do
        for k, slot in ipairs(slots) do
            pairs_[#pairs_ + 1] = {m = m, k = k, d = V3.LenSqr(V3.Sub(m.pos, slot))}
        end
    end
    table.sort(pairs_, function(a, b) return a.d < b.d end)

    local assign, usedSlot = {}, {}
    for _, p in ipairs(pairs_) do
        if not assign[p.m.id] and not usedSlot[p.k] then
            assign[p.m.id] = p.k
            usedSlot[p.k] = true
        end
    end
    return assign
end

local function Assignment(fleet, flag)
    local members = Naval.FleetMembers(fleet)
    local slots, spacing = SlotPositions(fleet, flag, members)

    local ids = {}
    for _, m in ipairs(members) do ids[#ids + 1] = m.id end
    local key = table.concat(ids, ",") .. "|" .. fleet.formation .. "|" .. math.Round(spacing)

    local now = CurTime()
    if fleet.assignKey ~= key or not fleet.assign then
        fleet.assign = GreedyAssign(members, slots)
        fleet.assignKey = key
        fleet.assignAt = now
    elseif now - (fleet.assignAt or 0) > 5 then
        fleet.assignAt = now
        local better = GreedyAssign(members, slots)
        if TotalDistance(members, slots, better) < TotalDistance(members, slots, fleet.assign) * 0.85 then
            fleet.assign = better
        end
    end

    return fleet.assign, slots
end

function Naval.FormationSlot(fleet, ship, flag)
    local assign, slots = Assignment(fleet, flag)
    return slots[assign[ship.id] or 1] or flag.pos
end

-- Abstand zu allen anderen Schiffen im Umkreis: Ausweichgeschwindigkeit weg
-- von zu nahen Schiffen (staerker, je naeher)
local function Separation(ship, maxSpeed)
    local myLen = (ship:Class() or {}).lengthM or 300
    local push = {x = 0, y = 0, z = 0}

    for _, other in pairs(Naval.Ships) do
        if other ~= ship and other.systemId == ship.systemId and other.state ~= S.HYPERSPACE and other.state ~= S.DESTROYED then
            local rel = V3.Sub(ship.pos, other.pos)
            local d = V3.Len(rel)
            local safe = (myLen + ((other:Class() or {}).lengthM or 300)) * 0.75 + 300
            -- Wirkt erst knapp ausserhalb des Sicherheitsabstands, damit sich
            -- Nachbarn in der Formation (2,5 Schiffslaengen) nicht wegdruecken
            local reach = safe * 1.2
            if d < reach and d > 1 then
                local strength = (reach - d) / reach * maxSpeed * 1.2
                push = V3.Add(push, V3.Scale(rel, strength / d))
            end
        end
    end

    return push
end

-- Platz halten: gleiche Fahrt wie das Flaggschiff plus Korrektur zum Platz
local function HoldSlot(ship, flag, slot)
    local err = V3.Sub(slot, ship.pos)
    local d = V3.Len(err)
    local fwd = Q.Forward(flag.rot)
    local flagVel = V3.Scale(fwd, flag:Speed())
    local maxSpeed = math.max(ship:Stat("maxSpeed"), 1)
    local decel = math.max(ship:Stat("decel"), 1)
    local tol = ((ship:Class() or {}).lengthM or 300) + 500

    -- Weit weg: mit Ausweichen um Himmelskoerper zum Platz
    if d > tol * 40 and Naval.AutoSteer then
        Naval.AutoSteer(ship, slot, tol)
        return
    end

    local desired
    if d < tol then
        desired = V3.Add(flagVel, V3.Scale(err, 0.05))
    else
        local approach = math.min(maxSpeed, math.sqrt(2 * decel * 0.8 * d) + 30)
        desired = V3.Add(flagVel, V3.Scale(err, approach / d))
    end

    -- Nicht durch andere Schiffe fliegen
    desired = V3.Add(desired, Separation(ship, maxSpeed))

    local speed = V3.Len(desired)
    if speed < 15 then
        ship.ctrl.autopilot = {dir = fwd}
        ship.ctrl.throttle = 0
    else
        ship.ctrl.autopilot = {dir = desired}
        local _, _, _, angErr = Naval.FaceRates(ship, desired)
        ship.ctrl.throttle = math.Clamp(speed / maxSpeed, 0, 1) * (angErr > 30 and 0.3 or 1)
    end
end

local function Hostile(a, b)
    return Naval.GetRelation(a.factionId, b.factionId) == Naval.Relation.HOSTILE
end

local function Valid(target, ship)
    return target and target.systemId == ship.systemId and target.state ~= S.DESTROYED and target.state ~= S.HYPERSPACE
        and not (target.flags and target.flags.surrendered)
end

local function NearestEnemy(ship, range)
    local best, bestD
    for _, other in pairs(Naval.Ships) do
        if other ~= ship and Valid(other, ship) and other.state ~= S.DISABLED and Hostile(ship, other) then
            local d = V3.Dist(other.pos, ship.pos)
            if d <= range and (not bestD or d < bestD) then best, bestD = other, d end
        end
    end
    return best
end

-- Aus der KI fuer jedes Schiff ohne eigenen Befehl; true = erledigt
function Naval.FleetStep(ship)
    local fleet = Naval.Fleets[ship.fleetId or 0]
    if not fleet then return false end
    if ship.flags and (ship.flags.surrendered or ship.flags.prisoner) then return false end

    local flag = Naval.Ships[fleet.flagshipId]
    if not flag or flag == ship then return false end

    local handlers = Naval.AIHandlers

    -- Flaggschiff springt / ist woanders: hinterher
    local flagLeaving = flag.systemId == ship.systemId and (flag.state == S.SPOOLING or flag.state == S.JUMPING) and flag.hyper and flag.hyper.to
    local dest = flagLeaving and flag.hyper.to or (flag.systemId ~= ship.systemId and flag.state ~= S.HYPERSPACE and flag.systemId)
    if flag.state == S.HYPERSPACE and flag.hyper and flag.hyper.to and flag.hyper.to ~= ship.systemId then dest = flag.hyper.to end

    if dest and dest ~= ship.systemId then
        if not ship.fleetJump or ship.fleetJump.systemId ~= dest then
            ship.fleetJump = {type = "jump", systemId = dest, arriveNear = flag.id, issuedBy = "Flotte " .. fleet.name}
        end
        if handlers.jump(ship, ship.fleetJump) then ship.fleetJump = nil end
        return true
    end

    if ship.state ~= S.NORMAL then return true end
    ship.fleetJump = nil

    local flagTarget = flag.subs and flag.subs.target and Naval.Ships[flag.subs.target]
    if not Valid(flagTarget, ship) then flagTarget = nil end

    if fleet.mode == "hold" then
        handlers.hold(ship)
        if flagTarget and ship.subs and ship.subs.roe ~= "hold" then ship.subs.target = flagTarget.id end
        return true
    end

    if fleet.mode == "engage" then
        local target = flagTarget or NearestEnemy(ship, (Naval.MaxWeaponRange and Naval.MaxWeaponRange(ship) or 30000) * 3)
        if target then
            if ship.subs and ship.subs.roe == "hold" then ship.subs.roe = "return" end
            handlers.attack(ship, {type = "attack", targetId = target.id})
            return true
        end
    end

    -- Formation halten, auf das Ziel des Flaggschiffs feuern
    if flagTarget and ship.subs and ship.subs.roe ~= "hold" then ship.subs.target = flagTarget.id end
    HoldSlot(ship, flag, Naval.FormationSlot(fleet, ship, flag))
    return true
end

-- Flaggschiff verloren
local function FlagshipLost(ship, why)
    local fleet = Naval.Fleets[ship.fleetId or 0]
    if not fleet or fleet.flagshipId ~= ship.id then return end

    local nextFlag = PickFlagship(fleet, ship)
    if not nextFlag then return end

    fleet.flagshipId = nextFlag.id
    Naval.SaveFleet(fleet)

    for _, m in ipairs(Naval.FleetMembers(fleet, true)) do
        if Naval.MoraleShock then Naval.MoraleShock(m, 25) end
    end

    if Naval.CommsMessage then
        local mapShip = Naval.GetMapShip()
        if mapShip and mapShip.systemId == ship.systemId and mapShip ~= nextFlag then
            Naval.CommsMessage(nextFlag, ("%s %s. %s übernimmt das Kommando über %s."):format(ship.name, why, nextFlag.name, fleet.name), "fleet")
        end
    end
    if PD.LOGS and PD.LOGS.Add and not (ship.flags and ship.flags.test) then
        PD.LOGS.Add("Naval", fleet.name .. ": Flaggschiff " .. ship.name .. " " .. why .. ", neues Flaggschiff " .. nextFlag.name, Color(255, 160, 80))
    end
end

hook.Add("PD.Naval.Event", "PD.Naval.Fleets", function(ship, kind)
    if kind == "destroyed" then FlagshipLost(ship, "wurde zerstört")
    elseif kind == "surrender" then FlagshipLost(ship, "hat kapituliert") end
end)

hook.Add("PD.Naval.ShipRemoved", "PD.Naval.Fleets", function(ship)
    local fleet = Naval.Fleets[ship.fleetId or 0]
    if fleet and fleet.flagshipId == ship.id then
        local nextFlag = PickFlagship(fleet, ship)
        if nextFlag then
            fleet.flagshipId = nextFlag.id
            Naval.SaveFleet(fleet)
        else
            Naval.DeleteFleet(fleet)
        end
    end
end)

--------------------------------------------------------------------------------
-- Abfangfeld
--------------------------------------------------------------------------------

local function Interdicting(i)
    return i.flags and i.flags.interdictor and not (i.subs and i.subs.interdict == false)
        and i.state == S.NORMAL and not i.flags.surrendered
end

-- Aktiver feindlicher Abfangkreuzer in Reichweite (oder nil)
function Naval.InterdictorFor(ship)
    local range = Setting("interdict_range", 1000000)
    for _, i in pairs(Naval.Ships) do
        if i ~= ship and i.systemId == ship.systemId and Interdicting(i) and Hostile(i, ship)
            and V3.Dist(i.pos, ship.pos) <= range then
            return i
        end
    end
end

-- Aktiver feindlicher Abfangkreuzer im Zielsystem (zieht Spruenge zu sich)
function Naval.InterdictorIn(systemId, ship)
    for _, i in pairs(Naval.Ships) do
        if i ~= ship and i.systemId == systemId and Interdicting(i) and Hostile(i, ship) then return i end
    end
end

Naval.JumpBlockers = Naval.JumpBlockers or {}
Naval.JumpBlockers.interdiction = function(ship)
    local i = Naval.InterdictorFor(ship)
    if i then
        local known = not Naval.IdentLevel or Naval.IdentLevel(ship, i) >= 1
        return "Abfangfeld aktiv (" .. (known and i.name or "unbekannter Kontakt") .. ")"
    end
end

function Naval.SetInterdictor(ship, on)
    ship.flags = ship.flags or {}
    ship.subs = ship.subs or {}
    if on then
        ship.flags.interdictor = true
        ship.subs.interdict = true
    else
        ship.subs.interdict = false
    end
    ship.dirty = true
end

--------------------------------------------------------------------------------
-- Status fuer die Konsole Flottenfuehrung (Map-Schiff als Flaggschiff)
--------------------------------------------------------------------------------

Naval.StatusExtras = Naval.StatusExtras or {}
Naval.StatusExtras.fleet = function(ship)
    local fleet = Naval.Fleets[ship.fleetId or 0]
    if not fleet then return nil end

    local flag = Naval.Ships[fleet.flagshipId]
    local members = {}
    for _, m in ipairs(Naval.FleetMembers(fleet)) do
        local class = m:Class() or {}
        local entry = {id = m.id, name = m.name, classId = m.classId, state = m.state,
            hull = math.Round((m.hull or 0) / math.max(class.hull or 1, 1) * 100),
            morale = m.subs and m.subs.morale and math.Round(m.subs.morale) or nil,
            surrendered = m.flags and m.flags.surrendered or nil}
        if m.systemId == ship.systemId then
            entry.dist = math.Round(V3.Dist(m.pos, ship.pos))
            if flag and flag.systemId == m.systemId then
                entry.slotDist = math.Round(V3.Dist(m.pos, Naval.FormationSlot(fleet, m, flag)))
            end
        end
        members[#members + 1] = entry
    end

    return {id = fleet.id, name = fleet.name, formation = fleet.formation, mode = fleet.mode,
        spacing = flag and math.Round(Spacing(fleet, Naval.FleetMembers(fleet), flag)) or nil,
        flagship = flag and flag.name, isFlagship = fleet.flagshipId == ship.id, members = members}
end

Naval.StatusExtras.interdict = function(ship)
    local i = Naval.InterdictorFor(ship)
    if not i then return nil end
    local known = not Naval.IdentLevel or Naval.IdentLevel(ship, i) >= 1
    return known and i.name or "unbekannter Kontakt"
end

--------------------------------------------------------------------------------
-- Konsole Flottenfuehrung (nur wenn das Map-Schiff Flaggschiff ist)
--------------------------------------------------------------------------------

Naval.CombatCommands = Naval.CombatCommands or {}
Naval.CombatCommands.fleetcmd = Naval.CombatCommands.fleetcmd or {}
local FC = Naval.CombatCommands.fleetcmd

local function OwnFleet(ply, ship)
    local fleet = Naval.Fleets[ship.fleetId or 0]
    if not fleet or fleet.flagshipId ~= ship.id then
        PD.Notify("Wir führen keine Flotte", Color(255, 90, 90), false, ply)
        return nil
    end
    return fleet
end

FC.formation = function(ply, ship, args)
    local fleet = OwnFleet(ply, ship)
    if not fleet or not FORMATION[args.id or ""] then return end
    fleet.formation = args.id
    Naval.SaveFleet(fleet)
    ship:Log("fleet", ply:Nick(), fleet.name .. ": Formation " .. args.id)
end

FC.mode = function(ply, ship, args)
    local fleet = OwnFleet(ply, ship)
    if not fleet or not MODE[args.id or ""] then return end
    fleet.mode = args.id
    Naval.SaveFleet(fleet)
    ship:Log("fleet", ply:Nick(), fleet.name .. ": " .. args.id)
end

FC.spacing = function(ply, ship, args)
    local fleet = OwnFleet(ply, ship)
    if not fleet then return end
    local current = Spacing(fleet, Naval.FleetMembers(fleet), ship)
    fleet.spacing = math.Clamp(math.Round(current * (tonumber(args.factor) or 1)), 300, 200000)
    Naval.SaveFleet(fleet)
end

FC.roe = function(ply, ship, args)
    local fleet = OwnFleet(ply, ship)
    if not fleet or (args.roe ~= "hold" and args.roe ~= "return" and args.roe ~= "free") then return end
    for _, m in ipairs(Naval.FleetMembers(fleet)) do
        if m.subs then m.subs.roe = args.roe m.dirty = true end
    end
    ship:Log("fleet", ply:Nick(), fleet.name .. ": Feuerbefehl " .. args.roe)
end
