PD.AI = PD.AI or {}

net.Receive("PD.AI.SendText", function()
    local words = net.ReadTable()

    local text = table.concat(words, " ", 1)
    chat.AddText(Color(255, 0, 0), text)
end)

net.Receive("PD.AI.SendTTS", function()
    local words = net.ReadTable() -- Read the TTS text from the network

    local text = table.concat(words, " ", 1)
    local ply = net.ReadEntity() -- Read the player entity from the network
    text = string.sub(string.Replace(text, " ", "%20"), 1, 1000) -- Replace spaces with "%20" and limit the text length to 100 characters

    -- Play the TTS sound using the provided URL
    sound.PlayURL("https://tetyys.com/SAPI4/SAPI4?voice=Sam&pitch=100&speed=150&text=" .. text, "3d", function(sound)
        if IsValid(sound) then
            sound:SetPos(ply:GetPos()) -- Set the sound position to the player's position
            sound:SetVolume(3) -- Set the sound volume to maximum
            sound:Play() -- Play the sound
            sound:Set3DFadeDistance(200, 1000) -- Set the 3D sound fade distance
            ply.sound = sound -- Store the sound reference in the player entity
        end
    end)
end)
