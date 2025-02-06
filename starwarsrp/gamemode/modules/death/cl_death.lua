PD.Death = PD.Death or {}

PD.Death.RespawnDelay = 30
PD.Death.DeadTime = 0

local DeathFrame

net.Receive("PD.DeadTime", function()
    PD.Death.DeadTime = CurTime()
end)

hook.Add("PreRender","PD.Death.Screen",function()
    if not LocalPlayer():Alive() then
        gui.HideGameUI()
        PD.Death:Screen()
    else
        if ValidPanel(DeathFrame) then
            if timer.Exists("PD.Death.Timer") then
                timer.Remove( "PD.Death.Timer" )
            end
            gui.HideGameUI()
            DeathFrame:Remove()
        end
    end
end)

function PD.Death:Screen()
    if IsValid(DeathFrame) then return end

    DeathFrame = PD.Frame("", ScrW(), ScrH(), false, function(self,w,h)
        draw.RoundedBox(1, 0, 0, w, h, Color(255, 30, 30, 50))
    end)
    DeathFrame:SetBarColor(Color(255,255,255, 0))
    DeathFrame:SetBlur(true)

    local lbl = PD.Label("Du kannst in " .. PD.Death.RespawnDelay  .. " Sekunden Respawnen", DeathFrame)
    lbl:Dock(NODOCK)
    lbl:SetPos((ScrW() / 2) - (lbl:GetWide() / 2), ScrH() / 2)

    local button1 = PD.Button("Respawn", DeathFrame, function()
        timer.Remove( "PD.Death.Timer" )
        net.Start("PD.Respawn")
        net.WriteEntity(LocalPlayer())
        net.SendToServer()

        net.Start("PD.Armor:Respawn")
        net.SendToServer()
    end)
    button1:Dock(NODOCK)
    button1:SetPos(ScrW() / 2 - button1:GetWide() / 2, ScrH() / 2 + PD.H(30))
    button1:SetDisabled(true)

    if LocalPlayer():IsAdmin() then
        local button2 = PD.Button("Admin Respawn", DeathFrame, function()
            timer.Remove( "PD.Death.Timer" )
            net.Start("PD.AdminRespawn")
            net.WriteEntity(LocalPlayer())
            net.SendToServer()
        end)
        button2:Dock(NODOCK)
        button2:SetPos(ScrW() / 2 - button2:GetWide() / 2, ScrH() / 2 + PD.H(70))
    end

    timer.Create( "PD.Death.Timer", 1, 0, function()
        local waitTime = math.floor((PD.Death.DeadTime + PD.Death.RespawnDelay) - CurTime())
        if waitTime < 0 then
            waitTime = 0
            button1:SetDisabled(false)
        end
        lbl:SetText("Du kannst in " .. waitTime  .. " Sekunden Respawnen")
    end)

    function DeathFrame:OnKeyCodePressed( key )
        if input.GetKeyName( key ) == input.LookupBinding( "messagemode" ) then
            chat.Open(1)
        end
	end
end