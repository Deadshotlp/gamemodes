PD.Char = PD.Char or {}

function PD.Char:SaveChar(plyid,tbl)
    if #tbl == 0 then tbl = {} end

    if !file.IsDir("progama057/char", "DATA") then
        file.CreateDir("progama057/char")
    end
    
    if file.Exists("progama057/char/" .. plyid .. ".json", "DATA") then
        file.Delete("progama057/char/" .. plyid .. ".json")
    end
    file.Write("progama057/char/" .. plyid .. ".json", util.TableToJSON(tbl,true))
end

function PD.Char:LoadChar(plyid, wo)
    if not file.IsDir("progama057/char", "DATA") then
        file.CreateDir("progama057/char")
    end

    if file.Exists("progama057/char/" .. plyid .. ".json", "DATA") then
        -- print("Char Daten gefunden (" .. plyid .. " | ".. wo ..")")
        return util.JSONToTable(file.Read("progama057/char/" .. plyid .. ".json", "DATA"))
    else
        print("Char Daten nicht gefunden (" .. plyid .. " | ".. wo ..")")
        return nil
    end
end

function PD.Char:SyncChar(ply, wo)
    local tbl = PD.Char:LoadChar(ply:SteamID64(), wo)

    if tbl then
        net.Start("PD.Char.Synccl")
        net.WriteTable(tbl)
        net.Send(ply)
    else
        net.Start("PD.Char.Synccl")
        net.WriteTable({})
        net.Send(ply)
    end
end

function PD.Char:LoadAllChars()
    local tbl = {}

    if !file.IsDir("progama057/char", "DATA") then
        file.CreateDir("progama057/char")
    end

    for k,v in pairs(file.Find("progama057/char/*.json", "DATA")) do
        local resultString = string.gsub(v, "%.json$", "")
        tbl[resultString] = util.JSONToTable(file.Read("progama057/char/" .. v, "DATA"))
        --print("Char: " .. resultString .. " wurde geladen.")
    end

    return tbl
end

function PD.Char:SetPlayerCharID(ply, setid)
    local tbl = PD.Char:LoadChar(ply:SteamID64(), "SetPlayerCharID")
    local id = string.sub(ply:Nick(),1, 7)

    if setid then
        -- print("SetID: " .. setid)
        -- print("Player: " .. ply)
        ply.CharID = setid
        ply:SetNWString("character_id",setid)
    else
        -- if tbl then
            ply.CharID = id
            ply:SetNWString("character_id",id)
        -- else
        --     ply.CharID = 0
        -- end
    end
end

function PD.Char:GetCharacterID(ply)
    PD.Char:SetPlayerCharID(ply)

    if ply.CharID then
        return ply.CharID
    else
        return nil
    end
end

function PD.Char:GetPlayerCharTBL(ply)
    local tbl = PD.Char:LoadChar(ply:SteamID64(), "GetPlayerCharTBL")
    
    for k, v in pairs(tbl) do
        if v.id == PD.Char:GetCharacterID(ply) then
            return v
        end
    end

    return nil
end

function PD.Char:ChangePlayerJob(ply,jobID)
    local tbl = PD.Char:LoadChar(ply:SteamID64(), "ChangePlayerJob")
    local charID = FindPlayerCharbyName(string.sub(ply:Nick(),9),tbl)
    local jobName, jobTable = PD.JOBS.GetJob(jobID)

    if charID then
        tbl[charID].job = {
            name = jobName,
            model = jobTable.model[1],
            unit = jobTable.unit,
            id = jobName
        }
        PD.Char:SaveChar(ply:SteamID64(),tbl)
        PD.Char:SyncChar(ply, "ChangePlayerJob (Sync)")
    else
        print("Char nicht gefunden.")
    end
end

local playerTimers = {}
function PD.Char:StartTimer(playerSteamID)
    if not playerTimers[playerSteamID] then
        playerTimers[playerSteamID] = RealTime()
    end
end

function PD.Char:GetTimer(playerSteamID)
    if playerTimers[playerSteamID] then
        return true
    else
        return false
    end
end

function PD.Char:StopTimer(playerSteamID)
    if playerTimers[playerSteamID] then
        local elapsedTime = RealTime() - playerTimers[playerSteamID]
        playerTimers[playerSteamID] = nil
        print("Timer gestoppt: " .. elapsedTime)

        if not elapsedTime then
            return 0
        end

        return elapsedTime
    else
        return 0
    end
end

function PD.Char:PlayerSetChar(ply,charid) 
    local Atbl = PD.Char:LoadChar(ply:SteamID64(), "PlayerSetChar")
    local lastplaytime = os.date("%d.%m.%Y %H:%M:%S",os.time())
    local jobName, jobTable = PD.JOBS.GetJob(Atbl[charid].job.id)
    Atbl[charid].lastplaytime = lastplaytime

    if PD.Char:GetTimer(ply:SteamID64()) then
        local t = PD.Char:GetPlayerCharTBL(ply)    
        
        if not t then print("Char nicht gefunden. (PlayerSetChar: Zeile 197)") return end
        
        t.playtime = t.playtime + PD.Char:StopTimer(ply:SteamID64())
        PD.Char:SaveChar(ply:SteamID64(),Atbl)
    else
        print("Timer nicht gefunden. (PlayerSetChar: Zeile 205)")
    end

    PD.Char:StartTimer(ply:SteamID64())

    PD.Char:SaveChar(ply:SteamID64(),Atbl)
    PD.Char:SyncChar(ply, "PlayerSetChar (Sync)")
    
    if ply:IsPlayer() then
        -- if ply:Team() == Atbl[charid].job then
        --     ply:Respawn()
        -- else
            print("Job Change (PlayerSetChar: Zeile 213)")
            ply:changeTeam(Atbl[charid].job.id, true, true)
        -- end
        ply:PDSetMoney(Atbl[charid].money)
        ply:SetNWString("rpname", Atbl[charid].id.." "..Atbl[charid].name)
        PD.Char:SetPlayerCharID(ply,Atbl[charid].id)
        print("Char ID: " .. Atbl[charid].id)
        ply:SetModel(jobTable.model[1])
        ply:SetNWString("character_id",Atbl[charid].id)
        ply:SetJob(jobName, jobTable)

        print(Atbl[charid].name .. " wurde in den Job " .. Atbl[charid].job.name .. " gesetzt.")
    else
        print("Spieler nicht gefunden. (PlayerSetChar: Zeile 220)")
    end 
    
    return Atbl[charid].job.id
end

function PD.Char:PlayerActiveChar(ply)
    local tbl = PD.Char:LoadChar(ply:SteamID64(), "PlayerActiveChar")

    if tbl then
        for k,v in pairs(tbl) do
            if v.id == PD.Char:GetCharacterID(ply) then
                return true
            end
        end
    end

    return false
end

function PD.Char:PlayerSetFaction(ply,factionName, SubFactionName, jobName)
    local tbl = PD.Char:LoadChar(ply:SteamID64(), "SetPlayerFactionTable")

    if not tbl then print("Char nicht gefunden. (PlayerSetFaction: Zeile 201)") return end

    for k,v in pairs(tbl) do
        if v.id == PD.Char:GetCharacterID(ply) then
            v.faction = {
                unit = factionName,
                subunit = SubFactionName,
                job = jobName
            }
        end
    end
end

local PLAYER = FindMetaTable("Player")
function PLAYER:changeTeam(jobID, force)
    print("Test: " .. jobID)
    local jobName, jobTable = PD.JOBS.GetJob(jobID)

    if not jobName then print("Job kann nicht gewechselt werden!!!") return end

    -- if not self:isArrested() and not self:isWanted() and (force or job.vote or self:isCP()) then
        -- self:SetTeam(jobID)
        -- self:applyPlayerClassVars(job)
        -- self:applyPlayerClassFunctions(job)
        -- self:resetViewRoll()
        self:StripWeapons()
        self:UnSpectate()

        if force then
            self:KillSilent()
            self:Spawn()
        end

        self:SetHealth(jobTable.maxhealth or 100)
        self:SetArmor(jobTable.startarmor or 0)
        self:SetMaxHealth(jobTable.maxhealth or 100)
        self:SetMaxArmor(jobTable.maxarmor or 100)
        self:SetJob(jobName, jobTable)

        if self:IsAdmin() or PD.Admin.Ranks[self:GetUserGroup()] then 
            for k, v in SortedPairs(PD.Admin.Equip) do
                self:Give(v)    
            end
        end

        for k, v in SortedPairs(jobTable.equip) do
            self:Give(v)
        end

        if jobTable.model then
            self:SetModel(jobTable.model[1])
        end

    -- end

    hook.Run("PlayerChangedChar", self)
end

function PLAYER:SetJob(jobID, jobTbl)
    self.JobID = jobID
    self.JobTbl = jobTbl
end

function PLAYER:GetJob()
    return self.JobID, self.JobTbl or nil, nil
end

hook.Add("PlayerSpawn", "PD.Char.PlayerSpawnSetJobEquip", function(ply)
    if PD.Char:PlayerActiveChar(ply) then
        local tbl = PD.Char:GetPlayerCharTBL(ply)
        local jobName, jobTable = PD.JOBS.GetJob(tbl.job.id)

        -- if jobName then
        --     ply:SetJob(jobName, jobTable)
        --     ply:StripWeapons()
        --     if ply:IsAdmin() or PD.Admin.Ranks[ply:GetUserGroup()] then 
        --         for k, v in pairs(PD.Admin.Equip) do
        --             ply:Give(v)    
        --         end
        --     end
    
        --     for k, v in pairs(jobTable.equip) do
        --         ply:Give(v)
        --     end
           
        --     if jobTable.model then
        --         ply:SetModel(jobTable.model[1])
        --     end
    
        --     ply:SetHealth(jobTable.maxhealth or 100)
        --     ply:SetArmor(jobTable.startarmor or 0)

        --     return false
        -- end
    end
end)