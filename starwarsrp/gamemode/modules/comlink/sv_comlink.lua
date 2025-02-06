PD.Comlink = PD.Comlink or {}

util.AddNetworkString("PD.Comlink.StartVoice")
util.AddNetworkString("PD.Comlink.EndVoice")
util.AddNetworkString("PD.Comlink.SendTalkerInfo")
util.AddNetworkString("PD.Comlink.SendListenerInfo")

local playerTalkerTable = {}

net.Receive("PD.Comlink.StartVoice", function(len, ply)
    local channel = net.ReadString()
    local id = net.ReadInt(4)

    if not PD.Comlink.Table[channel].check(ply) then return end

    if not playerTalkerTable[ply:Nick()] then
        playerTalkerTable[ply:Nick()] = {}
    end 
    
    if id == 1 then
        playerTalkerTable[ply:Nick()].active = channel
        print("Active")
    elseif id == 2 then
        playerTalkerTable[ply:Nick()].passive1 = channel
        print("Passive 1")
    elseif id == 3 then
        playerTalkerTable[ply:Nick()].passive2 = channel
        print("Passive 2")
    elseif id == 4 then
        playerTalkerTable[ply:Nick()].passive3 = channel
        print("Passive 3")
    end
end)

net.Receive("PD.Comlink.EndVoice", function(len, ply)
    local channel = net.ReadString()
    local id = net.ReadInt(4)

    if not playerTalkerTable[ply:Nick()] then return end

    if id == 1 then
        playerTalkerTable[ply:Nick()].active = nil
    elseif id == 2 then
        playerTalkerTable[ply:Nick()].passive1 = nil
    elseif id == 3 then
        playerTalkerTable[ply:Nick()].passive2 = nil
    elseif id == 4 then
        playerTalkerTable[ply:Nick()].passive3 = nil
    end
end)

concommand.Add("printcomlink", function(ply)
    for k, v in pairs(playerTalkerTable) do
        print(k)
        PrintTable(v)
    end
end)

hook.Add("PlayerCanHearPlayersVoice", "PD.Comlink.Voice", function(listener, talker)

    if not playerTalkerTable[talker:Nick()] then return false end
    if not playerTalkerTable[listener:Nick()] then return false end

    local talkerChannel = playerTalkerTable[talker:Nick()].active 
    local listenerChannel = playerTalkerTable[listener:Nick()]
    local talkerJobID, talkerJobTable = talker:GetJob()
    local listenerJobID, listenerJobTable = listener:GetJob()
    local channelTable = PD.Comlink.Table[talkerChannel]
    local unit = talkerJobTable.unit

    if not talkerChannel then return false end
    if not PD.Comlink.Table[talkerChannel].check(talker, unit) then return false end

    if not listenerChannel then return false end
    if not PD.Comlink.Table[listenerChannel].check(listener, unit) then return false end

    -- if listener:GetPos():DistToSqr(talker:GetPos()) > 250000 then return false end
    
    if channelTable[talkerChannel] then
        -- net.Start("PD.Comlink.SendTalkerInfo")
        --     net.WriteString(talkerChannel)
        --     net.WriteEntity(talker)
        -- net.Send(talker)

        return true, false
    end

    if listenerChannel.active == talkerChannel or listenerChannel.passive1 == talkerChannel or listenerChannel.passive2 == talkerChannel or listenerChannel.passive3 == talkerChannel then
        -- net.Start("PD.Comlink.SendListenerInfo")
        --     net.WriteString(talkerChannel)
        --     net.WriteEntity(talker)
        -- net.Send(listener)

        return true, false
    end
end)