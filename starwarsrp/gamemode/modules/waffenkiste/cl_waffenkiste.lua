PD.WB = PD.WB or {}

local function getPrintName(class)
    local stored = weapons.GetStored(class)

    if stored and stored.PrintName and stored.PrintName ~= "" then
        return stored.PrintName
    end

    return class
end

local function formatWeight(weight)
    if weight == math.floor(weight) then
        return tostring(weight)
    end

    return string.format("%.1f", weight)
end

local function sendGive(class)
    net.Start("PD.WB:GiveWeapon")
        net.WriteString(class)
    net.SendToServer()
end

local function sendRemove(class)
    net.Start("PD.WB:RemoveWeapon")
        net.WriteString(class)
    net.SendToServer()
end

--------------------------------------------------------------------------------
-- Bausteine
--------------------------------------------------------------------------------

local function header(parent, text, color)
    local pnl = vgui.Create("DPanel", parent)
    pnl:Dock(TOP)
    pnl:SetTall(PD.H(30))
    pnl:DockMargin(0, 0, 0, PD.H(6))

    pnl.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        surface.SetDrawColor(color or PD.Theme.Colors.AccentRed)
        surface.DrawRect(0, 0, PD.W(3), h)
        draw.DrawText(text, "MLIB.14", PD.W(12), h / 2 - PD.H(7), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
    end

    return pnl
end

-- Eine Ausrüstungszeile mit Name, Gewicht und Aktionsknopf.
local function equipRow(parent, class, actionText, actionColor, onClick, disabledReason)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:SetTall(PD.H(42))
    row:DockMargin(0, 0, 0, PD.H(4))

    local weight = PD.WB.GetWeaponWeight(class)
    local name = getPrintName(class)

    row.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
        surface.SetDrawColor(disabledReason and PD.Theme.Colors.AccentGray or actionColor)
        surface.DrawRect(0, 0, PD.W(3), h)

        local textColor = disabledReason and PD.Theme.Colors.TextMuted or PD.Theme.Colors.Text

        draw.DrawText(name, "MLIB.14", PD.W(12), PD.H(5), textColor, TEXT_ALIGN_LEFT)
        draw.DrawText(disabledReason or (formatWeight(weight) .. " Kg"), "MLIB.12", PD.W(12), PD.H(23),
            PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
    end

    if not disabledReason then
        local btn = PD.Button(actionText, row, onClick, {height = PD.H(30), font = "MLIB.12"})
        btn:Dock(RIGHT)
        btn:SetWide(PD.W(110))
        btn:DockMargin(0, PD.H(6), PD.W(6), PD.H(6))
        btn:SetAccentColor(actionColor)
    end

    return row
end

--------------------------------------------------------------------------------
-- Menü
--------------------------------------------------------------------------------

local function buildCarried(parent, ply)
    parent:Clear()

    header(parent, "GETRAGEN", PD.Theme.Colors.AccentGreen)

    local scroll = PD.Scroll(parent)
    local carried = PD.WB.GetCarried(ply)
    local anything = false

    for _, category in ipairs(PD.WB.Categories) do
        local list = carried[category.name]

        if list and #list > 0 then
            anything = true

            local lbl = PD.Label(string.upper(category.name), scroll, {
                height = PD.H(20),
                font = "MLIB.12",
                color = PD.Theme.Colors.TextDim
            })
            lbl:Dock(TOP)

            for _, class in ipairs(list) do
                equipRow(scroll, class, "Ablegen", PD.Theme.Colors.AccentRed, function()
                    sendRemove(class)
                end)
            end
        end
    end

    -- Immer-Ausrüstung getrennt anzeigen, damit klar ist warum sie nicht ablegbar ist
    local alwaysShown = false

    for _, class in ipairs(PD.WB.Always) do
        if ply:HasWeapon(class) then
            if not alwaysShown then
                alwaysShown = true

                local lbl = PD.Label("IMMER DABEI", scroll, {
                    height = PD.H(20),
                    font = "MLIB.12",
                    color = PD.Theme.Colors.TextDim
                })
                lbl:Dock(TOP)
            end

            equipRow(scroll, class, nil, PD.Theme.Colors.AccentBlue, nil, "Fest ausgerüstet")
        end
    end

    if not anything and not alwaysShown then
        local lbl = PD.Label("Nichts ausgerüstet.", scroll, {
            height = PD.H(28),
            font = "MLIB.14",
            color = PD.Theme.Colors.TextMuted,
            align = 5
        })
        lbl:Dock(TOP)
    end
end

local function buildAvailable(parent, ply)
    parent:Clear()

    header(parent, "VERFÜGBARE AUSRÜSTUNG", PD.Theme.Colors.AccentBlue)

    local scroll = PD.Scroll(parent)
    local available = PD.WB.GetAvailableByCategory(ply)
    local anything = false

    for _, category in ipairs(PD.WB.Categories) do
        local list = available[category.name]

        if list and #list > 0 then
            anything = true

            local carriedCount = PD.WB.GetCarriedInCategory(ply, category.name)
            local limitText = category.max > 0 and (carriedCount .. "/" .. category.max) or tostring(carriedCount)

            local catHeader = vgui.Create("DPanel", scroll)
            catHeader:Dock(TOP)
            catHeader:SetTall(PD.H(26))
            catHeader:DockMargin(0, PD.H(8), 0, PD.H(4))
            catHeader.Paint = function(s, w, h)
                draw.DrawText(string.upper(category.name), "MLIB.12", PD.W(4), PD.H(5), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
                draw.DrawText(limitText, "MLIB.12", w - PD.W(4), PD.H(5), PD.Theme.Colors.TextDim, TEXT_ALIGN_RIGHT)

                surface.SetDrawColor(PD.Theme.Colors.Divider)
                surface.DrawRect(0, h - 1, w, 1)
            end

            for _, class in ipairs(list) do
                if ply:HasWeapon(class) then
                    equipRow(scroll, class, "Ablegen", PD.Theme.Colors.AccentRed, function()
                        sendRemove(class)
                    end)
                else
                    local ok, reason = PD.WB.CanTake(ply, class)

                    if ok then
                        equipRow(scroll, class, "Nehmen", PD.Theme.Colors.AccentGreen, function()
                            sendGive(class)
                        end)
                    else
                        equipRow(scroll, class, nil, PD.Theme.Colors.AccentGray, nil,
                            formatWeight(PD.WB.GetWeaponWeight(class)) .. " Kg  -  " .. (reason or "nicht verfügbar"))
                    end
                end
            end
        end
    end

    if not anything then
        local lbl = PD.Label("Für deinen Job ist keine Ausrüstung hinterlegt.", scroll, {
            height = PD.H(28),
            font = "MLIB.14",
            color = PD.Theme.Colors.TextMuted,
            align = 5
        })
        lbl:Dock(TOP)
    end
end

function PD.WB:Refresh()
    local frame = self.Frame

    if not IsValid(frame) then return end
    if not IsValid(frame._left) or not IsValid(frame._right) or not IsValid(frame._weightBar) then return end

    local ply = LocalPlayer()
    local weight = PD.WB.GetCarriedWeight(ply)

    buildCarried(frame._left, ply)
    buildAvailable(frame._right, ply)

    frame._weightBar._weight = weight
end

function PD.WB:Menu()
    if IsValid(self.Frame) then
        self.Frame:Remove()
        self.Frame = nil
        return
    end

    local frame = PD.Frame("WAFFENKISTE", PD.W(900), PD.H(650), true)
    self.Frame = frame

    local content = frame:GetContentPanel()

    -- Gewichtsanzeige unten, damit sie beim Scrollen stehen bleibt
    local weightBar = vgui.Create("DPanel", content)
    weightBar:Dock(BOTTOM)
    weightBar:SetTall(PD.H(46))
    weightBar:DockMargin(0, PD.H(10), 0, 0)
    weightBar._weight = 0

    weightBar.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)

        local weight = s._weight or 0
        local fraction = math.Clamp(weight / PD.WB.MaxWeight, 0, 1)

        local barX = PD.W(12)
        local barY = h - PD.H(14)
        local barW = w - PD.W(24)
        local barH = PD.H(6)

        surface.SetDrawColor(PD.Theme.Colors.BackgroundLight)
        surface.DrawRect(barX, barY, barW, barH)

        local color = PD.Theme.Colors.AccentGreen

        if fraction >= 1 then
            color = PD.Theme.Colors.StatusCritical
        elseif fraction >= 0.8 then
            color = PD.Theme.Colors.StatusWarning
        end

        surface.SetDrawColor(color)
        surface.DrawRect(barX, barY, barW * fraction, barH)

        draw.DrawText("TRAGELAST", "MLIB.12", barX, PD.H(6), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
        draw.DrawText(formatWeight(weight) .. " / " .. PD.WB.MaxWeight .. " Kg", "MLIB.14", w - barX, PD.H(5),
            color, TEXT_ALIGN_RIGHT)
    end

    local left = vgui.Create("DPanel", content)
    left:Dock(LEFT)
    left:SetWide(PD.W(400))
    left:DockMargin(0, 0, PD.W(10), 0)
    left.Paint = function() end

    local right = vgui.Create("DPanel", content)
    right:Dock(FILL)
    right.Paint = function() end

    frame._left = left
    frame._right = right
    frame._weightBar = weightBar

    PD.WB:Refresh()
end

-- Der Server stößt nach jedem Give/Strip an. Die Waffenliste des Spielers kommt
-- beim Client leicht verzögert an, deshalb der kurze Nachlauf.
net.Receive("PD.WB:Refresh", function()
    timer.Simple(0.1, function()
        PD.WB:Refresh()
    end)
end)

-- Kategorien, Gewichte und Tragelast kommen aus der Datenbank. Ohne diese
-- Übernahme würde der Client mit den Startwerten aus sh_waffenkiste.lua rechnen
-- und andere Ergebnisse anzeigen, als der Server zulässt.
net.Receive("PD.WB:Config", function()
    PD.WB.ApplyConfig(net.ReadTable())

    if IsValid(PD.WB.Frame) then
        PD.WB:Refresh()
    end
end)

concommand.Add("pd_waffenkiste_print", function()
    local ply = LocalPlayer()

    print("Erlaubte Klassen:")
    PrintTable(PD.WB.GetAllowedClasses(ply))

    print("Nach Kategorie:")
    PrintTable(PD.WB.GetAvailableByCategory(ply))

    print("Getragen:")
    PrintTable(PD.WB.GetCarried(ply))

    print("Gewicht: " .. PD.WB.GetCarriedWeight(ply) .. " / " .. PD.WB.MaxWeight)
end)
