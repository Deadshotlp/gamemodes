-- Scoreboard - Star Wars Andor Imperial Style (Zentral über PD.Theme)

PD.Scoreboard = PD.Scoreboard or {}

hook.Add("Initialize", "RemoveGamemodeFunctions", function()
    GAMEMODE.ScoreboardShow = nil
    GAMEMODE.ScoreboardHide = nil
end)

hook.Add("ScoreboardShow", "Lukas_TAB_ScoreboardShow", function()
    PD.Scoreboard:Draw()
    return false
end)

hook.Add("ScoreboardHide", "Lukas_TAB_ScoreboardHide", function()
    if IsValid(mainFrameScore) then
        mainFrameScore:Remove()
    end
end)

local function CheckPlayerUnit(ply, unit)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if ply:Nick() == "00-0000 " .. "Unknown" then return unit == "Betritt die Galaxy" end

    local jobID, jobTable = "", nil

    local success, err = pcall(function()
        jobID, jobTable = ply:GetJob()
    end)

    if not success or not jobTable then
        return unit == "FEHLERHAFTE DATEN"
    end

    if jobTable.unit == unit then
        return true
    end

    for k, v in SortedPairs(PD.JOBS.GetSubUnit(false, true)) do
        if v.unit == unit and jobTable.unit == v.name then
            return true
        end
    end

    return false
end

local function HasUnitPlayers(unit)
    if unit == nil then return false end
    for _, ply in ipairs(player.GetAll()) do

        if CheckPlayerUnit(ply, unit) then
            return true
        end
    end
    return false
end

local function DrawImperialPanel(x, y, w, h, title, content, contentSub, accentColor)
    accentColor = accentColor or PD.Theme.Colors.AccentGray
    
    -- Hintergrund
    draw.RoundedBox(0, x, y, w, h, PD.Theme.Colors.Background)
    
    -- Linke Akzentlinie
    surface.SetDrawColor(accentColor)
    surface.DrawRect(x, y, PD.W(3), h)
    
    -- Obere Linie
    surface.SetDrawColor(PD.Theme.Colors.AccentGray)
    surface.DrawRect(x + PD.W(3), y, w - PD.W(3), 1)
    
    -- Untere Linie
    surface.DrawRect(x + PD.W(3), y + h - 1, w - PD.W(3), 1)
    
    -- Ecken-Dekor (rechts oben)
    local cornerSize = PD.W(8)
    surface.DrawLine(x + w - cornerSize, y, x + w, y)
    surface.DrawLine(x + w - 1, y, x + w - 1, y + cornerSize)
    
    -- Ecken-Dekor (rechts unten)
    surface.DrawLine(x + w - cornerSize, y + h - 1, x + w, y + h - 1)
    surface.DrawLine(x + w - 1, y + h - cornerSize, x + w - 1, y + h)
    
    -- Content
    if content then
        draw.DrawText(content, "MLIB.22", x + w / 2, y + PD.H(8), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
    end
    
    -- Content Sub
    if contentSub then
        draw.DrawText(contentSub, "MLIB.14", x + w / 2, y + PD.H(32), PD.Theme.Colors.TextDim, TEXT_ALIGN_CENTER)
    end
end

function PD.Scoreboard:Draw()
    if IsValid(mainFrameScore) then return end

    local function LoadUnits()
        local tbl = {}

        for k, v in SortedPairs(PD.JOBS.GetUnit(false, true)) do
            if not tbl[k] then
                tbl[k] = v
            end
        end

        tbl["Betritt die Galaxy"] = {
            color = Color(255, 255, 255),
            unit = "Betritt die Galaxy"
        }

        -- tbl["FEHLERHAFTE DATEN"] = {
        --     color = Color(255, 0, 0),
        --     unit = "FEHLERHAFTE DATEN"
        -- }

        return tbl
    end

    local function LoadSubUnits()
        local tbl = {}

        for k, v in SortedPairs(PD.JOBS.GetSubUnit(false, true)) do
            if not tbl[k] then
                tbl[k] = v
            end
        end

        tbl["Betritt die Galaxy"] = {
            color = Color(255, 255, 255),
            unit = "Betritt die Galaxy"
        }

        -- tbl["FEHLERHAFTE DATEN"] = {
        --     color = Color(255, 0, 0),
        --     unit = "FEHLERHAFTE DATEN"
        -- }

        return tbl
    end

    mainFrameScore = vgui.Create("DFrame")
    mainFrameScore:SetSize(ScrW(), ScrH())
    mainFrameScore:SetPos(0, 0)
    mainFrameScore:SetTitle("")
    mainFrameScore:SetDraggable(false)
    mainFrameScore:ShowCloseButton(false)
    mainFrameScore:MakePopup()
    mainFrameScore:SetKeyboardInputEnabled(false)
    
    mainFrameScore.Paint = function(s, w, h)
        -- Blur-Effekt
        Derma_DrawBackgroundBlur(s, s.startTime or SysTime())
        
        -- Dunkler Overlay
        draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 180))
        
        -- Subtiles Grid-Muster im Hintergrund
        if PD.Theme and PD.Theme.DrawGridPattern then
            PD.Theme.DrawGridPattern(0, 0, w, h, PD.W(40), PD.Theme.ColorAlpha(PD.Theme.Colors.BackgroundLight, 0.15))
        end
    end
    mainFrameScore.startTime = SysTime()

    -- Header mit Server-Name
    local headerPanel = vgui.Create("DPanel", mainFrameScore)
    headerPanel:Dock(TOP)
    headerPanel:SetTall(PD.H(120))
    headerPanel.Paint = function(s, w, h)
        -- Imperial Header-Box
        local boxW = PD.W(800)
        local boxH = PD.H(80)
        local boxX = w / 2 - boxW / 2
        local boxY = PD.H(20)
        
        -- Hintergrund
        draw.RoundedBox(0, boxX, boxY, boxW, boxH, PD.Theme.Colors.Background)
        
        -- Obere Akzentlinie (Imperial Red)
        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
        surface.DrawRect(boxX, boxY, boxW, PD.H(4))
        
        -- Untere Akzentlinie
        surface.DrawRect(boxX, boxY + boxH - PD.H(4), boxW, PD.H(4))
        
        -- Seitliche Linien
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(boxX, boxY + PD.H(4), 1, boxH - PD.H(8))
        surface.DrawRect(boxX + boxW - 1, boxY + PD.H(4), 1, boxH - PD.H(8))
        
        -- Imperial Ecken-Dekor
        local cornerSize = PD.W(20)
        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
        -- Oben links
        surface.DrawRect(boxX, boxY, cornerSize, PD.H(2))
        surface.DrawRect(boxX, boxY, PD.W(2), cornerSize)
        -- Oben rechts
        surface.DrawRect(boxX + boxW - cornerSize, boxY, cornerSize, PD.H(2))
        surface.DrawRect(boxX + boxW - PD.W(2), boxY, PD.W(2), cornerSize)
        -- Unten links
        surface.DrawRect(boxX, boxY + boxH - PD.H(2), cornerSize, PD.H(2))
        surface.DrawRect(boxX, boxY + boxH - cornerSize, PD.W(2), cornerSize)
        -- Unten rechts
        surface.DrawRect(boxX + boxW - cornerSize, boxY + boxH - PD.H(2), cornerSize, PD.H(2))
        surface.DrawRect(boxX + boxW - PD.W(2), boxY + boxH - cornerSize, PD.W(2), cornerSize)
        
        -- Server Name
        draw.DrawText(GetHostName(), "MLIB.40", w / 2, boxY + PD.H(12), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
        
        -- Spieleranzahl
        local playerCount = #player.GetAll() .. " / " .. game.MaxPlayers() .. " SPIELER"
        draw.DrawText(playerCount, "MLIB.14", w / 2, boxY + PD.H(52), PD.Theme.Colors.TextDim, TEXT_ALIGN_CENTER)
    end

    -- Linkes Panel (Command Structure)
    local leftPanel = vgui.Create("DPanel", mainFrameScore)
    leftPanel:Dock(LEFT)
    leftPanel:SetWide(PD.W(380))
    leftPanel:DockMargin(PD.W(20), 0, 0, PD.H(20))
    leftPanel.Paint = function(s, w, h)
        -- Panel Header
        local headerY = PD.H(10)
        draw.DrawText("Kommandostruktur", "MLIB.24", w / 2, headerY, PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
        
        -- Trennlinie
        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
        surface.DrawRect(PD.W(20), PD.H(45), w - PD.W(40), PD.H(2))
        
        -- Imperial Ecken-Dekor an Trennlinie
        local lineY = PD.H(45)
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(PD.W(10), lineY - PD.H(5), PD.W(2), PD.H(12))
        surface.DrawRect(w - PD.W(12), lineY - PD.H(5), PD.W(2), PD.H(12))
        
        -- Officer Panels
        local panelStartY = PD.H(60)
        local panelH = PD.H(55)
        local panelSpacing = PD.H(8)
        local panelW = w - PD.W(20)
        local panelX = PD.W(10)
        
        local officers = {
            {name = PD.Officer.Table.co, title = "Commanding Officer", color = PD.Theme.Colors.AccentRed},
            {name = PD.Officer.Table.eo, title = "Executive Officer", color = PD.Theme.Colors.AccentOrange},
            {name = PD.Officer.Table.mo, title = "Medical Officer", color = PD.Theme.Colors.AccentBlue},
            {name = PD.Officer.Table.no, title = "Naval Officer", color = PD.Theme.Colors.AccentGray},
            {name = PD.Officer.Table.so, title = "Security Officer", color = PD.Theme.Colors.AccentGray},
            {name = PD.Officer.Table.to, title = "Technical Officer", color = PD.Theme.Colors.AccentGray}
        }
        
        for i, officer in ipairs(officers) do
            local y = panelStartY + (i - 1) * (panelH + panelSpacing)
            DrawImperialPanel(panelX, y, panelW, panelH, officer.title, officer.name, officer.title, officer.color)
        end
    end

    -- Rechtes Panel (Information)
    local rightPanel = vgui.Create("DPanel", mainFrameScore)
    rightPanel:Dock(RIGHT)
    rightPanel:SetWide(PD.W(380))
    rightPanel:DockMargin(0, 0, PD.W(20), PD.H(20))
    rightPanel.Paint = function(s, w, h)
        -- Panel Header
        local headerY = PD.H(10)
        draw.DrawText("Informationen", "MLIB.24", w / 2, headerY, PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
        
        -- Trennlinie
        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
        surface.DrawRect(PD.W(20), PD.H(45), w - PD.W(40), PD.H(2))
        
        -- Imperial Ecken-Dekor an Trennlinie
        local lineY = PD.H(45)
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(PD.W(10), lineY - PD.H(5), PD.W(2), PD.H(12))
        surface.DrawRect(w - PD.W(12), lineY - PD.H(5), PD.W(2), PD.H(12))
        
        -- DEFCON Info
        local defconData = DEFCON:GetDefcon()
        local panelX = PD.W(10)
        local panelW = w - PD.W(20)
        local panelY = PD.H(60)
        local panelH = PD.H(70)
        
        -- DEFCON Panel
        draw.RoundedBox(0, panelX, panelY, panelW, panelH, PD.Theme.Colors.Background)
        
        -- Obere Akzentlinie (DEFCON Farbe)
        surface.SetDrawColor(defconData.col)
        surface.DrawRect(panelX, panelY, panelW, PD.H(3))
        
        -- Seitliche Linien
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(panelX, panelY + PD.H(3), 1, panelH - PD.H(3))
        surface.DrawRect(panelX + panelW - 1, panelY + PD.H(3), 1, panelH - PD.H(3))
        
        -- DEFCON Nummer Box
        local boxSize = PD.H(45)
        local boxX = panelX + PD.W(15)
        local boxY = panelY + (panelH - boxSize) / 2 + PD.H(2)
        
        -- Box Hintergrund
        surface.SetDrawColor(defconData.col.r, defconData.col.g, defconData.col.b, 50)
        surface.DrawRect(boxX, boxY, boxSize, boxSize)
        
        -- Box Rahmen
        surface.SetDrawColor(defconData.col)
        surface.DrawOutlinedRect(boxX, boxY, boxSize, boxSize, 2)
        
        -- DEFCON Nummer
        draw.DrawText(defconData.nr, "MLIB.30", boxX + boxSize / 2, boxY + PD.H(6), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
        
        -- DEFCON Text
        draw.DrawText("DEFCON " .. defconData.nr, "MLIB.18", boxX + boxSize + PD.W(15), panelY + PD.H(18), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
        draw.DrawText(defconData.txt, "MLIB.12", boxX + boxSize + PD.W(15), panelY + PD.H(40), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
        
        -- Server-Zeit Info
        local timeY = panelY + panelH + PD.H(15)
        DrawImperialPanel(panelX, timeY, panelW, PD.H(55), "ZEIT", os.date("%H:%M:%S"), os.date("%d.%m.%Y"), PD.Theme.Colors.AccentBlue)
    end

    -- Mittleres Panel (Spielerliste)
    local mainPanel = vgui.Create("DPanel", mainFrameScore)
    mainPanel:Dock(FILL)
    mainPanel:DockMargin(PD.W(20), 0, PD.W(20), PD.H(20))
    mainPanel.Paint = function(s, w, h) end

    local scrl = vgui.Create("DScrollPanel", mainPanel)
    scrl:Dock(FILL)
    
    -- Scrollbar stylen
    local sbar = scrl:GetVBar()
    sbar:SetWide(PD.W(6))
    sbar.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
    end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.AccentGray)
    end

    for k, v in SortedPairs(LoadUnits()) do
        if not HasUnitPlayers(v.name) then continue end

        -- Unit Header
        local unitHeader = vgui.Create("DPanel", scrl)
        unitHeader:Dock(TOP)
        unitHeader:SetTall(PD.H(45))
        unitHeader:DockMargin(0, PD.H(10), 0, 0)
        unitHeader.Paint = function(s, w, h)
            -- Hintergrund
            draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.Background)
            
            -- Linke Akzentlinie (Unit Farbe)
            local unitColor = v.color or PD.Theme.Colors.AccentGray
            surface.SetDrawColor(unitColor)
            surface.DrawRect(0, 0, PD.W(4), h)
            
            -- Obere Linie
            surface.SetDrawColor(PD.Theme.Colors.AccentGray)
            surface.DrawRect(PD.W(4), 0, w - PD.W(4), 1)
            
            -- Untere Linie
            surface.DrawRect(PD.W(4), h - 1, w - PD.W(4), 1)

            -- Unit Name
            draw.DrawText(v.name, "MLIB.22", PD.W(20), h / 2 - PD.H(11), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
            
            -- Spieleranzahl in dieser Unit
            local count = 0
            for _, ply in pairs(player.GetAll()) do
                if CheckPlayerUnit(ply, v.name) then count = count + 1 end
            end
            draw.DrawText(count .. " Spieler", "MLIB.12", w - PD.W(15), h / 2 - PD.H(6), PD.Theme.Colors.TextDim, TEXT_ALIGN_RIGHT)
            
            -- Imperial Ecken-Dekor
            local cornerSize = PD.W(10)
            surface.SetDrawColor(PD.Theme.Colors.AccentGray)
            surface.DrawLine(w - cornerSize, 0, w, 0)
            surface.DrawLine(w - 1, 0, w - 1, cornerSize)
            surface.DrawLine(w - cornerSize, h - 1, w, h - 1)
            surface.DrawLine(w - 1, h - cornerSize, w - 1, h)
        end

        for k2, v2 in SortedPairs(LoadSubUnits()) do
            if v2.unit ~= v.name then
                continue 
            end

            if not HasUnitPlayers(v2.name) then continue end

            local subUnitHeader = vgui.Create("DPanel", scrl)
            subUnitHeader:Dock(TOP)
            subUnitHeader:SetTall(PD.H(35))
            subUnitHeader:DockMargin(PD.W(20), PD.H(5), 0, 0)
            subUnitHeader.Paint = function(s, w, h)
                -- Hintergrund
                draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)

                -- Linke Akzentlinie (SubUnit Farbe)
                local subUnitColor = v2.color or PD.Theme.Colors.AccentGray
                surface.SetDrawColor(subUnitColor)
                surface.DrawRect(0, 0, PD.W(3), h)

                -- SubUnit Name
                draw.DrawText(v2.name, "MLIB.16", PD.W(15), h / 2 - PD.H(8), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)

                -- Spieleranzahl in dieser SubUnit
                local count = 0
                for _, ply in pairs(player.GetAll()) do
                    if CheckPlayerUnit(ply, v2.name) then count = count + 1 end
                end
                draw.DrawText(count .. " Spieler", "MLIB.12", w - PD.W(15), h / 2 - PD.H(6), PD.Theme.Colors.TextDim, TEXT_ALIGN_RIGHT)
            end

            for _, ply in pairs(player.GetAll()) do
                if not IsValid(ply) or not ply:IsPlayer() then continue end

                local jobID, jobTable = "FEHLER", {
                    color = Color(255, 0, 0),
                    unit = "FEHLERHAFTE DATEN"
                }
                local name = "Unknown"
                local pingColor = PD.Theme.Colors.StatusActive

                if ply:Nick() == "00-0000 " .. "Unknown" then
                    jobID, jobTable = "Betritt die Galaxy", {
                        color = Color(255, 255, 255),
                        unit = "Betritt die Galaxy",
                    }
                    name = ply:Name()
                else
                    local success, result1, result2 = pcall(function()
                        return ply:GetJob()
                    end)
                    if success and result1 and result2 then
                        jobID, jobTable = result1, result2
                        --name = PD.HUD.GetKnownPlayers(ply:SteamID64()) or ply:Name()
                        name = ply:Nick()
                    end
                end

                if not CheckPlayerUnit(ply, v2.name) then continue end

                local plyPanel = vgui.Create("DButton", scrl)
                plyPanel:SetText("")
                plyPanel:Dock(TOP)
                plyPanel:SetTall(PD.H(45))
                plyPanel:DockMargin(PD.W(20), PD.H(2), 0, 0)
                
                local isHovered = false
                plyPanel.Paint = function(s, w, h)
                    -- Hintergrund
                    local bgColor = isHovered and PD.Theme.Colors.BackgroundHover or PD.Theme.Colors.BackgroundLight
                    draw.RoundedBox(0, 0, 0, w, h, bgColor)
                    
                    -- Untere Akzentlinie (Job Farbe)
                    surface.SetDrawColor(jobTable.color or PD.Theme.Colors.AccentGray)
                    surface.DrawRect(0, h - PD.H(2), w, PD.H(2))
                    
                    -- Linke Markierung wenn gehovert
                    if isHovered then
                        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
                        surface.DrawRect(0, 0, PD.W(3), h - PD.H(2))
                    end
                    
                    -- Ping-Farbe bestimmen
                    local ping = ply:Ping()
                    if ping > 100 then
                        pingColor = PD.Theme.Colors.StatusCritical
                    elseif ping > 50 then
                        pingColor = PD.Theme.Colors.StatusWarning
                    else
                        pingColor = PD.Theme.Colors.StatusActive
                    end

                    if jobTable.showid then
                        local nameWords = string.Split(name, " ")
                        name = ""

                        for i = 2, #nameWords do
                            name = name .. " " .. nameWords[i]
                        end
                    end
                    
                    -- Name (links)
                    draw.DrawText(name, "MLIB.16", PD.W(15), h / 2 - PD.H(8), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
                    
                    -- Job (mittig)
                    draw.DrawText(jobTable.name, "MLIB.14", w / 2, h / 2 - PD.H(7), PD.Theme.Colors.TextDim, TEXT_ALIGN_CENTER)
                    
                    -- Ping (rechts)
                    draw.DrawText(ping .. " ms", "MLIB.14", w - PD.W(15), h / 2 - PD.H(7), pingColor, TEXT_ALIGN_RIGHT)
                end
                
                plyPanel.OnCursorEntered = function() isHovered = true end
                plyPanel.OnCursorExited = function() isHovered = false end
                
                plyPanel.DoClick = function()
                    if not LocalPlayer():IsAdmin() then return end
                    
                    -- Mini-Frame für Spieler-Optionen
                    if IsValid(miniFrame) then
                        miniFrame:Remove()
                    end

                    miniFrame = vgui.Create("DFrame")
                    miniFrame:SetSize(PD.W(350), PD.H(400))
                    miniFrame:Center()
                    miniFrame:SetTitle("")
                    miniFrame:SetDraggable(true)
                    miniFrame:ShowCloseButton(false)
                    miniFrame:MakePopup()
                    
                    miniFrame.Paint = function(s, w, h)
                        -- Hintergrund
                        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.Background)
                        
                        -- Obere Akzentlinie
                        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
                        surface.DrawRect(0, 0, w, PD.H(4))
                        
                        -- Rahmen
                        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
                        surface.DrawOutlinedRect(0, 0, w, h, 1)
                        
                        -- Imperial Ecken-Dekor
                        local cornerSize = PD.W(15)
                        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
                        surface.DrawRect(0, 0, cornerSize, PD.H(2))
                        surface.DrawRect(0, 0, PD.W(2), cornerSize)
                        surface.DrawRect(w - cornerSize, 0, cornerSize, PD.H(2))
                        surface.DrawRect(w - PD.W(2), 0, PD.W(2), cornerSize)
                        
                        -- Spielername
                        draw.DrawText(ply:Nick(), "MLIB.20", w / 2, PD.H(15), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
                        
                        -- Trennlinie
                        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
                        surface.DrawRect(PD.W(20), PD.H(45), w - PD.W(40), 1)
                    end
                    
                    -- Close Button
                    local closeBtn = vgui.Create("DButton", miniFrame)
                    closeBtn:SetText("")
                    closeBtn:SetSize(PD.W(25), PD.H(25))
                    closeBtn:SetPos(miniFrame:GetWide() - PD.W(35), PD.H(10))
                    closeBtn.Paint = function(s, w, h)
                        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
                        surface.DrawLine(PD.W(5), PD.H(5), w - PD.W(5), h - PD.H(5))
                        surface.DrawLine(w - PD.W(5), PD.H(5), PD.W(5), h - PD.H(5))
                    end
                    closeBtn.DoClick = function()
                        miniFrame:Remove()
                    end
                    
                    -- Scroll für Buttons
                    local btnScrl = vgui.Create("DScrollPanel", miniFrame)
                    btnScrl:SetPos(PD.W(15), PD.H(60))
                    btnScrl:SetSize(miniFrame:GetWide() - PD.W(30), miniFrame:GetTall() - PD.H(80))
                    
                    -- Scrollbar stylen
                    local btnSbar = btnScrl:GetVBar()
                    btnSbar:SetWide(PD.W(4))
                    btnSbar.Paint = function(s, w, h) end
                    btnSbar.btnUp.Paint = function() end
                    btnSbar.btnDown.Paint = function() end
                    btnSbar.btnGrip.Paint = function(s, w, h)
                        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.AccentGray)
                    end

                    for _, btnData in pairs(PD.Scoreboard.Buttons) do
                        local btn = vgui.Create("DButton", btnScrl)
                        btn:SetText("")
                        btn:Dock(TOP)
                        btn:SetTall(PD.H(40))
                        btn:DockMargin(0, 0, 0, PD.H(5))
                        
                        local btnHover = false
                        btn.Paint = function(s, w, h)
                            local bgCol = btnHover and PD.Theme.Colors.BackgroundHover or PD.Theme.Colors.BackgroundLight
                            draw.RoundedBox(0, 0, 0, w, h, bgCol)
                            
                            -- Linke Akzentlinie
                            surface.SetDrawColor(btnHover and PD.Theme.Colors.AccentRed or PD.Theme.Colors.AccentGray)
                            surface.DrawRect(0, 0, PD.W(3), h)
                            
                            -- Text
                            draw.DrawText(btnData.name, "MLIB.16", PD.W(15), h / 2 - PD.H(8), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
                        end
                        
                        btn.OnCursorEntered = function() btnHover = true end
                        btn.OnCursorExited = function() btnHover = false end
                        
                        btn.DoClick = function()
                            btnData.func(LocalPlayer(), ply)
                            miniFrame:Remove()
                        end
                    end
                end

                plyPanel.DoRightClick = function()
                    ply:ShowProfile()
                end
            end
        end
    end
end

hook.Add("Tick", "Lukas_TAB_ScoreboardTick", function()
    -- PD.Scoreboard:Draw()
end)

if mainFrameScore then
    mainFrameScore:Remove()
end

local tbl = {"A5", "F12", "D7", "G2", "H15", "J3", "K9", "L1", "M14", "N4", "B6", "C11", "E8", "F13", "G10", "H16",
             "I3", "J7", "K2", "L18", "M5", "N12", "O6", "P9", "Q11", "R14", "S8", "T4", "U15", "V1", "W13", "X2",
             "Y17", "Z6", "A10", "B3"}

local function shuffleTable(t)
    local shuffled = {}
    for i = #t, 1, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

local function randomCode()
    local code = ""
    local stbl = shuffleTable(tbl)
    for i = 1, 10 do
        code = code .. stbl[i]
    end
    return code
end

function Decode_Menu(vfunkstr)
    if IsValid(mainFrameDecode) then
        return
    end
    local rCode = randomCode()
    local selfCode = ""

    if vfunkstr == nil then
        vfunkstr = "N/A"
    end

    mainFrameDecode = PD.Frame("Decode", PD.W(1000), PD.H(650), true)

    local mainPanel = PD.Panel(mainFrameDecode)
    mainPanel:Dock(FILL)
    mainPanel:SetWide(PD.W(610))

    local panelRight = PD.Panel(mainFrameDecode)
    panelRight:Dock(RIGHT)
    panelRight:SetWide(PD.W(360))

    local lbl = PD.Label("Verschlüsselter Funk: \n" .. vfunkstr, panelRight)

    local DeCodelbl = PD.Label("Gesuchter Code: \n" .. rCode, panelRight)

    local times = 90
    local time = PD.Label(LANG.COMMANDS_UI_DECODE_TIME .. ": " .. times, panelRight)
    time:SetFont("MLIB.40")
    time:SetTall(PD.H(50))

    timer.Create("DecodeTimer", 1, times, function()
        times = times - 1
        time:SetText(LANG.COMMANDS_UI_DECODE_TIME .. ": " .. times)

        if times == 0 then
            timer.Remove("DecodeTimer")
            chat.AddText(red, "[DECODE] ", white, LANG.COMMANDS_UI_DECODE_FAILED)
            mainFrameDecode:Remove()
        end
    end)

    local name = "N/A"
    local x, y = PD.W(10), PD.H(10)
    local sort = 1
    local tbl = shuffleTable(tbl)
    for i = 1, 36 do
        name = tbl[i]
        local panel = PD.Button(name, mainPanel, function(self)
            if self:GetBackColor() == Color(0,255,0) then
                self:SetBackColor(Color(50, 50, 50))
                selfCode = selfCode:gsub(self:GetText(), "")
            else
                self:SetBackColor(Color(0,255,0))
                selfCode = selfCode .. self:GetText()

                -- if times == 30 then
                --     timer.Create("DecodeTimer", 1, 30, function()
                --         times = times - 1
                --         time:SetText("Zeit: " .. times)

                --         if times == 0 then
                --             timer.Remove("DecodeTimer")
                --             chat.AddText(red, "[DECODE] ", white, "Der Code wurde nicht erfolgreich entschlüsselt!")
                --             mainFrameDecode:Remove()
                --         end
                --     end)
                -- end
            end

            UpdateCode()
        end)
        panel:Dock(NODOCK)
        panel:SetSize(PD.W(90), PD.H(90))
        panel:SetPos(x, y)
        panel:SetBackColor(Color(50, 50, 50))

        if sort == 6 then
            y = y + PD.H(100)
            x = PD.W(10)
            sort = 1
        else
            x = x + PD.W(100)
            sort = sort + 1
        end
    end

    function UpdateCode()
        if IsValid(Codelbl) then
            Codelbl:Remove()
        end

        Codelbl = PD.Label(LANG.COMMANDS_UI_DECODE_YOUR_CODE .. "\n" .. selfCode, panelRight)
        Codelbl:Dock(BOTTOM)
    end

    local btn = PD.Button("Entschlüsseln", panelRight, function()
        if rCode == selfCode then
            timer.Remove("DecodeTimer")

            chat.AddText(red, "[DECODE] ", white, LANG.COMMANDS_UI_DECODE_SUCCESS)
            net.Start("CMD_Decode")
            net.WriteString(vfunkstr)
            net.SendToServer()
            mainFrameDecode:Remove()
        else
            chat.AddText(red, "[DECODE] ", white, LANG.COMMANDS_UI_DECODE_FAILED)
        end
    end)
    btn:Dock(BOTTOM)
    btn:SetTall(PD.H(50))
end

concommand.Add("decode_menu_test", function(ply, cmd, args)
    local vfunkstr = "Hallo Günther"
    Decode_Menu(vfunkstr)
end)
