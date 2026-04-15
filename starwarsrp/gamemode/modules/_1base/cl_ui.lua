--[[
    Zentrales UI Theme System - Andor Imperial Style
    Alle UI-Elemente sollen diese Konfiguration nutzen
    
    VERWENDUNG:
    Statt PD.Frame(), PD.Button() etc. nutze:
    - PD.Frame("Titel", breite, höhe, close)
    - PD.Button("Text", parent, onClick)
    - PD.Panel(parent, config)
    - PD.Scroll(parent)
    - PD.TextEntry(parent, placeholder, value)
    - PD.Checkbox(parent, text, value, onChange)
    - PD.Slider(parent, label, min, max, value, onChange)
    
    Diese Funktionen wenden automatisch den Imperial Andor Style an.
]]

PD = PD or {}
PD.Theme = PD.Theme or {}

-- ============================================
-- FARBEN - Imperial Andor Style
-- ============================================
PD.Theme.Colors = {
    -- Hintergründe
    Background = Color(15, 15, 20, 245),
    BackgroundLight = Color(25, 25, 30, 240),
    BackgroundDark = Color(10, 10, 15, 250),
    BackgroundTransparent = Color(15, 15, 20, 180),
    BackgroundHover = Color(35, 35, 45, 255),
    
    -- Akzentfarben (Imperial)
    AccentGray = Color(120, 120, 130, 200),
    AccentRed = Color(178, 30, 30, 255),
    AccentGreen = Color(45, 140, 50, 255),
    AccentBlue = Color(60, 100, 160, 255),
    AccentOrange = Color(255, 165, 0, 255),
    AccentYellow = Color(255, 255, 0, 255),
    
    -- Text
    Text = Color(220, 220, 225, 255),
    TextDim = Color(160, 160, 170, 200),
    TextMuted = Color(100, 100, 110, 180),
    TextHighlight = Color(255, 255, 255, 255),
    
    -- Status
    StatusActive = Color(45, 140, 50, 255),
    StatusInactive = Color(178, 30, 30, 255),
    StatusWarning = Color(255, 165, 0, 255),
    StatusCritical = Color(200, 0, 0, 255),
    
    -- UI Elemente
    ButtonBg = Color(35, 35, 40, 255),
    ButtonHover = Color(50, 50, 60, 255),
    ButtonActive = Color(178, 30, 30, 255),
    InputBg = Color(20, 20, 25, 255),
    InputBorder = Color(60, 60, 70, 255),
    InputFocus = Color(178, 30, 30, 255),
    
    -- Spezial
    Border = Color(80, 80, 90, 150),
    Divider = Color(60, 60, 70, 100),
    Shadow = Color(0, 0, 0, 100),
}

-- ============================================
-- ABSTÄNDE & GRÖßEN
-- ============================================
PD.Spacing = {
    XS = 4,
    SM = 8,
    MD = 12,
    LG = 20,
    XL = 30,
}

PD.BorderWidth = {
    Thin = 1,
    Normal = 2,
    Thick = 3,
}

PD.CornerSize = 12
PD.AccentHeight = 3

-- ============================================
-- HILFSFUNKTIONEN
-- ============================================

function PD.ColorAlpha(color, alphaMult)
    if not color then return Color(255, 0, 255) end
    return Color(color.r, color.g, color.b, (color.a or 255) * (alphaMult or 1))
end

function PD.LerpColor(from, to, t)
    t = math.Clamp(t, 0, 1)
    return Color(
        Lerp(t, from.r, to.r),
        Lerp(t, from.g, to.g),
        Lerp(t, from.b, to.b),
        Lerp(t, from.a or 255, to.a or 255)
    )
end

-- ============================================
-- ZEICHENFUNKTIONEN
-- ============================================

-- Imperial Ecken-Dekor zeichnen
function PD.DrawCorners(x, y, w, h, color, size)
    size = size or PD.W(PD.CornerSize)
    local col = color or PD.Theme.Colors.AccentGray
    
    surface.SetDrawColor(col)
    
    -- Oben links
    surface.DrawLine(x, y, x, y + size)
    surface.DrawLine(x, y, x + size, y)
    
    -- Oben rechts
    surface.DrawLine(x + w - 1, y, x + w - 1, y + size)
    surface.DrawLine(x + w - size, y, x + w, y)
    
    -- Unten links
    surface.DrawLine(x, y + h - size, x, y + h)
    surface.DrawLine(x, y + h - 1, x + size, y + h - 1)
    
    -- Unten rechts
    surface.DrawLine(x + w - 1, y + h - size, x + w - 1, y + h)
    surface.DrawLine(x + w - size, y + h - 1, x + w, y + h - 1)
end

-- Imperial Panel-Hintergrund
function PD.DrawPanel(x, y, w, h, config)
    config = config or {}
    local bgColor = config.background or PD.Theme.Colors.Background
    local accentColor = config.accent or PD.Theme.Colors.AccentRed
    local accentTop = config.accentTop ~= false
    local accentBottom = config.accentBottom or false
    local corners = config.corners ~= false
    local borders = config.borders or false
    local accentHeight = PD.H(config.accentHeight or PD.AccentHeight)
    
    draw.RoundedBox(0, x, y, w, h, bgColor)
    
    if accentTop then
        surface.SetDrawColor(accentColor)
        surface.DrawRect(x, y, w, accentHeight)
    end
    
    if accentBottom then
        surface.SetDrawColor(accentColor)
        surface.DrawRect(x, y + h - accentHeight, w, accentHeight)
    end
    
    if borders then
        surface.SetDrawColor(PD.Theme.Colors.AccentGray.r, PD.Theme.Colors.AccentGray.g, PD.Theme.Colors.AccentGray.b, 100)
        surface.DrawRect(x, y + (accentTop and accentHeight or 0), 1, h - (accentTop and accentHeight or 0) - (accentBottom and accentHeight or 0))
        surface.DrawRect(x + w - 1, y + (accentTop and accentHeight or 0), 1, h - (accentTop and accentHeight or 0) - (accentBottom and accentHeight or 0))
    end
    
    if corners then
        local cornerY = y + (accentTop and accentHeight or 0)
        local cornerH = h - (accentTop and accentHeight or 0) - (accentBottom and accentHeight or 0)
        PD.DrawCorners(x, cornerY, w, cornerH, PD.ColorAlpha(PD.Theme.Colors.AccentGray, 0.8))
    end
end

-- Imperial Box mit Rahmen
function PD.DrawBox(x, y, w, h, config)
    config = config or {}
    local bgColor = config.background or PD.ColorAlpha(PD.Theme.Colors.AccentGray, 0.2)
    local borderColor = config.border or PD.Theme.Colors.AccentGray
    local borderWidth = config.borderWidth or PD.BorderWidth.Normal
    
    surface.SetDrawColor(bgColor)
    surface.DrawRect(x, y, w, h)
    
    surface.SetDrawColor(borderColor)
    surface.DrawOutlinedRect(x, y, w, h, borderWidth)
end

-- Status-Indikator (pulsierender Punkt)
function PD.DrawStatusIndicator(x, y, size, color, pulse)
    local pulseAlpha = 255
    if pulse then
        pulseAlpha = 155 + math.sin(CurTime() * 5) * 100
    end
    draw.RoundedBox(100, x, y, size, size, Color(color.r, color.g, color.b, pulseAlpha))
end

-- Horizontale Trennlinie
function PD.DrawDivider(x, y, w, color)
    color = color or PD.ColorAlpha(PD.Theme.Colors.AccentGray, 0.5)
    surface.SetDrawColor(color)
    surface.DrawRect(x, y, w, 1)
end

-- Progress Bar
function PD.DrawProgressBar(x, y, w, h, percent, color, bgColor)
    percent = math.Clamp(percent or 0, 0, 1)
    bgColor = bgColor or Color(40, 40, 45, 200)
    color = color or PD.Theme.Colors.AccentRed
    
    surface.SetDrawColor(bgColor)
    surface.DrawRect(x, y, w, h)
    
    surface.SetDrawColor(color)
    surface.DrawRect(x, y, w * percent, h)
end

-- Grid-Pattern Hintergrund
function PD.DrawGridPattern(x, y, w, h, gridSize, color)
    gridSize = gridSize or PD.W(30)
    color = color or Color(40, 40, 50, 30)
    
    surface.SetDrawColor(color)
    
    for gx = x, x + w, gridSize do
        surface.DrawRect(gx, y, 1, h)
    end
    
    for gy = y, y + h, gridSize do
        surface.DrawRect(x, gy, w, 1)
    end
end

-- Seitliche Dekor-Balken
function PD.DrawSideBars(x, y, w, h, barWidth, color)
    barWidth = barWidth or PD.W(3)
    color = color or PD.Theme.Colors.AccentGray
    
    surface.SetDrawColor(color)
    surface.DrawRect(x, y, barWidth, h)
    surface.DrawRect(x + w - barWidth, y, barWidth, h)
end

-- ============================================
-- LABEL HELPER
-- ============================================
function PD.DrawLabel(text, font, x, y, color, align)
    align = align or TEXT_ALIGN_LEFT
    color = color or PD.Theme.Colors.TextDim
    draw.DrawText(text, font or "MLIB.12", x, y, color, align)
end

function PD.DrawValue(text, font, x, y, color, align)
    align = align or TEXT_ALIGN_LEFT
    color = color or PD.Theme.Colors.Text
    draw.DrawText(text, font or "MLIB.16", x, y, color, align)
end

-- ============================================
-- TEXT WRAPPING
-- ============================================
function PD.WrapText(text, maxWidth, font)
    surface.SetFont(font or "MLIB.14")
    local words = string.Explode(" ", text)
    local lines = {}
    local currentLine = ""
    
    for _, word in ipairs(words) do
        local testLine = currentLine == "" and word or (currentLine .. " " .. word)
        local testW, _ = surface.GetTextSize(testLine)
        
        if testW > maxWidth and currentLine ~= "" then
            table.insert(lines, currentLine)
            currentLine = word
        else
            currentLine = testLine
        end
    end
    
    if currentLine ~= "" then
        table.insert(lines, currentLine)
    end
    
    return lines
end

-- ============================================
-- VGUI KOMPONENTEN - Imperial Style
-- ============================================

--[[
    PD.Frame - Imperial Frame (Hauptfenster)
    
    Beispiel:
    local frame = PD.Frame("Menü Titel", PD.W(600), PD.H(400), true)
    local content = frame:GetContentPanel()
    -- Füge Elemente zum content hinzu
]]
function PD.Frame(title, w, h, showClose, config)
    config = config or {}
    
    local frame = vgui.Create("DFrame")
    frame:SetSize(w, h)
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:SetDraggable(config.draggable or false)
    frame:SetSizable(config.sizable or false)
    frame:DockPadding(PD.W(15), PD.H(50), PD.W(15), PD.H(15))
    
    -- Animation State
    frame._hoverAnim = 0
    frame._accentColor = config.accent or PD.Theme.Colors.AccentRed
    frame._noPaint = config.noPaint or false
    frame._noPopup = config.noPopup or false
    frame.OnClose = config.onClose or nil

    if not frame._noPopup then
        frame:MakePopup()
    end
    
    frame.Paint = function(self, sw, sh)
        if self._noPaint then return end
        -- Hintergrund
        draw.RoundedBox(0, 0, 0, sw, sh, PD.Theme.Colors.Background)
        
        -- Obere Akzentlinie
        surface.SetDrawColor(self._accentColor)
        surface.DrawRect(0, 0, sw, PD.H(PD.AccentHeight))
        
        -- Untere Akzentlinie
        surface.DrawRect(0, sh - PD.H(PD.AccentHeight), sw, PD.H(PD.AccentHeight))
        
        -- Seitliche Linien
        surface.SetDrawColor(PD.Theme.Colors.AccentGray.r, PD.Theme.Colors.AccentGray.g, PD.Theme.Colors.AccentGray.b, 100)
        surface.DrawRect(0, PD.H(PD.AccentHeight), 1, sh - PD.H(PD.AccentHeight * 2))
        surface.DrawRect(sw - 1, PD.H(PD.AccentHeight), 1, sh - PD.H(PD.AccentHeight * 2))
        
        -- Imperial Ecken-Dekor
        PD.DrawCorners(PD.W(5), PD.H(5), sw - PD.W(10), sh - PD.H(10), PD.ColorAlpha(PD.Theme.Colors.AccentGray, 0.6), PD.W(15))
        
        -- Titel-Bereich Hintergrund
        draw.RoundedBox(0, 0, 0, sw, PD.H(45), PD.ColorAlpha(PD.Theme.Colors.BackgroundDark, 0.8))
        
        -- Titel
        draw.DrawText(title or "IMPERIAL TERMINAL", "MLIB.20", sw / 2, PD.H(12), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
        
        -- Trennlinie unter Titel
        PD.DrawDivider(PD.W(15), PD.H(45), sw - PD.W(30), PD.ColorAlpha(PD.Theme.Colors.AccentGray, 0.5))
        
        -- Grid Pattern (optional)
        if config.grid then
            PD.DrawGridPattern(0, PD.H(45), sw, sh - PD.H(45), PD.W(40), Color(30, 30, 35, 20))
        end
    end
    
    -- Content Panel
    local content = vgui.Create("DPanel", frame)
    content:Dock(FILL)
    content:DockMargin(0, PD.H(5), 0, 0)
    content.Paint = function() end
    
    frame.ContentPanel = content
    frame.GetContentPanel = function(self) return self.ContentPanel end
    
    -- Close Button
    if showClose then
        local closeBtn = vgui.Create("DButton", frame)
        closeBtn:SetSize(PD.W(30), PD.H(30))
        closeBtn:SetPos(w - PD.W(40), PD.H(8))
        closeBtn:SetText("")
        closeBtn._hover = 0
        
        closeBtn.Paint = function(self, bw, bh)
            local hover = self:IsHovered()
            self._hover = Lerp(FrameTime() * 10, self._hover, hover and 1 or 0)
            
            local bgAlpha = 50 + self._hover * 150
            local col = PD.LerpColor(PD.Theme.Colors.AccentGray, PD.Theme.Colors.AccentRed, self._hover)
            
            draw.RoundedBox(0, 0, 0, bw, bh, Color(col.r, col.g, col.b, bgAlpha))
            draw.DrawText("×", "MLIB.25", bw / 2, bh / 2 - PD.H(14), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
        end
        
        closeBtn.DoClick = function()
            surface.PlaySound("UI/buttonclick.wav")
            if frame.OnClose then frame:OnClose() end
            frame:Remove()
        end
        
        closeBtn.OnCursorEntered = function()
            surface.PlaySound("UI/buttonrollover.wav")
        end
        
        frame.CloseButton = closeBtn
    end
    
    -- SetAccentColor
    frame.SetAccentColor = function(self, col)
        self._accentColor = col
    end
    
    return frame
end

--[[
    PD.Label - Imperial Label (Textanzeige)
    
    Beispiel:
    local label = PD.Label("Menü Titel", config)
    -- Füge Elemente zum content hinzu
]]
function PD.Label(text, parent, config)
    config = config or {}
    
    local lbl = parent:Add("DLabel")
    lbl:SetText(text or "")
    lbl:SetContentAlignment(config.align or 1)
    lbl:SetTall(config.height or PD.H(16))
    lbl:DockMargin(PD.W(5), PD.H(5), PD.W(5), PD.H(5))
    lbl:Dock(config.dock or TOP)
    lbl:SetTextColor(config.color or PD.Theme.Colors.Text)
    lbl:SetFont(config.font or "MLIB.16")
    
    -- lbl.Paint = function(self, w, h)
        
        
    -- end

    return lbl
end

--[[
    PD.Button - Imperial Button
    
    Beispiel:
    local btn = PD.Button("Klick mich", parent, function(self)
        print("Button geklickt!")
    end)
    btn:Dock(TOP)
]]
function PD.Button(text, parent, onClick, config)
    config = config or {}
    
    local btn = parent:Add("DButton")
    btn:SetText("")
    btn:SetTall(config.height or PD.H(40))
    btn:DockMargin(PD.W(5), PD.H(5), PD.W(5), PD.H(5))
    
    btn._text = text
    btn._hover = 0
    btn._active = false
    btn._disabled = false
    btn._disable_sound = config.disableSound or false
    btn._accentColor = config.accent or PD.Theme.Colors.AccentRed
    btn._icon = config.icon
    btn._font = config.font or "MLIB.16"
    btn._hideBox = config.hideBox or false
    btn._arrow = config.arrow or false
    
    btn.Paint = function(self, w, h)
        if self._hideBox then return end

        local hover = self:IsHovered() and not self._disabled
        self._hover = Lerp(FrameTime() * 12, self._hover, (hover or self._active) and 1 or 0)
        
        -- Hintergrund
        local bgColor = PD.LerpColor(PD.Theme.Colors.ButtonBg, PD.Theme.Colors.ButtonHover, self._hover)
        if self._disabled then
            bgColor = Color(30, 30, 35, 200)
        end
        draw.RoundedBox(0, 0, 0, w, h, bgColor)
        
        -- Linke Akzentlinie (erscheint bei Hover)
        local accentW = PD.W(3) * self._hover
        if accentW > 0.5 then
            surface.SetDrawColor(self._accentColor)
            surface.DrawRect(0, 0, accentW, h)
        end
        
        -- Untere Linie
        surface.SetDrawColor(PD.Theme.Colors.AccentGray.r, PD.Theme.Colors.AccentGray.g, PD.Theme.Colors.AccentGray.b, 50 + self._hover * 100)
        surface.DrawRect(0, h - 1, w, 1)
        
        -- Text
        local textX = PD.W(15)
        if self._icon then
            textX = PD.W(40)
        end
        
        local textColor = self._disabled and PD.Theme.Colors.TextMuted or PD.LerpColor(PD.Theme.Colors.TextDim, PD.Theme.Colors.Text, self._hover)
        draw.DrawText(self._text, self._font, textX, h / 2 - PD.H(8), textColor, TEXT_ALIGN_LEFT)
        
        -- Pfeil rechts (bei Hover)
        if self._hover > 0.1 and not self._disabled and self._arrow then
            local arrowAlpha = 255 * self._hover
            draw.DrawText("›", "MLIB.20", w - PD.W(15), h / 2 - PD.H(12), Color(self._accentColor.r, self._accentColor.g, self._accentColor.b, arrowAlpha), TEXT_ALIGN_RIGHT)
        end
        
        -- Active Indikator
        if self._active then
            draw.RoundedBox(100, w - PD.W(20), h / 2 - PD.H(4), PD.W(8), PD.H(8), PD.Theme.Colors.StatusActive)
        end
    end
    
    btn.OnCursorEntered = function(self)
        if not self._disabled and not self._disable_sound then
            surface.PlaySound("UI/buttonrollover.wav")
        end
    end
    
    btn.DoClick = function(self)
        if self._disabled then return end
        if not self._disable_sound then
            surface.PlaySound("UI/buttonclick.wav")
        end
        if onClick then onClick(self) end
    end
    
    -- Helper Methods
    btn.SetActive = function(self, active) self._active = active end
    btn.GetActive = function(self) return self._active end
    btn.SetDisabled = function(self, disabled) self._disabled = disabled end
    btn.GetDisabled = function(self) return self._disabled end
    btn.SetText = function(self, txt) self._text = txt end
    btn.GetText = function(self) return self._text end
    btn.SetAccentColor = function(self, col) self._accentColor = col end
    btn.SetFont = function(self, font) self._font = font end
    btn.SetArrow = function(self, show) self._arrow = show end
    btn.SetBackColor = function(self, col) self._accentColor = col end
    btn.GetBackColor = function(self) return self._accentColor end
    
    return btn
end

--[[
    PD.ImageButton - Imperial Image Button
    
    Beispiel:
    local btn = PD.ImageButton("Klick mich", parent, function(self)
        print("Button geklickt!")
    end, {
        icon = "path/to/icon.png",
        accent = PD.Theme.Colors.AccentBlue
    })
    btn:Dock(TOP)
]]
function PD.ImageButton(wo, img, width, height, onClick)
    local ImageButton = wo:Add("DImageButton")
    ImageButton:SetSize(width, height)
    ImageButton:DockMargin(PD.H(5),PD.H(5),PD.H(5),PD.H(5))
    ImageButton:Dock(FILL)
    ImageButton:SetImage(img)

    ImageButton.DoClick = function()
        if ImageButton.disabled then return end
            if onClick then
                onClick(ImageButton)
            end
    end

    return ImageButton
end

--[[
    PD.Image - Imperial Image Panel
    
    Beispiel:
    local panel, image = PD.Image(parent, "Panel Titel", "path/to/image.png", showPanelBackground, function(imgPath)
        print("Aktuelles Bild: " .. imgPath)
    end)
]]
function PD.Image(wo, title, img, show_pnl, func)
    local panel = PD.Panel(wo, {title = title or ""})
    panel:SetTall(PD.H(150))

    if not show_pnl then 
        panel:SetBackColor(Color(0,0,0,0))
        panel.noPaint = true
    end

    local image = panel:Add("DImage")
    image:Dock(FILL)
    image:SetImage(img)

    image.Think = function(self)
        if func then
            func(self:GetImage())
        end
    end

    return panel,image
end

--[[
    PD.Panel - Imperial Panel (Container)
    
    Beispiel:
    local panel = PD.Panel(parent, {
        title = "Panel Titel",
        accent = PD.Theme.Colors.AccentRed
    })
]]
function PD.Panel(parent, config, paint)
    config = config or {}
    
    local pnl = parent:Add("DPanel")
    pnl:Dock(config.dock or TOP)
    pnl:DockMargin(PD.W(5), PD.H(5), PD.W(5), PD.H(5))
    pnl:SetTall(config.height or PD.H(50))
    
    pnl._title = config.title
    pnl._accent = config.accent or PD.Theme.Colors.AccentRed
    pnl._showCorners = config.corners ~= false
    pnl._hideBox = config.hideBox ~= false
    
    pnl.Paint = function(self, w, h)
        if not self._hideBox then 
            -- Hintergrund
            draw.RoundedBox(0, 0, 0, w, h, config.background or PD.Theme.Colors.BackgroundLight)
        
            -- Obere Akzentlinie
            if config.accentTop ~= false then
                surface.SetDrawColor(self._accent)
                surface.DrawRect(0, 0, w, PD.H(2))
            end
        
            -- Ecken
            if self._showCorners then
                PD.DrawCorners(0, PD.H(2), w, h - PD.H(2), PD.ColorAlpha(PD.Theme.Colors.AccentGray, 0.5), PD.W(8))
            end
        
            -- Titel
            if self._title then
                draw.DrawText(self._title, "MLIB.12", PD.W(10), PD.H(8), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
            end
        end

        -- Custom Paint
        if paint then
            paint(self, w, h)
        end
    end
    
    pnl.SetTitle = function(self, title) self._title = title end
    pnl.SetAccentColor = function(self, col) self._accent = col end
    pnl.SetBackColor = function(self, col) config.background = col end
    
    return pnl
end

--[[
    PD.Scroll - Imperial ScrollPanel
    
    Beispiel:
    local scroll = PD.Scroll(parent)
    -- Füge Elemente zum scroll hinzu
]]
function PD.Scroll(parent, config)
    config = config or {}
    
    local scroll = parent:Add("DScrollPanel")
    scroll:Dock(FILL)
    
    local sbar = scroll:GetVBar()
    sbar:SetWide(PD.W(8))
    sbar:SetHideButtons(true)
    
    sbar.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
    end
    
    sbar.btnGrip.Paint = function(self, w, h)
        local hover = self:IsHovered()
        local color = hover and PD.Theme.Colors.AccentRed or PD.Theme.Colors.AccentGray
        draw.RoundedBox(PD.W(2), PD.W(1), 0, w - PD.W(2), h, color)
    end
    
    return scroll
end

--[[
    PD.TextEntry - Imperial Text Input
    
    Beispiel:
    local input = PD.TextEntry(parent, "Suchbegriff eingeben...", "", function(text)
        print("Text: " .. text)
    end)
]]
function PD.TextEntry(parent, placeholder, value, onChange, config)
    config = config or {}
    
    local entry = parent:Add("DTextEntry")
    entry:Dock(config.dock or TOP)
    entry:DockMargin(PD.W(5), PD.H(5), PD.W(5), PD.H(5))
    entry:SetTall(config.height or PD.H(40))
    entry:SetFont(config.font or "MLIB.16")
    entry:SetValue(value or "")
    entry:SetTextColor(PD.Theme.Colors.Text)
    
    entry._placeholder = placeholder or ""
    entry._focused = false
    
    entry.Paint = function(self, w, h)
        local focused = self:HasFocus()
        
        -- Hintergrund
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.InputBg)
        
        -- Rahmen
        local borderColor = focused and PD.Theme.Colors.AccentRed or PD.Theme.Colors.InputBorder
        surface.SetDrawColor(borderColor)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        
        -- Linke Akzentlinie bei Fokus
        if focused then
            surface.SetDrawColor(PD.Theme.Colors.AccentRed)
            surface.DrawRect(0, 0, PD.W(3), h)
        end
        
        -- Placeholder
        if self:GetValue() == "" and not focused then
            draw.DrawText(self._placeholder, config.font or "MLIB.16", PD.W(12), h / 2 - PD.H(8), PD.Theme.Colors.TextMuted, TEXT_ALIGN_LEFT)
        end
        
        -- Text zeichnen
        self:DrawTextEntryText(PD.Theme.Colors.Text, PD.Theme.Colors.AccentRed, PD.Theme.Colors.Text)
    end
    
    if onChange then
        entry.OnChange = function(self)
            onChange(self:GetValue())
        end
    end
    
    entry.SetPlaceholder = function(self, ph) self._placeholder = ph end
    
    return entry
end

--[[
    PD.Checkbox - Imperial Toggle/Checkbox
    
    Beispiel:
    local check = PD.Checkbox(parent, "Option aktivieren", false, function(value)
        print("Checkbox: " .. tostring(value))
    end)
]]
function PD.Checkbox(parent, text, value, onChange, config)
    config = config or {}
    
    local pnl = parent:Add("DPanel")
    pnl:Dock(config.dock or TOP)
    pnl:DockMargin(PD.W(5), PD.H(5), PD.W(5), PD.H(5))
    pnl:SetTall(config.height or PD.H(40))
    pnl:SetCursor("hand")
    
    pnl._value = value or false
    pnl._text = text
    pnl._hover = 0
    pnl._anim = value and 1 or 0
    
    pnl.Paint = function(self, w, h)
        local hover = self:IsHovered()
        self._hover = Lerp(FrameTime() * 10, self._hover, hover and 1 or 0)
        self._anim = Lerp(FrameTime() * 8, self._anim, self._value and 1 or 0)
        
        -- Hintergrund
        local bgAlpha = 150 + self._hover * 50
        draw.RoundedBox(0, 0, 0, w, h, Color(PD.Theme.Colors.BackgroundLight.r, PD.Theme.Colors.BackgroundLight.g, PD.Theme.Colors.BackgroundLight.b, bgAlpha))
        
        -- Toggle Box
        local boxW = PD.W(50)
        local boxH = PD.H(24)
        local boxX = w - boxW - PD.W(10)
        local boxY = h / 2 - boxH / 2
        
        local toggleColor = PD.LerpColor(PD.Theme.Colors.StatusInactive, PD.Theme.Colors.StatusActive, self._anim)
        draw.RoundedBox(boxH / 2, boxX, boxY, boxW, boxH, toggleColor)
        
        -- Toggle Knob
        local knobSize = boxH - PD.H(4)
        local knobX = boxX + PD.W(2) + (boxW - knobSize - PD.W(4)) * self._anim
        draw.RoundedBox(100, knobX, boxY + PD.H(2), knobSize, knobSize, PD.Theme.Colors.Text)
        
        -- Text
        draw.DrawText(self._text, config.font or "MLIB.16", PD.W(15), h / 2 - PD.H(8), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
    end
    
    pnl.OnMousePressed = function(self)
        self._value = not self._value
        surface.PlaySound("UI/buttonclick.wav")
        if onChange then onChange(self._value) end
    end
    
    pnl.GetValue = function(self) return self._value end
    pnl.SetValue = function(self, val) self._value = val end
    pnl.SetText = function(self, txt) self._text = txt end
    
    return pnl
end

--[[
    PD.Slider - Imperial Slider
    
    Beispiel:
    local slider = PD.Slider(parent, "Lautstärke", 0, 100, 50, function(value)
        print("Slider: " .. value)
    end)
]]
function PD.Slider(parent, label, min, max, value, onChange, config)
    config = config or {}
    
    local pnl = parent:Add("DPanel")
    pnl:Dock(config.dock or TOP)
    pnl:DockMargin(PD.W(5), PD.H(5), PD.W(5), PD.H(5))
    pnl:SetTall(config.height or PD.H(60))
    
    pnl._label = label
    pnl._min = min or 0
    pnl._max = max or 100
    pnl._value = math.Clamp(value or min, min, max)
    pnl._dragging = false
    pnl._hover = 0
    
    local trackPadding = PD.W(15)
    
    pnl.Paint = function(self, w, h)
        self._hover = Lerp(FrameTime() * 10, self._hover, self:IsHovered() and 1 or 0)
        
        -- Label & Wert
        draw.DrawText(self._label, "MLIB.14", PD.W(10), PD.H(8), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
        draw.DrawText(tostring(math.Round(self._value)), "MLIB.14", w - PD.W(10), PD.H(8), PD.Theme.Colors.Text, TEXT_ALIGN_RIGHT)
        
        -- Track
        local trackY = PD.H(35)
        local trackH = PD.H(6)
        local trackW = w - trackPadding * 2
        
        -- Track Background
        draw.RoundedBox(trackH / 2, trackPadding, trackY, trackW, trackH, PD.Theme.Colors.InputBg)
        
        -- Track Progress
        local percent = (self._value - self._min) / (self._max - self._min)
        local progressW = trackW * percent
        draw.RoundedBox(trackH / 2, trackPadding, trackY, progressW, trackH, PD.Theme.Colors.AccentRed)
        
        -- Knob
        local knobSize = PD.H(16)
        local knobX = trackPadding + progressW - knobSize / 2
        local knobY = trackY + trackH / 2 - knobSize / 2
        
        local knobColor = self._dragging and PD.Theme.Colors.AccentRed or PD.Theme.Colors.Text
        draw.RoundedBox(100, knobX, knobY, knobSize, knobSize, knobColor)
    end
    
    pnl.OnMousePressed = function(self)
        self._dragging = true
        self:MouseCapture(true)
    end
    
    pnl.OnMouseReleased = function(self)
        self._dragging = false
        self:MouseCapture(false)
        if onChange then onChange(self._value) end
    end
    
    pnl.Think = function(self)
        if self._dragging then
            local mx = self:ScreenToLocal(gui.MouseX())
            local trackW = self:GetWide() - trackPadding * 2
            local percent = math.Clamp((mx - trackPadding) / trackW, 0, 1)
            self._value = self._min + (self._max - self._min) * percent
        end
    end
    
    pnl.GetValue = function(self) return self._value end
    pnl.SetValue = function(self, val) self._value = math.Clamp(val, self._min, self._max) end
    pnl.SetLabel = function(self, lbl) self._label = lbl end
    
    return pnl
end

--[[
    PD.Dropdown - Imperial Dropdown/ComboBox
    
    Beispiel:
    local dropdown = PD.Dropdown(parent, "Wähle eine Option", function(value, data)
        print("Ausgewählt: " .. value)
    end)
    dropdown:AddOption("Option 1", 1)
    dropdown:AddOption("Option 2", 2)
]]
function PD.Dropdown(parent, defaultText, onSelect, config)
    config = config or {}
    
    local btn = parent:Add("DButton")
    btn:Dock(config.dock or TOP)
    btn:DockMargin(PD.W(5), PD.H(5), PD.W(5), PD.H(5))
    btn:SetTall(config.height or PD.H(40))
    btn:SetText("")
    
    btn._text = defaultText or "Auswählen..."
    btn._options = {}
    btn._hover = 0
    btn._open = false
    btn._menu = nil
    
    btn.Paint = function(self, w, h)
        self._hover = Lerp(FrameTime() * 10, self._hover, self:IsHovered() and 1 or 0)
        
        -- Hintergrund
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.InputBg)
        
        -- Rahmen
        local borderColor = self._open and PD.Theme.Colors.AccentRed or PD.Theme.Colors.InputBorder
        surface.SetDrawColor(borderColor)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        
        -- Text
        draw.DrawText(self._text, config.font or "MLIB.16", PD.W(15), h / 2 - PD.H(8), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
        
        -- Pfeil
        local arrow = self._open and "▲" or "▼"
        draw.DrawText(arrow, "MLIB.12", w - PD.W(15), h / 2 - PD.H(6), PD.Theme.Colors.TextDim, TEXT_ALIGN_RIGHT)
    end
    
    btn.DoClick = function(self)
        if self._open and IsValid(self._menu) then
            self._menu:Remove()
            self._open = false
            return
        end
        
        surface.PlaySound("UI/buttonclick.wav")
        self._open = true
        
        local menu = vgui.Create("DPanel")
        local menuH = math.min(#self._options * PD.H(35) + PD.H(10), PD.H(200))
        local x, y = self:LocalToScreen(0, self:GetTall())
        menu:SetPos(x, y)
        menu:SetSize(self:GetWide(), menuH)
        menu:MakePopup()
        menu:SetKeyboardInputEnabled(false)
        
        menu.Paint = function(m, w, h)
            draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.Background)
            surface.SetDrawColor(PD.Theme.Colors.AccentRed)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        
        local scroll = PD.Scroll(menu)
        
        for _, opt in ipairs(self._options) do
            local optBtn = PD.Button(opt.text, scroll, function()
                self._text = opt.text
                if onSelect then onSelect(opt.text, opt.data) end
                menu:Remove()
                self._open = false
            end)
            optBtn:Dock(TOP)
            optBtn:SetTall(PD.H(35))
        end
        
        self._menu = menu
        
        menu.Think = function(m)
            if not self:IsHovered() and not m:IsHovered() then
                local mx, my = gui.MousePos()
                local px, py = m:GetPos()
                local pw, ph = m:GetSize()
                if mx < px or mx > px + pw or my < py or my > py + ph then
                    if m and IsValid(m) and not m:HasFocus()  then--input.IsMouseDown(MOUSE_LEFT) or input.IsMouseDown(MOUSE_RIGHT) then
                        self._open = false
                        m:Remove()
                    end
                end
            end
        end

        -- menu:OnFocusChanged = function(bool)
        --     print("Focus changed: " .. tostring(bool))
        --     if not bool then
        --         self._open = false
        --         menu:Remove()
        --     end
        -- end
    end
    
    btn.AddOption = function(self, text, data)
        table.insert(self._options, { text = text, data = data })
    end
    
    btn.SetValue = function(self, text) self._text = text end
    btn.GetValue = function(self) return self._text end
    btn.ClearOptions = function(self) self._options = {} end
    
    return btn
end

--[[
    PD.Progress - Imperial Progress Bar
    
    Beispiel:
    local progress = PD.Progress(parent, 0.5, {
        height = PD.H(25),
        accent = PD.Theme.Colors.AccentBlue
    })
    progress:SetProgress(0.75)
]]
function PD.Progress(parent, value, config)
    config = config or {}
    
    local pnl = parent:Add("DPanel")
    pnl:Dock(config.dock or TOP)
    pnl:DockMargin(PD.W(5), PD.H(5), PD.W(5), PD.H(5))
    pnl:SetTall(config.height or PD.H(25))
        
    pnl._value = math.Clamp(value or 0, 0, 1)
    pnl._label = config.label or "Progress"
    pnl._accent = config.accent or PD.Theme.Colors.AccentRed
    pnl._showPercent = config.showPercent ~= false
        
    pnl.Paint = function(self, w, h)
        -- Hintergrund
        draw.RoundedBox(0, 0, 0, w, h, config.background or PD.Theme.Colors.BackgroundLight)
            
        -- Obere Akzentlinie
        if config.accentTop ~= false then
            surface.SetDrawColor(self._accent)
            surface.DrawRect(0, 0, w, PD.H(2))
        end
            
        -- Label & Prozent
        draw.DrawText(self._label, "MLIB.12", PD.W(10), PD.H(8), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
        if self._showPercent then
            draw.DrawText(math.Round(self._value * 100) .. "%", "MLIB.12", w - PD.W(10), PD.H(8), PD.Theme.Colors.Text, TEXT_ALIGN_RIGHT)
        end
            
        -- Progress Track Background
        local trackY = PD.H(25)
        local trackH = h / 2--PD.H(14)
        local trackX = PD.W(10)
        local trackW = w - PD.W(20)
            
        draw.RoundedBox(trackH / 2, trackX, trackY, trackW, trackH, PD.Theme.Colors.InputBg)
            
        -- Progress Bar
        local progressW = trackW * self._value
        draw.RoundedBox(trackH / 2, trackX, trackY, progressW, trackH, self._accent)
    end
        
    pnl.SetValue = function(self, val) self._value = math.Clamp(val, 0, 1) end
    pnl.GetValue = function(self) return self._value end
    pnl.SetLabel = function(self, lbl) self._label = lbl end
    pnl.SetAccentColor = function(self, col) self._accent = col end
        
    return pnl
end

--[[
    PD.Model - Imperial 3D Model Panel
    
    Beispiel:
    local model = PD.Model(parent, "models/props_c17/oildrum001.mdl", x, y, w, h)
]]
function PD.Model(wo, setmodel, x, y, w, h, config)
    local model = wo:Add("DModelPanel")
    model:SetPos(x, y)
    model:SetSize(w, h)
    model:DockMargin(PD.H(5),PD.H(5),PD.H(5),PD.H(5))
    model:SetModel(setmodel)
    model:SetCamPos(Vector(50,0,50))

    model.rot = 110
	model.fov = 20
	model:SetFOV( model.fov )
	model.dragging = false
	model.dragging2 = false
	model.ux = 0
	model.uy = 0
	model.spinmul = 0.4
	model.zoommul = 0.09
	model.xmod = 0
	model.ymod = 0

    model._canRotate = config.canRotate or true
    model._canZoom = config.canZoom or true

    function model.Entity:GetPlayerColor() return Vector (1, 0, 0) end

    local function InverseLerp( pos, p1, p2 )
        local range = 0
        range = p2-p1
        if range == 0 then return 1 end
        return ((pos - p1)/range)
    end

    function model:LayoutEntity( ent )

		local newrot = self.rot
		local newfov = self:GetFOV()

		if self.dragging == true and self._canRotate then
			newrot = self.rot + (gui.MouseX() - self.ux)*self.spinmul
			newfov = self.fov + (self.uy - gui.MouseY()) * self.zoommul
			if newfov < 20 then newfov = 20 end
			if newfov > 75 then newfov = 75 end
		end

		local newxmod, newymod = self.xmod, self.ymod

		if self.dragging2 == true and self._canZoom then
			newxmod = self.xmod + (self.ux - gui.MouseX())*0.02
			newymod = self.ymod + (self.uy - gui.MouseY())*0.02
		end

		newxmod = math.Clamp( newxmod, -16, 16 )
		newymod = math.Clamp( newymod, -16, 16 )

		ent:SetAngles( Angle(0,0,0) )
		self:SetFOV( newfov )

		local height = 72/2
		local frac = InverseLerp( newfov, 75, 20 )
		height = Lerp( frac, 72/2, 64 )

		local norm = (self:GetCamPos() - Vector(0,0,64))
		norm:Normalize()
		local lookAng = norm:Angle()

		self:SetLookAt( Vector(0,0,height-(2*frac) ) - Vector( 0, 0, newymod*2*(1-frac) ) - lookAng:Right()*newxmod*2*(1-frac) )
		self:SetCamPos( Vector( 64*math.sin( newrot * (math.pi/180)), 64*math.cos( newrot * (math.pi/180)), height + 4*(1-frac)) - Vector( 0, 0, newymod*2*(1-frac) ) - lookAng:Right()*newxmod*2*(1-frac) )

	end

	function model:OnMousePressed( k )
		self.ux = gui.MouseX()
		self.uy = gui.MouseY()
		self.dragging = (k == MOUSE_LEFT) or false 
		self.dragging2 = (k == MOUSE_RIGHT) or false 
	end

	function model:OnMouseReleased( k )
		if self.dragging == true then
			self.rot = self.rot + (gui.MouseX() - self.ux)*self.spinmul
			self.fov = self.fov + (self.uy - gui.MouseY()) * self.zoommul
			self.fov = math.Clamp( self.fov, 20, 75 )
		end

		if self.dragging2 == true then
			self.xmod = self.xmod + (self.ux - gui.MouseX())*0.02
			self.ymod = self.ymod + (self.uy - gui.MouseY())*0.02

			self.xmod = math.Clamp( self.xmod, -16, 16 )
			self.ymod = math.Clamp( self.ymod, -16, 16 )
		end

		self.dragging = false 
		self.dragging2 = false
	end

	function model:OnCursorExited()
		if self.dragging == true or self.dragging2 == true then
			self:OnMouseReleased()
		end
	end

    return model
end

--[[
    PD.List - Imperial Liste mit Items
    
    Beispiel:
    local list = PD.List(parent, function(item)
        print("Ausgewählt: " .. item.text)
    end)
    list:AddItem("Item 1", { id = 1 })
    list:AddItem("Item 2", { id = 2 })
]]
function PD.ListUI(parent, onSelect, config)
    config = config or {}
    
    local pnl = parent:Add("DPanel")
    pnl:Dock(config.dock or FILL)
    pnl:DockMargin(PD.W(5), PD.H(5), PD.W(5), PD.H(5))
    pnl.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, config.background or PD.Theme.Colors.BackgroundDark)
    end
    
    local scroll = PD.Scroll(pnl)
    
    pnl._items = {}
    pnl._selected = nil
    
    pnl.AddItem = function(self, text, data, icon)
        local item = { text = text, data = data, icon = icon }
        
        local btn = PD.Button(text, scroll, function()
            -- Deselect all
            for _, it in ipairs(self._items) do
                if IsValid(it.btn) then it.btn:SetActive(false) end
            end
            btn:SetActive(true)
            self._selected = item
            if onSelect then onSelect(item) end
        end)
        btn:Dock(TOP)
        btn:SetTall(PD.H(38))
        
        item.btn = btn
        table.insert(self._items, item)
        
        return item
    end
    
    pnl.GetSelected = function(self) return self._selected end
    pnl.ClearItems = function(self)
        for _, item in ipairs(self._items) do
            if IsValid(item.btn) then item.btn:Remove() end
        end
        self._items = {}
        self._selected = nil
    end
    
    return pnl
end

function PD.Binder(wo, title, value, func)
    local panel = PD.Panel(wo)
    panel:SetTall(PD.H(100))

    local binder = panel:Add("DBinder")
    binder:Dock(FILL)
    -- binder:DockMargin(PD.H(5),PD.H(5),PD.H(5),PD.H(5))
    binder:SetTall(PD.H(50))
    binder:SetValue(value)
	binder:SetFont("MLIB.20")
	binder:SetTextColor(PD.Theme.Colors.Text)
	binder.Paint = function(self,w,h)
		draw.RoundedBox(0,0,0,w,h, PD.Theme.Colors.ButtonBg)

		if self:IsHovered() then
			draw.RoundedBox(0,0,0,w,h,PD.Theme.Colors.ButtonHover)
		end
	end

    binder.OnChange = function(self,val)
        func(self,val)
    end

    return panel, binder
end

local x, y = ScrW() - 10, ScrH() - 10
local ptbl = {}
local popupHeight = PD.H(50)

local function reposition()
    for i, v in ipairs(ptbl) do
        if IsValid(v.pnl) then
            local w = v.pnl:GetWide()
            v.pnl:MoveTo(x - w, y - i * popupHeight, 0.3, 0, 1)
        else
            table.remove(ptbl, i)
        end
    end
end

-- Zentrale Alert Popup State
local centerPopup = {
    active = false,
    startTime = 0,
    config = nil,
    fadeIn = 0.5,
    fadeOut = 1
}

--[[
    PD.Popup - Flexibles Popup-System im Andor Imperial Style
    
    Verwendung:
    1. Kleine Benachrichtigung (unten rechts):
       PD.Popup("Nachricht", Color(255, 0, 0))
       
    2. Große zentrale Alert-Benachrichtigung:
       PD.Popup({
           center = true,              -- Zentrale Anzeige aktivieren
           title = "DEFCON ÄNDERUNG",  -- Titel oben
           mainText = "3",             -- Große Zahl/Text in der Mitte
           subText = "Status",         -- Text unter der Hauptanzeige
           infoText = "Geändert von:", -- Kleinerer Info-Text
           color = Color(255, 0, 0),   -- Akzentfarbe
           duration = 5,               -- Anzeigedauer in Sekunden
           sound = "path/sound.mp3",   -- Optional: Sound abspielen
           pulse = false               -- Pulsierender Effekt
       })
]]
function PD.Popup(textOrConfig, color)
    -- Prüfen ob es ein config-table ist (zentrale Anzeige)
    if type(textOrConfig) == "table" and textOrConfig.center then
        local cfg = textOrConfig
        cfg.title = cfg.title or "ALERT"
        cfg.mainText = cfg.mainText or ""
        cfg.subText = cfg.subText or ""
        cfg.infoText = cfg.infoText or ""
        cfg.color = cfg.color or Color(178, 30, 30, 255)
        cfg.duration = cfg.duration or 5
        cfg.pulse = cfg.pulse or false
        
        -- Sound abspielen wenn angegeben
        if cfg.sound then
            surface.PlaySound(cfg.sound)
        end
        
        -- Alert-Daten setzen
        centerPopup.active = true
        centerPopup.startTime = CurTime()
        centerPopup.config = cfg
        return
    end
    
    -- Standard kleine Benachrichtigung (unten rechts)
    local text = textOrConfig
    for _, v in ipairs(ptbl) do
        if v.text == text then return end
    end

    surface.SetFont("MLIB.20")
    local tw, th = surface.GetTextSize(text)
    local w = tw + PD.W(20)
    local startX = x - w
    local startY = y - #ptbl * popupHeight - popupHeight

    local pnl = vgui.Create("DPanel")
    pnl:SetSize(w, popupHeight)
    pnl:SetPos(startX, startY)

    local bar = 0
    pnl.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors["BackgroundLight"])
        draw.DrawText(text, "MLIB.20", w/2, h/2 - PD.H(10), PD.Theme.Colors["Text"], TEXT_ALIGN_CENTER)
        bar = math.Clamp(bar + FrameTime() / 5, 0, 1)
        draw.RoundedBox(0, 0, h - PD.H(5), w * bar, PD.H(5), color)
    end

    table.insert(ptbl, { text = text, pnl = pnl })

    timer.Simple(5, function()
        if not IsValid(pnl) then return end
        local xp, yp = pnl:GetPos()
        pnl:MoveTo(xp + ScrW() + 100, yp, 0.5, 0, 1, function()
            reposition()
            timer.Simple(2, function()
                for i = #ptbl, 1, -1 do
                    if ptbl[i].pnl == pnl then
                        table.remove(ptbl, i)
                        break
                    end
                end
                if IsValid(pnl) then pnl:Remove() end
            end)
        end)
    end)

    return pnl
end

-- Hilfsfunktion zum manuellen Schließen des Center-Popups
function PD.HideCenterPopup()
    centerPopup.active = false
end

-- Zeichnet das Alert-Banner (oben am Bildschirm, slided rein) - Zentral über PD.Theme
hook.Add("HUDPaint", "PD.Popup.CenterDraw", function()
    if not centerPopup.active then return end
    if not PD.Theme then return end
    
    local cfg = centerPopup.config
    if not cfg then return end
    
    local elapsed = CurTime() - centerPopup.startTime
    local totalDuration = cfg.duration
    local slideInTime = 0.4
    local slideOutTime = 0.5
    local holdTime = totalDuration - slideInTime - slideOutTime
    
    -- Popup beenden
    if elapsed > totalDuration then
        centerPopup.active = false
        return
    end
    
    local accentColor = cfg.color or PD.Theme.Colors.AccentRed
    
    -- Banner-Größe (breiter, flacher)
    local panelW = PD.W(500)
    local panelH = PD.H(85)
    local panelX = ScrW() / 2 - panelW / 2
    local targetY = PD.H(20)  -- Zielposition am oberen Rand
    
    -- Slide Animation: Von oben reinsliden, dann wieder raus
    local panelY
    if elapsed < slideInTime then
        -- Slide In (von oben)
        local progress = elapsed / slideInTime
        progress = 1 - math.pow(1 - progress, 3)  -- Ease out cubic
        panelY = -panelH + (targetY + panelH) * progress
    elseif elapsed > slideInTime + holdTime then
        -- Slide Out (nach oben)
        local outElapsed = elapsed - slideInTime - holdTime
        local progress = outElapsed / slideOutTime
        progress = math.pow(progress, 2)  -- Ease in quad
        panelY = targetY - (targetY + panelH) * progress
    else
        -- Halten
        panelY = targetY
    end
    
    -- Hintergrund
    draw.RoundedBox(0, panelX, panelY, panelW, panelH, PD.Theme.Colors.Background)
    
    -- Obere Akzentlinie (Farbe)
    surface.SetDrawColor(accentColor)
    surface.DrawRect(panelX, panelY, panelW, PD.H(3))
    
    -- Untere Akzentlinie
    surface.DrawRect(panelX, panelY + panelH - PD.H(3), panelW, PD.H(3))
    
    -- Seitliche Linien
    surface.SetDrawColor(PD.Theme.Colors.AccentGray)
    surface.DrawRect(panelX, panelY + PD.H(3), 1, panelH - PD.H(6))
    surface.DrawRect(panelX + panelW - 1, panelY + PD.H(3), 1, panelH - PD.H(6))
    
    -- Imperial Ecken-Dekor
    local cornerSize = PD.W(12)
    surface.SetDrawColor(PD.Theme.Colors.AccentGray.r, PD.Theme.Colors.AccentGray.g, PD.Theme.Colors.AccentGray.b, 180)
    -- Unten links
    surface.DrawLine(panelX, panelY + panelH - PD.H(3) - cornerSize, panelX, panelY + panelH - PD.H(3))
    surface.DrawLine(panelX, panelY + panelH - PD.H(3), panelX + cornerSize, panelY + panelH - PD.H(3))
    -- Unten rechts
    surface.DrawLine(panelX + panelW - 1, panelY + panelH - PD.H(3) - cornerSize, panelX + panelW - 1, panelY + panelH - PD.H(3))
    surface.DrawLine(panelX + panelW - cornerSize, panelY + panelH - PD.H(3), panelX + panelW, panelY + panelH - PD.H(3))
    
    -- Layout: [Nummer-Box] [Titel + Status + Info]
    local boxSize = PD.H(55)
    local boxX = panelX + PD.W(20)
    local boxY = panelY + (panelH - boxSize) / 2
    
    -- Nummer-Box mit Theme
    PD.DrawBox(boxX, boxY, boxSize, boxSize, {
        background = Color(accentColor.r, accentColor.g, accentColor.b, 50),
        border = accentColor,
        borderWidth = 2
    })
    
    -- Haupttext (Nummer)
    draw.DrawText(cfg.mainText, "MLIB.35", boxX + boxSize / 2, boxY + PD.H(8), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
    
    -- Text-Bereich rechts von der Box
    local textX = boxX + boxSize + PD.W(20)
    
    -- Titel (klein, oben)
    PD.DrawLabel(cfg.title, "MLIB.12", textX, panelY + PD.H(15))
    
    -- Status-Text (groß)
    draw.DrawText(cfg.subText, "MLIB.22", textX, panelY + PD.H(30), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
    
    -- Info-Text (Geändert von etc.)
    if cfg.infoText and cfg.infoText ~= "" then
        draw.DrawText(cfg.infoText, "MLIB.12", textX, panelY + PD.H(58), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
    end
    
    -- Pulsierender Effekt bei kritischen Alerts
    if cfg.pulse then
        local pulseAlpha = math.sin(CurTime() * 6) * 25 + 25
        surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b, pulseAlpha)
        surface.DrawRect(panelX, panelY, panelW, panelH)
    end
end)

net.Receive("PD.Notify", function()
    local msg = net.ReadString()
    local col = net.ReadColor()

    local pop = PD.Popup(msg, col)
end)

-- ============================================
-- PRESET CONFIGS
-- ============================================
PD.Presets = {}

PD.Presets.HUDPanel = {
    background = PD.Theme.Colors.BackgroundLight,
    accent = PD.Theme.Colors.AccentGray,
    accentTop = true,
    accentBottom = false,
    corners = true,
    borders = true,
    accentHeight = 3,
}

PD.Presets.MenuPanel = {
    background = PD.Theme.Colors.Background,
    accent = PD.Theme.Colors.AccentRed,
    accentTop = true,
    accentBottom = true,
    corners = true,
    borders = true,
    accentHeight = 4,
}

PD.Presets.AlertPanel = {
    background = PD.Theme.Colors.Background,
    accent = PD.Theme.Colors.AccentRed,
    accentTop = true,
    accentBottom = true,
    corners = true,
    borders = false,
    accentHeight = 3,
}

-- print("[PD] Andor Imperial Theme System loaded - Use PD.Frame(), PD.Button(), etc.")

surface.CreateFont("PD_HackFont_Small", {font = "Courier New", size = 16, weight = 700, antialias = true})
surface.CreateFont("PD_HackFont_Large", {font = "Courier New", size = 22, weight = 800, antialias = true})

function PD.HackMenu(title, w, h, close, paint, test)
    local scrw, scrh = ScrW(), ScrH()
    local w = w or math.min(1100, scrw - 200)
    local h = h or math.min(700, scrh - 200)
    local Mbase = PD.Frame(title or "", w, h, close or false)
    Mbase:SetTitle("")
    Mbase:ShowCloseButton(true)
    Mbase:SetDraggable(true)
    Mbase:SetSizable(false)
    Mbase:SetAlpha(0)
    Mbase:AlphaTo(255, 0.2, 0)

    local overlay = vgui.Create("DPanel", Mbase)
    overlay:Dock(FILL)
    overlay:SetCursor("beam")
    overlay:SetMouseInputEnabled(true)

    local cols = {}
    local colCount = math.floor(w / 12)
    for i = 1, colCount do
        cols[i] = {
            x = (i-1) * 12,
            y = math.random(-h,0),
            speed = math.Rand(30,160),
            len = math.random(6,30)
        }
    end

    local messages = {
        "INIZALISIERE SYSTEM ...",
        "VERBINDE MIT HACKING NETZWERK ...",
        "VERIFIZIERE ZUGANGSDATEN ...",
        "ZUGANG GEWAEHRT.",
        "ZIEL AUSWAHLEN ..."
    }

    local typed = {}
    for i=1, #messages do typed[i] = "" end
    local curLine = 1
    local curChar = 0
    local lastTick = SysTime()
    local charDelay = 0.03
    local cursorBlink = true
    local lastCursor = SysTime()

    overlay.Paint = function(self, sw, sh)
        surface.SetDrawColor(0,0,0,220)
        surface.DrawRect(0,0,sw,sh)

        for i, col in ipairs(cols) do
            col.y = col.y + FrameTime() * col.speed
            if col.y > sh + (col.len * 12) then
                col.y = math.random(-sh,0)
                col.speed = math.Rand(30,160)
                col.len = math.random(6,30)
            end
            for j = 0, col.len - 1 do
                local ch = string.char(math.random(48,90))
                local yy = col.y - (j * 12)
                if yy > -12 and yy < sh + 12 then
                    local alpha = 255 - (j * (255 / col.len))
                    draw.SimpleText(ch, "PD_HackFont_Small", col.x, yy, Color(0,255,0,math.Clamp(alpha,0,255)), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end
            end
        end

        local pad = 20
        draw.RoundedBox(0, pad-6, pad-6, sw - pad*2 + 12, (16 * (#messages + 2)) + 24, Color(0,0,0,120))
        for i = 1, #messages do
            local y = pad + ((i-1) * 18)
            draw.SimpleText(typed[i], "PD_HackFont_Large", pad, y, Color(0,255,80,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end

        if cursorBlink then
            local cx = pad + surface.GetTextSize((typed[curLine] or ""), "PD_HackFont_Large")
            local cy = pad + ((curLine-1) * 18)
            draw.SimpleText("_", "PD_HackFont_Large", cx, cy, Color(0,255,80,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end

    Mbase.Think = function(self)
        local now = SysTime()
        if now - lastTick >= charDelay then
            lastTick = now
            if curLine <= #messages then
                curChar = curChar + 1
                local msg = messages[curLine]
                typed[curLine] = string.sub(msg, 1, curChar)
                if curChar >= #msg then
                    curLine = curLine + 1
                    curChar = 0
                end
            else
                if #typed > 0 then
                    for i=1,#typed do
                        if math.random() < 0.005 then
                            local m = messages[i]
                            local p = math.random(1, #m)
                            typed[i] = string.sub(m,1,p) .. string.char(math.random(48,90))
                        end
                    end
                end
            end
        end
        if SysTime() - lastCursor >= 0.5 then
            lastCursor = SysTime()
            cursorBlink = not cursorBlink
        end
    end

    return Mbase
end

concommand.Add("pd_hackmenu", function()
    PD.HackMenu("Hacking Menu", 800, 400, true, nil, false)
end)

-- PD.HackMenu("Hacking Menu", 800, 400, true, nil, false)