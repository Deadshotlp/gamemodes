--[[
    Naval - Moral der KI-Schiffe (Server, Stufe 3).

    ship.subs.morale 0..100 (Start 75). Jede Sekunde naehert sie sich einem
    Zielwert aus der Lage: Huelle, ausgefallene Subsysteme, Kraefteverhaeltnis
    im Umkreis (Huelle der Verbuendeten gegen die der Feinde), Flotte mit
    Flaggschiff in der Naehe, frischer Schock (Flaggschiff verloren). Sie
    faellt schnell und erholt sich langsam.

    Entscheidungen (aus der KI, Naval.MoraleDecide):
      unter morale_flee       -> Flucht ins naechste System (wenn moeglich)
      unter morale_surrender  -> Kapitulation, wenn Flucht nicht moeglich ist
                                 (Hyperantrieb aus, Abfangfeld, Huelle sehr
                                 schwach)
    Kapituliert: feuert nicht, haelt still, meldet sich per Funk.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3 = Naval.V3
local S = Naval.State

local RANGE = 150000 -- m: Umkreis fuer das Kraefteverhaeltnis

local function Setting(key, default)
    return tonumber(Naval.Settings and Naval.Settings[key]) or default
end

local function HullFrac(ship)
    local max = (ship:Class() or {}).hull or 1
    return math.Clamp((ship.hull or max) / math.max(max, 1), 0, 1)
end

local function Strength(ship)
    return (ship.hull or 0) * ((ship.state == S.DISABLED or (ship.flags and ship.flags.surrendered)) and 0 or 1)
end

function Naval.MoraleTarget(ship)
    local subs = ship.subs or {}
    local target = 85 * math.sqrt(HullFrac(ship))

    -- Ausgefallene Subsysteme
    for id, hp in pairs(subs.hp or {}) do
        if hp <= 0 then target = target - (id == "hyperdrive" and 12 or 7) end
    end

    -- Kraefteverhaeltnis
    local friends, foes = Strength(ship), 0
    for _, other in pairs(Naval.Ships) do
        if other ~= ship and other.systemId == ship.systemId and other.state ~= S.HYPERSPACE and other.state ~= S.DESTROYED
            and V3.Dist(other.pos, ship.pos) <= RANGE then
            local rel = Naval.GetRelation(ship.factionId, other.factionId)
            if rel == Naval.Relation.ALLY then friends = friends + Strength(other)
            elseif rel == Naval.Relation.HOSTILE then foes = foes + Strength(other) end
        end
    end
    if foes > 0 then
        local ratio = friends / foes
        if ratio < 0.4 then target = target - 25
        elseif ratio < 0.8 then target = target - 12
        elseif ratio > 2 then target = target + 10 end
    end

    -- Flotte mit Flaggschiff in der Naehe gibt Halt
    local fleet = Naval.Fleets and Naval.Fleets[ship.fleetId or 0]
    local flag = fleet and Naval.Ships[fleet.flagshipId]
    if flag and flag ~= ship and flag.systemId == ship.systemId then target = target + 8 end

    -- Schock (Flaggschiff verloren o. ae.) klingt ueber 2 Minuten ab
    if (subs.moraleShockUntil or 0) > CurTime() then
        target = target - (subs.moraleShock or 0) * (subs.moraleShockUntil - CurTime()) / 120
    end

    return math.Clamp(target, 0, 100)
end

function Naval.MoraleShock(ship, amount)
    if ship:IsPlayerShip() then return end
    ship.subs = ship.subs or {}
    ship.subs.morale = math.max(0, (ship.subs.morale or 75) - amount)
    ship.subs.moraleShock = amount
    ship.subs.moraleShockUntil = CurTime() + 120
end

function Naval.Surrender(ship, by)
    if ship.flags and ship.flags.surrendered then return end
    ship.flags = ship.flags or {}
    ship.flags.surrendered = true
    ship.fleeing = nil

    if Naval.Combat then
        local subs, sh = Naval.Combat(ship)
        subs.roe = "hold"
        subs.target = nil
        subs.fire = nil
        sh.up = false
    end

    Naval.SetOrders(ship, {}, by or "Kapitulation")
    ship.ctrl.throttle = 0
    ship.dirty = true

    Naval.Event(ship, "surrender", {})
    if Naval.CommsMessage then
        Naval.CommsMessage(ship, "Hier " .. ship.name .. ". Wir kapitulieren! Wir senken die Schilde und stellen das Feuer ein.", "surrender")
    end
    if PD.LOGS and PD.LOGS.Add and not (ship.flags and ship.flags.test) then
        PD.LOGS.Add("Naval", ship.name .. " hat kapituliert", Color(255, 200, 80))
    end
end

-- Aus der KI (CheckFlee in sv_naval_ai.lua)
function Naval.MoraleDecide(ship)
    local morale = ship.subs and ship.subs.morale
    if not morale or (ship.flags and ship.flags.surrendered) then return end

    if morale < Setting("morale_surrender", 12) then
        -- Lieber fliehen, wenn es geht; sonst aufgeben
        if not Naval.AIFlee(ship) then Naval.Surrender(ship) end
    elseif morale < Setting("morale_flee", 30) then
        Naval.AIFlee(ship)
    end
end

timer.Create("PD.Naval.Morale", 1, 0, function()
    if not Naval.SimRunning or Naval.Paused then return end

    for _, ship in pairs(Naval.Ships) do
        if not ship:IsPlayerShip() and ship.state == S.NORMAL and not (ship.flags and ship.flags.surrendered) then
            ship.subs = ship.subs or {}
            local current = ship.subs.morale or 75
            local delta = Naval.MoraleTarget(ship) - current
            ship.subs.morale = math.Clamp(current + math.Clamp(delta, -3, 1.5), 0, 100)
        end
    end
end)
