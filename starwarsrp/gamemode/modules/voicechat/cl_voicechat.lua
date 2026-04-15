PD.VC = PD.VC or {}
PD.VC.showindicator = false

function PD.VC:Change()
    local ent = LocalPlayer()
    local currentMode = ent:GetNWInt("VoiceMode", 2)

    currentMode = currentMode + 1
    if currentMode > 4 then currentMode = 1 end

    PD.Popup("Deine Sprachreichweite wurde auf '" .. PD.VC.Config[currentMode].name .. "' geändert.", Color(255, 255, 255))

    net.Start("PD.VC.ChangeVoiceMode")
        net.WriteUInt(currentMode, 3)
    net.SendToServer()
end

function PD.VC:Start_ShowIndicator()
    PD.VC.showindicator = true
end

function PD.VC:Stop_ShowIndicator()
    PD.VC.showindicator = false
end


hook.Add("PostDrawTranslucentRenderables", "PD.DrawSphere", function()
    if not PD.VC.showindicator then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local pos = ply:GetPos() + Vector(0, 0, 5)
    local radius = PD.VC.Config[ply:GetNWInt("VoiceMode", 2)].range or 500

    render.SetColorMaterial()
    render.DrawWireframeSphere(
        pos,
        radius,
        32,
        32,
        Color(255, 255, 255, 80),
        true
    )
end)
