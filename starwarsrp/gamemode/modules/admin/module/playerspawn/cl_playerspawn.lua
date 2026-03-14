-- Playerspawn System - Star Wars Andor Imperial Style (Zentral über PD.Theme)

local Spawns = {}
local showSpawns = false

function PlayerSpawnMenu(base)
    if not IsValid(base) then return end
    base:Clear()

    -- Header
    local header = vgui.Create("DPanel", base)
    header:Dock(TOP)
    header:SetTall(PD.H(50))
    header:DockMargin(0, 0, 0, PD.H(10))
    header.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        
        -- Linke Akzentlinie
        surface.SetDrawColor(PD.Theme.Colors.AccentOrange)
        surface.DrawRect(0, 0, PD.W(4), h)
        
        -- Obere/Untere Linie
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(PD.W(4), 0, w - PD.W(4), 1)
        surface.DrawRect(PD.W(4), h - 1, w - PD.W(4), 1)
        
        -- Titel
        draw.DrawText("SPAWN POSITIONEN", "MLIB.18", PD.W(20), h / 2 - PD.H(9), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
        
        -- Info
        local statusText = showSpawns and "ANZEIGE AKTIV" or "ANZEIGE INAKTIV"
        local statusColor = showSpawns and PD.Theme.Colors.StatusActive or PD.Theme.Colors.TextDim
        draw.DrawText(statusText, "MLIB.12", w - PD.W(15), h / 2 - PD.H(6), statusColor, TEXT_ALIGN_RIGHT)
    end

    -- Info Panel
    local infoPanel = vgui.Create("DPanel", base)
    infoPanel:Dock(TOP)
    infoPanel:SetTall(PD.H(60))
    infoPanel:DockMargin(0, 0, 0, PD.H(10))
    infoPanel.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(0, 0, PD.W(3), h)
        
        draw.DrawText("Wähle Units aus und setze deren Spawn-Position auf deine aktuelle Position.", "MLIB.12", PD.W(15), PD.H(12), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
        draw.DrawText("Deine Position: " .. tostring(math.Round(LocalPlayer():GetPos().x)) .. ", " .. tostring(math.Round(LocalPlayer():GetPos().y)) .. ", " .. tostring(math.Round(LocalPlayer():GetPos().z)), "MLIB.14", PD.W(15), PD.H(32), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
    end

    -- Scroll-Container für Units
    local scroll = PD.Scroll(base)

    local Units = PD.JOBS.GetUnit(false, true)
    local unitTbl = {}

    -- Units-Header
    local unitsHeader = vgui.Create("DPanel", scroll)
    unitsHeader:Dock(TOP)
    unitsHeader:SetTall(PD.H(35))
    unitsHeader:DockMargin(0, 0, 0, PD.H(5))
    unitsHeader.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(0, h - 1, w, 1)
        draw.DrawText("VERFÜGBARE UNITS", "MLIB.12", PD.W(10), h / 2 - PD.H(6), PD.Theme.Colors.AccentGray, TEXT_ALIGN_LEFT)
    end

    for k, v in SortedPairs(Units) do
        local unitColor = v.color or PD.Theme.Colors.AccentGray
        local isSelected = false
        
        local unitPanel = vgui.Create("DPanel", scroll)
        unitPanel:Dock(TOP)
        unitPanel:SetTall(PD.H(45))
        unitPanel:DockMargin(0, 0, 0, PD.H(3))
        unitPanel:SetCursor("hand")
        
        unitPanel.Paint = function(s, w, h)
            -- Hintergrund
            local bgColor = isSelected and PD.ColorAlpha(PD.Theme.Colors.StatusActive, 0.2) or PD.Theme.Colors.BackgroundLight
            draw.RoundedBox(0, 0, 0, w, h, bgColor)
            
            -- Linke Farbmarkierung
            surface.SetDrawColor(unitColor)
            surface.DrawRect(0, 0, PD.W(4), h)
            
            -- Rahmen bei Auswahl
            if isSelected then
                surface.SetDrawColor(PD.Theme.Colors.StatusActive)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
            end
            
            -- Unit Name
            draw.DrawText(k, "MLIB.16", PD.W(20), h / 2 - PD.H(8), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
            
            -- Checkbox Indikator
            local checkSize = PD.H(20)
            local checkX = w - checkSize - PD.W(15)
            local checkY = h / 2 - checkSize / 2
            
            draw.RoundedBox(0, checkX, checkY, checkSize, checkSize, PD.Theme.Colors.BackgroundDark)
            surface.SetDrawColor(isSelected and PD.Theme.Colors.StatusActive or PD.Theme.Colors.AccentGray)
            surface.DrawOutlinedRect(checkX, checkY, checkSize, checkSize, 1)
            
            if isSelected then
                -- Häkchen
                draw.DrawText("✓", "MLIB.14", checkX + checkSize / 2, checkY + PD.H(2), PD.Theme.Colors.StatusActive, TEXT_ALIGN_CENTER)
            end
        end
        
        unitPanel.OnMousePressed = function()
            isSelected = not isSelected
            surface.PlaySound("UI/buttonclick.wav")
            
            if isSelected then
                unitTbl[k] = {
                    pos = LocalPlayer():GetPos(),
                    ang = LocalPlayer():GetAngles()
                }
            else
                unitTbl[k] = nil
            end
        end
        
        unitPanel.OnCursorEntered = function()
            surface.PlaySound("UI/buttonrollover.wav")
        end
    end

    -- Button Container
    local buttonContainer = vgui.Create("DPanel", base)
    buttonContainer:Dock(BOTTOM)
    buttonContainer:SetTall(PD.H(160))
    buttonContainer:DockMargin(0, PD.H(10), 0, 0)
    buttonContainer.Paint = function() end

    -- Setzen Button
    local setBtn = PD.Button(LANG.SPAWN_MENU_SET or "Spawns setzen", buttonContainer, function()
        net.Start("PDPlayerSpawnSet")
        net.WriteTable(unitTbl)
        net.SendToServer()
        
        PD.Popup("Spawn-Positionen wurden gesetzt!", PD.Theme.Colors.StatusActive)
        surface.PlaySound("buttons/button14.wav")
    end)
    setBtn:Dock(TOP)
    setBtn:SetTall(PD.H(45))
    setBtn:SetAccentColor(PD.Theme.Colors.StatusActive)

    -- Anzeigen Button
    local showBtn = PD.Button(LANG.SPAWN_MENU_SHOW or "Spawns anzeigen", buttonContainer, function()
        showSpawns = not showSpawns
        surface.PlaySound("UI/buttonclick.wav")
    end)
    showBtn:Dock(TOP)
    showBtn:SetTall(PD.H(45))
    showBtn:SetAccentColor(PD.Theme.Colors.AccentBlue)

    -- Löschen Button
    local deleteBtn = PD.Button(LANG.SPAWN_MENU_DELETE or "Alle Spawns löschen", buttonContainer, function()
        unitTbl = {}
        
        net.Start("PDDeltePlayerSpawns")
        net.SendToServer()
        
        PD.Popup("Alle Spawn-Positionen wurden gelöscht!", PD.Theme.Colors.StatusCritical)
        surface.PlaySound("buttons/button14.wav")
    end)
    deleteBtn:Dock(TOP)
    deleteBtn:SetTall(PD.H(45))
    deleteBtn:SetAccentColor(PD.Theme.Colors.StatusCritical)
end

-- HUD Anzeige für Spawns
hook.Add("HUDPaint", "PlayerSpawnShow", function()
    if not showSpawns then return end
    if not LocalPlayer():IsAdmin() then return end
    if not PD.Theme then return end

    for k, v in pairs(Spawns) do
        print(5)
        local pos = v.pos
        if not pos then continue end
        
        local screenPos = pos:ToScreen()
        if not screenPos.visible then continue end
        
        local text = (LANG.SPAWN_MENU_SPAWN or "Spawn") .. ": " .. k
        surface.SetFont("MLIB.16")
        local w, h = surface.GetTextSize(text)
        
        local boxW = w + PD.W(30)
        local boxH = PD.H(35)
        local boxX = screenPos.x - boxW / 2
        local boxY = screenPos.y - boxH / 2
        
        -- Hintergrund
        draw.RoundedBox(0, boxX, boxY, boxW, boxH, PD.Theme.Colors.BackgroundDark)
        
        -- Obere Akzentlinie
        surface.SetDrawColor(PD.Theme.Colors.AccentOrange)
        surface.DrawRect(boxX, boxY, boxW, PD.H(2))
        
        -- Rahmen
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawOutlinedRect(boxX, boxY, boxW, boxH, 1)
        
        -- Text
        draw.DrawText(text, "MLIB.16", screenPos.x, screenPos.y - PD.H(8), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
    end
end)

timer.Simple(1, function()
    net.Start("PDSyncPlayerSpawns")
    net.SendToServer()
end)

net.Receive("PDSyncPlayerSpawns", function()
    Spawns = net.ReadTable()
end)
