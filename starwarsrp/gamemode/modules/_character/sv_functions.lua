PD.Char = PD.Char or {}

function PD.Char:SaveChar(plyid,tbl)
    if #tbl == 0 then tbl = {} end

    if !file.IsDir("modules/char", "DATA") then
        file.CreateDir("modules/char")
    end
    
    if file.Exists("modules/char/" .. plyid .. ".json", "DATA") then
        file.Delete("modules/char/" .. plyid .. ".json")
    end
    file.Write("modules/char/" .. plyid .. ".json", util.TableToJSON(tbl,true))
end

function PD.Char:LoadChar(plyid, wo)
    if not file.IsDir("modules/char", "DATA") then
        file.CreateDir("modules/char")
    end

    if file.Exists("modules/char/" .. plyid .. ".json", "DATA") then
        -- print("Char Daten gefunden (" .. plyid .. " | ".. wo ..")")
        return util.JSONToTable(file.Read("modules/char/" .. plyid .. ".json", "DATA"))
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

    if !file.IsDir("modules/char", "DATA") then
        file.CreateDir("modules/char")
    end

    for k,v in pairs(file.Find("modules/char/*.json", "DATA")) do
        local resultString = string.gsub(v, "%.json$", "")
        tbl[resultString] = util.JSONToTable(file.Read("modules/char/" .. v, "DATA"))
        --print("Char: " .. resultString .. " wurde geladen.")
    end

    return tbl
end

function PD.Char:SetPlayerCharID(ply, setid)
    local tbl = PD.Char:LoadChar(ply:SteamID64(), "SetPlayerCharID")
    local id = false

    if not tbl then
        print("Kein Char Tabel gefunden für SetPlayerCharID")
        return
    end

    for k,v in pairs(tbl) do
        if v.id .. " " .. v.name == ply:Nick() then
            id = v.id
            break
        end
    end

    if setid then
        ply.CharID = setid
        ply:SetNWString("character_id", setid)
    else
        ply.CharID = id
        ply:SetNWString("character_id", id)
    end
end

function PD.Char:GetCharacterID(ply)
    PD.Char:SetPlayerCharID(ply)

    if ply.CharID then
        return ply.CharID
    else
        return false
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

function getRightJob(info)
    local allJobs = PD.JOBS.GetTable()

    for k,v in pairs(allJobs) do
        for sk, sv in pairs(v.subunits) do
            if sk == info.jobsubunit then
                for jk, jv in pairs(sv.jobs) do
                    if jk == info.jobid then
                        return jk, jv
                    end
                end
            end
        end
    end

    return PD.JOBS.GetFallBackJob()
end

function PD.Char:PlayerSetChar(ply,charid) 
    local Atbl = PD.Char:LoadChar(ply:SteamID64(), "PlayerSetChar")
    local lastplaytime = os.date("%d.%m.%Y %H:%M:%S",os.time())
    local jobName, jobTable = getRightJob({
        jobid = Atbl[charid].faction.job,
        jobsubunit = Atbl[charid].faction.subunit,
        jobunit = Atbl[charid].faction.unit
    })
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
    
        ply:changeTeam({
            jobid = Atbl[charid].faction.job,
            jobsubunit = Atbl[charid].faction.subunit,
            jobunit = Atbl[charid].faction.unit
        }, true, true)

        ply.CharID = Atbl[charid].id
        --ply:PDSetMoney(Atbl[charid].money)
        ply:SetNWString("rpname", Atbl[charid].id.." "..Atbl[charid].name)
        PD.Char:SetPlayerCharID(ply,Atbl[charid].id)
        ply:SetModel(jobTable.model[1])
        ply:SetNWString("character_id",Atbl[charid].id)
        ply:SetJob(jobName, jobTable)

        net.Start("PD.Char.JobChange")
            net.WriteEntity(ply)
            net.WriteString(jobName)
            net.WriteTable(jobTable)
        net.Send(ply)

        PD.List:SetFaction(ply, Atbl[charid].faction.unit, Atbl[charid].faction.subunit, Atbl[charid].faction.job)

        -- print(Atbl[charid].name .. " wurde in den Job " .. Atbl[charid].job.name .. " gesetzt.")
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
                return v
            end
        end
    end

    return false
end

local PLAYER = FindMetaTable("Player")
function PLAYER:changeTeam(jobinfo, force)
    -- print("Test: " .. jobID)
    local jobName, jobTable = getRightJob({
        jobid = jobinfo.jobid,
        jobsubunit = jobinfo.jobsubunit,
        jobunit = jobinfo.jobunit
    })

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
        self:SetWalkSpeed(200)
        self:SetRunSpeed(300)
        self:SetJob(jobName, jobTable)
        

        if self:IsAdmin() or PD.Admin.Ranks[self:GetUserGroup()] then 
            for k, v in SortedPairs(PD.Admin.Equip) do
                self:Give(v)    
            end
        end

        for k, v in SortedPairs(jobTable.equip) do
            self:Give(v)
        end

        local name, subunit = PD.JOBS.GetSubUnit(jobTable.unit)

        for k, v in SortedPairs(subunit.equip) do
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
    local fallbackID, fallbackTbl = PD.JOBS.GetJob(false, false)

    self.JobID = self.JobID or fallbackID
    self.JobTbl = self.JobTbl or fallbackTbl

    return self.JobID, self.JobTbl
end

local function PD_SetPlayerPhaseModel(ply)
    local jobName, jobTable = ply:GetJob()
    local mdl = jobTable.model and jobTable.model[1] or CONFIG.BackModel

    ply:SetModel(mdl)
    ply:SetColor(color_white)
    ply:SetMaterial("")
    ply:SetRenderMode(RENDERMODE_NORMAL)
    ply:SetModelScale(1, 0)
    
    if ply.SetBodygroup and ply.PD_Bodygroups then
        for id, val in pairs(ply.PD_Bodygroups) do
            ply:SetBodygroup(id, val)
        end
    end

    
end

hook.Add("PlayerSpawn", "PD.Char.SetModelOnSpawn", function(ply)
    local jobName, jobTable = PD.JOBS.GetJob()

    if jobTable and jobTable.model then
        ply:SetModel(tostring(jobTable.model[1]))
    end

    timer.Simple(0, function()
        if not IsValid(ply) then return end
        PD_SetPlayerPhaseModel(ply)
    end)
end)
