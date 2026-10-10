--[[
    Naval - Kampfstationen des Map-Schiffs (Server).

      PD.Naval.CombatCmd   Client -> Server: Station, Aktion, JSON
        weapons:     target {id}, subtarget {sub}, fire {on}, battery {idx, on}
        shields:     up {on}, ratio {value 0..1}, dist {zone = Gewicht},
                     mod_start, mod_submit {f, p} (Modulation, Minispiel)
        engineering: power {engines, shields, weapons, sensors}
        Weitere Stationen haengen sich an Naval.CombatCommands (Schadens-
        kontrolle, Sensoren, Alarm).

    Zustand fuer die Konsolen: Naval.CombatStatus(ship) haengt am
    Status-Paket (sv_naval_stations.lua, 2 Hz).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3 = Naval.V3

util.AddNetworkString("PD.Naval.CombatCmd")
util.AddNetworkString("PD.Naval.ModGame")

local function Who(ply) return IsValid(ply) and ply:Nick() or "?" end

local function Notify(ply, text, ok)
    Naval.Feedback(ply, text, ok)
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

    local localRel = target and target.systemId == ship.systemId and Naval.Q.RotateVec(Naval.Q.Conj(ship.rot), V3.Sub(target.pos, ship.pos))
    local batteries = {}
    for i, b in ipairs(cc.weapons) do
        local wt = Naval.WeaponTypes[b.type] or {}
        local inArc = false
        local alive, inArcCount

        if b.hps then
            -- Geschuetzstellungen: intakte und im Bogen liegende zaehlen
            alive = 0
            for _, idx in ipairs(b.hps) do
                if (subs.hphp[idx] or 1) > 0 then alive = alive + (tonumber(cc.hardpoints[idx].count) or 1) end
            end
            if localRel then
                inArcCount = Naval.HardpointsInArc(ship, cc, b, localRel)
                inArc = inArcCount > 0
            end
        else
            for _, a in ipairs(b.arc or {}) do if a == zone then inArc = true end end
        end

        batteries[i] = {
            type = b.type, name = b.group or wt.name or b.type, count = b.count, arc = b.arc,
            alive = alive, inArcCount = inArcCount, stations = b.hps and #b.hps or nil,
            ammo = wt.ammo and subs.ammo[i] or nil, maxAmmo = wt.ammo and (b.ammo or 50) or nil,
            on = not subs.off[i], range = wt.range,
            inArc = target and inArc or nil,
            inRange = target and dist <= (wt.range or 0) or nil,
            chance = target and Naval.HitChance(ship, target, wt, dist) or nil,
        }
    end

    local now = Naval.Now()
    local mod = sh.mod or {}

    return {
        hull = math.Round(ship.hull or 0), hullMax = class.hull or 0,
        up = sh.up, ratio = sh.ratio, zones = zones,
        modLeft = (mod.untilT or 0) > now and math.Round(mod.untilT - now) or nil,
        modBlocked = (mod.blockUntil or 0) > now and math.Round(mod.blockUntil - now) or nil,
        targetSub = subs.targetSub,
        power = subs.power, factors = factors, output = math.Round(output), sum = sum,
        systems = systems, batteries = batteries, target = tinfo, fire = subs.fire == true,
    }
end

--------------------------------------------------------------------------------
-- Befehle
--------------------------------------------------------------------------------

Naval.CombatCommands = Naval.CombatCommands or {}
local Commands = Naval.CombatCommands
Commands.weapons = Commands.weapons or {}
Commands.shields = Commands.shields or {}
Commands.engineering = Commands.engineering or {}

Commands.weapons.target = function(ply, ship, args)
    local target = Naval.Ships[tonumber(args.id) or -1]
    if not target or target == ship or target.systemId ~= ship.systemId then
        ship.subs.target = nil
        return
    end

    if ship.subs.target ~= target.id then ship.subs.targetSub = nil end
    ship.subs.target = target.id
    local known = not Naval.IdentLevel or Naval.IdentLevel(ship, target) >= 1
    ship:Log("combat", Who(ply), "Ziel aufgeschaltet: " .. (known and target.name or "unbekannter Kontakt"))
end

-- Subsystem des Ziels gezielt beschiessen (erst nach genauem Scan)
Commands.weapons.subtarget = function(ply, ship, args)
    local target = ship.subs.target and Naval.Ships[ship.subs.target]
    local sub = tostring(args.sub or "")
    if sub == "" or not target then ship.subs.targetSub = nil return end
    if Naval.IdentLevel and Naval.IdentLevel(ship, target) < 2 then Notify(ply, "Ziel erst genau scannen (Sensoren)") return end
    if not Naval.SubsystemNames[sub] then return end

    ship.subs.targetSub = sub
    ship:Log("combat", Who(ply), "Feuer auf " .. Naval.SubsystemNames[sub] .. " von " .. target.name)
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

-- Schildmodulation: der Server legt Frequenz und Phase fest, der Spieler
-- muss seine Welle darauf einstellen (cl_naval_combat_ui.lua).
Commands.shields.mod_start = function(ply, ship)
    local sh = ship.shields
    local now = Naval.Now()
    sh.mod = istable(sh.mod) and sh.mod or {}
    if (sh.mod.blockUntil or 0) > now then
        Notify(ply, ("Modulator kühlt ab (%d s)"):format(sh.mod.blockUntil - now))
        return
    end

    local mg = {f = math.Round(math.Rand(1.5, 8.5), 1), p = math.random(0, 35) * 10, untilT = CurTime() + 30}
    ply.PD_NavalModGame = mg

    net.Start("PD.Naval.ModGame")
    net.WriteFloat(mg.f)
    net.WriteUInt(mg.p, 9)
    net.Send(ply)
end

Commands.shields.mod_submit = function(ply, ship, args)
    local mg = ply.PD_NavalModGame
    ply.PD_NavalModGame = nil
    if not mg or CurTime() > mg.untilT then Notify(ply, "Zeit abgelaufen") return end

    local sh = ship.shields
    sh.mod = istable(sh.mod) and sh.mod or {}
    local df = math.abs((tonumber(args.f) or 0) - mg.f)
    local dp = math.abs(math.AngleDifference(tonumber(args.p) or 0, mg.p))

    if df <= 0.25 and dp <= 20 then
        sh.mod.untilT = Naval.Now() + (Naval.Settings.shield_mod_duration or 90)
        ship:Log("combat", Who(ply), "Schildmodulation angepasst")
        Notify(ply, "Modulation angepasst - Schilde halten mehr aus", true)
    else
        sh.mod.blockUntil = Naval.Now() + (Naval.Settings.shield_mod_cooldown or 20)
        Notify(ply, "Modulation fehlgeschlagen")
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

    if ship.state == Naval.State.DISABLED and (station == "weapons" or station == "shields" or station == "engineering") then
        Notify(ply, "Das Schiff ist kampfunfähig")
        return
    end

    fn(ply, ship, args)
    ship.dirty = true
end)
