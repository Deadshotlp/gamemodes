PD.Death = PD.Death or {}

PD.Death.RespawnDelay = 5
PD.Death.DeadTime = 0

net.Receive("PD.DeadTime", function()
    PD.Death.DeadTime = CurTime()
end)

hook.Add("PreRender", "PD.Death.Screen", function()
    if not LocalPlayer():Alive() then
        PD.Death:Screen()
    else
        if ValidPanel(DeathFrame) then --
            DeathFrame:Remove()
        end
    end
end)

local function start_death_timer()

    if timer.Exists("PD.Death.Timer") then
        return
    end

    timer.Create("PD.Death.Timer", 1, 0, function()
        if not IsValid(DeathFrame) then return end
        local waitTime = math.floor(PD.Death.DeadTime + PD.Death.RespawnDelay - CurTime())
        if waitTime < 0 then
            waitTime = 0
            DeathButton:SetDisabled(false)
        end
        DeathLabel:SetText("Du kannst in " .. waitTime .. " Sekunden Respawnen")
    end)
end

function PD.Death:Screen()
    if IsValid(DeathFrame) then
        return
    end

    DeathFrame = PD.Frame("", ScrW(), ScrH(), true)

    surface.SetFont("MLIB.16")
    local nameW2, nameH2 = surface.GetTextSize("Du kannst in " .. PD.Death.RespawnDelay .. " Sekunden Respawnen")

    DeathLabel = PD.Label("Du kannst in " .. PD.Death.RespawnDelay .. " Sekunden Respawnen",
        DeathFrame)
    DeathLabel:Dock(NODOCK)
    DeathLabel:SetWide(nameW2)
    DeathLabel:SetPos((ScrW() / 2) - (DeathLabel:GetWide() / 2), ScrH() / 2)

    DeathButton = PD.Button("Respawnen", DeathFrame, function()
        timer.Remove("PD.Death.Timer")
        net.Start("PD.Respawn")
        net.WriteEntity(LocalPlayer())
        net.SendToServer()
    end)
    DeathButton:Dock(NODOCK)
    DeathButton:SetSize(PD.W(200), PD.H(40))
    DeathButton:SetPos(ScrW() / 2 - DeathButton:GetWide() / 2, ScrH() / 2 + PD.H(30))
    DeathButton:SetDisabled(true)

    if LocalPlayer():IsAdmin() then
        local button2 = PD.Button("Admin Respawn", DeathFrame, function()
            timer.Remove("PD.Death.Timer")
            net.Start("PD.AdminRespawn")
            net.WriteEntity(LocalPlayer())
            net.SendToServer()
        end)
        button2:Dock(NODOCK)
        button2:SetSize(PD.W(200), PD.H(40))
        button2:SetPos(ScrW() / 2 - button2:GetWide() / 2, ScrH() / 2 + PD.H(70))
    end

    local key_num = PD.Binds:FindBindByID("mouse")
    local key_lbl
    if not key_num or key_num == 0 then
        key_lbl = "[Keine Taste Ausgewählt]"
    else
        key_lbl = input.GetKeyName(PD.Binds:FindBindByID("mouse"))
    end

    surface.SetFont("MLIB.16")
    local nameW2, nameH2 = surface.GetTextSize("Drücke '" .. key_lbl ..
                               "' um dir den Mauszeiger Anzeigen zu lassen!")

    local lbl_g = PD.Label("Drücke '" .. key_lbl ..
                               "' um dir den Mauszeiger Anzeigen zu lassen!", DeathFrame)
    lbl_g:Dock(NODOCK)
    lbl_g:SetWide(nameW2)
    lbl_g:SetPos((ScrW() / 2) - (lbl_g:GetWide() / 2), ScrH() - lbl_g:GetTall() - PD.H(20))
    start_death_timer()
    

    function DeathFrame:OnKeyCodePressed(key)
        if input.GetKeyName(key) == input.LookupBinding("messagemode") then
            chat.Open(1)
        end
    end
end

hook.Add("Think", "PD.Death.CheckRespawn", function()
    if input.IsKeyDown(KEY_SPACE) and not LocalPlayer():Alive() then
        local waitTime = PD.Death.DeadTime + PD.Death.RespawnDelay - CurTime()
        if waitTime <= 0 then
            timer.Remove("PD.Death.Timer")
            net.Start("PD.Respawn")
            net.WriteEntity(LocalPlayer())
            net.SendToServer()
        end
    end
end)

