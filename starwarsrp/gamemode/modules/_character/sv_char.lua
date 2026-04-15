PD.Char = PD.Char or {}

util.AddNetworkString("PD.Char.Create")
util.AddNetworkString("PD.Char.Change")
util.AddNetworkString("PD.Char.Delete")
util.AddNetworkString("PD.Char.Play")
util.AddNetworkString("PD.Char.Synccl")
util.AddNetworkString("PD.Char.Syncsv")
util.AddNetworkString("OpenCharbyDelete")
util.AddNetworkString("PD.Char.Open")
util.AddNetworkString("PD.Char.JobChange")
util.AddNetworkString("PD.Char.SetJobFunction")
util.AddNetworkString("PD.Char.DefaultFaction")

local function GenerateRandomNumber()
    local prefix = string.format("%02d", math.random(10, 99))
    local suffix = string.format("%04d", math.random(1000, 9999))
    return prefix .. "-" .. suffix
end

local function IDCheck(id)
    local tbl = PD.Char:LoadAllChars()

    for _, chars in pairs(tbl or {}) do
        for _, char in pairs(chars or {}) do
            if char.id == id then
                return false
            end
        end
    end

    return true
end

local function GetFirstModel(jobTable)
    if not istable(jobTable) then return nil end
    if istable(jobTable.model) then return jobTable.model[1] end
    if istable(jobTable.models) then return jobTable.models[1] end
    if isstring(jobTable.model) then return jobTable.model end
end

local function GetDefaultJobData()
    local jobs = PD.JOBS and PD.JOBS.Jobs or {}

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

function GetAllPlayerJobs()
    local jobs = {}

    for _, v in pairs(player.GetAll()) do
        local jobID, jobTable = v:GetJob()
        jobs[v:SteamID64()] = {
            jobID = jobID,
            jobTable = jobTable
        }
    end

    return jobs
end

timer.Simple(0.1, function()
    for _, v in pairs(player.GetAll()) do
        if not IsValid(v) then continue end

        local jobID, jobTable = v:GetJob()

        net.Start("PD.Char.SetJobFunction")
        net.WriteEntity(v)
        net.WriteString(jobID or "")
        net.WriteTable(jobTable or {})
        net.WriteTable(GetAllPlayerJobs())
        net.Send(v)
    end
end)

net.Receive("PD.Char.DefaultFaction", function(_, ply)
    if not IsValid(ply) then return end
    if PD.List and PD.List.SetPlayerDefaultFaction then
        PD.List:SetPlayerDefaultFaction(ply)
    end
end)

net.Receive("PD.Char.Create", function(_, ply)
    if not IsValid(ply) then return end

    net.ReadEntity()
    local name = string.Trim(net.ReadString() or "")
    if name == "" then return end

    local id = GenerateRandomNumber()
    while not IDCheck(id) do
        id = GenerateRandomNumber()
    end

    local createDate = os.date("%d.%m.%Y %H:%M:%S", os.time())
    local unitIndex, subIndex, jobIndex, jobTable = GetDefaultJobData()
    if not unitIndex or not subIndex or not jobIndex or not jobTable then
        print("Default Job nicht gefunden. (PD.Char.Create)")
        return
    end

    local chars = PD.Char:LoadChar(ply:SteamID64(), "PD.Char.Create") or {}

    local data = {
        name = name,
        id = id,
        job = {
            name = jobTable.name,
            model = GetFirstModel(jobTable) or "",
            unit = subIndex,
            id = jobIndex
        },
        faction = {
            unit = unitIndex,
            subunit = subIndex,
            job = jobIndex
        },
        money = 0,
        cratedate = createDate,
        lastplaytime = createDate,
        playtime = 0,
        rank = ""
    }

    local oldCharID = PD.Char:GetCharacterID(ply)
    if oldCharID then
        local oldCharIndex = PD.Char:GetCharIndexByID(chars, oldCharID)
        if oldCharIndex and chars[oldCharIndex] then
            chars[oldCharIndex].playtime = (chars[oldCharIndex].playtime or 0) + PD.Char:StopTimer(ply:SteamID64())
            chars[oldCharIndex].lastplaytime = createDate
        else
            PD.Char:StopTimer(ply:SteamID64())
        end
    else
        PD.Char:StopTimer(ply:SteamID64())
    end

    table.insert(chars, data)

    ply.CharID = id
    ply:SetNWString("character_id", id)
    ply:SetNWString("rpname", id .. " " .. name)

    PD.Char:SaveChar(ply:SteamID64(), chars)
    PD.Char:StartTimer(ply:SteamID64())
    PD.Char:SyncChar(ply, "PD.Char.Create")

    ply:changeTeam({
        jobIndex = jobIndex,
        jobsubunitIndex = subIndex,
        jobunitIndex = unitIndex
    }, true)

    ply:SetJob(jobIndex, jobTable)
    ply:SetModel(GetFirstModel(jobTable) or ply:GetModel())

    if PD.List and PD.List.SetPlayerFaction then
        PD.List:SetPlayerFaction(ply, unitIndex, subIndex, jobIndex)
    end

    net.Start("PD.Char.JobChange")
    net.WriteEntity(ply)
    net.WriteString(jobIndex)
    net.WriteTable(jobTable or {})
    net.WriteTable(GetAllPlayerJobs())
    net.Broadcast()

    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("[Char]", "Charakter " .. name .. " (" .. id .. ") wurde erstellt. " .. ply:SteamID64(), Color(0, 255, 0))
    end

    hook.Run("PlayerCreateCharacter", ply, data)
end)

net.Receive("PD.Char.Play", function(_, ply)
    if not IsValid(ply) then return end

    net.ReadEntity()
    local charIndex = net.ReadUInt(32)

    local jobID = PD.Char:PlayerSetChar(ply, charIndex)
    if not jobID then return end

    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("[Char]", "Charakter " .. tostring(ply:GetNWString("rpname", ply:Nick())) .. " (" .. tostring(charIndex) .. ") wurde ausgewählt. " .. ply:SteamID64(), Color(0, 255, 0))
    end
end)

net.Receive("PD.Char.Delete", function(_, ply)
    if not IsValid(ply) then return end

    net.ReadEntity()
    local tblID = net.ReadInt(32)
    local displayName = net.ReadString()

    local chars = PD.Char:LoadChar(ply:SteamID64(), "PD.Char.Delete") or {}
    local deletingChar = chars[tblID]
    if not deletingChar then return end

    local isActiveDeletedChar = PD.Char:GetCharacterID(ply) == deletingChar.id

    hook.Run("PlayerDeleteCharacter", ply, deletingChar)

    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("[Char]", "Charakter " .. deletingChar.id .. " " .. deletingChar.name .. " wurde gelöscht. " .. ply:SteamID64(), Color(255, 0, 0))
    end

    if isActiveDeletedChar then
        deletingChar.playtime = (deletingChar.playtime or 0) + PD.Char:StopTimer(ply:SteamID64())
        deletingChar.lastplaytime = os.date("%d.%m.%Y %H:%M:%S", os.time())
    end

    if PD.List and PD.List.RemoveFactionByCharID then
        PD.List:RemoveFactionByCharID(deletingChar.id, false, ply)
    end

    table.remove(chars, tblID)
    PD.Char:SaveChar(ply:SteamID64(), chars)

    if isActiveDeletedChar then
        ply.CharID = nil
        ply:SetNWString("character_id", "9999")
        ply:SetNWString("rpname", "")

        local unitIndex, subIndex, jobIndex, jobTable = GetDefaultJobData()
        if unitIndex and subIndex and jobIndex and jobTable then
            ply:changeTeam({
                jobIndex = jobIndex,
                jobsubunitIndex = subIndex,
                jobunitIndex = unitIndex
            }, true)

            ply:SetJob(jobIndex, jobTable)
            ply:SetModel(GetFirstModel(jobTable) or ply:GetModel())
        end
    end

    PD.Char:SyncChar(ply, "PD.Char.Delete")

    if isActiveDeletedChar then
        ply:SetNWString("rname", displayName)
    end

    timer.Simple(0.2, function()
        if not IsValid(ply) then return end
        net.Start("OpenCharbyDelete")
        net.Send(ply)
    end)
end)

net.Receive("PD.Char.Syncsv", function(_, ply)
    if not IsValid(ply) then return end

    local openMenu = net.ReadBool()

    PD.Char:SyncChar(ply, "PD.Char.Syncsv")

    if openMenu then
        timer.Simple(0.2, function()
            if not IsValid(ply) then return end
            net.Start("PD.Char.Open")
            net.Send(ply)
        end)
    end
end)

hook.Add("PD_Money_AddMoney", "PD.Char.PlayerWalletChanged", function(ply, amount)
    if not IsValid(ply) then return end

    local charID = PD.Char:GetCharacterID(ply)
    if not charID then return end

    local chars = PD.Char:LoadChar(ply:SteamID64(), "PD_Money_AddMoney")
    if not chars then return end

    local charIndex = PD.Char:GetCharIndexByID(chars, charID)
    if not charIndex or not chars[charIndex] then return end

    chars[charIndex].money = (chars[charIndex].money or 0) + amount
    PD.Char:SaveChar(ply:SteamID64(), chars)
end)

hook.Add("PlayerDisconnected", "PD.Char.PlayerDisconnected", function(ply)
    if not IsValid(ply) then return end

    local charID = PD.Char:GetCharacterID(ply)
    if not charID then
        PD.Char:StopTimer(ply:SteamID64())
        return
    end

    local chars = PD.Char:LoadChar(ply:SteamID64(), "PlayerDisconnected")
    if not chars then
        PD.Char:StopTimer(ply:SteamID64())
        return
    end

    local charIndex = PD.Char:GetCharIndexByID(chars, charID)
    if not charIndex or not chars[charIndex] then
        PD.Char:StopTimer(ply:SteamID64())
        return
    end

    chars[charIndex].playtime = (chars[charIndex].playtime or 0) + PD.Char:StopTimer(ply:SteamID64())
    chars[charIndex].lastplaytime = os.date("%d.%m.%Y %H:%M:%S", os.time())

    PD.Char:SaveChar(ply:SteamID64(), chars)
end)

hook.Add("ShutDown", "PD.Char.ServerDown", function()
    for _, v in pairs(player.GetAll()) do
        if not IsValid(v) then continue end

        local charID = PD.Char:GetCharacterID(v)
        if not charID then
            PD.Char:StopTimer(v:SteamID64())
            continue
        end

        local chars = PD.Char:LoadChar(v:SteamID64(), "ShutDown")
        if not chars then
            PD.Char:StopTimer(v:SteamID64())
            continue
        end

        local charIndex = PD.Char:GetCharIndexByID(chars, charID)
        if not charIndex or not chars[charIndex] then
            PD.Char:StopTimer(v:SteamID64())
            continue
        end

        chars[charIndex].playtime = (chars[charIndex].playtime or 0) + PD.Char:StopTimer(v:SteamID64())
        chars[charIndex].lastplaytime = os.date("%d.%m.%Y %H:%M:%S", os.time())

        PD.Char:SaveChar(v:SteamID64(), chars)
    end
end)

concommand.Add("charprints", function()
    PrintTable(PD.Char:LoadAllChars())
end)

hook.Add("PD_Faction_Change", "PD.Char.FactionChangeSync", function(ply, factionIndex, subfactionIndex, jobIndex)
    if not IsValid(ply) then return end

    local charID = PD.Char:GetCharacterID(ply)
    if not charID then return end

    local ok, _, jobTable = PD.Char:UpdateStoredCharJobData(ply:SteamID64(), charID, factionIndex, subfactionIndex, jobIndex)
    if not ok then
        print("Job Table für Faction Change in sv_char.lua nicht gefunden.")
        return
    end

    if jobTable then
        ply:SetJob(jobIndex, jobTable)
    end

    PD.Char:SyncChar(ply, "PD_Faction_Change")

    net.Start("PD.Char.JobChange")
    net.WriteEntity(ply)
    net.WriteString(jobIndex or "")
    net.WriteTable(jobTable or {})
    net.WriteTable(GetAllPlayerJobs())
    net.Broadcast()
end)

hook.Add("PlayerInitialSpawn", "PD.Char.PlayerInitialSpawn", function(ply)
    local _, _, defaultJobID, defaultJobTbl = GetDefaultJobData()

    if defaultJobID and defaultJobTbl then
        ply:SetJob(defaultJobID, defaultJobTbl)
    end

    ply.CharID = nil
    ply:SetNWString("character_id", "9999")
    ply:SetNWString("rpname", "")
    ply:KillSilent()
end)