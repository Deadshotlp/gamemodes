PD = PD or {}
PD.Armor = PD.Armor or {}

PD.Armor.Entry = {
    Name = "Rüstung",
    Description = "Eine Rüstung, die den Spieler schützt.",
    Model = "models/props_c17/BriefCase001a.mdl",
    ArmorValue = 50,
    SpeedModifier = 0.9,
}

function PD.Armor:Menu(panel)
    if not IsValid(panel) then return end
    panel:Clear()

    net.Start("PD.Armor.RequestData")
    net.SendToServer()

    -- Header
    local header = vgui.Create("DPanel", panel)
    header:Dock(TOP)
    header:SetTall(PD.H(50))
    header:DockMargin(0, 0, 0, PD.H(10))
    header.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        
        -- Linke Akzentlinie
        surface.SetDrawColor(PD.Theme.Colors.AccentBlue)
        surface.DrawRect(0, 0, PD.W(4), h)
        
        -- Obere/Untere Linie
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(PD.W(4), 0, w - PD.W(4), 1)
        surface.DrawRect(PD.W(4), h - 1, w - PD.W(4), 1)
        
        -- Titel
        draw.DrawText("RÜSTUNGS SYSTEM", "MLIB.18", PD.W(20), h / 2 - PD.H(9), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
    end

    -- Linke Spalte (Liste)
    local left = vgui.Create("DPanel", panel)
    left:Dock(LEFT)
    left:SetWide(PD.W(200))
    left.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(w - 1, 0, 1, h)
    end

    -- Rechte Spalte (Editor)
    local right = vgui.Create("DPanel", panel)
    right:Dock(FILL)
    right:DockMargin(PD.W(10), 0, 0, 0)
    right.Paint = function() end

    local armor_listScroll = PD.Scroll(left)
    local armor_list = {}
    local selected_armor = nil

    local function RefreshArmorList()
        armor_listScroll:Clear()

        for i, armor in ipairs(armor_list) do
            local item = PD.Button(armor.Name or "Neuer Eintrag", armor_listScroll, function()
                selected_armor = i

                -- Clear right panel
                right:Clear()

                -- Name
                local name_label = PD.Label("Name:", right)
                local name_entry = PD.TextEntry(right, "Rüstungsname...", armor.Name or "", function(val)
                    armor.Name = val
                end)

                -- Description
                local desc_label = PD.Label("Beschreibung:", right)
                local desc_entry = PD.TextEntry(right, "Beschreibung eingeben...", armor.Description or "", function(val)
                    armor.Description = val
                end)

                -- Model
                local model_label = PD.Label("Modell:", right)
                local model_entry = PD.TextEntry(right, "Model-Pfad...", armor.Model or "", function(val)
                    armor.Model = val
                end)

                -- Armor Value
                local armor_label = PD.Label("Rüstungswert (0 = 0% Schaden, 100 = 100% Schaden):", right)
                local armor_slider = PD.Slider(right, "Rüstungswert", 0, 100, armor.ArmorValue or 50, function(val)
                    armor.ArmorValue = val
                end)

                -- Save Button
                local save_btn = PD.Button("Speichern", right, function()
                    net.Start("PD.Armor.UpdateData")
                    net.WriteTable(armor_list)
                    net.SendToServer()

                    RefreshArmorList()
                    right:Clear()
                    selected_armor = nil
                end)
                save_btn:Dock(BOTTOM)
                save_btn:SetFont("MLIB.14")

                -- Delete Button
                local delete_btn = PD.Button("Löschen", right, function()
                    table.remove(armor_list, i)

                    -- Gleich an den Server geben. Vorher verschwand der Eintrag
                    -- nur hier im Menü - gespeichert wurde erst beim nächsten
                    -- "Speichern", und ohne das kam er beim Öffnen zurück.
                    net.Start("PD.Armor.UpdateData")
                    net.WriteTable(armor_list)
                    net.SendToServer()

                    RefreshArmorList()
                    right:Clear()
                    selected_armor = nil
                end)
                delete_btn:Dock(BOTTOM)
                delete_btn:SetFont("MLIB.14")
            end)

            item:Dock(TOP)
            if selected_armor == i then
                item:SetActive(true)
            end
        end
    end

    local function CreateArmorEntry()
        if not armor_list then
            armor_list = {}
        end

        local new_item = {
            Name = "Neue Rüstung",
            Description = "Eine neue Rüstung...",
            Model = "models/props_c17/BriefCase001a.mdl",
            ArmorValue = 50,
        }

        table.insert(armor_list, new_item)

        selected_armor = #armor_list
        RefreshArmorList()
    end

    local armor_createBtn = PD.Button("Eintrag Anlegen", left, function()
        CreateArmorEntry()
    end)
    armor_createBtn:Dock(BOTTOM)

    net.Receive("PD.Armor.RequestData", function()
        local data = net.ReadTable()
        armor_list = data or {}

        RefreshArmorList()
    end)
    
    RefreshArmorList()
end