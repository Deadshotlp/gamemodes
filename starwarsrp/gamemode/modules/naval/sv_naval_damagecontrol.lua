--[[
    Naval - Schadenskontrolle an Bord des Map-Schiffs (Server).

    Schadenspunkte sind unsichtbare Konsolen (Station damage_point), die ein
    Admin auf der Map verteilt und einem Subsystem zuordnet (Admin-Tab ->
    Konsolen). Bei Huellen- und Subsystemtreffern entstehen dort Schaeden:
      sparks  Kurzschluss        (Schweregrad 1)
      smoke   Rauchentwicklung   (2)
      fire    Brand              (3, verletzt Spieler, frisst das Subsystem
                                  langsam weiter und greift nach
                                  dc_fire_spread Sekunden ueber)
    Spieler beheben sie vor Ort: hinschauen und E halten. Jeder behobene
    Schaden gibt dem Subsystem dc_repair_sub seiner Haltbarkeit zurueck.

    Reparaturtrupps (dc_team_count) arbeiten ohne Spieler langsam an einem
    Subsystem oder der Huelle (Notreparatur bis 50 %); offene Schaeden am
    selben Subsystem bremsen sie auf ein Viertel.

      PD.Naval.Incidents   Server -> Client: offene Schaeden (Effekte)
      CombatCmd damagecontrol assign {team, target}
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval

util.AddNetworkString("PD.Naval.Incidents")

Naval.Incidents = Naval.Incidents or {}
Naval.NextIncidentId = Naval.NextIncidentId or 1

local REPAIR_RANGE = 110
local KIND_INDEX = {sparks = 1, smoke = 2, fire = 3}

local function Setting(key, default)
    local v = Naval.Settings and tonumber(Naval.Settings[key])
    return v or default
end

local function Points()
    local list = {}
    for _, ent in ipairs(ents.FindByClass("pd_naval_console")) do
        if ent:GetStation() == "damage_point" then list[#list + 1] = ent end
    end
    return list
end

local function Busy(ent)
    for _, inc in pairs(Naval.Incidents) do
        if inc.ent == ent then return true end
    end
    return false
end

local function SubMax(ship, id)
    for _, s in ipairs((ship:Class() or {}).subsystems or {}) do
        if s.id == id then return s.hp or 1 end
    end
    return 1
end

local function PointName(ent)
    local label = ent:GetNWString("PD_NavalLabel", "")
    if label ~= "" then return label end
    local sub = ent:GetNWString("PD_NavalSub", "")
    return Naval.SubsystemNames[sub] or (sub == "hull" and "Hülle") or ("Punkt #" .. ent:GetConsoleId())
end

--------------------------------------------------------------------------------
-- Netz
--------------------------------------------------------------------------------

local function Sync()
    local list = {}
    for _, inc in pairs(Naval.Incidents) do
        if IsValid(inc.ent) then list[#list + 1] = inc end
    end

    local recipients = {}
    for _, ply in ipairs(player.GetHumans()) do
        if ply.PD_NavalReady then recipients[#recipients + 1] = ply end
    end
    if #recipients == 0 then return end

    net.Start("PD.Naval.Incidents")
        net.WriteUInt(#list, 8)
        for _, inc in ipairs(list) do
            net.WriteUInt(inc.id, 16)
            net.WriteEntity(inc.ent)
            net.WriteUInt(KIND_INDEX[inc.kind] or 1, 2)
            net.WriteFloat(inc.progress)
        end
    net.Send(recipients)
end

--------------------------------------------------------------------------------
-- Entstehen und Beheben
--------------------------------------------------------------------------------

-- Neuer Schaden an einem freien Punkt (bevorzugt einer mit passendem Subsystem)
function Naval.SpawnIncident(sub, kind, exclude)
    if table.Count(Naval.Incidents) >= Setting("dc_max_incidents", 6) then return nil end

    local matching, free = {}, {}
    for _, ent in ipairs(Points()) do
        if ent ~= exclude and not Busy(ent) then
            free[#free + 1] = ent
            if sub and ent:GetNWString("PD_NavalSub", "") == sub then matching[#matching + 1] = ent end
        end
    end

    local pool = #matching > 0 and matching or free
    local ent = pool[math.random(#pool)]
    if not ent then return nil end

    local id = Naval.NextIncidentId
    Naval.NextIncidentId = id + 1

    local pointSub = ent:GetNWString("PD_NavalSub", "")
    local inc = {
        id = id, ent = ent, kind = kind or "sparks", progress = 0, t0 = CurTime(),
        sub = pointSub ~= "" and pointSub or sub,
        spreadAt = CurTime() + Setting("dc_fire_spread", 90),
    }
    Naval.Incidents[id] = inc

    ent:EmitSound(kind == "fire" and "ambient/fire/ignite.wav" or "ambient/energy/spark" .. math.random(1, 6) .. ".wav", 80)

    local ship = Naval.GetMapShip()
    if ship then
        ship:Log("damage", "", (Naval.IncidentKinds[inc.kind] or {}).name .. ": " .. PointName(ent))
    end

    Sync()
    return inc
end

local function Resolve(inc, players)
    Naval.Incidents[inc.id] = nil

    local ship = Naval.GetMapShip()
    if ship and Naval.Combat then
        local subs = Naval.Combat(ship)
        if inc.sub and subs.hp[inc.sub] ~= nil then
            local max = SubMax(ship, inc.sub)
            subs.hp[inc.sub] = math.min(max, subs.hp[inc.sub] + max * Setting("dc_repair_sub", 0.25))
        end

        local hullMax = (ship:Class() or {}).hull or 1000
        if ship.state ~= Naval.State.DISABLED then
            ship.hull = math.min(hullMax, (ship.hull or 0) + hullMax * 0.01)
        end
        ship.dirty = true

        local names = {}
        for _, ply in ipairs(players or {}) do names[#names + 1] = ply:Nick() end
        ship:Log("damage", table.concat(names, ", "), (Naval.IncidentKinds[inc.kind] or {}).name .. " behoben: "
            .. (IsValid(inc.ent) and PointName(inc.ent) or "?"))
    end

    if IsValid(inc.ent) then inc.ent:EmitSound("buttons/button9.wav", 70) end

    Sync()
end

function Naval.ClearIncidents()
    Naval.Incidents = {}
    Sync()
end

local function RandomKind(heavy)
    local r = math.random()
    if r < (heavy and 0.35 or 0.15) then return "fire" end
    if r < 0.55 then return "smoke" end
    return "sparks"
end

hook.Add("PD.Naval.MapShipHit", "PD.Naval.DamageControl", function(ship, fx)
    if (fx.hull or 0) <= 0 then return end

    local hullMax = (ship:Class() or {}).hull or 1000
    local chance = Setting("dc_incident_chance", 0.35) * math.Clamp(fx.hull / (hullMax * 0.005), 0.3, 2)
    if math.random() < chance then
        Naval.SpawnIncident(nil, RandomKind(fx.hull > hullMax * 0.01))
    end
end)

hook.Add("PD.Naval.SubDamaged", "PD.Naval.DamageControl", function(ship, sub)
    if math.random() < Setting("dc_incident_chance", 0.35) * 0.5 then
        Naval.SpawnIncident(sub, RandomKind(false))
    end
end)

hook.Add("PD.Naval.Repaired", "PD.Naval.DamageControl", function(ship)
    if ship:IsPlayerShip() then Naval.ClearIncidents() end
end)

--------------------------------------------------------------------------------
-- Takt: Spieler reparieren, Feuer, Trupps
--------------------------------------------------------------------------------

local TICK = 0.25
local secondAcc = 0

local function IncidentPos(inc)
    return inc.ent:GetPos() + Vector(0, 0, 12)
end

local function PlayerRepairs()
    local working = {}

    for _, ply in ipairs(player.GetHumans()) do
        if ply:Alive() and ply:KeyDown(IN_USE) then
            local eye, aim = ply:EyePos(), ply:GetAimVector()
            local best, bestD

            for _, inc in pairs(Naval.Incidents) do
                if IsValid(inc.ent) then
                    local to = IncidentPos(inc) - eye
                    local d = to:Length()
                    if d < REPAIR_RANGE and (d < 40 or aim:Dot(to:GetNormalized()) > 0.6) and (not bestD or d < bestD) then
                        best, bestD = inc, d
                    end
                end
            end

            if best then
                working[best.id] = working[best.id] or {}
                table.insert(working[best.id], ply)
            end
        end
    end

    local changed = false
    for id, players in pairs(working) do
        local inc = Naval.Incidents[id]
        local severity = (Naval.IncidentKinds[inc.kind] or {}).severity or 1
        inc.progress = inc.progress + TICK * #players / (Setting("dc_repair_time", 6) * severity)
        changed = true

        if inc.progress >= 1 then Resolve(inc, players) end
    end

    return changed
end

local function EverySecond(ship)
    local subs = Naval.Combat(ship)

    -- Feuer
    for _, inc in pairs(Naval.Incidents) do
        if inc.kind == "fire" and IsValid(inc.ent) then
            local pos = IncidentPos(inc)
            local dmg = Setting("dc_fire_damage", 4)

            if dmg > 0 then
                for _, ply in ipairs(player.GetHumans()) do
                    if ply:Alive() and ply:GetPos():DistToSqr(pos) < 100 * 100 then
                        local info = DamageInfo()
                        info:SetDamage(dmg)
                        info:SetDamageType(DMG_BURN)
                        info:SetAttacker(game.GetWorld())
                        info:SetInflictor(game.GetWorld())
                        ply:TakeDamageInfo(info)
                    end
                end
            end

            if inc.sub and subs.hp[inc.sub] ~= nil then
                subs.hp[inc.sub] = math.max(0, subs.hp[inc.sub] - SubMax(ship, inc.sub) * 0.002)
                ship.dirty = true
            end

            if CurTime() > inc.spreadAt then
                inc.spreadAt = CurTime() + Setting("dc_fire_spread", 90)
                Naval.SpawnIncident(nil, "fire", inc.ent)
            end
        end
    end

    -- Reparaturtrupps
    local count = math.Clamp(math.floor(Setting("dc_team_count", 2)), 0, 8)
    subs.teams = istable(subs.teams) and subs.teams or {}
    local rate = Setting("dc_team_rate", 0.004)

    for i = 1, count do
        local target = subs.teams[i]
        if target == "hull" then
            local hullMax = (ship:Class() or {}).hull or 1000
            if ship.state ~= Naval.State.DISABLED and (ship.hull or 0) < hullMax * 0.5 then
                ship.hull = math.min(hullMax * 0.5, (ship.hull or 0) + hullMax * rate * 0.5)
                ship.dirty = true
            end
        elseif target and subs.hp[target] ~= nil then
            local max = SubMax(ship, target)
            local blocked = false
            for _, inc in pairs(Naval.Incidents) do
                if inc.sub == target then blocked = true break end
            end

            if subs.hp[target] < max then
                subs.hp[target] = math.min(max, subs.hp[target] + max * rate * (blocked and 0.25 or 1))
                ship.dirty = true
            end
        end
    end
end

local syncAcc = 0

timer.Create("PD.Naval.DamageControl", TICK, 0, function()
    if not Naval.SimRunning or Naval.Paused or not Naval.Combat then return end
    local ship = Naval.GetMapShip()
    if not ship then return end

    -- Punkte, die es nicht mehr gibt (Konsolen neu aufgestellt)
    for id, inc in pairs(Naval.Incidents) do
        if not IsValid(inc.ent) then Naval.Incidents[id] = nil end
    end

    local ok, err = xpcall(function()
        local changed = PlayerRepairs()

        secondAcc = secondAcc + TICK
        if secondAcc >= 1 then
            secondAcc = 0
            EverySecond(ship)
        end

        syncAcc = syncAcc + TICK
        if changed or (syncAcc >= 2 and next(Naval.Incidents)) then
            syncAcc = 0
            Sync()
        end
    end, debug.traceback)
    if not ok then ErrorNoHalt("[Naval] Schadenskontrolle: " .. tostring(err) .. "\n") end
end)

hook.Add("PlayerInitialSpawn", "PD.Naval.DamageControl", function()
    timer.Simple(8, Sync)
end)

--------------------------------------------------------------------------------
-- Konsole
--------------------------------------------------------------------------------

Naval.CombatCommands = Naval.CombatCommands or {}
Naval.CombatCommands.damagecontrol = Naval.CombatCommands.damagecontrol or {}

Naval.CombatCommands.damagecontrol.assign = function(ply, ship, args)
    local count = math.Clamp(math.floor(Setting("dc_team_count", 2)), 0, 8)
    local team = tonumber(args.team)
    if not team or team < 1 or team > count then return end

    local subs = ship.subs
    subs.teams = istable(subs.teams) and subs.teams or {}

    local target = tostring(args.target or "")
    if target ~= "hull" and subs.hp[target] == nil then target = nil end
    for i = 1, count do subs.teams[i] = subs.teams[i] or "" end
    subs.teams[team] = target or ""

    ship:Log("damage", ply:Nick(), ("Trupp %d: %s"):format(team, target == "hull" and "Hülle"
        or (target and Naval.SubsystemNames[target] or "Bereitschaft")))
end

Naval.StatusExtras = Naval.StatusExtras or {}
Naval.StatusExtras.dc = function(ship)
    local list = {}
    for _, inc in pairs(Naval.Incidents) do
        if IsValid(inc.ent) then
            list[#list + 1] = {id = inc.id, kind = inc.kind, sub = inc.sub, where = PointName(inc.ent),
                progress = math.Round(inc.progress, 2), age = math.Round(CurTime() - inc.t0)}
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)

    local subs = ship.subs or {}
    return {
        incidents = list,
        teams = subs.teams or {},
        teamCount = math.Clamp(math.floor(Setting("dc_team_count", 2)), 0, 8),
        points = #Points(),
    }
end
