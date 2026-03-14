PD.Chat = PD.Chat or {}

util.AddNetworkString("PD.Chat.SendMSG")

net.Receive("PD.Chat.SendMSG", function(len, ply)
    local text = net.ReadString()

    PD.Chat.HandleMessage(ply, text)
end)

function PD.Chat.HandleMessage(ply, text)
    if text:Trim() == "" then return end

    hook.Run("PlayerSay", ply, text, false)

    local prefix = string.sub(text, 1, 1)
    local isCommand = false

    for _, p in pairs(PD.Chat.Command.Prefix) do
        if prefix == p then
            isCommand = true
            break
        end
    end

    if isCommand then
        local args = string.Split(text:sub(2), " ")
        local commandKey = args[1]:lower()
        table.remove(args, 1)

        for _, command in pairs(PD.Chat.Command.List) do
            if _ == commandKey then
                command.callback(ply, args)
                return
            end
        end
    else
        -- Normal chat message handling (broadcast to all players)
        PD.Chat.Command.List["looc"].callback(ply, {text})
    end
    
end

function PD.Chat.BroadcastMessage(text, key)

    net.Start("PD.Chat.SendMSG")
        net.WriteString(text)
        net.WriteString(key)
    net.Broadcast()
end

function PD.Chat.SendToPlayerMessage(ply, text, key)
    local talker_pos = ply:GetPos()
    local listener_pos

    for _, ply2 in pairs(player.GetAll()) do
        if ply2:Alive() then
            listener_pos = ply2:GetPos()
        elseif ply2:GetNW2Entity("PD.DM.Ragdoll"):IsValid() then
            listener_pos = ply2:GetNW2Entity("PD.DM.Ragdoll"):GetPos()
        end

        local voiceMode = ply:GetNWInt("VoiceMode",2)
        local modeSettings = PD.VC.Config[voiceMode]
        local distance = listener_pos:Distance(talker_pos)

        if distance <= modeSettings.range then
            net.Start("PD.Chat.SendMSG")
                net.WriteString(text)
                net.WriteString(key)
            net.Send(ply2)
        end
    end
end