PD.Char = PD.Char or {}

util.AddNetworkString("PD.Char.Create")
util.AddNetworkString("PD.Char.Change")
util.AddNetworkString("PD.Char.Delete")
util.AddNetworkString("PD.Char.Play")
util.AddNetworkString("PD.Char.Synccl")
util.AddNetworkString("PD.Char.Syncsv")
util.AddNetworkString("PD.Char.AdminSync")
util.AddNetworkString("PD.Char.AdminSave")
util.AddNetworkString("PD.Char.AdminDelete")
util.AddNetworkString("OpenCharbyDelete")
util.AddNetworkString("PD.Char.Open")
util.AddNetworkString("PD.Char.JobChange")
util.AddNetworkString("PD.Char.SetJobFunction")

-- Funktion zur Generierung einer Zufallszahl im Format XX-XXXX
local function GenerateRandomNumber()
    local prefix = string.format("%02d", math.random(10, 99))
    local suffix = string.format("%04d", math.random(1000, 9999))
    return prefix .. "-" .. suffix
end

local function IDCheck(id)
    local tbl = PD.Char:LoadAllChars()

    for k,v in pairs(tbl) do
        for i,j in pairs(v) do
            if j.id == id then
                return false
            end
        end
    end
    return true
end

net.Receive("PD.Char.Create",function()
    local ply = net.ReadEntity()
    local name = net.ReadString()
    local id = GenerateRandomNumber()
    local create = os.date("%d.%m.%Y %H:%M:%S", os.time())
    local jobName, jobTable = PD.JOBS.GetJob(false, false)
        

    if jobName then
        local data = {
            name = name,
            id = id,
            job = {
                name = jobName,
                model = jobTable.model[1],
                unit = jobTable.unit,
                id = jobName
            },
            faction = {
                unit = "",
                subunit = "",
                job = ""
            },
            money = 0,
            cratedate = create,
            lastplaytime = create,
            playtime = 0,
            rank = ""
        }

        if not IDCheck(id) then
            id = GenerateRandomNumber()
        end
        
        local Atbl = PD.Char:LoadChar(ply:SteamID64(), "PD.Char.Create")

        if Atbl then
            table.insert(Atbl,data)
        else
            Atbl = {}
            table.insert(Atbl,data)
        end

        PD.Char:SaveChar(ply:SteamID64(),Atbl)

        if ply:IsPlayer() then
            print("Job Change | PD.Char.Create | Zeile 48")
            ply:changeTeam(jobName, true)
           
            ply:SetNWString("rpname",id.." "..name)
            PD.Char:SetPlayerCharID(ply,id)
            print("CharID bei erstellung: " .. id)
            ply:PDSetMoney(0)
            ply:SetModel(jobTable.model[1])
            ply:SetNWString("character_id",id)
            PD.Char:StartTimer(ply:SteamID64())
            ply:SetJob(jobName, jobTable)

            net.Start("PD.Char.JobChange")
                net.WriteEntity(ply)
                net.WriteString(jobName)
                net.WriteTable(jobTable)
            net.Broadcast()

            PD.List:SetPlayerDefaultFaction(ply)
            print(name .. " wurde in den Job " .. jobName .. " gesetzt.")
        else
            print("Spieler nicht gefunden. (PD.Char.Create: Zeile 180)")
        end

        hook.Run("PlayerCreateCharacter", ply, data)
    else
        print("Job-ID nicht gefunden. (PD.Char.Create: Zeile 185)")
    end

    PD.Char:SyncChar(ply, "PD.Char.Create")
end)

net.Receive("PD.Char.Play",function()
    local ply = net.ReadEntity()
    local id = net.ReadUInt(32)

    local jobID = PD.Char:PlayerSetChar(ply,id)

    hook.Run("PlayerSetCharacter", ply, jobID)
end)

net.Receive("PD.Char.Delete",function()
    local ply = net.ReadEntity()
    local tblID = net.ReadUInt(32)
    local name = net.ReadString()

    local Atbl = PD.Char:LoadChar(ply:SteamID64(), "Delete Char")

    hook.Run("PlayerDeleteCharacter", ply, Atbl[tblID])

    if PD.Char:PlayerActiveChar(ply) then
        table.remove(Atbl,tblID)
        ply:KillSilent()

        PD.Char:SaveChar(ply:SteamID64(),Atbl)
        PD.Char:SyncChar(ply, "PD.Char.Delete")

        ply:changeTeam(1, true)
        ply:SetNWString("rname",name)

        timer.Simple(0.5,function()
            net.Start("OpenCharbyDelete")
            net.Send(ply)
        end)
    else
        table.remove(Atbl,tblID)
        PD.Char:SaveChar(ply:SteamID64(),Atbl)

        timer.Simple(0.5,function()
            net.Start("OpenCharbyDelete")
            net.Send(ply)
        end)
    end
end)

net.Receive("PD.Char.Syncsv",function(len,ply)
    local b = net.ReadBool()

    PD.Char:SyncChar(ply, "PD.Char.Syncsv")

    if b then
        timer.Simple(1,function()
            net.Start("PD.Char.Open")
            net.Send(ply)
        end)
    end
end)

net.Receive("PD.Char.AdminSave",function()
    local plyid = net.ReadString()
    local charid = net.ReadUInt(32)
    local id = net.ReadString()
    local name = net.ReadString()
    local job = net.ReadString()
    local money = net.ReadUInt(32)
    local jobName, jobTable = PD.JOBS.GetJob(job, false)

    local tbl = PD.Char:LoadChar(plyid, "AdminSave")

    if tbl then
        tbl[charid].id = id
        tbl[charid].name = name
        tbl[charid].job = {
            name = jobName,
            model = jobTable.model[1],
            unit = jobTable.unit,
            id = jobName
        }
        tbl[charid].money = money

        PD.Char:SaveChar(plyid,tbl)
    end
end)

net.Receive("PD.Char.AdminSync",function(len,ply)
    local tbl = PD.Char:LoadAllChars()

    -- print("AdminSync")
    -- PrintTable(tbl)

    net.Start("PD.Char.AdminSync")
    net.WriteTable(tbl)
    net.Send(ply)
end)

net.Receive("PD.Char.AdminDelete",function(len,ply)
    local plyid = net.ReadString()
    local charid = net.ReadUInt(32)

    local tbl = PD.Char:LoadChar(plyid, "AdminDelete: " .. plyid)

    if tbl then
        table.remove(tbl,charid)
        PD.Char:SaveChar(plyid,tbl)
    end
end)

hook.Add("PD_Money_AddMoney","PD.Char:playerWalletChanged",function(ply,amount)
    local tbl = PD.Char:LoadChar(ply:SteamID64(), "playerWalletChanged")
    local id = FindPlayerCharbyName(string.sub(ply:Nick(),9),tbl)

    if tbl and tbl[id] then
        tbl[id].money = tbl[id].money + amount
        PD.Char:SaveChar(ply:SteamID64(),tbl)
    end
end)

gameevent.Listen("player_disconnect")
hook.Add("player_disconnect","PD.Char:PlayerDisconnect",function(data)
    local ply = Player(data.userid)
    if not IsValid(ply) then return end

    local tbl = PD.Char:LoadChar(ply:SteamID64(), "PlayerDisconnect")

    if tbl then
        local id = FindPlayerCharbyName(string.sub(ply:Nick(),9),tbl)
        tbl[id].playtime = tbl[id].playtime + PD.Char:StopTimer(ply:SteamID64())
        tbl[id].lastplaytime = os.date("%d.%m.%Y %H:%M:%S",os.time())
        tbl[id].money = ply:PDGetMoney()
        PD.Char:SaveChar(ply:SteamID64(),tbl)

        print("Player: " .. ply:Nick() .. " wurde gespeichert.")
        print("Char: " .. tbl[id].name .. " wurde gespeichert.")
    end
end)

hook.Add("ShutDown","PD.Char:ServerDown",function()
    for k,v in pairs(player.GetAll()) do
        local tbl = PD.Char:LoadChar(v:SteamID64(), "ShutDown")
        local id = FindPlayerCharbyName(string.sub(v:Nick(),9),tbl)

        if tbl and tbl[id] then
            tbl[id].playtime = tbl[id].playtime + PD.Char:StopTimer(v:SteamID64())
            tbl[id].lastplaytime = os.date("%d.%m.%Y %H:%M:%S",os.time())
            tbl[id].money = v:PDGetMoney()
            PD.Char:SaveChar(v:SteamID64(),tbl)

            print("Player: " .. v:Nick() .. " wurde gespeichert.")
            print("Char: " .. tbl[id].name .. " wurde gespeichert.")
        end
    end
end)

concommand.Add("charprints",function(ply)
    local tbl = PD.Char:LoadAllChars()

    PrintTable(tbl)
end)

hook.Add("PlayerSetCharacter", "TestHookChar", function(ply, jobID)
    print("PlayerSetCharacter")
    print(ply)

    local jobID, jobTbl = PD.JOBS.GetJob(jobID)

    net.Start("PD.Char.JobChange")
        net.WriteEntity(ply)
        net.WriteString(jobID)
        net.WriteTable(jobTbl)
    net.Broadcast()
end)

hook.Add("PD_Faction_Change", "PD.Char:PD_Faction_Change", function(ply, factionName, subfactionName, jobName)
    if not PD.Char:PlayerActiveChar(ply) then return end
    print("PD_Faction_Change")

    local tbl = PD.Char:LoadChar(ply:SteamID64(), "Char_SetFactionInfomations")
    local charID = FindPlayerCharbyName(string.sub(ply:Nick(),9),tbl)

    if not tbl[charID] then return end

    tbl[charID].faction.unit = factionName
    tbl[charID].faction.subunit = subfactionName
    tbl[charID].faction.job = jobName

    local jobID, jobTbl = PD.JOBS.GetJob(jobName)

    net.Start("PD.Char.JobChange")
        net.WriteEntity(ply)
        net.WriteString(jobID)
        net.WriteTable(jobTbl)
    net.Broadcast()

    PD.Char:SaveChar(ply:SteamID64(), tbl)

    PD.Char:ChangePlayerJob(ply, jobName)
end)

-- Wenn Spieler joint wird standard Job geladen
hook.Add("PlayerInitialSpawn", "PD.Char:PlayerInitialSpawn", function(ply)
    local defaultJobID, defaultJobTbl = PD.JOBS.GetJob(false, false)

    if defaultJobID then
        ply:SetJob(defaultJobID, defaultJobTbl)
    end

    ply:KillSilent()
end)

