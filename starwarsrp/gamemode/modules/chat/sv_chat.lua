PD.Chat = PD.Chat or {}

util.AddNetworkString("PD.Chat.SendMSG")

--[[
    F1 (gm_showhelp) tut nichts.

    Sandbox beantwortet gm_showhelp mit "Spawnmenue oeffnen und Suche
    fokussieren". F1 ist aber per PD-Bind belegt (z. B. Funk). cl_bindblock
    fing das nur ab, solange F1 noch gedrueckt war, wenn die Antwort beim
    Client ankam - daher "manchmal Spawnmenue". Ein Rueckgabewert hier
    verhindert, dass GM:ShowHelp ueberhaupt laeuft; den Rest erledigt der Bind.
]]
hook.Remove("ShowHelp", "PD.Chat.F1OpensChat") -- Vorfassung, oeffnete den Chat
hook.Add("ShowHelp", "PD.Chat.BlockShowHelp", function()
    return true
end)

-- Wie die Engine beim normalen say: eine Nachricht je Intervall. Laengere
-- Texte werden abgeschnitten, damit niemand den Chat mit Riesenzeilen flutet.
local MSG_INTERVAL = 0.5
local MSG_MAXLEN = 1000

net.Receive("PD.Chat.SendMSG", function(len, ply)
    if not IsValid(ply) then return end

    local now = CurTime()
    if (ply.PD_ChatNext or 0) > now then return end
    ply.PD_ChatNext = now + MSG_INTERVAL

    local text = string.sub(net.ReadString(), 1, MSG_MAXLEN)

    PD.Chat.HandleMessage(ply, text)
end)

function PD.Chat.HandleMessage(ply, text)
    if text:Trim() == "" then return end

    --[[
        @ ist der Admin-Chat und laeuft allein ueber PD.Chat.AdminChat, ohne
        PlayerSay: SAM haengt sich dort ebenfalls an @ und schickt die
        Nachricht als !asay ein zweites Mal. Auch stummgeschaltete Spieler
        sollen die Admins erreichen koennen.
    ]]
    if string.sub(text, 1, 1) == "@" then
        PD.Chat.AdminChat.callback(ply, {string.sub(text, 2)})
        return
    end

    --[[
        Gibt ein PlayerSay-Hook "" zurueck, wird die Nachricht nicht gezeigt.
        So unterdrueckt SAM Nachrichten stummgeschalteter Spieler und seine
        eigenen !-Befehle. Frueher wurde die Rueckgabe ignoriert und ein Mute
        blieb wirkungslos.
    ]]
    local result = hook.Run("PlayerSay", ply, text, false)

    if result == "" then
        return
    end

    local prefix = string.sub(text, 1, 1)

    if PD.Chat.Command.List[prefix] then
        local group = PD.Chat.Command.List[prefix]
        local args = string.Split(text:sub(2), " ")
        local typed = args[1] or ""
        table.remove(args, 1)

        -- Erst genau so nachschlagen, wie es getippt wurde. Sonst waeren Befehle
        -- mit Grossbuchstaben im Namen nicht erreichbar: die Suche lief frueher
        -- nur ueber :lower(), die Schluessel in sh_chat.lua stehen aber so da,
        -- wie sie geschrieben wurden.
        local command = group[typed]

        -- Danach ohne Ruecksicht auf Gross- und Kleinschreibung, damit /OOC
        -- weiterhin wie /ooc funktioniert.
        if not command then
            local wanted = string.lower(typed)

            for name, entry in pairs(group) do
                if string.lower(name) == wanted then
                    command = entry
                    break
                end
            end
        end

        if command and isfunction(command.callback) then
            command.callback(ply, args)
        else
            -- Frueher passierte hier gar nichts: ein Tippfehler und ein nicht
            -- geladener Befehl sahen voellig gleich aus. Deshalb eine Rueckmeldung.
            --ply:ChatPrint("Unbekannter Befehl: " .. prefix .. typed)
        end
    elseif prefix == "@" then
        local adminText = text:sub(2)

        PD.Chat.AdminChat.callback(ply, {adminText})
    else
        -- Normal chat message handling (local IC chat)
        PD.Chat.Command.Flat["looc"].callback(ply, {text})
    end
    
end

function PD.Chat.BroadcastMessage(text, key)

    net.Start("PD.Chat.SendMSG")
        net.WriteString(text)
        net.WriteString(key)
    net.Broadcast()
end

function PD.Chat.SendToPlayerMessage(ply, text, key)
    if not IsValid(ply) then return end

    local talker_pos = ply:GetPos()

    -- Der Sprechmodus gehoert dem Sprecher, nicht dem Zuhoerer - einmal vor der
    -- Schleife reicht.
    local modeSettings = PD.VC.Config[ply:GetNWInt("VoiceMode", 2)] or PD.VC.Config[2]
    if not modeSettings then return end

    for _, ply2 in pairs(player.GetAll()) do
        --[[
            Wo hoert der Zuhoerer?

            Lebend an der eigenen Position, tot an der seiner Leiche. Die
            Standardposition muss hier drin stehen: listener_pos war vorher
            ausserhalb der Schleife deklariert und wurde nur in den beiden
            Zweigen gesetzt. Ein toter Spieler ohne Leiche behielt damit die
            Position des vorher geprueften Spielers - und war er der erste in
            der Liste, war der Wert nil, die Schleife brach mit einem Fehler ab
            und alle danach bekamen die Nachricht gar nicht mehr.
        ]]
        local listener_pos = ply2:GetPos()

        if not ply2:Alive() then
            local ragdoll = ply2:GetNW2Entity("PD.DM.Ragdoll")

            if IsValid(ragdoll) then
                listener_pos = ragdoll:GetPos()
            end
        end

        if listener_pos:Distance(talker_pos) <= modeSettings.range then
            net.Start("PD.Chat.SendMSG")
                net.WriteString(text)
                net.WriteString(key)
            net.Send(ply2)
        end
    end
end

function PD.Chat.SendToAdmin(text, key)
    for _, ply in pairs(player.GetAll()) do
        if ply:IsAdmin() then
            net.Start("PD.Chat.SendMSG")
                net.WriteString(text)
                net.WriteString(key)
            net.Send(ply)
        end
    end
end

hook.Add("PlayerConnect", "PD.ConnectMSG", function(name, ip)
    -- Namen maskieren: sie koennen Formatierungs-Tags enthalten.
    local text = PD.Chat.Format.Escape(name) .. " has connected to the server."
    PD.Chat.BroadcastMessage(text, "system")
end)

hook.Add("PlayerDisconnected", "PD.DisconnectMSG", function(ply)
    local text = PD.Chat.Format.Escape(ply:Nick()) .. " has disconnected from the server."
    PD.Chat.BroadcastMessage(text, "system")
end)