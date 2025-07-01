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
    local talkerData = playerTalkerTable[talker:Nick()]
    local listenerData = playerTalkerTable[listener:Nick()]

    -- Wenn einer von beiden nicht im Comlink ist, dann normale Voice durch Nähe
    if not talkerData or not listenerData then
        return listener:GetPos():DistToSqr(talker:GetPos()) <= 250000, true
    end

    local talkerChannel = talkerData.active
    local listenerChannel = listenerData

    if not talkerChannel then
        return listener:GetPos():DistToSqr(talker:GetPos()) <= 250000, true
    end

    local talkerJobID, talkerJobTable = talker:GetJob()
    local listenerJobID, listenerJobTable = listener:GetJob()
    local unit = talkerJobTable.unit

    -- Channel existiert nicht oder Check schlägt fehl
    local channelConfig = PD.Comlink.Table[talkerChannel]
    if not channelConfig or not channelConfig.check(talker, unit) then
        return false
    end

    if not listenerChannel.active then
        return listener:GetPos():DistToSqr(talker:GetPos()) <= 250000, true
    end

    -- Check auch für Listener
    if not PD.Comlink.Table[listenerChannel.active].check(listener, unit) then
        return false
    end

    -- Selber Channel oder passiv verbunden → hören erlaubt
    if listenerChannel.active == talkerChannel
        or listenerChannel.passive1 == talkerChannel
        or listenerChannel.passive2 == talkerChannel
        or listenerChannel.passive3 == talkerChannel then

        return true, false
    end

    return false
end)
