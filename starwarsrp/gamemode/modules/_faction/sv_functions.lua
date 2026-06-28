PD.List = PD.List or {}
PD.List.Tbl = PD.List.Tbl or {}

local playerTimers = {}

local function GetJobsTable()
    return PD.JOBS and PD.JOBS.Jobs or {}
end

local function GetSortedJobs(jobs)
    local entries = {}

    for jobIndex, jobData in pairs(jobs or {}) do
        table.insert(entries, {
            index = jobIndex,
            data = jobData
        })
    end

    table.sort(entries, function(a, b)
        local aPos = tonumber(a.data.position) or 999999
        local bPos = tonumber(b.data.position) or 999999

        if aPos == bPos then
            return tostring(a.index) < tostring(b.index)
        end

        return aPos < bPos
    end)

    return entries
end

local function GetFactionPath(unitValue, subValue, jobValue)
    local jobs = GetJobsTable()

    if jobs[unitValue]
        and jobs[unitValue].subunits
        and jobs[unitValue].subunits[subValue]
        and jobs[unitValue].subunits[subValue].jobs
        and jobs[unitValue].subunits[subValue].jobs[jobValue] then
        return unitValue, subValue, jobValue, jobs[unitValue].subunits[subValue].jobs[jobValue]
    end

    for unitIndex, unitData in pairs(jobs) do
        if unitIndex == unitValue or unitData.name == unitValue then
            for subIndex, subData in pairs(unitData.subunits or {}) do
                if subIndex == subValue or subData.name == subValue then
                    if subData.jobs and subData.jobs[jobValue] then
                        return unitIndex, subIndex, jobValue, subData.jobs[jobValue]
                    end

                    for jobIndex, jobData in pairs(subData.jobs or {}) do
                        if jobIndex == jobValue or jobData.name == jobValue then
                            return unitIndex, subIndex, jobIndex, jobData
                        end
                    end
                end
            end
        end
    end

    for unitIndex, unitData in pairs(jobs) do
        for subIndex, subData in pairs(unitData.subunits or {}) do
            for jobIndex, jobData in pairs(subData.jobs or {}) do
                if jobIndex == jobValue or jobData.name == jobValue then
                    return unitIndex, subIndex, jobIndex, jobData
                end
            end
        end
    end
end

local function GetDefaultFactionPath()
    local jobs = GetJobsTable()

    for unitIndex, unitData in pairs(jobs) do
        if unitData.default then
            for subIndex, subData in pairs(unitData.subunits or {}) do
                if subData.default then
                    for jobIndex, jobData in pairs(subData.jobs or {}) do
                        if jobData.default then
                            return unitIndex, subIndex, jobIndex, jobData
                        end
                    end
                end
            end
        end
    end

    local unitIndex, unitData = next(jobs)
    if not unitIndex or not unitData then return end

    local subIndex, subData = next(unitData.subunits or {})
    if not subIndex or not subData then return end

    local jobIndex, jobData = next(subData.jobs or {})
    if not jobIndex or not jobData then return end

    return unitIndex, subIndex, jobIndex, jobData
end

local function GetJobNode(unitIndex, subIndex, jobIndex)
    return PD.List.Tbl[unitIndex]
        and PD.List.Tbl[unitIndex].subunits
        and PD.List.Tbl[unitIndex].subunits[subIndex]
        and PD.List.Tbl[unitIndex].subunits[subIndex].jobs
        and PD.List.Tbl[unitIndex].subunits[subIndex].jobs[jobIndex]
end

local function GetPlayerCharID(ply)
    if not IsValid(ply) then return nil end
    return PD.Char and PD.Char.GetCharacterID and PD.Char:GetCharacterID(ply) or ply:GetNWString("character_id", "9999")
end

function PD.List:LoadFactions()
    PD.List.Tbl = {}

    if PD.JOBS and PD.JOBS.LoadJobs then
        PD.JOBS.LoadJobs()
    end

    local allplayers = PD.JSON and PD.JSON.Read and PD.JSON.Read("factions/players.json") or {}
    allplayers = istable(allplayers) and allplayers or {}

    for unitIndex, unitData in SortedPairs(GetJobsTable()) do
        PD.List.Tbl[unitIndex] = {
            index = unitIndex,
            name = unitData.name or unitIndex,
            color = unitData.color,
            default = unitData.default,
            subunits = {}
        }

        for subIndex, subData in SortedPairs(unitData.subunits or {}) do
            PD.List.Tbl[unitIndex].subunits[subIndex] = {
                index = subIndex,
                name = subData.name or subIndex,
                unit = unitIndex,
                color = subData.color,
                default = subData.default,
                maxmembers = subData.maxmembers,
                jobs = {}
            }

            local rank = 1
            for _, entry in ipairs(GetSortedJobs(subData.jobs or {})) do
                local jobIndex = entry.index
                local jobData = entry.data

                PD.List.Tbl[unitIndex].subunits[subIndex].jobs[jobIndex] = {
                    index = jobIndex,
                    name = jobData.name or jobIndex,
                    players = {},
                    color = jobData.color,
                    default = jobData.default,
                    permissionlevel = tonumber(jobData.permissionlevel) or 0,
                    rank = rank,
                    position = tonumber(jobData.position) or rank
                }

                rank = rank + 1
            end
        end
    end

    for charID, data in pairs(allplayers) do
        local unitIndex, subIndex, jobIndex = GetFactionPath(data.unit, data.subunit, data.job)

        local jobNode = GetJobNode(unitIndex, subIndex, jobIndex)
        if jobNode then
            data.unit = unitIndex
            data.subunit = subIndex
            data.job = jobIndex
            jobNode.players[charID] = {
                name = data.name or charID,
                steamid = data.steamid or "",
                unit = unitIndex,
                subunit = subIndex,
                job = jobIndex,
                join = data.join or os.date("%d.%m.%Y %H:%M:%S", os.time()),
                lastplay = data.lastplay or os.date("%d.%m.%Y %H:%M:%S", os.time()),
                playtime = tonumber(data.playtime) or 0
            }
        end
    end
end

function PD.List.Save()
    local players = {}

    for _, unit in pairs(PD.List.Tbl or {}) do
        for _, subunit in pairs(unit.subunits or {}) do
            for _, job in pairs(subunit.jobs or {}) do
                for charID, data in pairs(job.players or {}) do
                    players[charID] = {
                        name = data.name,
                        steamid = data.steamid,
                        unit = data.unit,
                        subunit = data.subunit,
                        job = data.job,
                        join = data.join,
                        lastplay = data.lastplay,
                        playtime = tonumber(data.playtime) or 0
                    }
                end
            end
        end
    end

    if PD.JSON and PD.JSON.Write then
        PD.JSON.Write("factions/players.json", players)
    end
end

function PD.List:Sync(ply)
    if not IsValid(ply) then return end

    net.Start("PD.List.Sync")
    net.WriteTable(PD.List.Tbl or {})
    net.Send(ply)
end

function PD.List:SyncAll()
    net.Start("PD.List.Sync")
    net.WriteTable(PD.List.Tbl or {})
    net.Broadcast()
end

function PD.List:StartTimer(playerSteamID)
    if not playerTimers[playerSteamID] then
        playerTimers[playerSteamID] = RealTime()
    end
end

function PD.List:GetTimer(playerSteamID)
    return playerTimers[playerSteamID] ~= nil
end

function PD.List:StopTimer(playerSteamID)
    if not playerTimers[playerSteamID] then
        return 0
    end

    local elapsedTime = RealTime() - playerTimers[playerSteamID]
    playerTimers[playerSteamID] = nil

    return elapsedTime or 0
end

function PD.List:GetPlayerFactionByCharID(charID)
    if not charID then return nil end

    for factionIndex, faction in pairs(PD.List.Tbl or {}) do
        for subIndex, subunit in pairs(faction.subunits or {}) do
            for jobIndex, job in pairs(subunit.jobs or {}) do
                if job.players and job.players[charID] then
                    return factionIndex, subIndex, jobIndex, job.players[charID]
                end
            end
        end
    end
end

function PD.List:GetPlayerFaction(ply)
    local charID = GetPlayerCharID(ply)
    if not charID then return nil end
    return PD.List:GetPlayerFactionByCharID(charID)
end

function PD.List:GetPlayerTable(ply)
    local _, _, _, data = PD.List:GetPlayerFaction(ply)
    return data
end

function PD.List:GetPlayerData(ply)
    local unit, subunit, job = PD.List:GetPlayerFaction(ply)
    if unit and subunit and job then
        return unit, subunit, job
    end

    local activeChar = PD.Char and PD.Char.PlayerActiveChar and PD.Char:PlayerActiveChar(ply)
    if activeChar and activeChar.faction then
        return activeChar.faction.unit, activeChar.faction.subunit, activeChar.faction.job
    end
end

function PD.List:RemoveFactionByCharID(charID, setDefault, ply)
    if not charID then return false end

    local factionIndex, subIndex, jobIndex, data = PD.List:GetPlayerFactionByCharID(charID)
    if not factionIndex or not subIndex or not jobIndex then
        return false
    end

    local jobNode = GetJobNode(factionIndex, subIndex, jobIndex)
    if not jobNode or not jobNode.players then
        return false
    end

    if data and data.steamid then
        local savedTime = 0
        if IsValid(ply) then
            savedTime = PD.List:StopTimer(data.steamid)
        else
            savedTime = PD.List:StopTimer(data.steamid)
        end

        if data.playtime then
            data.playtime = data.playtime + savedTime
        end

        data.lastplay = os.date("%d.%m.%Y %H:%M:%S", os.time())
    end

    jobNode.players[charID] = nil

    if setDefault and IsValid(ply) then
        local defaultUnit, defaultSub, defaultJob = PD.List:SetPlayerDefaultFaction(ply)
        PD.List.Save()
        PD.List:SyncAll()
        hook.Run("PD_Faction_Change", ply, defaultUnit, defaultSub, defaultJob)
        return true
    end

    PD.List.Save()
    PD.List:SyncAll()
    return true
end

function PD.List:SetPlayerFaction(ply, factionIndex, subFactionIndex, jobIndex)
    if not IsValid(ply) then return end

    local charID = GetPlayerCharID(ply)
    if not charID or charID == "9999" then
        print("SetPlayerFaction abgebrochen: Kein aktiver Char.")
        return
    end

    local resolvedUnit, resolvedSub, resolvedJob = GetFactionPath(factionIndex, subFactionIndex, jobIndex)
    local jobNode = GetJobNode(resolvedUnit, resolvedSub, resolvedJob)
    if not resolvedUnit or not resolvedSub or not resolvedJob or not jobNode then
        print("SetPlayerFaction: Ziel-Fraktion konnte nicht aufgelöst werden.")
        return
    end

    local _, _, _, oldData = PD.List:GetPlayerFactionByCharID(charID)
    PD.List:RemoveFactionByCharID(charID, false, ply)

    jobNode = GetJobNode(resolvedUnit, resolvedSub, resolvedJob)
    if not jobNode then return end

    local entry = oldData or {}
    entry.name = ply:GetNWString("rpname", ply:Nick())
    entry.steamid = ply:SteamID64()
    entry.unit = resolvedUnit
    entry.subunit = resolvedSub
    entry.job = resolvedJob
    entry.join = entry.join or os.date("%d.%m.%Y %H:%M:%S", os.time())
    entry.lastplay = os.date("%d.%m.%Y %H:%M:%S", os.time())
    entry.playtime = tonumber(entry.playtime) or 0

    jobNode.players[charID] = entry

    PD.List:StartTimer(ply:SteamID64())
    PD.List.Save()
    PD.List:SyncAll()

    hook.Run("PD_Faction_Change", ply, resolvedUnit, resolvedSub, resolvedJob)
end

function PD.List:RankUp(ply, factionIndex, subIndex, jobIndex)
    if not IsValid(ply) then return end

    local currentJob = GetJobNode(factionIndex, subIndex, jobIndex)
    if not currentJob then return end

    local nextJobIndex
    local nextRank = currentJob.rank + 1

    for candidateJobIndex, candidateJob in pairs(PD.List.Tbl[factionIndex].subunits[subIndex].jobs or {}) do
        if candidateJob.rank == nextRank then
            nextJobIndex = candidateJobIndex
            break
        end
    end

    if not nextJobIndex then return end

    PD.List:SetPlayerFaction(ply, factionIndex, subIndex, nextJobIndex)
end

function PD.List:RankDown(ply, factionIndex, subIndex, jobIndex)
    if not IsValid(ply) then return end

    local currentJob = GetJobNode(factionIndex, subIndex, jobIndex)
    if not currentJob then return end

    local nextJobIndex
    local nextRank = currentJob.rank - 1

    for candidateJobIndex, candidateJob in pairs(PD.List.Tbl[factionIndex].subunits[subIndex].jobs or {}) do
        if candidateJob.rank == nextRank then
            nextJobIndex = candidateJobIndex
            break
        end
    end

    if not nextJobIndex then return end

    PD.List:SetPlayerFaction(ply, factionIndex, subIndex, nextJobIndex)
end

function PD.List:PlayerHasFaction(ply)
    return PD.List:GetPlayerFaction(ply) ~= nil
end

function PD.List:ChangeFaction(ply, factionIndex, subIndex, jobIndex)
    PD.List:SetPlayerFaction(ply, factionIndex, subIndex, jobIndex)
end

function PD.List:CheckPermissionLevel(ply, factionIndex, subIndex, jobIndex)
    if not IsValid(ply) then return false end
    if ply:IsAdmin() then return true end

    local actorFaction, actorSub, actorJob = PD.List:GetPlayerFaction(ply)
    if not actorFaction or not actorSub or not actorJob then return false end
    if actorFaction ~= factionIndex or actorSub ~= subIndex then return false end

    local actorJobNode = GetJobNode(actorFaction, actorSub, actorJob)
    local targetJobNode = GetJobNode(factionIndex, subIndex, jobIndex)
    if not actorJobNode or not targetJobNode then return false end

    return tonumber(actorJobNode.rank or 0) > tonumber(targetJobNode.rank or 0) + 1
end

function PD.List:SetPlayerDefaultFaction(ply)
    if not IsValid(ply) then return end

    local unitIndex, subIndex, jobIndex = GetDefaultFactionPath()
    if not unitIndex or not subIndex or not jobIndex then return end

    PD.List:SetPlayerFaction(ply, unitIndex, subIndex, jobIndex)
    return unitIndex, subIndex, jobIndex
end

if PD.JSON and PD.JSON.Create then
    timer.Simple(1, function()
        PD.JSON.Create("factions")
    end)
end

local PLAYER = FindMetaTable("Player")

function PLAYER:GetCharacterID()
    return self.CharID or self:GetNWString("character_id", "9999")
end

hook.Add("PostPDLoaded", "PD.List.LoadFactions.Core", function()
    PD.List:LoadFactions()
end)

hook.Add("PD.JOBS.SaveJob", "PD.List.ReloadFactions.OnJobSave", function()
    PD.List:LoadFactions()
    PD.List:SyncAll()
end)

timer.Simple(1, function()
    PD.List:LoadFactions()
    PD.List:SyncAll()
end)

hook.Add("PlayerDisconnected", "PD.List.PlayerDisconnected.Core", function(ply)
    if not IsValid(ply) then return end

    local data = PD.List:GetPlayerTable(ply)
    if not data then
        PD.List:StopTimer(ply:SteamID64())
        PD.List.Save()
        return
    end

    local time = PD.List:StopTimer(ply:SteamID64())
    data.playtime = (data.playtime or 0) + time
    data.lastplay = os.date("%d.%m.%Y %H:%M:%S", os.time())

    PD.List.Save()
end)

hook.Add("ShutDown", "PD.List.ShutDown.Core", function()
    for _, ply in pairs(player.GetAll()) do
        if not IsValid(ply) then continue end

        local data = PD.List:GetPlayerTable(ply)
        if not data then
            PD.List:StopTimer(ply:SteamID64())
            continue
        end

        local time = PD.List:StopTimer(ply:SteamID64())
        data.playtime = (data.playtime or 0) + time
        data.lastplay = os.date("%d.%m.%Y %H:%M:%S", os.time())
    end

    PD.List.Save()
end)