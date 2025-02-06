PD.VC = PD.VC or {}

-- Definiere die verschiedenen Sprachmodi
PD.VC.Config = {
    ["Whisper"] =  100,
    ["Reden"] = 500,
    ["Loud"] = 1000,
    ["Shout"] = 1500
}

PD.VC.FUNK = {}
PD.VC.FUNK.Channels = {}

PD.VC.FUNK.Hide = {
	["CHudVoiceSelfStatus"] = true,
	["CHudVoiceStatus"] = true
}

--Sollte die sprachanzeige in der linken unteren ecke verstecken
hook.Add( "HUDShouldDraw", "HideHUD", function( name )
	if ( PD.VC.FUNK.Hide[ name ] ) then
		return false
	end
end )

-- Erstellt alle funks nachdem der GM geladen hat
hook.Add("", "", function()
    for _, i in ipairs(PD.JOBS.GetUnit(false, false)) do
        table.insert(PD.VC.FUNK.Channels, i.name)
    end

    for x, y in ipairs(PD.JOBS.GetSubUnit(false, false)) do 
        table.insert(PD.VC.FUNK.Channels, y.name)
    end
end)

-- Initialisierung der Standard-Sprachlautstärke
hook.Add("PlayerInitialSpawn", "SetDefaultVoiceMode", function(ply)
    ply:SetNWString("VoiceMode", "Reden")
end)

-- Erstellung eines Tastenbindungs-Systems
hook.Add("PlayerButtonDown", "ChangeVoiceMode", function(ply, button)
    if button == KEY_N then
        local currentMode = ply:GetNWString("VoiceMode", "Reden")
        local nextMode

        if currentMode == "Flüstern" then
            nextMode = "Reden"
            PD.Notify("Sprachlautstärke: " .. nextMode, Color(0,255,0,255), false, ply)
        elseif currentMode == "Reden" then
            nextMode = "Rufen"
            PD.Notify("Sprachlautstärke: " .. nextMode, Color(255,200,0,255), false, ply)
        elseif currentMode == "Rufen" then
            nextMode = "Schreien"
            PD.Notify("Sprachlautstärke: " .. nextMode, Color(255,0,0,255), false, ply)
        else
            nextMode = "Flüstern"
            PD.Notify("Sprachlautstärke: " .. nextMode, Color(255,255,255,255), false, ply)
        end

        ply:SetNWString("VoiceMode", nextMode)
    end
end)

-- Berechnung der Sprachreichweite und Anpassung der Lautstärke
hook.Add("PlayerCanHearPlayersVoice", "VoiceChatRange", function(listener, talker)
    local voiceMode = talker:GetNWString("VoiceMode", "Reden")
    local modeSettings = CONFIG:GetConfig(voiceMode) or PD.VC.Config[voiceMode]
    local distance = listener:GetPos():Distance(talker:GetPos())

    -- if distance <= modeSettings and talker:Alive() then
    --     local adjustedVolume = modeSettings * (1 - (distance / modeSettings))
    --     return true, true --adjustedVolume
    -- else
    --     return false, false --0
    -- end
end)