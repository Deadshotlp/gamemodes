-- Escape Menu - Star Wars Andor Imperial Style (Zentral über PD.Theme)

PD.ESC = PD.ESC or {}

-- Konfigurierbare Credits-Liste (anpassbar vom Server-Admin)
-- Strukturierte Credits: Rolle oben (klein), Namen darunter
-- Beispiel: { role = "Lead Developer", names = { "Max Mustermann" } }
PD.Credits = PD.Credits or {
    { role = "Lead Developer", names = { "Jens" } },
    { role = "Stellv. Lead Developer", names = { "Deadshot" } },
    { role = "Developer", names = { "Programa057", "Lost_Evo", "Younis", "Lucky" } },
    { role = "Development Coordinator", names = { "TheRealj0sh", "Galaktron234" } },
    { role = "UX / UI Design", names = { "ks_shiny" } }
}
local buttons = {
    {
        name = "Neu verbinden",
        icon = "↻",
        func = function()
            RunConsoleCommand("retry")
        end
    }, {
        name = "Kollektion",
        icon = "☁",
        func = function()
            gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=3545771562")
        end
    }, {
        name = "Discord",
        icon = "💬",
        func = function()
            gui.OpenURL("https://discord.gg/thrawnsrevenge")
            gui.HideGameUI()
        end
    }, {
        name = "Patreon",
        icon = "💬",
        func = function()
            gui.OpenURL("https://www.patreon.com/cw/ThrawnsRevenge")
            gui.HideGameUI()
        end
    }, {
        name = "Tastenbelegung",
        icon = "⌨",
        func = function()
            PD.Binds:Menu()
        end
    }, 
    -- {
    --     name = "Config Menü",
    --     icon = "⚙",
    --     func = function()
    --         PD.Config:Menu()
    --     end
    -- }, 
    {
        name = "Fraktions Verwaltung",
        icon = "⚙",
        func = function()
            PD.FV:Menu()
        end
    }, 
    {
        name = "Admin Einstellungen",
        icon = "👤",
        admin = true,
        func = function(base)
            if IsValid(base) then
                base:Remove()
            end
            PD.Admin:Menu()
        end
    }, {
        name = "Bone Reset",
        icon = "⌨",
        func = function()
            local ply = LocalPlayer()
            local boneCount = ply:GetBoneCount()
                if boneCount then
                    for bone = 0, boneCount - 1 do
                        print(ply:GetManipulateBonePosition(bone))
                        print(ply:GetManipulateBoneAngles(bone))
                        ply:ManipulateBoneAngles(bone, angle_zero)
                        ply:ManipulateBonePosition(bone, vector_origin)
                    end

                    ply:SetupBones()
                end
        end
    }, 
}

hook.Add("PreRender", "PD.ESC.Toggle", function()
    if input.IsKeyDown(KEY_ESCAPE) and gui.IsGameUIVisible() then
        if ValidPanel(mainFrameESC) then
            gui.HideGameUI()
            mainFrameESC:Remove()
        else
            gui.HideGameUI()
            PD.ESC:Menu()
        end
    end
end)

function PD.ESC:Menu()
    if IsValid(mainFrameESC) then return end

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- Hauptframe (Vollbild)
    mainFrameESC = vgui.Create("DFrame")
    mainFrameESC:SetSize(ScrW(), ScrH())
    mainFrameESC:SetPos(0, 0)
    mainFrameESC:SetTitle("")
    mainFrameESC:SetDraggable(false)
    mainFrameESC:ShowCloseButton(false)
    mainFrameESC:MakePopup()
    mainFrameESC.startTime = SysTime()
    
    mainFrameESC.Paint = function(s, w, h)
        -- Blur-Effekt
        Derma_DrawBackgroundBlur(s, s.startTime)
        
        -- Dunkler Overlay
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 150))
        
        -- Subtiles Grid-Muster
        if PD.Theme and PD.Theme.DrawGridPattern then
            PD.Theme.DrawGridPattern(0, 0, w, h, PD.W(50), PD.Theme.ColorAlpha(PD.Theme.Colors.BackgroundLight, 0.1))
        end
    end

    -- Berechne Button-Anzahl
    local buttonCount = 2 + #buttons + 1  -- Continue, Settings, Custom Buttons, Leave
    local adminCount = 0
    for _, btn in ipairs(buttons) do
        if btn.admin and not ply:IsAdmin() then
            adminCount = adminCount + 1
        end
    end
    buttonCount = buttonCount - adminCount

    -- Panel-Größe
    local buttonHeight = PD.H(55)
    local buttonSpacing = PD.H(6)
    local panelWidth = PD.W(400)
    local panelPadding = PD.W(20)
    local headerHeight = PD.H(100)
    local panelHeight = headerHeight + (buttonCount * (buttonHeight + buttonSpacing)) + panelPadding * 2
    
    local panelX = PD.W(50)
    local panelY = ScrH() / 2 - panelHeight / 2

    -- Hauptpanel
    local panel = vgui.Create("DPanel", mainFrameESC)
    panel:SetSize(panelWidth, panelHeight)
    panel:SetPos(panelX, panelY)
    
    panel.Paint = function(s, w, h)
        -- Hintergrund
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.Background)
        
        -- Rechte Akzentlinie (Imperial Red)
        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
        surface.DrawRect(w - PD.W(4), 0, PD.W(4), h)
        
        -- Obere Akzentlinie
        surface.DrawRect(0, 0, w - PD.W(4), PD.H(4))
        
        -- Untere Akzentlinie
        surface.DrawRect(0, h - PD.H(4), w - PD.W(4), PD.H(4))
        
        -- Linke Linie
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(0, PD.H(4), 1, h - PD.H(8))
        
        -- Imperial Ecken-Dekor
        local cornerSize = PD.W(20)
        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
        -- Oben links
        surface.DrawRect(0, 0, cornerSize, PD.H(2))
        surface.DrawRect(0, 0, PD.W(2), cornerSize)
        -- Unten links
        surface.DrawRect(0, h - PD.H(2), cornerSize, PD.H(2))
        surface.DrawRect(0, h - cornerSize, PD.W(2), cornerSize)
        
        -- Dekorative Elemente (links)
        local decoX = PD.W(8)
        local decoStartY = h / 2 - PD.H(60)
        for i = 0, 5 do
            local alpha = 180 - i * 25
            surface.SetDrawColor(PD.Theme.Colors.AccentRed.r, PD.Theme.Colors.AccentRed.g, PD.Theme.Colors.AccentRed.b, alpha)
            surface.DrawRect(decoX, decoStartY + i * PD.H(20), PD.W(3), PD.H(12))
        end
    end

    -- Header Bereich
    local header = vgui.Create("DPanel", panel)
    header:Dock(TOP)
    header:SetTall(headerHeight)
    header:DockMargin(0, 0, 0, PD.H(10))
    
    header.Paint = function(s, w, h)
        -- Spielername
        local name = ply:GetNWString("rpname", ply:Nick())
        draw.DrawText(name, "MLIB.28", panelPadding, PD.H(20), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
        
        -- Job
        local jobID, jobTbl = ply:GetJob()
        local jobName = jobTbl and jobTbl.name or "Unbekannt"
        draw.DrawText(jobName, "MLIB.14", panelPadding, PD.H(52), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
        
        -- Trennlinie
        surface.SetDrawColor(PD.Theme.Colors.AccentGray.r, PD.Theme.Colors.AccentGray.g, PD.Theme.Colors.AccentGray.b, 100)
        surface.DrawRect(panelPadding, h - PD.H(15), w - panelPadding * 2, 1)
        
        -- Server Info rechts
        draw.DrawText(GetHostName(), "MLIB.10", w - panelPadding - PD.W(4), PD.H(25), PD.Theme.Colors.TextMuted, TEXT_ALIGN_RIGHT)
        draw.DrawText(#player.GetAll() .. "/" .. game.MaxPlayers() .. " Spieler", "MLIB.10", w - panelPadding - PD.W(4), PD.H(40), PD.Theme.Colors.TextMuted, TEXT_ALIGN_RIGHT)
    end

    -- Button Container
    local buttonContainer = vgui.Create("DPanel", panel)
    buttonContainer:Dock(FILL)
    buttonContainer:DockMargin(panelPadding, 0, panelPadding + PD.W(4), panelPadding)
    buttonContainer.Paint = function() end

    -- Button erstellen Funktion
    local function CreateMenuButton(parent, text, onClick, isHighlight, isDanger)
        local btn = vgui.Create("DButton", parent)
        btn:SetText("")
        btn:Dock(TOP)
        btn:SetTall(buttonHeight)
        btn:DockMargin(0, 0, 0, buttonSpacing)
        
        local isHovered = false
        btn.Paint = function(s, w, h)
            -- Hintergrund
            local bgColor = isHovered and PD.Theme.Colors.BackgroundHover or PD.Theme.Colors.BackgroundLight
            if isDanger and isHovered then
                bgColor = PD.ColorAlpha(PD.Theme.Colors.StatusCritical, 0.3)
            end
            draw.RoundedBox(0, 0, 0, w, h, bgColor)
            
            -- Linke Akzentlinie
            local accentColor = PD.Theme.Colors.AccentGray
            if isHovered then
                accentColor = isDanger and PD.Theme.Colors.StatusCritical or PD.Theme.Colors.AccentRed
            elseif isHighlight then
                accentColor = PD.Theme.Colors.StatusActive
            end
            surface.SetDrawColor(accentColor)
            surface.DrawRect(0, 0, PD.W(3), h)
            
            -- Obere/Untere Linien
            surface.SetDrawColor(PD.Theme.Colors.AccentGray.r, PD.Theme.Colors.AccentGray.g, PD.Theme.Colors.AccentGray.b, 80)
            surface.DrawRect(PD.W(3), 0, w - PD.W(3), 1)
            surface.DrawRect(PD.W(3), h - 1, w - PD.W(3), 1)
            
            -- Ecken-Dekor rechts (bei Hover)
            if isHovered then
                local cornerSize = PD.W(8)
                local cornerColor = isDanger and PD.Theme.Colors.StatusCritical or PD.Theme.Colors.AccentRed
                surface.SetDrawColor(cornerColor)
                -- Oben rechts
                surface.DrawLine(w - cornerSize, 0, w, 0)
                surface.DrawLine(w - 1, 0, w - 1, cornerSize)
                -- Unten rechts
                surface.DrawLine(w - cornerSize, h - 1, w, h - 1)
                surface.DrawLine(w - 1, h - cornerSize, w - 1, h)
            end
            
            -- Text
            local textColor = isHovered and PD.Theme.Colors.Text or PD.Theme.Colors.TextDim
            if isDanger and isHovered then
                textColor = PD.Theme.Colors.StatusCritical
            end
            draw.DrawText(text, "MLIB.16", PD.W(15), h / 2 - PD.H(8), textColor, TEXT_ALIGN_LEFT)
            
            -- Pfeil rechts (bei Hover)
            if isHovered then
                draw.DrawText("›", "MLIB.22", w - PD.W(15), h / 2 - PD.H(11), textColor, TEXT_ALIGN_RIGHT)
            end
        end
        
        btn.OnCursorEntered = function()
            isHovered = true
            surface.PlaySound("UI/buttonrollover.wav")
        end
        btn.OnCursorExited = function() isHovered = false end
        
        btn.DoClick = function()
            surface.PlaySound("UI/buttonclick.wav")
            onClick()
        end
        
        return btn
    end

    -- "Weiter" Button (grün hervorgehoben)
    CreateMenuButton(buttonContainer, "Weiterspielen", function()
        mainFrameESC:Remove()
    end, true, false)

    -- "Einstellungen" Button
    CreateMenuButton(buttonContainer, "Spieleinstellungen", function()
        mainFrameESC:Remove()
        gui.ActivateGameUI()
        RunConsoleCommand("gamemenucommand", "openoptionsdialog")
    end, false, false)

    -- Custom Buttons
    for _, v in ipairs(buttons) do
        if v.admin and not ply:IsAdmin() then
            continue
        end

        CreateMenuButton(buttonContainer, v.name, function()
            v.func(mainFrameESC)
            if IsValid(mainFrameESC) then
                mainFrameESC:Remove()
            end
        end, false, false)
    end

    -- "Verlassen" Button (rot/gefährlich)
    CreateMenuButton(buttonContainer, "Verlassen", function()
        RunConsoleCommand("disconnect")
    end, false, true)

    -- Rechte Seite: Server Info Panel + Credits Panel (vertikal zentriert)
    local infoPanelH = PD.H(200)
    local entryH = PD.H(34)
    local creditsPanelH = PD.H(45) + #(PD.Credits or {}) * entryH
    local panelGap = PD.H(8)
    local totalHeight = infoPanelH + panelGap + creditsPanelH
    local startY = ScrH() / 2 - totalHeight / 2

    local infoPanel = vgui.Create("DPanel", mainFrameESC)
    infoPanel:SetSize(PD.W(300), infoPanelH)
    infoPanel:SetPos(ScrW() - PD.W(350), startY)
    
    infoPanel.Paint = function(s, w, h)
        -- Hintergrund
        draw.RoundedBox(0, 0, 0, w, h, Color(PD.Theme.Colors.Background.r, PD.Theme.Colors.Background.g, PD.Theme.Colors.Background.b, 200))
        
        -- Linke Akzentlinie
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(0, 0, PD.W(3), h)
        
        -- Obere Linie
        surface.DrawRect(PD.W(3), 0, w - PD.W(3), 1)
        
        -- Untere Linie
        surface.DrawRect(PD.W(3), h - 1, w - PD.W(3), 1)
        
        -- Ecken-Dekor
        local cornerSize = PD.W(10)
        -- Oben rechts
        surface.DrawLine(w - cornerSize, 0, w, 0)
        surface.DrawLine(w - 1, 0, w - 1, cornerSize)
        -- Unten rechts
        surface.DrawLine(w - cornerSize, h - 1, w, h - 1)
        surface.DrawLine(w - 1, h - cornerSize, w - 1, h)
        
        -- DEFCON Status
        local defconData = DEFCON:GetDefcon()
        draw.DrawText("SYSTEMSTATUS", "MLIB.12", PD.W(15), PD.H(15), PD.Theme.Colors.AccentGray, TEXT_ALIGN_LEFT)
        
        -- Trennlinie
        surface.SetDrawColor(PD.Theme.Colors.AccentGray.r, PD.Theme.Colors.AccentGray.g, PD.Theme.Colors.AccentGray.b, 100)
        surface.DrawRect(PD.W(15), PD.H(35), w - PD.W(30), 1)
        
        -- DEFCON Info
        draw.DrawText("DEFCON", "MLIB.10", PD.W(15), PD.H(50), PD.Theme.Colors.TextMuted, TEXT_ALIGN_LEFT)
        draw.DrawText(defconData.nr .. " - " .. defconData.txt, "MLIB.14", PD.W(15), PD.H(65), defconData.col, TEXT_ALIGN_LEFT)
        
        -- Spielzeit
        local playTime = math.floor(CurTime() / 60)
        local hours = math.floor(playTime / 60)
        local mins = playTime % 60
        draw.DrawText("SPIELZEIT", "MLIB.10", PD.W(15), PD.H(95), PD.Theme.Colors.TextMuted, TEXT_ALIGN_LEFT)
        draw.DrawText(string.format("%02d:%02d", hours, mins), "MLIB.14", PD.W(15), PD.H(110), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
        
        -- Ping
        draw.DrawText("VERBINDUNG", "MLIB.10", PD.W(15), PD.H(140), PD.Theme.Colors.TextMuted, TEXT_ALIGN_LEFT)
        local ping = LocalPlayer():Ping()
        local pingColor = PD.Theme.Colors.StatusActive
        if ping > 100 then pingColor = PD.Theme.Colors.StatusCritical
        elseif ping > 50 then pingColor = PD.Theme.Colors.StatusWarning end
        draw.DrawText(ping .. " ms", "MLIB.14", PD.W(15), PD.H(155), pingColor, TEXT_ALIGN_LEFT)
    end

    -- Credits Panel (unterhalb von Systemstatus)
    do
        local ix, iy = infoPanel:GetPos()
        local iw, ih = infoPanel:GetSize()
        local creditsPanel = vgui.Create("DPanel", mainFrameESC)
        creditsPanel:SetSize(PD.W(300), creditsPanelH)
        creditsPanel:SetPos(ix, iy + ih + panelGap)
        creditsPanel.Paint = function(s, w, h)
            local credits = PD.Credits or {}
            
            draw.RoundedBox(0, 0, 0, w, h, Color(PD.Theme.Colors.Background.r, PD.Theme.Colors.Background.g, PD.Theme.Colors.Background.b, 200))
            surface.SetDrawColor(PD.Theme.Colors.AccentGray)
            surface.DrawRect(0, 0, PD.W(3), h)
            surface.DrawRect(PD.W(3), 0, w - PD.W(3), 1)
            surface.DrawRect(PD.W(3), h - 1, w - PD.W(3), 1)

            draw.DrawText("CREDITS", "MLIB.12", PD.W(15), PD.H(8), PD.Theme.Colors.AccentGray, TEXT_ALIGN_LEFT)

            surface.SetDrawColor(PD.Theme.Colors.AccentGray.r, PD.Theme.Colors.AccentGray.g, PD.Theme.Colors.AccentGray.b, 100)
            surface.DrawRect(PD.W(15), PD.H(28), w - PD.W(30), 1)

            local startY = PD.H(34)
            local lineH = PD.H(34)
            for i, entry in ipairs(credits) do
                local roleLabel = (entry.role or ""):upper()
                draw.DrawText(roleLabel, "MLIB.10", PD.W(15), startY + (i-1) * lineH, PD.Theme.Colors.TextMuted, TEXT_ALIGN_LEFT)

                local valueText = table.concat(entry.names or {}, ", ")
                draw.DrawText(valueText, "MLIB.14", PD.W(15), startY + PD.H(14) + (i-1) * lineH, PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
            end
        end
    end

    -- Copyright/Version unten
    local footer = vgui.Create("DPanel", mainFrameESC)
    footer:SetSize(PD.W(300), PD.H(30))
    footer:SetPos(panelX, panelY + panelHeight + PD.H(10))
    footer.Paint = function(s, w, h)
        draw.DrawText("IMPERIAL ROLEPLAY • " .. os.date("%Y"), "MLIB.10", 0, 0, PD.Theme.Colors.TextMuted, TEXT_ALIGN_LEFT)
    end
end
