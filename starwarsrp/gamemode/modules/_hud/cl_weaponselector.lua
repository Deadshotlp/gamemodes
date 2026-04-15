-- Weaponselector - Star Wars Andor Imperial Style (Zentral über PD.Theme)
-- Layout am oberen Bildschirmrand mit Slot-Gruppierung

local selectedIndex = 1
local weaponList = {}
local selectorVisible = false
local glowPulse = 0
local lastScrollTime = 0

-- Slide Animation
local slideProgress = 0
local slideTarget = 0
local SLIDE_SPEED = 10

local function GetWeaponSlot(wep)
    if not IsValid(wep) then return 0 end

    local slot = 0
    if isfunction(wep.Slot) then
        slot = wep:Slot() or 0
    elseif isnumber(wep.Slot) then
        slot = wep.Slot
    end

    return slot + 1
end

local function GetWeaponSlotPos(wep)
    if not IsValid(wep) then return 0 end

    if isfunction(wep.SlotPos) then
        return wep:SlotPos() or 0
    elseif isnumber(wep.SlotPos) then
        return wep.SlotPos
    end

    return 0
end

local function SortWeaponsBySlot(weapons)
    local sortedWeapons = table.Copy(weapons)
    table.sort(sortedWeapons, function(a, b)
        local slotA = GetWeaponSlot(a)
        local slotB = GetWeaponSlot(b)
        if slotA ~= slotB then
            return slotA < slotB
        end

        local slotPosA = GetWeaponSlotPos(a)
        local slotPosB = GetWeaponSlotPos(b)
        if slotPosA ~= slotPosB then
            return slotPosA < slotPosB
        end

        return (a:GetClass() or "") < (b:GetClass() or "")
    end)

    return sortedWeapons
end

local function FindWeaponIndexByEntity(weapons, targetWep)
    if not IsValid(targetWep) then return nil end
    for i, wep in ipairs(weapons) do
        if wep == targetWep then
            return i
        end
    end
end

local function BuildSlotGroups(sortedWeapons)
    local groups = {}
    local order = {}

    for _, wep in ipairs(sortedWeapons) do
        local slot = GetWeaponSlot(wep)
        if not groups[slot] then
            groups[slot] = {}
            table.insert(order, slot)
        end
        table.insert(groups[slot], wep)
    end

    table.sort(order)
    return groups, order
end

-- Zeichnet ein einzelnes Waffen-Item
local function DrawWeaponItem(x, y, itemW, itemH, wep, isSelected, isActive)
    if not IsValid(wep) then return end

    local w = itemW
    local h = itemH
    
    -- Glow-Effekt Animation bei Auswahl
    if isSelected then
        glowPulse = glowPulse + FrameTime() * 4
        local glowAlpha = 60 + math.sin(glowPulse) * 30
        
        for i = 1, 3 do
            local offset = i * PD.W(2)
            local alpha = glowAlpha / i
            surface.SetDrawColor(PD.Theme.Colors.AccentRed.r, PD.Theme.Colors.AccentRed.g, PD.Theme.Colors.AccentRed.b, alpha)
            surface.DrawOutlinedRect(x - offset, y - offset, w + offset * 2, h + offset * 2, 1)
        end
    end
    
    -- Hintergrund
    local bgColor = isSelected and PD.Theme.Colors.BackgroundHover or PD.Theme.Colors.Background
    if isActive then
        bgColor = PD.ColorAlpha(PD.Theme.Colors.StatusActive, 0.25)
    end
    draw.RoundedBox(0, x, y, w, h, bgColor)
    
    -- Linke Akzentlinie
    local accentColor = PD.Theme.Colors.AccentGray
    if isSelected then
        accentColor = PD.Theme.Colors.AccentRed
    elseif isActive then
        accentColor = PD.Theme.Colors.StatusActive
    end
    surface.SetDrawColor(accentColor)
    surface.DrawRect(x, y, PD.W(3), h)
    
    -- Obere/Untere Linien
    surface.SetDrawColor(PD.Theme.Colors.AccentGray.r, PD.Theme.Colors.AccentGray.g, PD.Theme.Colors.AccentGray.b, 100)
    surface.DrawRect(x + PD.W(3), y, w - PD.W(3), 1)
    surface.DrawRect(x + PD.W(3), y + h - 1, w - PD.W(3), 1)
    
    -- Ecken-Dekor rechts (nur bei Auswahl)
    if isSelected then
        local cornerSize = PD.W(8)
        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
        surface.DrawLine(x + w - cornerSize, y, x + w, y)
        surface.DrawLine(x + w - 1, y, x + w - 1, y + cornerSize)
        surface.DrawLine(x + w - cornerSize, y + h - 1, x + w, y + h - 1)
        surface.DrawLine(x + w - 1, y + h - cornerSize, x + w - 1, y + h)
    end
    
    -- SlotPos-Nummer
    -- local slotPos = GetWeaponSlotPos(wep) + 1
    -- local slotColor = isSelected and PD.Theme.Colors.AccentRed or PD.Theme.Colors.AccentGray
    -- draw.DrawText(slotPos, "MLIB.14", x + PD.W(15), y + h / 2 - PD.H(7), slotColor, TEXT_ALIGN_CENTER)
    
    -- Trennlinie nach Nummer
    -- surface.SetDrawColor(PD.Theme.Colors.AccentGray.r, PD.Theme.Colors.AccentGray.g, PD.Theme.Colors.AccentGray.b, 80)
    -- surface.DrawRect(x + PD.W(28), y + PD.H(8), 1, h - PD.H(16))
    
    -- Waffen-Name
    local name = wep:GetPrintName() or wep:GetClass()
    if #name > 16 then
        name = string.sub(name, 1, 14) .. ".."
    end
    local textColor = isSelected and PD.Theme.Colors.Text or PD.Theme.Colors.TextDim
    draw.DrawText(name, "MLIB.14", x + PD.W(15), y + h / 2 - PD.H(7), textColor, TEXT_ALIGN_LEFT)
    
    -- Munitionsanzeige
    local clip = wep:Clip1()
    if clip and clip >= 0 then
        local ammo = LocalPlayer():GetAmmoCount(wep:GetPrimaryAmmoType())
        local ammoText = clip .. "/" .. ammo
        
        local ammoColor = PD.Theme.Colors.TextMuted
        if clip == 0 then
            ammoColor = PD.Theme.Colors.StatusCritical
        elseif clip <= 5 then
            ammoColor = PD.Theme.Colors.StatusWarning
        end
        draw.DrawText(ammoText, "MLIB.12", x + w - PD.W(10), y + h / 2 - PD.H(6), ammoColor, TEXT_ALIGN_RIGHT)
    end
    
    -- Aktiv-Indikator
    if isActive then
        draw.RoundedBox(100, x + w - PD.W(18), y + PD.H(5), PD.W(6), PD.H(6), PD.Theme.Colors.StatusActive)
    end
end

-- Hauptzeichenfunktion
hook.Add("HUDPaint", "PD.WeaponSelector.Draw", function()
    if not PD.Theme then return end
    
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply:InVehicle() then return end
    
    -- Slide Animation
    slideProgress = Lerp(FrameTime() * SLIDE_SPEED, slideProgress, slideTarget)
    
    if slideProgress < 0.01 and slideTarget == 0 then return end
    
    weaponList = ply:GetWeapons()
    if #weaponList == 0 then return end

    if selectedIndex < 1 or selectedIndex > #weaponList then
        selectedIndex = 1
    end
    
    local activeWeapon = ply:GetActiveWeapon()
    
    local sortedWeapons = SortWeaponsBySlot(weaponList)
    local slotGroups, slotOrder = BuildSlotGroups(sortedWeapons)
    if #slotOrder == 0 then return end

    local SELECTOR_PADDING = PD.W(12)
    local COLUMN_SPACING = PD.W(8)
    local ITEM_HEIGHT = PD.H(36)
    local ITEM_SPACING = PD.H(3)
    local HEADER_HEIGHT = PD.H(30)
    local FOOTER_HEIGHT = PD.H(22)

    local maxWeaponsInSlot = 1
    for _, slot in ipairs(slotOrder) do
        maxWeaponsInSlot = math.max(maxWeaponsInSlot, #slotGroups[slot])
    end

    local slotCount = #slotOrder
    local maxPanelWidth = ScrW() - PD.W(40)
    local calculatedItemWidth = math.floor((maxPanelWidth - SELECTOR_PADDING * 2 - COLUMN_SPACING * (slotCount - 1)) / slotCount)
    local ITEM_WIDTH = math.Clamp(calculatedItemWidth, PD.W(120), PD.W(190))
    local panelW = slotCount * ITEM_WIDTH + (slotCount - 1) * COLUMN_SPACING + SELECTOR_PADDING * 2
    local listH = maxWeaponsInSlot * (ITEM_HEIGHT + ITEM_SPACING) - ITEM_SPACING
    local panelH = HEADER_HEIGHT + listH + FOOTER_HEIGHT + SELECTOR_PADDING * 2

    local panelX = ScrW() / 2 - panelW / 2
    local hiddenY = -panelH - PD.H(10)
    local visibleY = PD.H(15)
    local panelY = Lerp(slideProgress, hiddenY, visibleY)
    
    -- Hintergrund
    draw.RoundedBox(0, panelX, panelY, panelW, panelH, PD.Theme.Colors.BackgroundDark)
    
    -- Rechte Akzentlinie
    surface.SetDrawColor(PD.Theme.Colors.AccentRed)
    surface.DrawRect(panelX + panelW - PD.W(3), panelY, PD.W(3), panelH)
    
    -- Obere/Untere Akzentlinie
    surface.DrawRect(panelX, panelY, panelW - PD.W(3), PD.H(3))
    surface.DrawRect(panelX, panelY + panelH - PD.H(3), panelW - PD.W(3), PD.H(3))
    
    -- Linke Linie
    surface.SetDrawColor(PD.Theme.Colors.AccentGray)
    surface.DrawRect(panelX, panelY + PD.H(3), 1, panelH - PD.H(6))
    
    -- Imperial Ecken-Dekor
    local cornerSize = PD.W(15)
    surface.SetDrawColor(PD.Theme.Colors.AccentRed)
    surface.DrawRect(panelX, panelY, cornerSize, PD.H(2))
    surface.DrawRect(panelX, panelY, PD.W(2), cornerSize)
    surface.DrawRect(panelX, panelY + panelH - PD.H(2), cornerSize, PD.H(2))
    surface.DrawRect(panelX, panelY + panelH - cornerSize, PD.W(2), cornerSize)
    
    -- Titel
    draw.DrawText("AUSRÜSTUNG", "MLIB.12", panelX + panelW / 2, panelY + PD.H(10), PD.Theme.Colors.AccentGray, TEXT_ALIGN_CENTER)
    
    -- Trennlinie
    surface.SetDrawColor(PD.Theme.Colors.AccentGray.r, PD.Theme.Colors.AccentGray.g, PD.Theme.Colors.AccentGray.b, 100)
    surface.DrawRect(panelX + SELECTOR_PADDING, panelY + PD.H(28), panelW - SELECTOR_PADDING * 2, 1)
    
    -- Waffen-Liste nach Slots
    local startX = panelX + SELECTOR_PADDING
    local startY = panelY + HEADER_HEIGHT + SELECTOR_PADDING
    local selectedWeapon = weaponList[selectedIndex]

    for col, slot in ipairs(slotOrder) do
        local colX = startX + (col - 1) * (ITEM_WIDTH + COLUMN_SPACING)

        -- Slot-Header
        --draw.RoundedBox(0, colX, startY - PD.H(20), ITEM_WIDTH, PD.H(16), PD.Theme.Colors.Background)
        draw.DrawText("SLOT " .. slot, "MLIB.10", colX + ITEM_WIDTH / 2, startY - PD.H(0), PD.Theme.Colors.AccentGray, TEXT_ALIGN_CENTER)

        for row, wep in ipairs(slotGroups[slot]) do
            local itemY = startY + PD.H(20) + (row - 1) * (ITEM_HEIGHT + ITEM_SPACING)
            local isSelected = (wep == selectedWeapon)
            local isActive = (wep == activeWeapon)
            DrawWeaponItem(colX, itemY, ITEM_WIDTH, ITEM_HEIGHT, wep, isSelected, isActive)
        end
    end
    
    -- Hinweis
    local hintY = panelY + panelH - PD.H(18)
    draw.DrawText("[KLICK] Ausrüsten", "MLIB.10", panelX + panelW / 2, hintY, PD.Theme.Colors.TextMuted, TEXT_ALIGN_CENTER)
end)

-- Selector anzeigen
local function ShowSelector()
    selectorVisible = true
    slideTarget = 1
    glowPulse = 0
    
    -- Timer für Auto-Hide zurücksetzen
    timer.Remove("WeaponSelector_AutoHide")
    timer.Create("WeaponSelector_AutoHide", 2.5, 1, function()
        slideTarget = 0
        selectorVisible = false
    end)
end

-- Selector verstecken
local function HideSelector()
    slideTarget = 0
    selectorVisible = false
    timer.Remove("WeaponSelector_AutoHide")
end

-- Waffe ausrüsten
local function EquipSelectedWeapon()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    
    weaponList = ply:GetWeapons()
    if selectedIndex < 1 or selectedIndex > #weaponList then return end
    
    local wep = weaponList[selectedIndex]
    if IsValid(wep) then
        -- Direkt die Waffe ausrüsten via input.SelectWeapon
        input.SelectWeapon(wep)
        
        -- Auch Server benachrichtigen
        net.Start("PD.WeaponSelector:SelectWeapon")
        net.WriteInt(selectedIndex, 32)
        net.SendToServer()
    end
    
    -- Kurz anzeigen dann verstecken
    timer.Remove("WeaponSelector_AutoHide")
    timer.Create("WeaponSelector_AutoHide", 1, 1, function()
        slideTarget = 0
        selectorVisible = false
    end)
end

-- Scroll-Funktion (Richtung korrigiert: Scroll UP = vorherige, Scroll DOWN = nächste)
local SCROLL_COOLDOWN = 0.08 -- Cooldown um doppelte Scroll-Events zu verhindern

local function ScrollWeapon(up)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply:InVehicle() then return end
    
    -- Cooldown prüfen
    if CurTime() - lastScrollTime < SCROLL_COOLDOWN then
        return
    end
    lastScrollTime = CurTime()
    
    weaponList = ply:GetWeapons()
    if #weaponList == 0 then return end

    local sortedWeapons = SortWeaponsBySlot(weaponList)
    if #sortedWeapons == 0 then return end
    
    -- Bei erstem Öffnen: Aktive Waffe auswählen
    if not selectorVisible then
        local activeWep = ply:GetActiveWeapon()
        local activeIndex = FindWeaponIndexByEntity(weaponList, activeWep)
        if activeIndex then
            selectedIndex = activeIndex
        end
    end

    if selectedIndex < 1 or selectedIndex > #weaponList then
        selectedIndex = 1
    end

    local selectedWeapon = weaponList[selectedIndex]
    local sortedIndex = FindWeaponIndexByEntity(sortedWeapons, selectedWeapon) or 1

    if up then
        sortedIndex = sortedIndex - 1
        if sortedIndex < 1 then
            sortedIndex = #sortedWeapons
        end
    else
        sortedIndex = sortedIndex + 1
        if sortedIndex > #sortedWeapons then
            sortedIndex = 1
        end
    end

    local newWeapon = sortedWeapons[sortedIndex]
    local newIndex = FindWeaponIndexByEntity(weaponList, newWeapon)
    if newIndex then
        selectedIndex = newIndex
    end
    
    ShowSelector()
    surface.PlaySound("UI/buttonrollover.wav")
end

-- Mausrad abfangen via PlayerBindPress
hook.Add("PlayerBindPress", "PD.WeaponSelector.Scroll", function(ply, bind, pressed)
    if not IsValid(ply) then return end
    if ply ~= LocalPlayer() then return end

    if string.find(bind, "slot") then
        return true
    end

    if string.find(bind, "invprev") then
        return true
    end

    if string.find(bind, "invnext") then
        return true
    end
end)

hook.Add( "StartCommand", "StartCommandExample", function( ply, cmd )
    if cmd:GetMouseWheel() == 0 then return end
    if cmd:GetMouseWheel() > 0 and not input.IsMouseDown(MOUSE_LEFT) then
        -- Mausrad HOCH = vorherige Waffe
        ScrollWeapon(true)
    elseif cmd:GetMouseWheel() < 0 and not input.IsMouseDown(MOUSE_LEFT) then
        -- Mausrad RUNTER = nächste Waffe
        ScrollWeapon(false)
    end
end )

-- Mausklick zum Ausrüsten
hook.Add("Think", "PD.WeaponSelector.Click", function()
    if not selectorVisible then return end
    
    -- Linksklick zum Ausrüsten
    if input.IsMouseDown(MOUSE_LEFT) then
        if not PD.WeaponSelector_ClickHandled then
            PD.WeaponSelector_ClickHandled = true
            EquipSelectedWeapon()
            surface.PlaySound("UI/buttonclick.wav")
        end
    else
        PD.WeaponSelector_ClickHandled = false
    end
    
    -- Rechtsklick zum Schließen
    if input.IsMouseDown(MOUSE_RIGHT) then
        if not PD.WeaponSelector_RClickHandled then
            PD.WeaponSelector_RClickHandled = true
            HideSelector()
        end
    else
        PD.WeaponSelector_RClickHandled = false
    end
end)

-- Zahlen-Tasten für schnelle Auswahl
hook.Add("PlayerButtonDown", "PD.WeaponSelector.NumberKeys", function(ply, button)
    if not IsFirstTimePredicted() then return end
    if not IsValid(ply) or ply ~= LocalPlayer() then return end
    
    local slotKeys = {
        [KEY_1] = 1, [KEY_2] = 2, [KEY_3] = 3, [KEY_4] = 4,
        [KEY_5] = 5, [KEY_6] = 6, [KEY_7] = 7, [KEY_8] = 8, [KEY_9] = 9
    }
    
    if slotKeys[button] then
        weaponList = ply:GetWeapons()
        local sortedWeapons = SortWeaponsBySlot(weaponList)
        local slot = slotKeys[button]

        local slotWeapons = {}
        for _, wep in ipairs(sortedWeapons) do
            if GetWeaponSlot(wep) == slot then
                table.insert(slotWeapons, wep)
            end
        end

        if #slotWeapons > 0 then
            local activeWeapon = ply:GetActiveWeapon()
            local activeSlotIndex = FindWeaponIndexByEntity(slotWeapons, activeWeapon)
            local targetSlotIndex = 1

            if activeSlotIndex then
                targetSlotIndex = activeSlotIndex + 1
                if targetSlotIndex > #slotWeapons then
                    targetSlotIndex = 1
                end
            end

            local slotWeapon = slotWeapons[targetSlotIndex]
            if IsValid(slotWeapon) then
                local index = FindWeaponIndexByEntity(weaponList, slotWeapon)
                if index then
                    selectedIndex = index
                    ShowSelector()
                    EquipSelectedWeapon()
                end
            end
        end
        surface.PlaySound("UI/buttonclick.wav")
    end
    
    -- if button == KEY_ESCAPE and selectorVisible then
    --     HideSelector()
    -- end
end)
