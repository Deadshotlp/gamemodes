PD.BB = PD.BB or {}

hook.Add("OnContextMenuOpen", "PD.CheckContectMenu", function()
    if not LocalPlayer():IsAdmin() then
        LocalPlayer():ChatPrint("Du bist kein Admin!")
        return false
    end
    PD.AdminCheck()
end)

hook.Add("OnSpawnMenuOpen", "PD.CheckSpawnMenu", function()
    if not LocalPlayer():IsAdmin() then
        LocalPlayer():ChatPrint("Du bist kein Admin!")
        return false
    end

    if input.IsKeyDown(KEY_F1) then
        return false
    end
    PD.AdminCheck()
end)

function PD.AdminCheck()
    net.Start("PD.CheckAdmin")
    net.WriteEntity(LocalPlayer())
    net.SendToServer()
end
