PD.VC = PD.VC or {}

PD.VC.Hide = {
    ["CHudVoiceSelfStatus"] = true,
    ["CHudVoiceStatus"] = true
}

util.AddNetworkString("PD.VC.ChangeVoiceMode")

net.Receive("PD.VC.ChangeVoiceMode", function(_, ply)
    local mode = net.ReadUInt(3)

    if not PD.VC.Config[mode] then return end

    ply:SetNWInt("VoiceMode", mode)
end)


-- Sollte die sprachanzeige in der linken unteren ecke verstecken
hook.Add("HUDShouldDraw", "HideHUD", function(name)
    if (PD.VC.Hide[name]) then
        return false
    end
end)

-- Initialisierung der Standard-Sprachlautstärke
hook.Add("PlayerSpawn", "PD.Voice.Init", function(ply)
    ply:SetNWInt("VoiceMode", ply:GetNWInt("VoiceMode", 2))
end)
