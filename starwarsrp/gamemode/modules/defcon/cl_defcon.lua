-- Client
DEFCON = DEFCON or {}

local Deftext = ""

net.Receive("ChangeDefcon",function()
    local id = net.ReadInt(4)
    local text = net.ReadString()
    local name = net.ReadString()

    -- if not DEFCON:GetID(id) then return then
        
    DEFCON.Active = DEFCON.ID[id]
    
    -- Globale Alert-Popup anzeigen (aus cl_ui.lua)
    local defconData = DEFCON.ID[id]
    if defconData then
        PD.Popup({
            center = true,  -- Zentrale Anzeige
            title = "DEFCON ÄNDERUNG",
            mainText = tostring(defconData.nr),
            subText = defconData.txt or "STATUS",
            infoText = name and name ~= "" and ("Geändert von: " .. name) or "",
            color = defconData.col,
            duration = 5,
            sound = DEFCON.Active.sound,
            pulse = defconData.nr <= 2  -- Pulsieren bei kritischem DEFCON
        })
    end
    
    chat.AddText(CONFIG:GetConfig("textcolor"),LANG.DEFCON_UI_CHANGED_First..name..LANG.DEFCON_UI_CHANGED_Second..DEFCON.Active.nr..LANG.DEFCON_UI_CHANGED_Third .. "!")
    if text != "" then Deftext = text chat.AddText(Color(255,0,0),LANG.DEFCON_UI_COMMANDS..": ",CONFIG:GetConfig("textcolor"),text) end
end)

net.Receive("SyncDefcon",function()
    local id = net.ReadInt(4)
    local text = net.ReadString()
    
    DEFCON.Active = DEFCON.ID[id]
    if text != "" then Deftext = text end
end)

-- DEFCON HUD - Star Wars Andor Imperial Style (Zentral über PD.Theme)
AddSmoothElement(PD.W(20), PD.H(20), PD.W(280), PD.H(100), function(smoothX, smoothY)
    if PD.FOV.thirdPerson then return end
    
    local defconColor = DEFCON.Active.col
    local defconText = DEFCON.Active.txt or "STATUS"

    -- Feste Panel-Größe
    local numberSectionW = PD.W(65)
    local textSectionW = PD.W(145)
    local panelW = numberSectionW + textSectionW
    
    -- Text in Zeilen aufteilen wenn zu lang
    local maxTextWidth = textSectionW - PD.W(20)
    local textLines = PD.WrapText(defconText, maxTextWidth, "MLIB.14")
    local lineHeight = PD.H(16)
    local textBlockHeight = #textLines * lineHeight
    
    -- Panel-Höhe anpassen wenn mehr als eine Zeile
    local basePanelH = PD.H(85)
    local extraHeight = math.max(0, (#textLines - 1) * lineHeight)
    local panelH = basePanelH + extraHeight

    -- Hintergrund
    draw.RoundedBox(0, smoothX, smoothY, panelW, panelH, PD.Theme.Colors.BackgroundLight)

    -- Obere Akzentlinie (DEFCON Farbe)
    surface.SetDrawColor(defconColor)
    surface.DrawRect(smoothX, smoothY, panelW, PD.H(3))

    -- Linke Akzentlinie
    surface.SetDrawColor(PD.Theme.Colors.AccentGray)
    surface.DrawRect(smoothX, smoothY + PD.H(3), 1, panelH - PD.H(3))

    -- Rechte Akzentlinie
    surface.DrawRect(smoothX + panelW - 1, smoothY + PD.H(3), 1, panelH - PD.H(3))

    -- Untere Akzentlinie
    surface.DrawRect(smoothX, smoothY + panelH - 1, panelW, 1)

    -- Imperial Ecken-Dekor (unten links)
    local cornerSize = PD.W(8)
    surface.SetDrawColor(PD.Theme.Colors.AccentGray)
    surface.DrawLine(smoothX, smoothY + panelH - cornerSize, smoothX, smoothY + panelH)
    surface.DrawLine(smoothX, smoothY + panelH - 1, smoothX + cornerSize, smoothY + panelH - 1)

    -- Imperial Ecken-Dekor (unten rechts)
    surface.DrawLine(smoothX + panelW - 1, smoothY + panelH - cornerSize, smoothX + panelW - 1, smoothY + panelH)
    surface.DrawLine(smoothX + panelW - cornerSize, smoothY + panelH - 1, smoothX + panelW, smoothY + panelH - 1)

    -- Vertikale Trennlinie
    PD.DrawDivider(smoothX + numberSectionW, smoothY + PD.H(12), 1, PD.ColorAlpha(PD.Theme.Colors.AccentGray, 0.5))
    surface.SetDrawColor(PD.Theme.Colors.AccentGray.r, PD.Theme.Colors.AccentGray.g, PD.Theme.Colors.AccentGray.b, 100)
    surface.DrawRect(smoothX + numberSectionW, smoothY + PD.H(12), 1, panelH - PD.H(30))

    -- "DEFCON" Label über der Nummer
    PD.DrawLabel("DEFCON", "MLIB.12", smoothX + numberSectionW / 2, smoothY + PD.H(8), PD.Theme.Colors.AccentGray, TEXT_ALIGN_CENTER)

    -- DEFCON Nummer (groß, im Andor-Stil mit Rahmen)
    local numX = smoothX + numberSectionW / 2
    local numY = smoothY + PD.H(22)
    local numSize = PD.W(38)
    
    -- Nummer-Box
    PD.DrawBox(numX - numSize / 2, numY, numSize, PD.H(38), {
        background = Color(defconColor.r, defconColor.g, defconColor.b, 40),
        border = defconColor,
        borderWidth = 1
    })
    
    -- DEFCON Nummer
    draw.DrawText(DEFCON.Active.nr, "MLIB.35", numX, numY + PD.H(2), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)

    -- Rechte Sektion: Status-Text
    local textX = smoothX + numberSectionW + PD.W(12)
    
    -- "STATUS" Label
    PD.DrawLabel("STATUS", "MLIB.12", textX, smoothY + PD.H(12))
    
    -- Status-Bezeichnung (mehrzeilig wenn nötig)
    for i, line in ipairs(textLines) do
        local lineY = smoothY + PD.H(26) + (i - 1) * lineHeight
        draw.DrawText(line, "MLIB.14", textX, lineY, PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
    end

    -- Status-Indikator Balken
    local barWidth = textSectionW - PD.W(20)
    local barHeight = PD.H(4)
    local barX = textX
    local barY = smoothY + panelH - PD.H(18)

    -- Balken-Label
    PD.DrawLabel("THREAT LEVEL", "MLIB.10", barX, barY - PD.H(12), PD.ColorAlpha(PD.Theme.Colors.AccentGray, 0.75))

    -- Threat Level Bar
    local fillPercent = (6 - DEFCON.Active.nr) / 5  -- DEFCON 5 = 20%, DEFCON 1 = 100%
    PD.DrawProgressBar(barX, barY, barWidth, barHeight, fillPercent, defconColor)

    -- Status-Punkt (pulsierend bei niedrigem DEFCON)
    local pulse = DEFCON.Active.nr <= 2
    PD.DrawStatusIndicator(smoothX + panelW - PD.W(16), smoothY + PD.H(10), PD.W(6), defconColor, pulse)
end)


function DEFCON:GetDefcon()
    return DEFCON.Active
end

function DEFCON:GetColor()
    return DEFCON.Active.col
end

function DEFCON:GetText()
    return Deftext
end

concommand.Add("syncdefcon",function()
    net.Start("SyncDefcon")
    net.SendToServer()

    chat.AddText(CONFIG:GetConfig("textcolor"),"Das Defcon wurde synchronisiert!")
end)

hook.Add("PlayerInitialSpawn","SyncDefcon",function()
    net.Start("SyncDefcon")
    net.SendToServer()
end)
