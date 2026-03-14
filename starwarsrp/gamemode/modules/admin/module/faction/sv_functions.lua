PD.List = PD.List or {}
PD.List.Tbl = PD.List.Tbl or {}

function PD.List:LoadFactions()
    local units = PD.JOBS.GetUnit(false, true)
    local allsubunits = PD.JOBS.GetSubUnit(false, true)
    local alljobs = PD.JOBS.GetJob(false, true)
    local allplayers = PD.JSON.Read("modules/factions/players.json")

    for k, unit in SortedPairs(units) do
        PD.List.Tbl[k] = {
            name = k,
            subunits = {},
            jobs = {},
            color = unit.color,
            default = unit.default
        }
    end

    for k, subunit in SortedPairs(allsubunits) do
        -- print("Subunit: " .. k)
        -- PrintTable(subunit)
        PD.List.Tbl[subunit.unit].subunits[k] = {
            name = k,
            unit = subunit.unit,
            jobs = {},
            color = subunit.color,
            maxmembers = subunit.maxmembers,
            default = subunit.default
        }
    end

    local rank = 0
    for k, job in SortedPairs(alljobs) do
        local subunuitName, subunitTable = PD.JOBS.GetSubUnit(job.subunit)

        -- Wenn subunit ändert wird rank zurückgesetzt
        if subunitTable.unit != job.subunit then
            rank = 0
        end

        -- print("Job: " .. k .. " - " .. subunuitName .. " - " .. subunitTable.unit)

        PD.List.Tbl[subunitTable.unit].subunits[subunuitName].jobs[k] = {
            name = k,
            players = {},
            color = job.color,
            default = job.default,
            permissionlevel = job.permissionlevel,
            rank = rank + 1
        }
    end

    for k, v in pairs(allplayers) do
        if PD.List.Tbl[v.unit] and not PD.List.Tbl[v.unit].subunits[v.subunit].jobs[v.job].players[k] then
            PD.List.Tbl[v.unit].subunits[v.subunit].jobs[v.job].players[k] = v
            print("Player: " .. v.name .. " wurde geladen.")
        end
    end
end

hook.Add("PostPDLoaded", "PD.List.LoadFactions", function()
    PD.List:LoadFactions()
end)

hook.Add("PD.JOBS.SaveJob", "FactionsSync", function()
    PD.List:LoadFactions()
end)

timer.Simple(1, function()
    PD.List:LoadFactions()
end)

function PD.List.Save()
    local players = {}

    for _, unit in pairs(PD.List.Tbl) do
        for _, subunit in pairs(unit.subunits) do
            for _, job in pairs(subunit.jobs) do
                for k, v in pairs(job.players) do
                    players[k] = v
                end
            end
        end
    end

    PD.JSON.Write("modules/factions/players.json", players)
end

function PD.List:SetPlayerFaction(ply, factionName, SubFactionName, jobName)
    if !IsValid(ply) then return end
    if !PD.List.Tbl[factionName] then return end
    if !PD.List.Tbl[factionName].subunits[SubFactionName].jobs[jobName] then return end

    local gfactionName, gsubfactionName, gjobName = PD.List:GetPlayerFaction(ply)
    if gfactionName then 
        local gfaction = PD.List.Tbl[gfactionName]
        local gsubfaction = gfaction.subunits[gsubfactionName]
        local gjob = gsubfaction.jobs[gjobName]

        gjob.players[ply:GetCharacterID()] = nil
    end

    local faction = PD.List.Tbl[factionName]
    local subfaction = faction.subunits[SubFactionName]
    local job = subfaction.jobs[jobName]

    if ply:GetCharacterID() == "9999" then 
        PD.Char:SetPlayerCharID(ply)
    end

    if job.players[ply:GetCharacterID()] then return end

    job.players[ply:GetCharacterID()] = {
        name = ply:Nick(),
        steamid = ply:SteamID64(),
        job = jobName,
        subunit = SubFactionName,
        unit = factionName,
        join = os.date("%d.%m.%Y %H:%M:%S", os.time()),
        lastplay = os.date("%d.%m.%Y %H:%M:%S", os.time()),
        playtime = 0
    }

    local jobTable = {}
    local _, sub = PD.JOBS.GetSubUnit(SubFactionName, false)
    jobTable = sub.jobs[jobName] or {}

    PD.List:StartTimer(ply:SteamID64())
    PD.List.Save()

    print(ply:Nick().." joined "..factionName.." - "..SubFactionName.." - "..jobName)
    hook.Run("PD_Faction_Change", ply, factionName, SubFactionName, jobName, jobTable)
end

function PD.List:GetPlayerFaction(ply)
    if !IsValid(ply) then return end

    for factionName, faction in pairs(PD.List.Tbl) do
        for subfactionName, subfaction in pairs(faction.subunits) do
            for jobName, job in pairs(subfaction.jobs) do
                if job.players[ply:GetCharacterID()] then
                    return factionName, subfactionName, jobName
                end
            end
        end
    end
end

function PD.List:RemovePlayerFaction(ply, change)
    if !IsValid(ply) then return end

    local factionName, subfactionName, jobName = PD.List:GetPlayerFaction(ply)

    if !factionName then return end

    local faction = PD.List.Tbl[factionName]
    local subfaction = faction.subunits[subfactionName]
    local job = subfaction.jobs[jobName]

    job.players[ply:GetCharacterID()] = nil

    -- Setzt den Spieler auf die Default Fraktion
    local factionName, subfactionName, jobName = PD.List:SetPlayerDefaultFaction(ply)

    local jobTable = {}
    local _, sub = PD.JOBS.GetSubUnit(subfactionName, false)
    jobTable = sub.jobs[jobName] or {}

    -- PD.List:StopTimer(ply:SteamID64())
    PD.List.Save()

    print(ply:Nick().." left "..factionName.." - "..subfactionName.." - "..jobName)

    hook.Run("PD_Faction_Change", ply, factionName, subfactionName, jobName, jobTable)
end

function PD.List:RankUp(ply, factionName, subfactionName, jobName)
    if !IsValid(ply) then return end
    if !PD.List.Tbl[factionName] then return end
    if !PD.List.Tbl[factionName].subunits[subfactionName] then return end
    if !PD.List.Tbl[factionName].subunits[subfactionName].jobs[jobName] then return end

    local faction = PD.List.Tbl[factionName]
    local subfaction = faction.subunits[subfactionName]
    local job = subfaction.jobs[jobName]

    -- Nächsten Job Finden und Spieler hinzufügen
    for _, nextJob in pairs(subfaction.jobs) do
        if nextJob.permissionlevel == job.permissionlevel + 1 then
            PD.List:SetPlayerFaction(ply, factionName, subfactionName, nextJob.name)
            break
        end
    end

    PD.List.Save()
end

function PD.List:RankDown(ply, factionName, subfactionName, jobName)
    if !IsValid(ply) then return end
    if !PD.List.Tbl[factionName] then return end
    if !PD.List.Tbl[factionName].subunits[subfactionName] then return end
    if !PD.List.Tbl[factionName].subunits[subfactionName].jobs[jobName] then return end

    local faction = PD.List.Tbl[factionName]
    local subfaction = faction.subunits[subfactionName]
    local job = subfaction.jobs[jobName]

    -- Nächsten Job Finden und Spieler hinzufügen
    for _, nextJob in pairs(subfaction.jobs) do
        if nextJob.rank == job.rank - 1 then
            PD.List:SetPlayerFaction(ply, factionName, subfactionName, nextJob.name)
            break
        end
    end

    PD.List.Save()
end

function PD.List:PlayerHasFaction(ply)
    return PD.List:GetPlayerFaction(ply) != nil
end

function PD.List:ChangeFaction(ply, factionName, subfactionName, jobName)
    PD.List:RemovePlayerFaction(ply)
    PD.List:SetPlayerFaction(ply, factionName, subfactionName, jobName)
end

function PD.List:CheckPermissionLevel(ply, factionName, subfactionName, jobName)
    if !IsValid(ply) then return end
    if !PD.List.Tbl[factionName] then return end
    if !PD.List.Tbl[factionName].subunits[subfactionName] then return end
    if !PD.List.Tbl[factionName].subunits[subfactionName].jobs[jobName] then return end

    local faction = PD.List.Tbl[factionName]
    local subfaction = faction.subunits[subfactionName]
    local job = subfaction.jobs[jobName]
    local plyLevel = PD.JOBS.GetJob(jobName).permissionlevel or 0

    if not job.permissionlevel then job.permissionlevel = 0 end

    return job.permissionlevel <= plyLevel
end

function PD.List:SetPlayerDefaultFaction(ply)
    if not IsValid(ply) then return end

    local factionName = PD.JOBS.GetUnit()
    local subfactionName = PD.JOBS.GetSubUnit()
    local jobName = PD.JOBS.GetJob()

    print("SetPlayerDefaultFaction: " .. factionName .. " - " .. subfactionName .. " - " .. jobName)
    
    PD.List:SetPlayerFaction(ply, factionName, subfactionName, jobName)


    return factionName, subfactionName, jobName                    
end

function PD.List:GetPlayerTable(ply)
    if !IsValid(ply) then return end

    local factionName, subfactionName, jobName = PD.List:GetPlayerFaction(ply)

    if !factionName then return end

    local faction = PD.List.Tbl[factionName]
    local subfaction = faction.subunits[subfactionName]
    local job = subfaction.jobs[jobName]

    for k, v in pairs(job.players) do
        if k == ply:GetCharacterID() then
            return v
        end
    end

    return {}
end

timer.Simple(1, function()
    PD.JSON.Create("factions")
end)

local PLAYER = FindMetaTable("Player")
function PLAYER:GetCharacterID()
    return self:GetNWString("character_id","9999")
end

gameevent.Listen("player_disconnect")
hook.Add("PlayerDisconnected", "PD.List.PlayerDisconnected", function(ply)
    local time = PD.List:StopTimer(ply:SteamID64())
    local plyTable = PD.List:GetPlayerTable(ply)

    if not plyTable then return end

    plyTable.playtime = plyTable.playtime + time

    if time > 0 then
        print("Spieler: " .. ply:Nick() .. " war " .. time .. " Sekunden online.")
    end

    PD.List.Save()
end)

hook.Add("ShutDown", "PD.List.ShutDown", function()
    local playerTimers = {}
    for k, v in pairs(playerTimers) do
        local time = PD.List:StopTimer(k:SteamID64())
        local plyTable = PD.List:GetPlayerTable(v)

        plyTable.playtime = plyTable.playtime + time

        if time > 0 then
            print("Spieler: " .. k .. " war " .. time .. " Sekunden online.")
        end


    end

    PD.List.Save()
end)

