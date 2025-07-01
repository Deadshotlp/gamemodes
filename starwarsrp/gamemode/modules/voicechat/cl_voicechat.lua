PD.VC = PD.VC or {}

PD.VC.Config = {
    ["Flüstern"] = 100,
    ["Reden"] = 500,
    ["Rufen"] = 1000,
    ["Schreien"] = 1500
}

local last_shown = CurTime() - 3
local delay = 2

net.Receive("PD.VC.SendVoiceRange", function()
    local currentMode = LocalPlayer():GetNWString("VoiceMode", "Reden")

    if currentMode == "Flüstern" then
        PD.Notify("Sprachlautstärke: " .. currentMode, Color(0, 255, 0, 255), false)
    elseif currentMode == "Reden" then
        PD.Notify("Sprachlautstärke: " .. currentMode, Color(255, 200, 0, 255), false)
    elseif currentMode == "Rufen" then
        PD.Notify("Sprachlautstärke: " .. currentMode, Color(255, 0, 0, 255), false)
    else
        PD.Notify("Sprachlautstärke: " .. currentMode, Color(255, 255, 255, 255), false)
    end

    last_shown = CurTime()
end)

-- hook.Add("PostDrawTranslucentRenderables", "PD.DrawSphere", function()
--     if (last_shown + delay) > CurTime() then
--         render.SetColorMaterial()

--         local pos = LocalPlayer():GetPos()
--         local radius = PD.VC.Config[LocalPlayer():GetNWString("VoiceMode", "Reden")] or 500
--         local wideSteps = 100
--         local tallSteps = 100

--         -- Draw the wireframe sphere!
--         render.DrawWireframeSphere(pos, 1000, wideSteps, tallSteps, Color(255, 255, 255, 255))
--     end
-- end)
