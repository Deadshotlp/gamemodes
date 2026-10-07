PD.FB = PD.FB or {}

-- Arbeitskopie der gerade bearbeiteten Fortbildung. Erst beim Speichern geht sie
-- an den Server, damit ein abgebrochener Edit nichts anfasst.
local editing = nil
local editingKey = nil
local adminView = "catalog"
local grantTarget = nil
local grantData = {}

local rebuildAdmin = function() end

net.Receive("PD.FB.AdminGrants", function()
    local charID = net.ReadString()

    grantData[charID] = net.ReadTable()
    rebuildAdmin()
end)

--------------------------------------------------------------------------------
-- Quellen für die Auswahllisten
--------------------------------------------------------------------------------

local function getWeaponList()
    local list = {}

    for _, wep in ipairs(weapons.GetList()) do
        if wep.ClassName and wep.ClassName ~= "" then
            table.insert(list, {value = wep.ClassName, label = wep.ClassName})
        end
    end

    table.sort(list, function(a, b) return a.label < b.label end)

    return list
end

local function getModelList()
    local list = {}

    for name, path in pairs(player_manager.AllValidModels() or {}) do
        table.insert(list, {value = path, label = name})
    end

    table.sort(list, function(a, b) return a.label < b.label end)

    return list
end

-- Der Job-Baum wird direkt durchlaufen: die Client-Getter PD.JOBS.GetSubUnit und
-- GetJob keyen ihre Rückgabe auf den Anzeigenamen, wir brauchen hier aber Keys.
local function getFactionLists()
    local units, subunits, jobs = {}, {}, {}

    for unitKey, unit in pairs(PD.JOBS.GetUnit(false, true) or {}) do
        table.insert(units, {value = unitKey, label = unit.name or unitKey})

        for subKey, subunit in pairs(unit.subunits or {}) do
            table.insert(subunits, {value = subKey, label = (unit.name or unitKey) .. " | " .. (subunit.name or subKey)})

            for jobKey, job in pairs(subunit.jobs or {}) do
                table.insert(jobs, {value = jobKey, label = (subunit.name or subKey) .. " | " .. (job.name or jobKey)})
            end
        end
    end

    local function sorter(a, b) return a.label < b.label end

    table.sort(units, sorter)
    table.sort(subunits, sorter)
    table.sort(jobs, sorter)

    return units, subunits, jobs
end

local function getCourseList(excludeKey)
    local list = {}

    for _, course in ipairs(PD.FB.GetSortedCourses()) do
        if course.fb_key ~= excludeKey then
            table.insert(list, {value = course.fb_key, label = course.name})
        end
    end

    return list
end

--------------------------------------------------------------------------------
-- Bausteine
--------------------------------------------------------------------------------

local function sectionHeader(parent, text)
    local header = vgui.Create("DPanel", parent)
    header:Dock(TOP)
    header:SetTall(PD.H(30))
    header:DockMargin(0, PD.H(10), 0, PD.H(6))

    header.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
        surface.DrawRect(0, 0, PD.W(3), h)
        draw.DrawText(text, "MLIB.14", PD.W(12), h / 2 - PD.H(7), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
    end

    return header
end

local function labeledEntry(parent, label, value, onChange)
    local wrap = vgui.Create("DPanel", parent)
    wrap:Dock(TOP)
    wrap:SetTall(PD.H(62))
    wrap:DockMargin(0, 0, 0, PD.H(4))
    wrap.Paint = function() end

    local lbl = PD.Label(label, wrap, {height = PD.H(18), font = "MLIB.12", color = PD.Theme.Colors.TextDim})
    lbl:Dock(TOP)

    local entry = PD.TextEntry(wrap, "", tostring(value or ""), nil, {height = PD.H(34)})
    entry:Dock(TOP)
    entry.OnChange = function(self)
        onChange(self:GetValue())
    end

    return entry
end

-- Zwei-Spalten-Auswahl. isSet = true behandelt "selected" als Map key->true,
-- sonst als Array. Beide Formen kommen im Datenmodell vor.
local function transferSection(parent, title, source, selected, isSet, height)
    sectionHeader(parent, title)

    local wrap = vgui.Create("DPanel", parent)
    wrap:Dock(TOP)
    wrap:SetTall(height or PD.H(220))
    wrap:DockMargin(0, 0, 0, PD.H(6))
    wrap.Paint = function() end

    local function isSelected(value)
        if isSet then
            return selected[value] == true
        end

        return table.HasValue(selected, value)
    end

    local function add(value)
        if isSelected(value) then return end

        if isSet then
            selected[value] = true
        else
            table.insert(selected, value)
        end
    end

    local function remove(value)
        if isSet then
            selected[value] = nil
        else
            table.RemoveByValue(selected, value)
        end
    end

    local leftPanel = vgui.Create("DPanel", wrap)
    leftPanel:Dock(LEFT)
    leftPanel:SetWide(PD.W(300))
    leftPanel:DockMargin(0, 0, PD.W(8), 0)
    leftPanel.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
    end

    local rightPanel = vgui.Create("DPanel", wrap)
    rightPanel:Dock(FILL)
    rightPanel.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
    end

    local search = PD.TextEntry(leftPanel, "Suchen...", "", nil, {height = PD.H(30)})
    search:Dock(TOP)

    local availableScroll = PD.Scroll(leftPanel)
    local selectedScroll = PD.Scroll(rightPanel)

    local refresh

    local function buildAvailable()
        availableScroll:GetCanvas():Clear()

        local filter = string.lower(search:GetValue() or "")
        local shown = 0

        for _, item in ipairs(source) do
            if not isSelected(item.value) and shown < 200 then
                if filter == "" or string.find(string.lower(item.label), filter, 1, true) then
                    shown = shown + 1

                    local btn = PD.Button(item.label, availableScroll, function()
                        add(item.value)
                        refresh()
                    end, {height = PD.H(28), font = "MLIB.12"})
                    btn:Dock(TOP)
                    btn:SetAccentColor(PD.Theme.Colors.AccentBlue)
                end
            end
        end
    end

    local function buildSelected()
        selectedScroll:GetCanvas():Clear()

        local labels = {}

        for _, item in ipairs(source) do
            labels[item.value] = item.label
        end

        local function addRow(value)
            local btn = PD.Button(labels[value] or value, selectedScroll, function()
                remove(value)
                refresh()
            end, {height = PD.H(28), font = "MLIB.12"})
            btn:Dock(TOP)
            btn:SetAccentColor(PD.Theme.Colors.AccentGreen)
        end

        if isSet then
            for value in SortedPairs(selected) do
                addRow(value)
            end
        else
            for _, value in ipairs(selected) do
                addRow(value)
            end
        end
    end

    refresh = function()
        buildAvailable()
        buildSelected()
    end

    search.OnChange = function()
        buildAvailable()
    end

    refresh()
end

--------------------------------------------------------------------------------
-- Abzeichen-Editor
--------------------------------------------------------------------------------

local function badgeSection(parent, badge)
    sectionHeader(parent, "ABZEICHEN (BODYGROUP / SKIN)")

    local hint = PD.Label("Bodygroup-Indizes sind modellabhängig. \"*\" gilt für jedes Model.", parent, {
        height = PD.H(20),
        font = "MLIB.12",
        color = PD.Theme.Colors.TextMuted
    })
    hint:Dock(TOP)

    -- Kleines Icon der Fortbildung (Vorschau rechts)
    local iconEntry = labeledEntry(parent, "Icon (Material, z. B. icon16/star.png; leer = keins)", badge.icon or "", function(value)
        value = string.Trim(value)
        badge.icon = value ~= "" and value or nil
    end)
    iconEntry.PaintOver = function(s, w, h)
        PD.FB.DrawIcon({badge = badge}, w - h + 4, 4, h - 8)
    end

    local skinEntry = labeledEntry(parent, "Skin (leer = unverändert)", badge.skin ~= nil and badge.skin or "", function(value)
        if value == "" then
            badge.skin = nil
        else
            badge.skin = tonumber(value) or nil
        end
    end)

    local list = vgui.Create("DPanel", parent)
    list:Dock(TOP)
    list:SetTall(PD.H(160))
    list:DockMargin(0, 0, 0, PD.H(6))
    list.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
    end

    local scroll = PD.Scroll(list)

    local rebuild

    rebuild = function()
        scroll:GetCanvas():Clear()

        if #badge.bodygroups == 0 then
            local lbl = PD.Label("Keine Bodygroup gesetzt.", scroll, {
                height = PD.H(26),
                font = "MLIB.12",
                color = PD.Theme.Colors.TextMuted,
                align = 5
            })
            lbl:Dock(TOP)
        end

        for i, entry in ipairs(badge.bodygroups) do
            local row = vgui.Create("DPanel", scroll)
            row:Dock(TOP)
            row:SetTall(PD.H(34))
            row:DockMargin(0, 0, 0, PD.H(4))
            row.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
            end

            local removeBtn = PD.Button("X", row, function()
                table.remove(badge.bodygroups, i)
                rebuild()
            end, {height = PD.H(26), font = "MLIB.12"})
            removeBtn:Dock(RIGHT)
            removeBtn:SetWide(PD.W(40))
            removeBtn:DockMargin(0, PD.H(4), PD.W(4), PD.H(4))
            removeBtn:SetAccentColor(PD.Theme.Colors.AccentRed)

            local valueEntry = PD.TextEntry(row, "Wert", tostring(entry.value or 0), nil, {height = PD.H(26), dock = RIGHT})
            valueEntry:Dock(RIGHT)
            valueEntry:SetWide(PD.W(70))
            valueEntry:DockMargin(0, PD.H(4), PD.W(4), PD.H(4))
            valueEntry.OnChange = function(self)
                entry.value = tonumber(self:GetValue()) or 0
            end

            local indexEntry = PD.TextEntry(row, "Index", tostring(entry.index or 0), nil, {height = PD.H(26), dock = RIGHT})
            indexEntry:Dock(RIGHT)
            indexEntry:SetWide(PD.W(70))
            indexEntry:DockMargin(0, PD.H(4), PD.W(4), PD.H(4))
            indexEntry.OnChange = function(self)
                entry.index = tonumber(self:GetValue()) or 0
            end

            local modelEntry = PD.TextEntry(row, "Model oder *", tostring(entry.model or PD.FB.AnyModel), nil, {height = PD.H(26)})
            modelEntry:Dock(FILL)
            modelEntry:DockMargin(PD.W(4), PD.H(4), PD.W(4), PD.H(4))
            modelEntry.OnChange = function(self)
                entry.model = self:GetValue()
            end
        end
    end

    local addBtn = PD.Button("Bodygroup hinzufügen", parent, function()
        table.insert(badge.bodygroups, {model = PD.FB.AnyModel, index = 0, value = 1})
        rebuild()
    end, {height = PD.H(32)})
    addBtn:Dock(TOP)
    addBtn:SetAccentColor(PD.Theme.Colors.AccentBlue)

    rebuild()
end

--------------------------------------------------------------------------------
-- Editor
--------------------------------------------------------------------------------

local function buildEditor(parent)
    parent:Clear()

    if not editing then
        local lbl = PD.Label("Links eine Fortbildung wählen oder eine neue anlegen.", parent, {
            height = PD.H(40),
            color = PD.Theme.Colors.TextMuted,
            align = 5
        })
        lbl:Dock(TOP)
        return
    end

    local scroll = PD.Scroll(parent)

    sectionHeader(scroll, "GRUNDDATEN")

    labeledEntry(scroll, "Name", editing.name, function(value) editing.name = value end)
    labeledEntry(scroll, "Beschreibung", editing.description, function(value) editing.description = value end)
    labeledEntry(scroll, "Sortierposition (kleiner = weiter oben, entscheidet auch bei Abzeichen-Kollisionen)",
        editing.position, function(value) editing.position = tonumber(value) or 0 end)
    labeledEntry(scroll, "Gültigkeit in Tagen (0 = dauerhaft)", editing.duration_days,
        function(value) editing.duration_days = tonumber(value) or 0 end)
    labeledEntry(scroll, "Maximale Inhaber (0 = unbegrenzt)", editing.max_holders,
        function(value) editing.max_holders = tonumber(value) or 0 end)

    sectionHeader(scroll, "FARBE")

    local mixer = vgui.Create("DColorMixer", scroll)
    mixer:Dock(TOP)
    mixer:SetTall(PD.H(140))
    mixer:DockMargin(0, 0, 0, PD.H(6))
    mixer:SetPalette(false)
    mixer:SetAlphaBar(false)
    mixer:SetWangs(true)
    mixer:SetColor(PD.FB.ToColor(editing.color, Color(60, 140, 60)))
    mixer.ValueChanged = function(s, col)
        editing.color = Color(col.r, col.g, col.b, 255)
    end

    local units, subunits, jobs = getFactionLists()

    transferSection(scroll, "AUSRÜSTUNG (WAFFEN)", getWeaponList(), editing.equip, false)
    transferSection(scroll, "PLAYERMODELS", getModelList(), editing.model, false)

    badgeSection(scroll, editing.badge)

    transferSection(scroll, "ZUGANG: EINHEITEN", units, editing.access.units, true, PD.H(180))
    transferSection(scroll, "ZUGANG: UNTEREINHEITEN", subunits, editing.access.subunits, true, PD.H(180))
    transferSection(scroll, "ZUGANG: JOBS", jobs, editing.access.jobs, true, PD.H(180))

    local hint = PD.Label("Sind alle drei Zugangslisten leer, ist die Fortbildung für jeden freigegeben.", scroll, {
        height = PD.H(20),
        font = "MLIB.12",
        color = PD.Theme.Colors.TextMuted
    })
    hint:Dock(TOP)

    transferSection(scroll, "INHABER DARF AUSBILDEN", getCourseList(editingKey), editing.teach, false, PD.H(160))
    transferSection(scroll, "VORAUSSETZUNGEN", getCourseList(editingKey), editing.requires, false, PD.H(160))

    local actions = vgui.Create("DPanel", scroll)
    actions:Dock(TOP)
    actions:SetTall(PD.H(50))
    actions:DockMargin(0, PD.H(10), 0, PD.H(10))
    actions.Paint = function() end

    local saveBtn = PD.Button("Speichern", actions, function()
        if editingKey then
            net.Start("PD.FB.Admin")
                net.WriteString("update")
                net.WriteString(editingKey)
                net.WriteTable(editing)
            net.SendToServer()
        else
            net.Start("PD.FB.Admin")
                net.WriteString("create")
                net.WriteTable(editing)
            net.SendToServer()
        end

        PD.Popup("Fortbildung gespeichert.", PD.Theme.Colors.AccentGreen)
    end)
    saveBtn:Dock(LEFT)
    saveBtn:SetWide(PD.W(200))
    saveBtn:SetAccentColor(PD.Theme.Colors.AccentGreen)

    if editingKey then
        local deleteBtn = PD.Button("Löschen", actions, function()
            Derma_Query("Fortbildung '" .. editing.name .. "' wirklich löschen? Alle Vergaben gehen verloren.",
                "Fortbildung löschen",
                "Löschen", function()
                    net.Start("PD.FB.Admin")
                        net.WriteString("delete")
                        net.WriteString(editingKey)
                    net.SendToServer()

                    editing = nil
                    editingKey = nil
                    rebuildAdmin()
                end,
                "Abbrechen", function() end)
        end)
        deleteBtn:Dock(LEFT)
        deleteBtn:SetWide(PD.W(160))
        deleteBtn:SetAccentColor(PD.Theme.Colors.AccentRed)
    end
end

--------------------------------------------------------------------------------
-- Vergabe-Ansicht (Admin-Override)
--------------------------------------------------------------------------------

local function buildGrantView(parent)
    parent:Clear()

    sectionHeader(parent, "FORTBILDUNGEN VERGEBEN UND ENTZIEHEN")

    local hint = PD.Label("Die Vergabe hier übergeht die Zugangsbeschränkung bewusst.", parent, {
        height = PD.H(20),
        font = "MLIB.12",
        color = PD.Theme.Colors.TextMuted
    })
    hint:Dock(TOP)

    local playerDropdown = PD.Dropdown(parent, grantTarget and IsValid(grantTarget) and grantTarget:Nick() or "Spieler wählen...", function(text, data)
        grantTarget = data

        local charID = PD.FB.GetCharID(data)

        if charID then
            net.Start("PD.FB.AdminGrants")
                net.WriteString(charID)
            net.SendToServer()
        end
    end)
    playerDropdown:Dock(TOP)

    for _, ply in ipairs(player.GetAll()) do
        if PD.FB.GetCharID(ply) then
            playerDropdown:AddOption(ply:Nick(), ply)
        end
    end

    local scroll = PD.Scroll(parent)

    if not IsValid(grantTarget) then
        local lbl = PD.Label("Zuerst einen Spieler wählen.", scroll, {
            height = PD.H(30),
            color = PD.Theme.Colors.TextMuted,
            align = 5
        })
        lbl:Dock(TOP)
        return
    end

    local charID = PD.FB.GetCharID(grantTarget)
    local granted = grantData[charID] or {}

    for _, course in ipairs(PD.FB.GetSortedCourses()) do
        local entry = granted[course.fb_key]
        local has = entry ~= nil and not PD.FB.IsExpired(entry)

        local row = vgui.Create("DPanel", scroll)
        row:Dock(TOP)
        row:SetTall(PD.H(44))
        row:DockMargin(0, 0, 0, PD.H(4))

        row.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
            surface.SetDrawColor(has and PD.Theme.Colors.StatusActive or PD.Theme.Colors.AccentGray)
            surface.DrawRect(0, 0, PD.W(3), h)

            local ix = PD.FB.DrawIcon(course, PD.W(15), PD.H(6), PD.H(16))
            draw.DrawText(course.name, "MLIB.14", PD.W(15) + ix, PD.H(6), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
            draw.DrawText(has and PD.FB.FormatRemaining(entry) or "nicht vorhanden", "MLIB.12", PD.W(15), PD.H(24),
                PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
        end

        local key = course.fb_key

        if has then
            local revokeBtn = PD.Button("Entziehen", row, function()
                net.Start("PD.FB.Revoke")
                    net.WriteString(charID)
                    net.WriteString(key)
                net.SendToServer()

                timer.Simple(0.3, function()
                    net.Start("PD.FB.AdminGrants")
                        net.WriteString(charID)
                    net.SendToServer()
                end)
            end)
            revokeBtn:Dock(RIGHT)
            revokeBtn:SetWide(PD.W(140))
            revokeBtn:DockMargin(0, PD.H(5), PD.W(5), PD.H(5))
            revokeBtn:SetAccentColor(PD.Theme.Colors.AccentRed)
        else
            local grantBtn = PD.Button("Vergeben", row, function()
                net.Start("PD.FB.Grant")
                    net.WriteEntity(grantTarget)
                    net.WriteString(key)
                net.SendToServer()

                timer.Simple(0.3, function()
                    net.Start("PD.FB.AdminGrants")
                        net.WriteString(charID)
                    net.SendToServer()
                end)
            end)
            grantBtn:Dock(RIGHT)
            grantBtn:SetWide(PD.W(140))
            grantBtn:DockMargin(0, PD.H(5), PD.W(5), PD.H(5))
            grantBtn:SetAccentColor(PD.Theme.Colors.AccentGreen)
        end
    end
end

--------------------------------------------------------------------------------
-- Hauptansicht
--------------------------------------------------------------------------------

function PD.FB:AdminMenu(panel)
    panel:Clear()

    editing = nil
    editingKey = nil

    local left = vgui.Create("DPanel", panel)
    left:Dock(LEFT)
    left:SetWide(PD.W(300))
    left:DockMargin(0, 0, PD.W(10), 0)
    left.Paint = function() end

    local right = vgui.Create("DPanel", panel)
    right:Dock(FILL)
    right.Paint = function() end

    local listHeader = vgui.Create("DPanel", left)
    listHeader:Dock(TOP)
    listHeader:SetTall(PD.H(34))
    listHeader:DockMargin(0, 0, 0, PD.H(6))
    listHeader.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        draw.DrawText("FORTBILDUNGEN", "MLIB.14", PD.W(12), h / 2 - PD.H(7), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
    end

    local search = PD.TextEntry(left, "Suchen...", "", nil, {height = PD.H(32)})
    search:Dock(TOP)

    local newBtn = PD.Button("Neue Fortbildung", left, function()
        editing = PD.FB.NewCourse()
        editingKey = nil
        adminView = "catalog"
        buildEditor(right)
    end, {height = PD.H(34)})
    newBtn:Dock(TOP)
    newBtn:SetAccentColor(PD.Theme.Colors.AccentGreen)

    local grantBtn = PD.Button("Vergabe verwalten", left, function()
        adminView = "grant"
        buildGrantView(right)
    end, {height = PD.H(34)})
    grantBtn:Dock(TOP)
    grantBtn:SetAccentColor(PD.Theme.Colors.AccentBlue)

    local scroll = PD.Scroll(left)

    local function buildList()
        scroll:GetCanvas():Clear()

        local filter = string.lower(search:GetValue() or "")

        for _, course in ipairs(PD.FB.GetSortedCourses()) do
            if filter == "" or string.find(string.lower(course.name), filter, 1, true) then
                local key = course.fb_key

                local btn = PD.Button(course.name, scroll, function()
                    editing = table.Copy(PD.FB.Courses[key])
                    editingKey = key

                    -- Fehlende Unterstrukturen aus älteren Datensätzen ergänzen
                    editing.badge = editing.badge or {bodygroups = {}}
                    editing.badge.bodygroups = editing.badge.bodygroups or {}
                    editing.access = editing.access or {}
                    editing.access.units = editing.access.units or {}
                    editing.access.subunits = editing.access.subunits or {}
                    editing.access.jobs = editing.access.jobs or {}
                    editing.equip = editing.equip or {}
                    editing.model = editing.model or {}
                    editing.teach = editing.teach or {}
                    editing.requires = editing.requires or {}

                    adminView = "catalog"
                    buildEditor(right)
                end, {height = PD.H(36)})
                btn:Dock(TOP)
                btn:SetAccentColor(PD.FB.ToColor(course.color, PD.Theme.Colors.AccentGray))
            end
        end
    end

    search.OnChange = function()
        buildList()
    end

    rebuildAdmin = function()
        if not IsValid(left) or not IsValid(right) then return end

        buildList()

        if adminView == "grant" then
            buildGrantView(right)
        else
            buildEditor(right)
        end
    end

    buildList()
    buildEditor(right)

    net.Start("PD.FB.SyncCatalog")
    net.SendToServer()
end

PD.Admin:AddTab("fortbildung", "Fortbildungen", function(base)
    PD.FB:AdminMenu(base)
end, PD.Admin.Job_Edit_Whitelist, 60)
