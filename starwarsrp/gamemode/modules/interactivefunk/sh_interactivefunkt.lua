--

if SERVER then
    
else
    PD = PD or {}
    PD.AI = PD.AI or {}
    function PD.AI.RequestNames(count, theme)
        net.Start("PD.AI.Names.Request")
        net.WriteUInt(math.Clamp(count or 10, 1, 50), 8)
        net.WriteString(theme or "")
        net.SendToServer()
    end
    local function pd_ai_open_ui(list)
        if IsValid(PD_AI_Frame) then PD_AI_Frame:Remove() end
        local f = vgui.Create("DFrame")
        PD_AI_Frame = f
        f:SetSize(ScrW()*0.25, ScrH()*0.45)
        f:Center()
        f:SetTitle("KI Namensvorschläge")
        f:MakePopup()
        local s = vgui.Create("DScrollPanel", f)
        s:Dock(FILL)
        local bar = vgui.Create("DPanel", f)
        bar:Dock(TOP)
        bar:SetTall(40)
        local entry = vgui.Create("DTextEntry", bar)
        entry:Dock(FILL)
        entry:SetPlaceholderText("Thema z.B. Recon, Assault, ARC ...")
        local refresh = vgui.Create("DButton", bar)
        refresh:Dock(RIGHT)
        refresh:SetWide(100)
        refresh:SetText("Neu laden")
        local function render(names)
            s:Clear()
            for _, n in ipairs(names or {}) do
                local pnl = vgui.Create("DPanel", s)
                pnl:Dock(TOP)
                pnl:SetTall(36)
                pnl:DockMargin(0,0,0,5)
                local lbl = vgui.Create("DLabel", pnl)
                lbl:Dock(LEFT)
                lbl:SetWide(pnl:GetWide()*0.6)
                lbl:SetText(n)
                lbl:SetContentAlignment(4)
                local copy = vgui.Create("DButton", pnl)
                copy:Dock(RIGHT)
                copy:SetWide(70)
                copy:SetText("Kopieren")
                copy.DoClick = function() SetClipboardText(n) surface.PlaySound("buttons/button14.wav") end
                local use = vgui.Create("DButton", pnl)
                use:Dock(RIGHT)
                use:SetWide(90)
                use:SetText("Übernehmen")
                use.DoClick = function() RunConsoleCommand("say", "/name "..n) end
            end
        end
        render(list or {})
        refresh.DoClick = function() PD.AI.RequestNames(12, entry:GetText()) end
    end
    net.Receive("PD.AI.Names.Response", function()
        local cnt = net.ReadUInt(8)
        local names = {}
        for i = 1, cnt do names[i] = net.ReadString() end
        pd_ai_open_ui(names)
    end)
    concommand.Add("pd_ai_names", function() PD.AI.RequestNames(12, "") end)
end

