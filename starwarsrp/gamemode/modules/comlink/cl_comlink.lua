PD.Comlink = PD.Comlink or {}
PD.Comlink.MaxSlots = 5

LocalPlayer().ActiveChannel = false
LocalPlayer().Extra1 = false
LocalPlayer().Extra2 = false
LocalPlayer().Extra3 = false
local comlinkChannelAktive = {}

-- Comlink Menu - Star Wars Andor Imperial Style (Zentral über PD.Theme)
function PD.Comlink:Menu()
    if IsValid(self.Frame) then self.Frame:Remove() return end
    local ply = LocalPlayer()

    -- Prüfen ob irgendein Kanal aktiv ist
    local hasActiveChannel = ply.Extra1 or ply.Extra2 or ply.Extra3
    local accentColor = hasActiveChannel and PD.Theme.Colors.StatusActive or PD.Theme.Colors.AccentRed

    self.Frame = PD.Frame(LANG.COMLINK_UI_TITLE or "KOMMUNIKATION", PD.W(550), PD.H(650), true)
    
    -- Custom Andor Imperial Background
    local frameW, frameH = self.Frame:GetSize()
    self.Frame.Paint = function(s, w, h)
        -- Haupthintergrund - sehr dunkel
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        
        -- Subtiles Grid-Muster (Imperial Tech Style)
        PD.DrawGridPattern(0, 0, w, h, PD.W(20), Color(30, 30, 35, 80))
        
        -- Äußerer Rahmen
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawOutlinedRect(PD.W(8), PD.H(8), w - PD.W(16), h - PD.H(16), 1)
        
        -- Innerer Rahmen (subtil)
        surface.SetDrawColor(PD.Theme.Colors.BackgroundLight.r, PD.Theme.Colors.BackgroundLight.g, PD.Theme.Colors.BackgroundLight.b, 200)
        surface.DrawOutlinedRect(PD.W(12), PD.H(12), w - PD.W(24), h - PD.H(24), 1)
        
        -- Obere Akzentlinie
        surface.SetDrawColor(accentColor)
        surface.DrawRect(PD.W(8), PD.H(8), w - PD.W(16), PD.H(3))
        
        -- Untere Akzentlinie
        surface.DrawRect(PD.W(8), h - PD.H(11), w - PD.W(16), PD.H(3))
        
        -- Imperial Ecken-Dekor (oben links)
        local cornerSize = PD.W(25)
        surface.SetDrawColor(accentColor)
        surface.DrawRect(PD.W(8), PD.H(8), cornerSize, PD.H(2))
        surface.DrawRect(PD.W(8), PD.H(8), PD.W(2), cornerSize)
        
        -- Imperial Ecken-Dekor (oben rechts)
        surface.DrawRect(w - PD.W(8) - cornerSize, PD.H(8), cornerSize, PD.H(2))
        surface.DrawRect(w - PD.W(10), PD.H(8), PD.W(2), cornerSize)
        
        -- Imperial Ecken-Dekor (unten links)
        surface.DrawRect(PD.W(8), h - PD.H(10), cornerSize, PD.H(2))
        surface.DrawRect(PD.W(8), h - PD.H(8) - cornerSize, PD.W(2), cornerSize)
        
        -- Imperial Ecken-Dekor (unten rechts)
        surface.DrawRect(w - PD.W(8) - cornerSize, h - PD.H(10), cornerSize, PD.H(2))
        surface.DrawRect(w - PD.W(10), h - PD.H(8) - cornerSize, PD.W(2), cornerSize)
        
        -- Seitliche Dekoration (links)
        local decoY = h / 2 - PD.H(50)
        for i = 0, 4 do
            local y = decoY + i * PD.H(20)
            local alpha = 150 - i * 25
            surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b, alpha)
            surface.DrawRect(PD.W(3), y, PD.W(4), PD.H(10))
        end
        
        -- Seitliche Dekoration (rechts)
        for i = 0, 4 do
            local y = decoY + i * PD.H(20)
            local alpha = 150 - i * 25
            surface.SetDrawColor(accentColor.r, accentColor.g, accentColor.b, alpha)
            surface.DrawRect(w - PD.W(7), y, PD.W(4), PD.H(10))
        end
    end

    -- Header Panel
    local headerPanel = vgui.Create("DPanel", self.Frame)
    headerPanel:Dock(TOP)
    headerPanel:SetTall(PD.H(60))
    headerPanel:DockMargin(0, 0, 0, PD.H(10))
    headerPanel.Paint = function(s, w, h)
        -- Hintergrund
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
        
        -- Obere Akzentlinie
        surface.SetDrawColor(accentColor)
        surface.DrawRect(0, 0, w, PD.H(3))
        
        -- Icon (Funk-Symbol)
        local iconSize = PD.H(30)
        local iconX = PD.W(15)
        local iconY = h / 2
        
        -- Funk-Wellen zeichnen
        for i = 1, 3 do
            local radius = PD.W(8) + (i * PD.W(6))
            local alpha = 255 - (i * 60)
            surface.SetDrawColor(PD.Theme.Colors.AccentBlue.r, PD.Theme.Colors.AccentBlue.g, PD.Theme.Colors.AccentBlue.b, alpha)
            local startAng = -45
            local endAng = 45
            for ang = startAng, endAng, 5 do
                local rad = math.rad(ang)
                local x1 = iconX + math.cos(rad) * radius
                local y1 = iconY - math.sin(rad) * radius
                local x2 = iconX + math.cos(rad) * (radius + 2)
                local y2 = iconY - math.sin(rad) * (radius + 2)
                surface.DrawLine(x1, y1, x2, y2)
            end
        end
        
        -- Titel
        draw.DrawText("COMM-LINK SYSTEM", "MLIB.20", PD.W(60), h / 2 - PD.H(10), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
        
        -- Status
        local statusText = hasActiveChannel and "AKTIV" or "STANDBY"
        local statusColor = hasActiveChannel and PD.Theme.Colors.StatusActive or PD.Theme.Colors.TextDim
        draw.DrawText(statusText, "MLIB.14", w - PD.W(15), h / 2 - PD.H(7), statusColor, TEXT_ALIGN_RIGHT)
    end

    -- Aktive Kanäle Info
    local activePanel = vgui.Create("DPanel", self.Frame)
    activePanel:Dock(TOP)
    activePanel:SetTall(PD.H(80))
    activePanel:DockMargin(0, 0, 0, PD.H(10))
    activePanel.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        
        -- Linke Akzentlinie
        surface.SetDrawColor(accentColor)
        surface.DrawRect(0, 0, PD.W(3), h)
        
        PD.DrawLabel("AKTIVE FREQUENZEN", "MLIB.12", PD.W(15), PD.H(8))
        
        -- Slots anzeigen (5 Slots)
        local slotW = (w - PD.W(30)) / 3
        for i = 1, 3 do
            local index = ply["Extra" .. i]
            local channelName = index and PD.Comlink.Table[index] and PD.Comlink.Table[index].name or false
            local slotX = PD.W(15) + (i - 1) * slotW
            local slotY = PD.H(28)
            local channel = channelName or false
            local channelText = tostring(channel) or "---"
            
            if #channelText > 30 then
                channelText = string.sub(channelText, 1, 28) .. ".."
            end
            
            -- Slot Hintergrund
            local slotColor = channel and PD.ColorAlpha(PD.Theme.Colors.StatusActive, 0.35) or PD.ColorAlpha(PD.Theme.Colors.BackgroundLight, 0.8)
            draw.RoundedBox(0, slotX, slotY, slotW - PD.W(3), PD.H(40), slotColor)
            
            -- Slot Rahmen
            local borderColor = channel and PD.Theme.Colors.StatusActive or PD.Theme.Colors.AccentGray
            surface.SetDrawColor(borderColor)
            surface.DrawOutlinedRect(slotX, slotY, slotW - PD.W(3), PD.H(40), 1)
            
            -- Slot Label
            PD.DrawLabel("S" .. i, "MLIB.10", slotX + (slotW - PD.W(3)) / 2, slotY + PD.H(3), PD.Theme.Colors.AccentGray, TEXT_ALIGN_CENTER)
            
            -- Kanal Name
            local textCol = channel and PD.Theme.Colors.Text or PD.Theme.Colors.TextDim
            local channelText = channel and channelText or "---"
            draw.DrawText(channelText, "MLIB.12", slotX + (slotW - PD.W(3)) / 2, slotY + PD.H(18), textCol, TEXT_ALIGN_CENTER)
        end
    end

    -- Kanalliste Header
    local listHeader = vgui.Create("DPanel", self.Frame)
    listHeader:Dock(TOP)
    listHeader:SetTall(PD.H(30))
    listHeader:DockMargin(0, 0, 0, 0)
    listHeader.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
        PD.DrawLabel("VERFÜGBARE KANÄLE", "MLIB.12", PD.W(10), h / 2 - PD.H(6))
        
        -- Trennlinie
        PD.DrawDivider(0, h - 1, w)
    end

    local scrl = PD.Scroll(self.Frame)

    local text = ""
    for k, v in SortedPairs(PD.Comlink.Table) do
        if not v.check(ply) then continue end

        local channelColor = v.color or Color(100, 100, 100)
        
        local pnl = vgui.Create("DPanel", scrl)
        pnl:Dock(TOP)
        pnl:SetTall(PD.H(55))
        pnl:DockMargin(0, PD.H(2), 0, 0)
        
        -- Prüfen ob dieser Kanal aktiv ist
        local isActive = (ply.Extra1 == k) or (ply.Extra2 == k) or (ply.Extra3 == k)
        
        pnl.Paint = function(s, w, h)
            text = v.name
            if #text > 40 then
                text = string.sub(text, 1, 38) .. "..."
            end
            
            -- Hintergrund
            local bgColor = isActive and PD.ColorAlpha(PD.Theme.Colors.StatusActive, 0.25) or PD.Theme.Colors.BackgroundLight
            draw.RoundedBox(0, 0, 0, w, h, bgColor)
            
            -- Linke Farbmarkierung (Kanal-Farbe)
            surface.SetDrawColor(channelColor)
            surface.DrawRect(0, 0, PD.W(4), h)
            
            -- Aktiv-Indikator
            if isActive then
                surface.SetDrawColor(PD.Theme.Colors.StatusActive)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end
            
            -- Kanal-Name
            draw.DrawText(text, "MLIB.16", PD.W(15), h / 2 - PD.H(8), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
            
            -- Status-Punkt
            local statusCol = isActive and PD.Theme.Colors.StatusActive or PD.Theme.Colors.AccentGray
            draw.RoundedBox(100, PD.W(250), h / 2 - PD.H(4), PD.H(8), PD.H(8), statusCol)
        end

        -- Slot-Buttons (5 Slots)
        for i = 3, 1, -1 do
            local slotActive = ply["Extra" .. i] == k
            
            local extraBtn = vgui.Create("DButton", pnl)
            extraBtn:SetText("")
            extraBtn:Dock(RIGHT)
            extraBtn:SetWide(PD.W(50))
            extraBtn:DockMargin(PD.W(2), PD.H(10), PD.W(2), PD.H(10))
            
            local btnHover = false
            extraBtn.Paint = function(s, w, h)
                local bgCol = slotActive and PD.Theme.Colors.StatusActive or PD.Theme.Colors.BackgroundLight
                if btnHover and not slotActive then
                    bgCol = PD.Theme.Colors.BackgroundHover
                end
                
                draw.RoundedBox(0, 0, 0, w, h, bgCol)
                
                -- Rahmen
                local borderCol = slotActive and PD.Theme.Colors.StatusActive or PD.Theme.Colors.AccentGray
                surface.SetDrawColor(borderCol)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                
                -- Text
                local txtCol = slotActive and PD.Theme.Colors.Text or PD.Theme.Colors.TextDim
                draw.DrawText("S" .. i, "MLIB.12", w / 2, h / 2 - PD.H(6), txtCol, TEXT_ALIGN_CENTER)
            end
            
            extraBtn.OnCursorEntered = function() btnHover = true end
            extraBtn.OnCursorExited = function() btnHover = false end
            
            extraBtn.DoClick = function()
                surface.PlaySound("UI/buttonclick.wav")
                if ply["Extra" .. i] == k then
                    ply["Extra" .. i] = false

                    net.Start("PD.Comlink.EndVoice")
                        net.WriteInt(k, 8)
                        net.WriteInt(i + 1, 4)
                    net.SendToServer()
                else
                    ply["Extra" .. i] = k

                    net.Start("PD.Comlink.StartVoice")
                        net.WriteInt(k, 8)
                        net.WriteInt(i + 1, 4)
                    net.SendToServer()
                end
                
                self.Frame:Remove()
                timer.Simple(0.1, function()
                    PD.Comlink:Menu()
                end)
            end

            extraBtn.OnCursorEntered = function()
                surface.PlaySound("UI/buttonrollover.wav")
            end
        end
    end
end

-- Comlink HUD - Star Wars Andor Imperial Style (Zentral über PD.Theme)
AddSmoothElement(ScrW() - PD.W(240), PD.H(20), PD.W(220), PD.H(130), function(smoothX, smoothY)
    if PD.FOV.thirdPerson then return end
    
    local ply = LocalPlayer()

    -- Prüfen ob Kanäle aktiv sind
    local hasActiveChannel = ply.Extra1 or ply.Extra2 or ply.Extra3
    local accentColor = hasActiveChannel and PD.Theme.Colors.StatusActive or PD.Theme.Colors.AccentRed

    local panelW = PD.W(220)
    local panelH = PD.H(80)

    -- Hintergrund
    draw.RoundedBox(0, smoothX, smoothY, panelW, panelH, PD.Theme.Colors.BackgroundLight)

    -- Rechte Akzentlinie
    surface.SetDrawColor(accentColor)
    surface.DrawRect(smoothX + panelW - PD.W(4), smoothY, PD.W(4), panelH)

    -- Obere Linie
    surface.SetDrawColor(PD.Theme.Colors.AccentGray)
    surface.DrawRect(smoothX, smoothY, panelW - PD.W(4), 1)

    -- Untere Linie
    surface.DrawRect(smoothX, smoothY + panelH - 1, panelW - PD.W(4), 1)

    -- Linke Linie
    surface.DrawRect(smoothX, smoothY, 1, panelH)

    -- Imperial Ecken-Dekor (oben links)
    local cornerSize = PD.W(8)
    surface.DrawLine(smoothX, smoothY, smoothX + cornerSize, smoothY)
    surface.DrawLine(smoothX, smoothY, smoothX, smoothY + cornerSize)

    -- Imperial Ecken-Dekor (unten links)
    surface.DrawLine(smoothX, smoothY + panelH - 1, smoothX + cornerSize, smoothY + panelH - 1)
    surface.DrawLine(smoothX, smoothY + panelH - cornerSize, smoothX, smoothY + panelH)

    -- "COMM-LINK" Label
    local titleText = LANG.COMLINK_UI_TITLE or "KOMMUNIKATION"

    if not table.IsEmpty(comlinkChannelAktive) then
        local index = comlinkChannelAktive.channel
        titleText = index and PD.Comlink.Table[index] and PD.Comlink.Table[index].name .. " - AKTIV" or "Nicht Verbunden"
    end

    if #titleText > 30 then
        titleText = string.sub(titleText, 1, 28) .. ".."
    end
    PD.DrawLabel(titleText, "MLIB.12", smoothX + PD.W(10), smoothY + PD.H(6))

    -- Aktiv-Indikator (pulsierend wenn aktiv)
    PD.DrawStatusIndicator(
        smoothX + panelW - PD.W(18), 
        smoothY + PD.H(8), 
        PD.W(6), 
        accentColor, 
        hasActiveChannel
    )

    -- Slot-Anzeigen (3 Slots)
    local slotY = smoothY + PD.H(22)
    local slotHeight = PD.H(18)
    local slots = {
        {name = "S1", channel = ply.Extra1},
        {name = "S2", channel = ply.Extra2},
        {name = "S3", channel = ply.Extra3}
    }

    for i, slot in ipairs(slots) do
        local y = slotY + (i - 1) * (slotHeight + PD.H(1))
        local index = ply["Extra" .. i]
        local channelName = index and PD.Comlink.Table[index] and PD.Comlink.Table[index].name or "Nicht Verbunden"
        local channelText = tostring(channelName) or "---"
        
        if slot.channel and #channelText > 30 then
            channelText = string.sub(channelText, 1, 28) .. ".."
        end
        
        -- Slot Label
        local labelColor = slot.channel and PD.Theme.Colors.StatusActive or PD.Theme.Colors.AccentGray
        draw.DrawText(slot.name, "MLIB.11", smoothX + PD.W(10), y + PD.H(2), labelColor, TEXT_ALIGN_LEFT)
        
        -- Trennstrich
        PD.DrawDivider(smoothX + PD.W(30), y + PD.H(7), PD.W(5))
        
        -- Kanal-Name
        local textColor = slot.channel and PD.Theme.Colors.Text or PD.Theme.Colors.TextMuted
        draw.DrawText(channelText, "MLIB.11", smoothX + PD.W(42), y + PD.H(2), textColor, TEXT_ALIGN_LEFT)
    end

    -- "Sprechen" Indikator wenn aktiver Kanal
    if ply.ActiveChannel then
        local talkAlpha = 155 + math.sin(CurTime() * 8) * 100
        surface.SetDrawColor(PD.Theme.Colors.StatusActive.r, PD.Theme.Colors.StatusActive.g, PD.Theme.Colors.StatusActive.b, talkAlpha)
        surface.DrawRect(smoothX, smoothY, panelW, PD.H(2))
        surface.DrawRect(smoothX, smoothY + panelH - PD.H(2), panelW, PD.H(2))
    end
end)

-- Funktion zum Aktivieren eines Kanals per Keybind
local function ActivateComlinkSlot(slotNum)
    local ply = LocalPlayer()
    local channel = ply["Extra" .. slotNum]

    if not channel then return end
    -- Wenn bereits ein Kanal aktiv ist, diesen zuerst beenden
    if ply.ActiveChannel then
        net.Start("PD.Comlink.EndVoice")
            net.WriteInt(ply.ActiveChannel, 8)
            net.WriteInt(1, 4)
        net.SendToServer()
    end
    
    -- Neuen Kanal aktivieren
    ply.ActiveChannel = channel
    net.Start("PD.Comlink.StartVoice")
        net.WriteInt(channel, 8)
        --net.WriteInt(slotNum + 1, 4)
        net.WriteInt(1, 4)
    net.SendToServer()

    surface.PlaySound("mario/funk_start.mp3")

    return channel
end

-- Funktion zum Deaktivieren des aktiven Kanals
local function DeactivateComlinkSlot()
    local ply = LocalPlayer()
    
    if ply.ActiveChannel then
        net.Start("PD.Comlink.EndVoice")
            net.WriteInt(ply.ActiveChannel, 8)
            net.WriteInt(1, 4)
        net.SendToServer()
        
        ply.ActiveChannel = false
    end

    surface.PlaySound("mario/funk_ende.mp3")
end

-- Hook für Keybinds
hook.Add("PlayerButtonDown", "PD.Comlink.PlayerButtonDown", function(ply, button)
    if not IsFirstTimePredicted() then return end
    if not PD.Binds or not PD.Binds.List then return end

    if comlinkChannelAktive and comlinkChannelAktive.button == button then
        DeactivateComlinkSlot()
        comlinkChannelAktive = {}
        return
    end

    -- Prüfe alle 3 Slots
    for i = 1, 3 do
        local bindID = "comlink_extra" .. i
        if PD.Binds.List[bindID] and PD.Binds.List[bindID].Key == button and ply["Extra" .. i] then
            local channel = ActivateComlinkSlot(i)

            comlinkChannelAktive = {channel = channel, button = button}
            return
        end
    end
end)

