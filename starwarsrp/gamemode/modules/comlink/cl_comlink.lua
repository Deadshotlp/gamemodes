PD.Comlink = PD.Comlink or {}

LocalPlayer().ActiveChannel = false
LocalPlayer().Extra1 = false
LocalPlayer().Extra2 = false
LocalPlayer().Extra3 = false

function PD.Comlink:Menu()
    if IsValid(self.Frame) then return end
    local ply = LocalPlayer()

    self.Frame = PD.Frame("Comlink", PD.W(500), PD.H(800), true)

    local scrl = PD.Scroll(self.Frame)

    for k, v in SortedPairs(PD.Comlink.Table) do
        if not v.check(ply) then continue end

        local pnl = PD.Panel("", scrl, function(self, w, h)
            draw.DrawText(k, "MLIB.20", w/2, PD.H(10), Color(255, 255, 255), TEXT_ALIGN_CENTER)
        end)
        pnl:SetTall(PD.H(85))
        pnl:SetBackColor(Color(v.color.r, v.color.g, v.color.b, 100))
        
        -- local muteBtn = PD.Button("Mute", pnl, function()
        --     if PD.Comlink.Muted[k] then
        --         PD.Comlink.Muted[k] = nil
        --     else
        --         PD.Comlink.Muted[k] = true

        --         if ply.ActiveChannel == k then
        --             ply.ActiveChannel = false

        --             net.Start("PD.Comlink.EndVoice")
        --                 net.WriteString(k)
        --                 net.WriteInt(1, 4)
        --             net.SendToServer()
        --         end

        --         self.Frame:Remove()
        --         self:Menu()
        --     end
        -- end)
        -- muteBtn:Dock(BOTTOM)
        -- muteBtn:SetTall(PD.H(20))
        -- muteBtn.Font = 20
        -- if not v.mute then
        --     muteBtn.disabled = true
        -- end

        local activeBtn = PD.Button("Aktivieren", pnl, function()
            if ply.ActiveChannel == k then
                ply.ActiveChannel = false

                net.Start("PD.Comlink.EndVoice")
                    net.WriteString(k)
                    net.WriteInt(1, 4)
                net.SendToServer()

                self.Frame:Remove()
            else
                ply.ActiveChannel = k

                net.Start("PD.Comlink.StartVoice")
                    net.WriteString(k)
                    net.WriteInt(1, 4)
                net.SendToServer()

                self.Frame:Remove()
            end
        end)
        activeBtn:Dock(BOTTOM)
        activeBtn:SetTall(PD.H(20))
        activeBtn.Font = 20

        for i = 1, 3 do
            local extraBtn = PD.Button("Extra " .. i, pnl, function()
                if ply["Extra" .. i] == k then
                    ply["Extra" .. i] = false

                    net.Start("PD.Comlink.EndVoice")
                        net.WriteString(k)
                        net.WriteInt(i + 1, 4)
                    net.SendToServer()

                    self.Frame:Remove()
                else
                    ply["Extra" .. i] = k

                    net.Start("PD.Comlink.StartVoice")
                        net.WriteString(k)
                        net.WriteInt(i + 1, 4)
                    net.SendToServer()

                    self.Frame:Remove()
                end
            end)
            extraBtn:Dock(NODOCK)
            extraBtn:SetSize(PD.W(100), PD.H(20))
            extraBtn:SetPos(PD.W(80) + (i - 1) * PD.W(110), PD.H(35))
            extraBtn.Font = 20

            if ply["Extra" .. i] == k then
                extraBtn:Activate()
            end
        end
    end
end

-- local text = "N/A"
local textChannel = "N/A"
local textExtra1, textExtra2, textExtra3 = "N/A", "N/A", "N/A"
hook.Add("HUDPaint", "PD.Comlink.HUDPaint", function()
    textChannel = LocalPlayer().ActiveChannel or "N/A"

    -- if PD.Comlink.Muted[textChannel] then
    --     text = "Channel: " .. textChannel .. " - Stumm"
    -- else
        text = "Channel: " .. textChannel
    -- end

    if LocalPlayer().ActiveChannel then
        draw.DrawText("DU BIST AKTIV", "MLIB.20", ScrW() - PD.W(15), PD.H(70), Color(255, 0, 0), TEXT_ALIGN_RIGHT)
    end

    textExtra1 = LocalPlayer().Extra1 or "N/A"
    textExtra2 = LocalPlayer().Extra2 or "N/A"
    textExtra3 = LocalPlayer().Extra3 or "N/A"

    surface.SetFont("MLIB.20")
    local tw1, th1 = surface.GetTextSize(text)

    draw.SimpleText(text, "MLIB.20", ScrW() - PD.W(15), PD.H(10), Color(255, 255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    surface.SetDrawColor(255, 255, 255)
    surface.DrawOutlinedRect(ScrW() - PD.W(20) - tw1, PD.H(9), tw1 + PD.W(10), PD.H(22), 2)

    surface.SetFont("MLIB.20")
    local tw2, th2 = surface.GetTextSize("E1: " .. textExtra1 .. " - E2: " .. textExtra2 .. " - E3: " .. textExtra3)

    draw.SimpleText("E1: " .. textExtra1 .. " - E2: " .. textExtra2 .. " - E3: " .. textExtra3, "MLIB.20", ScrW() - PD.W(15), PD.H(40), Color(255, 255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    surface.SetDrawColor(255, 255, 255)
    surface.DrawOutlinedRect(ScrW() - PD.W(20) - tw2, PD.H(38), tw2 + PD.W(10), PD.H(24), 2)
end)

local cache = {} 
hook.Add("PlayerButtonDown", "PD.Comlink.PlayerButtonDown", function(ply, button)
    if button == KEY_F1 then
        if not LocalPlayer().Extra1 then return end

        if LocalPlayer().ActiveChannel then
            cache[1] = LocalPlayer().ActiveChannel

            net.Start("PD.Comlink.EndVoice")
                net.WriteString(LocalPlayer().ActiveChannel)
                net.WriteInt(1, 4)
            net.SendToServer()

            LocalPlayer().ActiveChannel = LocalPlayer().Extra1
            LocalPlayer().Extra1 = cache[1]

            net.Start("PD.Comlink.StartVoice")
                net.WriteString(LocalPlayer().ActiveChannel)
                net.WriteInt(1, 4)
            net.SendToServer()
        end
        LocalPlayer().ActiveChannel = LocalPlayer().Extra1

        net.Start("PD.Comlink.StartVoice")
            net.WriteString(LocalPlayer().ActiveChannel)
            net.WriteInt(1, 4)
        net.SendToServer()
    elseif button == KEY_F2 then
        if not LocalPlayer().Extra2 then return end

        if LocalPlayer().ActiveChannel then
            cache[2] = LocalPlayer().ActiveChannel

            net.Start("PD.Comlink.EndVoice")
                net.WriteString(LocalPlayer().ActiveChannel)
                net.WriteInt(1, 4)
            net.SendToServer()

            LocalPlayer().ActiveChannel = LocalPlayer().Extra2
            LocalPlayer().Extra2 = cache[2]

            net.Start("PD.Comlink.StartVoice")
                net.WriteString(LocalPlayer().ActiveChannel)
                net.WriteInt(1, 4)
            net.SendToServer()
        end
        LocalPlayer().ActiveChannel = LocalPlayer().Extra2

        net.Start("PD.Comlink.StartVoice")
            net.WriteString(LocalPlayer().ActiveChannel)
            net.WriteInt(1, 4)
        net.SendToServer()
    elseif button == KEY_F3 then
        if not LocalPlayer().Extra3 then return end

        if LocalPlayer().ActiveChannel then
            cache[3] = LocalPlayer().ActiveChannel

            net.Start("PD.Comlink.EndVoice")
                net.WriteString(LocalPlayer().ActiveChannel)
                net.WriteInt(1, 4)
            net.SendToServer()

            LocalPlayer().ActiveChannel = LocalPlayer().Extra3
            LocalPlayer().Extra3 = cache[3]

            net.Start("PD.Comlink.StartVoice")
                net.WriteString(LocalPlayer().ActiveChannel)
                net.WriteInt(1, 4)
            net.SendToServer()
        end
        LocalPlayer().ActiveChannel = LocalPlayer().Extra3

        net.Start("PD.Comlink.StartVoice")
            net.WriteString(LocalPlayer().ActiveChannel)
            net.WriteInt(1, 4)
        net.SendToServer()
    end
end)

