--[[
    Naval - Kampfstationen des Map-Schiffs (Server).

      PD.Naval.CombatCmd   Client -> Server: Station, Aktion, JSON
        weapons:     target {id}, fire {on}, battery {idx, on}
        shields:     up {on}, ratio {value 0..1}, dist {zone = Gewicht}
        engineering: power {engines, shields, weapons, sensors}

    Zustand fuer die Konsolen: Naval.CombatStatus(ship) haengt am
    Status-Paket (sv_naval_stations.lua, 2 Hz).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3 = Naval.V3

util.AddNetworkString("PD.Naval.CombatCmd")

local function Who(ply) return IsValid(ply) and ply:Nick() or "?" end

local function Notify(ply, text, ok)
    PD.Notify(text, ok and Color(80, 200, 120) or Color(255, 90, 90), false, ply)
end

--------------------------------------------------------------------------------
-- Status
--------------------------------------------------------------------------------

function Naval.CombatStatus(ship)
    if not Naval.Combat then return nil end
    local subs, sh, cc = Naval.Combat(ship)
    local factors, output, sum = Naval.PowerFactors(ship)
    local class = ship:Class() or {}

    local zones = {}
    for _, z in ipairs(Naval.Zones) do
        local cap = cc.shields.perZone * (sh.dist[z] or 1)
        zones[z] = {e = math.Round(sh.zones[z].e), m = math.Round(sh.zones[z].m),
            ce = math.Round(cap * sh.ratio), cm = math.Round(cap * (1 - sh.ratio)), w = sh.dist[z]}
    end

    local systems = {}
    for _, s in ipairs(class.subsystems or {}) do
        systems[#systems + 1] = {id = s.id, hp = math.Round(subs.hp[s.id] or 0), max = s.hp}
    end

    -- Ziel und Feuerloesung je Batterie
    local target = subs.target and Naval.Ships[subs.target]
    local tinfo, dist, zone
    if target and target.systemId == ship.systemId then
        local rel = V3.Sub(target.pos, ship.pos)
        dist = V3.Len(rel)
        zone = Naval.ZoneOf(Naval.Q.RotateVec(Naval.Q.Conj(ship.rot), rel))
        tinfo = {id = target.id, name = target.name, dist = math.Round(dist), zone = zone,
            hull = math.Round((target.hull or 0) / math.max((target:Class() or {}).hull or 1, 1) * 100), state = target.state}
    end

    local batteries = {}
    for i, b in ipairs(cc.weapons) do
        local wt = Naval.WeaponTypes[b.type] or {}
        local inArc = false
        for _, a in ipairs(b.arc or {}) do if a == zone then inArc = true end end

        batteries[i] = {
            type = b.type, name = wt.name or b.type, count = b.count, arc = b.arc,
            ammo = wt.ammo and subs.ammo[i] or nil, maxAmmo = wt.ammo and (b.ammo or 50) or nil,
            on = not subs.off[i], range = wt.range,
            inArc = target and inArc or nil,
            inRange = target and dist <= (wt.range or 0) or nil,
            chance = target and Naval.HitChance(ship, target, wt, dist) or nil,
        }
    end

    return {
        hull = math.Round(ship.hull or 0), hullMax = class.hull or 0,
        up = sh.up, ratio = sh.ratio, zones = zones,
        power = subs.power, factors = factors, output = math.Round(output), sum = sum,
        systems = systems, batteries = batteries, target = tinfo, fire = subs.fire == true,
    }
end

--------------------------------------------------------------------------------
-- Befehle
--------------------------------------------------------------------------------

local Commands = {weapons = {}, shields = {}, engineering = {}}

Commands.weapons.target = function(ply, ship, args)
    local target = Naval.Ships[tonumber(args.id) or -1]
    if not target or target == ship or target.systemId ~= ship.systemId then
        ship.subs.target = nil
        return
    end

    ship.subs.target = target.id
    ship:Log("combat", Who(ply), "Ziel aufgeschaltet: " .. target.name)
end

Commands.weapons.fire = function(ply, ship, args)
    ship.subs.fire = args.on == true
    ship:Log("combat", Who(ply), ship.subs.fire and "Feuer frei" or "Feuer einstellen")
end

Commands.weapons.battery = function(ply, ship, args)
    local idx = tonumber(args.idx)
    if not idx then return end
    ship.subs.off[idx] = (args.on == false) or nil
end

Commands.shields.up = function(ply, ship, args)
    ship.shields.up = args.on == true
    ship:Log("combat", Who(ply), ship.shields.up and "Schilde hoch" or "Schilde gesenkt")
end

Commands.shields.ratio = function(ply, ship, args)
    ship.shields.ratio = math.Clamp(tonumber(args.value) or 0.7, 0, 1)
end

Commands.shields.dist = function(ply, ship, args)
    local weights, sum = {}, 0
    for _, z in ipairs(Naval.Zones) do
        weights[z] = math.Clamp(tonumber(istable(args.dist) and args.dist[z]) or 1, 0.25, 3)
        sum = sum + weights[z]
    end

    -- Summe bleibt 6: Umverteilen, nicht vermehren
    for _, z in ipairs(Naval.Zones) do
        ship.shields.dist[z] = math.Round(weights[z] * 6 / sum, 3)
    end
end

Commands.engineering.power = function(ply, ship, args)
    local values, sum = {}, 0
    for _, sys in ipairs(Naval.PowerSystems) do
        values[sys.id] = math.Clamp(math.Round(tonumber(args[sys.id]) or 25), 0, 60)
        sum = sum + values[sys.id]
    end
    if sum > 125 then Notify(ply, "Höchstens 125 % verteilen") return end

    ship.subs.power = values
end

net.Receive("PD.Naval.CombatCmd", function(_, ply)
    local station = net.ReadString()
    local action = net.ReadString()
    local args = util.JSONToTable(net.ReadString()) or {}

    if (ply.PD_NavalCombatNext or 0) > CurTime() then return end
    ply.PD_NavalCombatNext = CurTime() + 0.15

    local fn = Commands[station] and Commands[station][action]
    if not fn or not Naval.AtStation or not Naval.AtStation(ply, station) then return end

    local ship = Naval.GetMapShip()
    if not ship or not Naval.Combat then return end
    Naval.Combat(ship)

    if ship.state == Naval.State.DISABLED then Notify(ply, "Das Schiff ist kampfunfähig") return end

    fn(ply, ship, args)
    ship.dirty = true
end)
