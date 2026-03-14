-- Jobs Admin System - Star Wars Andor Imperial Style (Zentral über PD.Theme)

local selectedUnit, selectedSubunit, selectedJob

timer.Simple(1, function()
    net.Start("PD.JOBS.SyncJobs")
    net.SendToServer()
end)

-- Hilfsfunktion: Imperial Section Header
local function CreateSectionHeader(parent, title, color)
    local header = vgui.Create("DPanel", parent)
    header:Dock(TOP)
    header:SetTall(PD.H(35))
    header:DockMargin(0, PD.H(10), 0, PD.H(5))
    header.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        surface.SetDrawColor(color or PD.Theme.Colors.AccentGray)
        surface.DrawRect(0, 0, PD.W(4), h)
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(PD.W(4), h - 1, w - PD.W(4), 1)
        draw.DrawText(title, "MLIB.14", PD.W(15), h / 2 - PD.H(7), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
    end
    return header
end

local function equip_box(contentPanel, equip, searchString)
    local possible_equip = contentPanel.possibleScroll
    local current_equip = contentPanel.currentScroll
    
    for _, child in pairs(possible_equip:GetCanvas():GetChildren()) do child:Remove() end
    for _, child in pairs(current_equip:GetCanvas():GetChildren()) do child:Remove() end
    
    local weaponList = {}
    for _, v in pairs(weapons.GetList()) do
        local ok = true
        for _, i in ipairs(equip) do
            if i == v.ClassName then ok = false end
        end
        if ok then table.insert(weaponList, v.ClassName) end
    end
    table.sort(weaponList)
    table.sort(equip)
    
    for _, v in ipairs(weaponList) do
        if searchString and searchString ~= "" then
            if not string.find(string.lower(v), string.lower(searchString), 1, true) then
                continue
            end
        end

        local btn = PD.Button(v, possible_equip, function()
            table.insert(equip, v)
            PD.JOBS.EquipSection(contentPanel, equip)
            surface.PlaySound("UI/buttonclick.wav")
        end)
        btn:Dock(TOP)
        btn:SetTall(PD.H(35))
    end
    
    for k, v in ipairs(equip) do
        if searchString and searchString ~= "" then
            if not string.find(string.lower(v), string.lower(searchString), 1, true) then
                continue
            end
        end

        local btn = PD.Button(v, current_equip, function()
            table.remove(equip, k)
            PD.JOBS.EquipSection(contentPanel, equip)
            surface.PlaySound("UI/buttonclick.wav")
        end)
        btn:Dock(TOP)
        btn:SetTall(PD.H(35))
        btn:SetAccentColor(PD.Theme.Colors.StatusActive)
    end
    
    return equip
end

-- Equipment Section mit neuer UI
function PD.JOBS.EquipSection(contentPanel, equip)
    local main_panel = contentPanel.equipPanel
    if not IsValid(main_panel) then
        main_panel = vgui.Create("DPanel", contentPanel)
        contentPanel.equipPanel = main_panel
        main_panel:Dock(TOP)
        main_panel:SetTall(PD.H(300))
        main_panel.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
            surface.SetDrawColor(PD.Theme.Colors.AccentGray)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local equipSearch = PD.TextEntry(main_panel, "Ausrüstung suchen...", "")
        equipSearch:Dock(TOP)
        equipSearch:DockMargin(0, 0, 0, PD.H(10))
        equipSearch.OnChange = function(self)
            equip_box(contentPanel, equip, equipSearch:GetValue() or nil)
        end
        
        -- Linkes Panel (Verfügbar)
        local panel1 = vgui.Create("DPanel", main_panel)
        panel1:Dock(LEFT)
        panel1:SetWide(PD.W(350))
        panel1.Paint = function(s, w, h)
            draw.DrawText("VERFÜGBAR", "MLIB.10", w / 2, PD.H(5), PD.Theme.Colors.AccentGray, TEXT_ALIGN_CENTER)
        end
        
        -- Rechtes Panel (Zugewiesen)
        local panel2 = vgui.Create("DPanel", main_panel)
        panel2:Dock(FILL)
        panel2.Paint = function(s, w, h)
            draw.DrawText("ZUGEWIESEN", "MLIB.10", w / 2, PD.H(5), PD.Theme.Colors.StatusActive, TEXT_ALIGN_CENTER)
            surface.SetDrawColor(PD.Theme.Colors.AccentGray)
            surface.DrawRect(0, 0, 1, h)
        end
    
        contentPanel.possibleScroll = PD.Scroll(panel1)
        contentPanel.possibleScroll:DockMargin(0, PD.H(20), 0, 0)
        contentPanel.currentScroll = PD.Scroll(panel2)
        contentPanel.currentScroll:DockMargin(0, PD.H(20), 0, 0)
    end

    equip_box(contentPanel, equip, nil)
    
    return equip
end

local function model_box(contentPanel, models, searchString)
    local possible_sc = contentPanel.possibleModelScroll
    local current_sc = contentPanel.currentModelScroll
    
    for _, child in pairs(possible_sc:GetCanvas():GetChildren()) do child:Remove() end
    for _, child in pairs(current_sc:GetCanvas():GetChildren()) do child:Remove() end
    table.sort(models)
    PrintTable(models)

    for m, _ in pairs(player_manager.AllValidModels()) do
        if searchString and searchString ~= "" then
            if not string.find(string.lower(_), string.lower(searchString), 1, true) then
                continue
            end
        end

        if not table.HasValue(models, m) then
            local btn = PD.Button(m, possible_sc, function()
                table.insert(models, _)
                PD.JOBS.ModelSection(contentPanel, models)
                surface.PlaySound("UI/buttonclick.wav")
            end)
            btn:Dock(TOP)
            btn:SetTall(PD.H(35))
        end
    end
    
    for i, m in ipairs(models) do
        if searchString and searchString ~= "" then
            if not string.find(string.lower(m), string.lower(searchString), 1, true) then
                continue
            end
        end

        local btn = PD.Button(m, current_sc, function()
            table.remove(models, i)
            PD.JOBS.ModelSection(contentPanel, models)
            surface.PlaySound("UI/buttonclick.wav")
        end)
        btn:Dock(TOP)
        btn:SetTall(PD.H(35))
        btn:SetAccentColor(PD.Theme.Colors.StatusActive)
    end

    return models
end

-- Model Section mit neuer UI
function PD.JOBS.ModelSection(contentPanel, models)
    local main_panel = contentPanel.modelPanel
    if not IsValid(main_panel) then
        main_panel = vgui.Create("DPanel", contentPanel)
        contentPanel.modelPanel = main_panel
        main_panel:Dock(TOP)
        main_panel:SetTall(PD.H(300))
        main_panel.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
            surface.SetDrawColor(PD.Theme.Colors.AccentGray)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end

        local modelSearch = PD.TextEntry(main_panel, "Model suchen...", "")
        modelSearch:Dock(TOP)
        modelSearch:DockMargin(0, 0, 0, PD.H(10))
        modelSearch.OnChange = function(self)
            model_box(contentPanel, models, modelSearch:GetValue() or nil)
        end
        
        local panel1 = vgui.Create("DPanel", main_panel)
        panel1:Dock(LEFT)
        panel1:SetWide(PD.W(350))
        panel1.Paint = function(s, w, h)
            draw.DrawText("VERFÜGBAR", "MLIB.10", w / 2, PD.H(5), PD.Theme.Colors.AccentGray, TEXT_ALIGN_CENTER)
        end
        
        local panel2 = vgui.Create("DPanel", main_panel)
        panel2:Dock(FILL)
        panel2.Paint = function(s, w, h)
            draw.DrawText("ZUGEWIESEN", "MLIB.10", w / 2, PD.H(5), PD.Theme.Colors.StatusActive, TEXT_ALIGN_CENTER)
            surface.SetDrawColor(PD.Theme.Colors.AccentGray)
            surface.DrawRect(0, 0, 1, h)
        end
        
        contentPanel.possibleModelScroll = PD.Scroll(panel1)
        contentPanel.possibleModelScroll:DockMargin(0, PD.H(20), 0, 0)
        contentPanel.currentModelScroll = PD.Scroll(panel2)
        contentPanel.currentModelScroll:DockMargin(0, PD.H(20), 0, 0)
    end
    
    model_box(contentPanel, models, nil)
    
    return models
end

-- Units/SubUnits/Jobs Liste
local function UnitsETC(panel, search, onSelect)
    if not IsValid(panel) then return end
    
    for _, child in pairs(panel:GetCanvas():GetChildren()) do child:Remove() end
    
    local q = search and string.lower(string.Trim(search)) or ""
    local function match(line)
        if q == "" then return true end
        return string.find(string.lower(line or ""), q, 1, true) ~= nil
    end
    
    for unitName, unit in SortedPairs(PD.JOBS.Jobs or {}) do
        if match(unitName) then
            local unitBtn = PD.Button(unitName, panel, function()
                if onSelect then onSelect("unit", unitName) end
            end)
            unitBtn:Dock(TOP)
            unitBtn:SetTall(PD.H(40))
            unitBtn:SetAccentColor(unit.color or PD.Theme.Colors.AccentGray)
        end

        if selectedUnit ~= unitName and search == "" then continue end
        
        for subName, sub in SortedPairs(unit.subunits or {}) do
            if match(unitName .. " " .. subName) then
                local subBtn = PD.Button("  ├ " .. subName, panel, function()
                    if onSelect then onSelect("subunit", unitName, subName) end
                end)
                subBtn:Dock(TOP)
                subBtn:SetTall(PD.H(35))
                subBtn:DockMargin(PD.W(15), 0, 0, 0)
            end

            if selectedSubunit ~= subName and search == "" then continue end
            
            for jobName, job in SortedPairs(sub.jobs or {}) do
                if match(unitName .. " " .. subName .. " " .. jobName) then
                    local jobBtn = PD.Button("     └ " .. jobName, panel, function()
                        if onSelect then onSelect("job", unitName, subName, jobName) end
                    end)
                    jobBtn:Dock(TOP)
                    jobBtn:SetTall(PD.H(32))
                    jobBtn:DockMargin(PD.W(30), 0, 0, 0)
                end
            end
        end
    end
end

-- Unit Editor
function PD.JOBS.OpenUnitEditor(parent, unitName)
    if not IsValid(parent) then return end
    local unit = PD.JOBS.Jobs and PD.JOBS.Jobs[unitName]
    if not unit then return end
    
    parent:Clear()
    
    CreateSectionHeader(parent, "UNIT BEARBEITEN: " .. unitName, unit.color)
    
    local scroll = PD.Scroll(parent)
    
    -- Name
    local nameLabel = vgui.Create("DLabel", scroll)
    nameLabel:Dock(TOP)
    nameLabel:SetText("NAME")
    nameLabel:SetFont("MLIB.12")
    nameLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    nameLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))
    
    local name = PD.TextEntry(scroll, "Unit Name", unitName)
    name:Dock(TOP)
    name:SetTall(PD.H(40))
    
    -- Farbe
    local colorVal = unit.color or Color(255, 255, 255)
    local pickedColor = colorVal
    
    local colorLabel = vgui.Create("DLabel", scroll)
    colorLabel:Dock(TOP)
    colorLabel:SetText("FARBE")
    colorLabel:SetFont("MLIB.12")
    colorLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    colorLabel:DockMargin(PD.W(5), PD.H(15), 0, PD.H(3))
    
    local colorPicker = vgui.Create("DColorMixer", scroll)
    colorPicker:Dock(TOP)
    colorPicker:SetTall(PD.H(150))
    colorPicker:SetColor(colorVal)
    colorPicker:SetAlphaBar(false)
    colorPicker.ValueChanged = function(s, col)
        pickedColor = col
    end
    
    -- Buttons
    local save = PD.Button("Speichern", scroll, function()
        local data = { old = unitName, new = name:GetValue(), color = pickedColor }
        net.Start("PD.JOBS.unit_update")
        net.WriteTable(data)
        net.SendToServer()
        surface.PlaySound("buttons/button14.wav")
    end)
    save:Dock(TOP)
    save:SetTall(PD.H(45))
    save:DockMargin(0, PD.H(15), 0, 0)
    save:SetAccentColor(PD.Theme.Colors.StatusActive)
    
    local del = PD.Button("Löschen", scroll, function()
        local data = { name = unitName }
        net.Start("PD.JOBS.unit_delete")
        net.WriteTable(data)
        net.SendToServer()
        surface.PlaySound("buttons/button14.wav")
    end)
    del:Dock(TOP)
    del:SetTall(PD.H(45))
    del:SetAccentColor(PD.Theme.Colors.StatusCritical)
end

-- SubUnit Editor
function PD.JOBS.OpenSubunitEditor(parent, unitName, subName)
    if not IsValid(parent) then return end
    local unit = PD.JOBS.Jobs and PD.JOBS.Jobs[unitName]
    if not unit then return end
    local sub = unit.subunits and unit.subunits[subName]
    if not sub then return end
    
    parent:Clear()
    
    CreateSectionHeader(parent, "SUBUNIT BEARBEITEN: " .. subName, unit.color)
    
    local scroll = PD.Scroll(parent)
    
    -- Name
    local nameLabel = vgui.Create("DLabel", scroll)
    nameLabel:Dock(TOP)
    nameLabel:SetText("NAME")
    nameLabel:SetFont("MLIB.12")
    nameLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    nameLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))
    
    local name = PD.TextEntry(scroll, "SubUnit Name", subName)
    name:Dock(TOP)
    name:SetTall(PD.H(40))
    
    -- Unit Auswahl
    local currentUnit = unitName
    
    local unitLabel = vgui.Create("DLabel", scroll)
    unitLabel:Dock(TOP)
    unitLabel:SetText("ÜBERGEORDNETE UNIT")
    unitLabel:SetFont("MLIB.12")
    unitLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    unitLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))
    
    local unitBox = PD.Dropdown(scroll, unitName, function(v) currentUnit = v end)
    unitBox:Dock(TOP)
    unitBox:SetTall(PD.H(40))
    for k, _ in SortedPairs(PD.JOBS.Jobs or {}) do unitBox:AddOption(k) end
    
    -- Einstellungen
    local pickedColor = sub.color or Color(255, 255, 255)
    local maxmembers = sub.maxmambers or sub.maxmembers or 10
    local ismedic = sub.ismedic or false
    local isleo = sub.isleo or false
    local isengineer = sub.isengineer or false
    
    local maxLabel = vgui.Create("DLabel", scroll)
    maxLabel:Dock(TOP)
    maxLabel:SetText("MAX MITGLIEDER: " .. maxmembers)
    maxLabel:SetFont("MLIB.12")
    maxLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    maxLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))
    
    local maxSlider = PD.Slider(scroll, "Max Mitglieder", 0, 100, maxmembers, function(v)
        maxmembers = v
        maxLabel:SetText("MAX MITGLIEDER: " .. math.Round(v))
    end)
    maxSlider:Dock(TOP)
    
    -- Checkboxen
    local medicCheck = PD.Checkbox(scroll, "Ist Medic-Einheit", ismedic, function(v) ismedic = v end)
    local leoCheck = PD.Checkbox(scroll, "Ist Law Enforcement", isleo, function(v) isleo = v end)
    local engCheck = PD.Checkbox(scroll, "Ist Engineer-Einheit", isengineer, function(v) isengineer = v end)
    
    -- Equipment
    CreateSectionHeader(scroll, "AUSRÜSTUNG", PD.Theme.Colors.AccentBlue)
    
    local equip = table.Copy(sub.equip or {})
    local equipWrap = vgui.Create("DPanel", scroll)
    equipWrap:Dock(TOP)
    equipWrap:SetTall(PD.H(320))
    equipWrap.Paint = function() end
    PD.JOBS.EquipSection(equipWrap, equip)
    
    -- Buttons
    local save = PD.Button("Speichern", scroll, function()
        local data = {
            unit = currentUnit,
            old = subName,
            new = name:GetValue(),
            color = pickedColor,
            maxmembers = maxmembers,
            ismedic = ismedic,
            isleo = isleo,
            isengineer = isengineer,
            equip = equip
        }
        net.Start("PD.JOBS.subunit_update")
        net.WriteTable(data)
        net.SendToServer()
        surface.PlaySound("buttons/button14.wav")
    end)
    save:Dock(TOP)
    save:SetTall(PD.H(45))
    save:DockMargin(0, PD.H(15), 0, 0)
    save:SetAccentColor(PD.Theme.Colors.StatusActive)
    
    local del = PD.Button("Löschen", scroll, function()
        local data = { unit = currentUnit, name = subName }
        net.Start("PD.JOBS.subunit_delete")
        net.WriteTable(data)
        net.SendToServer()
        surface.PlaySound("buttons/button14.wav")
    end)
    del:Dock(TOP)
    del:SetTall(PD.H(45))
    del:SetAccentColor(PD.Theme.Colors.StatusCritical)
end

-- Job Editor
function PD.JOBS.OpenJobEditor(parent, unitName, subName, jobName)
    if not IsValid(parent) then return end
    local unit = PD.JOBS.Jobs and PD.JOBS.Jobs[unitName]
    if not unit then return end
    local sub = unit.subunits and unit.subunits[subName]
    if not sub then return end
    local job = sub.jobs and sub.jobs[jobName]
    if not job then return end
    
    parent:Clear()
    
    CreateSectionHeader(parent, "JOB BEARBEITEN: " .. jobName, job.color or unit.color)
    
    local scroll = PD.Scroll(parent)
    
    -- Name
    local nameLabel = vgui.Create("DLabel", scroll)
    nameLabel:Dock(TOP)
    nameLabel:SetText("NAME")
    nameLabel:SetFont("MLIB.12")
    nameLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    nameLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))
    
    local name = PD.TextEntry(scroll, "Job Name", jobName)
    name:Dock(TOP)
    name:SetTall(PD.H(40))
    
    -- Unit/SubUnit Auswahl
    local curUnit, curSub = unitName, subName
    
    local unitLabel = vgui.Create("DLabel", scroll)
    unitLabel:Dock(TOP)
    unitLabel:SetText("UNIT")
    unitLabel:SetFont("MLIB.12")
    unitLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    unitLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))
    
    local unitBox = PD.Dropdown(scroll, unitName, function(v) curUnit = v end)
    unitBox:Dock(TOP)
    unitBox:SetTall(PD.H(40))
    for k, _ in SortedPairs(PD.JOBS.Jobs or {}) do unitBox:AddOption(k) end
    
    local subLabel = vgui.Create("DLabel", scroll)
    subLabel:Dock(TOP)
    subLabel:SetText("SUBUNIT")
    subLabel:SetFont("MLIB.12")
    subLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    subLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))
    
    local subBox = PD.Dropdown(scroll, subName, function(v) curSub = v end)
    subBox:Dock(TOP)
    subBox:SetTall(PD.H(40))
    for k, _ in SortedPairs((PD.JOBS.Jobs[curUnit] and PD.JOBS.Jobs[curUnit].subunits) or {}) do subBox:AddOption(k) end
    
    -- Einstellungen
    local pickedColor = job.color or Color(255, 255, 255)
    local salary = job.salary or 100
    local speed = job.speed or 100
    
    local salarySlider = PD.Slider(scroll, "Gehalt", 0, 10000, salary, function(v) salary = v end)
    salarySlider:Dock(TOP)
    salarySlider:DockMargin(0, PD.H(10), 0, 0)
    
    local speedSlider = PD.Slider(scroll, "Geschwindigkeit", 0, 500, speed, function(v) speed = v end)
    speedSlider:Dock(TOP)
    
    -- Equipment
    CreateSectionHeader(scroll, "AUSRÜSTUNG", PD.Theme.Colors.AccentBlue)
    
    local equip = table.Copy(job.equip or {})
    local equipWrap = vgui.Create("DPanel", scroll)
    equipWrap:Dock(TOP)
    equipWrap:SetTall(PD.H(320))
    equipWrap.Paint = function() end
    PD.JOBS.EquipSection(equipWrap, equip)
    
    -- Models
    CreateSectionHeader(scroll, "MODELS", PD.Theme.Colors.AccentOrange)
    
    local models = table.Copy(job.model or job.models or {})
    local modelWrap = vgui.Create("DPanel", scroll)
    modelWrap:Dock(TOP)
    modelWrap:SetTall(PD.H(320))
    modelWrap.Paint = function() end
    PD.JOBS.ModelSection(modelWrap, models)
    
    -- Buttons
    local save = PD.Button("Speichern", scroll, function()
        local data = {
            sub = subName,
            job = jobName,
            name = name:GetValue(),
            subunit = curSub,
            color = pickedColor,
            salary = salary,
            speed = speed,
            equip = equip,
            model = models,
            default = false,
            id = string.lower(curSub) .. "_" .. string.lower(name:GetValue())
        }
        net.Start("PD.JOBS.job_update")
        net.WriteTable(data)
        net.SendToServer()
        surface.PlaySound("buttons/button14.wav")
    end)
    save:Dock(TOP)
    save:SetTall(PD.H(45))
    save:DockMargin(0, PD.H(15), 0, 0)
    save:SetAccentColor(PD.Theme.Colors.StatusActive)
    
    local del = PD.Button("Löschen", scroll, function()
        local data = { sub = subName, job = jobName }
        net.Start("PD.JOBS.job_delete")
        net.WriteTable(data)
        net.SendToServer()
        surface.PlaySound("buttons/button14.wav")
    end)
    del:Dock(TOP)
    del:SetTall(PD.H(45))
    del:SetAccentColor(PD.Theme.Colors.StatusCritical)
end

-- Hauptmenü
function PD.JOBS.AdminMenu(panel)
    if not IsValid(panel) then return end
    
    local function drawJobPanel()
        panel:Clear()
    
    -- Header
    local header = vgui.Create("DPanel", panel)
    header:Dock(TOP)
    header:SetTall(PD.H(50))
    header:DockMargin(0, 0, 0, PD.H(10))
    header.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
        surface.DrawRect(0, 0, PD.W(4), h)
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(PD.W(4), 0, w - PD.W(4), 1)
        surface.DrawRect(PD.W(4), h - 1, w - PD.W(4), 1)
        draw.DrawText("JOB VERWALTUNG", "MLIB.18", PD.W(20), h / 2 - PD.H(9), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
    end

       -- Top Panel mit Buttons
    local toppnl = vgui.Create("DPanel", panel)
    toppnl:Dock(TOP)
    toppnl:SetTall(PD.H(45))
    toppnl:DockMargin(0, 0, 0, PD.H(10))
    toppnl.Paint = function() end
    
    -- Hinzufügen Button
    local addbtn = PD.Button("+ Hinzufügen", toppnl, function()
        -- Erstellen-Optionen anzeigen
        local createFrame = PD.Frame("NEU ERSTELLEN", PD.W(400), PD.H(250), true)
        local content = createFrame:GetContentPanel()
        
        local unitBtn = PD.Button("Unit erstellen", content, function()
            createFrame:Remove()
            PD.JOBS.CreateUnitDialog()
        end)
        unitBtn:Dock(TOP)
        unitBtn:SetTall(PD.H(50))
        
        local subBtn = PD.Button("SubUnit erstellen", content, function()
            createFrame:Remove()
            PD.JOBS.CreateSubunitDialog()
        end)
        subBtn:Dock(TOP)
        subBtn:SetTall(PD.H(50))
        
        local jobBtn = PD.Button("Job erstellen", content, function()
            createFrame:Remove()
            PD.JOBS.CreateJobDialog()
        end)
        jobBtn:Dock(TOP)
        jobBtn:SetTall(PD.H(50))
    end)
    addbtn:Dock(LEFT)
    addbtn:SetWide(PD.W(150))
    addbtn:SetAccentColor(PD.Theme.Colors.StatusActive)
    
    -- Suchfeld
    local searchBox = PD.TextEntry(toppnl, "Suchen...", "")
    searchBox:Dock(FILL)
    searchBox:DockMargin(PD.W(10), 0, 0, 0)
    
    -- Body mit zwei Spalten
    local body = vgui.Create("DPanel", panel)
    body:Dock(FILL)
    body.Paint = function() end
    
    -- Linke Spalte (Liste)
    local left = vgui.Create("DPanel", body)
    left:Dock(LEFT)
    left:SetWide(PD.W(350))
    left.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(w - 1, 0, 1, h)
    end
    
    -- Rechte Spalte (Editor)
    local right = vgui.Create("DPanel", body)
    right:Dock(FILL)
    right:DockMargin(PD.W(10), 0, 0, 0)
    right.Paint = function() end
    
    local scrl = PD.Scroll(left)
    
    local function refreshList()
        UnitsETC(scrl, searchBox:GetValue(), function(kind, u, s, j)
            if kind == "unit" then
                if selectedUnit == u then
                    selectedUnit = nil
                    selectedSubunit = nil
                    selectedJob = nil
                    right:Clear()
                else
                    selectedUnit = u
                    selectedSubunit = nil
                    selectedJob = nil
                    PD.JOBS.OpenUnitEditor(right, u)
                end
            elseif kind == "subunit" then
                if selectedSubunit == s then
                    selectedSubunit = nil
                    selectedJob = nil
                    right:Clear()
                else
                    selectedUnit = u
                    selectedSubunit = s
                    selectedJob = nil
                    PD.JOBS.OpenSubunitEditor(right, u, s)
                end
            elseif kind == "job" then
                if selectedJob == j then
                    selectedJob = nil
                    right:Clear()
                else
                    selectedUnit = u
                    selectedSubunit = s
                    selectedJob = j
                    PD.JOBS.OpenJobEditor(right, u, s, j)
                end
            end

            refreshList()
        end)
    end
    
    searchBox.OnEnter = function() refreshList() end
    searchBox.OnChange = function() refreshList() end
    
    refreshList() 
    end

    drawJobPanel()

    net.Receive("PD.JOBS.UpdateTabel", function()
        PD.JOBS.Jobs = net.ReadTable()
        drawJobPanel()
    end)
end

-- Erstellen Dialoge
function PD.JOBS.CreateUnitDialog()
    local frame = PD.Frame("UNIT ERSTELLEN", PD.W(500), PD.H(400), true)
    local content = frame:GetContentPanel()
    local scroll = PD.Scroll(content)
    
    local unitTable = {}
    
    local nameLabel = vgui.Create("DLabel", scroll)
    nameLabel:Dock(TOP)
    nameLabel:SetText("NAME")
    nameLabel:SetFont("MLIB.12")
    nameLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    nameLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))
    
    local name = PD.TextEntry(scroll, "Unit Name", "")
    name:Dock(TOP)
    name:SetTall(PD.H(40))
    
    local colorLabel = vgui.Create("DLabel", scroll)
    colorLabel:Dock(TOP)
    colorLabel:SetText("FARBE")
    colorLabel:SetFont("MLIB.12")
    colorLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    colorLabel:DockMargin(PD.W(5), PD.H(15), 0, PD.H(3))
    
    local colorPicker = vgui.Create("DColorMixer", scroll)
    colorPicker:Dock(TOP)
    colorPicker:SetTall(PD.H(150))
    colorPicker:SetColor(Color(255, 255, 255))
    colorPicker:SetAlphaBar(false)
    colorPicker.ValueChanged = function(s, col)
        unitTable.color = col
    end
    
    local saveBtn = PD.Button("Unit erstellen", scroll, function()
        if name:GetValue() == "" then
            PD.Popup("Bitte einen Namen angeben!", PD.Theme.Colors.StatusCritical)
            return
        end
        if not unitTable.color then
            PD.Popup("Bitte eine Farbe auswählen!", PD.Theme.Colors.StatusCritical)
            return
        end
        
        local Table = { name = name:GetValue(), color = unitTable.color }
        net.Start("PD.JOBS.Admin")
        net.WriteString("unit")
        net.WriteTable(Table)
        net.SendToServer()
        
        frame:Remove()
        surface.PlaySound("buttons/button14.wav")
    end)
    saveBtn:Dock(TOP)
    saveBtn:SetTall(PD.H(50))
    saveBtn:DockMargin(0, PD.H(15), 0, 0)
    saveBtn:SetAccentColor(PD.Theme.Colors.StatusActive)
end

function PD.JOBS.CreateSubunitDialog()
    local frame = PD.Frame("SUBUNIT ERSTELLEN", PD.W(600), PD.H(700), true)
    local content = frame:GetContentPanel()
    local scroll = PD.Scroll(content)
    
    local subunitTable = {}
    
    local nameLabel = vgui.Create("DLabel", scroll)
    nameLabel:Dock(TOP)
    nameLabel:SetText("NAME")
    nameLabel:SetFont("MLIB.12")
    nameLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    nameLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))
    
    local name = PD.TextEntry(scroll, "SubUnit Name", "")
    name:Dock(TOP)
    name:SetTall(PD.H(40))
    
    local unitLabel = vgui.Create("DLabel", scroll)
    unitLabel:Dock(TOP)
    unitLabel:SetText("ÜBERGEORDNETE UNIT")
    unitLabel:SetFont("MLIB.12")
    unitLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    unitLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))
    
    local unitBox = PD.Dropdown(scroll, "Unit wählen...", function(v)
        subunitTable.unit = v
    end)
    unitBox:Dock(TOP)
    unitBox:SetTall(PD.H(40))
    for k, _ in SortedPairs(PD.JOBS.GetUnit(false, true) or {}) do
        unitBox:AddOption(k)
    end
    
    local maxSlider = PD.Slider(scroll, "Max Mitglieder", 0, 100, 10, function(v)
        subunitTable.maxmembers = v
    end)
    maxSlider:Dock(TOP)
    maxSlider:DockMargin(0, PD.H(10), 0, 0)
    
    local medicCheck = PD.Checkbox(scroll, "Ist Medic-Einheit", false, function(v) subunitTable.ismedic = v end)
    local leoCheck = PD.Checkbox(scroll, "Ist Law Enforcement", false, function(v) subunitTable.isleo = v end)
    local engCheck = PD.Checkbox(scroll, "Ist Engineer-Einheit", false, function(v) subunitTable.isengineer = v end)
    
    local equipTable = {}
    CreateSectionHeader(scroll, "AUSRÜSTUNG", PD.Theme.Colors.AccentBlue)
    local equipWrap = vgui.Create("DPanel", scroll)
    equipWrap:Dock(TOP)
    equipWrap:SetTall(PD.H(280))
    equipWrap.Paint = function() end
    PD.JOBS.EquipSection(equipWrap, equipTable)
    
    local saveBtn = PD.Button("SubUnit erstellen", scroll, function()
        if name:GetValue() == "" then
            PD.Popup("Bitte einen Namen angeben!", PD.Theme.Colors.StatusCritical)
            return
        end
        if not subunitTable.unit then
            PD.Popup("Bitte eine Unit auswählen!", PD.Theme.Colors.StatusCritical)
            return
        end
        
        local Table = {
            name = name:GetValue(),
            color = Color(255, 255, 255),
            unit = subunitTable.unit,
            maxmembers = subunitTable.maxmembers or 10,
            ismedic = subunitTable.ismedic or false,
            isleo = subunitTable.isleo or false,
            isengineer = subunitTable.isengineer or false,
            equip = equipTable
        }
        net.Start("PD.JOBS.Admin")
        net.WriteString("subunit")
        net.WriteTable(Table)
        net.SendToServer()
        
        frame:Remove()
        surface.PlaySound("buttons/button14.wav")
    end)
    saveBtn:Dock(TOP)
    saveBtn:SetTall(PD.H(50))
    saveBtn:DockMargin(0, PD.H(15), 0, 0)
    saveBtn:SetAccentColor(PD.Theme.Colors.StatusActive)
end

function PD.JOBS.CreateJobDialog()
    local frame = PD.Frame("JOB ERSTELLEN", PD.W(600), PD.H(800), true)
    local content = frame:GetContentPanel()
    local scroll = PD.Scroll(content)
    
    local jobTable = {}
    
    local nameLabel = vgui.Create("DLabel", scroll)
    nameLabel:Dock(TOP)
    nameLabel:SetText("NAME")
    nameLabel:SetFont("MLIB.12")
    nameLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    nameLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))
    
    local name = PD.TextEntry(scroll, "Job Name", "")
    name:Dock(TOP)
    name:SetTall(PD.H(40))
    
    local subLabel = vgui.Create("DLabel", scroll)
    subLabel:Dock(TOP)
    subLabel:SetText("SUBUNIT")
    subLabel:SetFont("MLIB.12")
    subLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    subLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))
    
    local subBox = PD.Dropdown(scroll, "SubUnit wählen...", function(v)
        jobTable.subunit = v
    end)
    subBox:Dock(TOP)
    subBox:SetTall(PD.H(40))
    for k, _ in SortedPairs(PD.JOBS.GetSubUnit(false, true) or {}) do
        subBox:AddOption(k)
    end
    
    local salarySlider = PD.Slider(scroll, "Gehalt", 0, 10000, 100, function(v) jobTable.salary = v end)
    salarySlider:Dock(TOP)
    salarySlider:DockMargin(0, PD.H(10), 0, 0)
    
    local speedSlider = PD.Slider(scroll, "Geschwindigkeit", 0, 500, 100, function(v) jobTable.speed = v end)
    speedSlider:Dock(TOP)
    
    local equipTable = {}
    local modelsTable = {}
    
    CreateSectionHeader(scroll, "AUSRÜSTUNG", PD.Theme.Colors.AccentBlue)
    local equipWrap = vgui.Create("DPanel", scroll)
    equipWrap:Dock(TOP)
    equipWrap:SetTall(PD.H(280))
    equipWrap.Paint = function() end
    PD.JOBS.EquipSection(equipWrap, equipTable)
    
    CreateSectionHeader(scroll, "MODELS", PD.Theme.Colors.AccentOrange)
    local modelWrap = vgui.Create("DPanel", scroll)
    modelWrap:Dock(TOP)
    modelWrap:SetTall(PD.H(280))
    modelWrap.Paint = function() end
    PD.JOBS.ModelSection(modelWrap, modelsTable)
    
    local saveBtn = PD.Button("Job erstellen", scroll, function()
        if name:GetValue() == "" then
            PD.Popup("Bitte einen Namen angeben!", PD.Theme.Colors.StatusCritical)
            return
        end
        if not jobTable.subunit then
            PD.Popup("Bitte eine SubUnit auswählen!", PD.Theme.Colors.StatusCritical)
            return
        end
        
        local Table = {
            name = name:GetValue(),
            color = Color(255, 255, 255),
            subunit = jobTable.subunit,
            salary = jobTable.salary or 100,
            speed = jobTable.speed or 100,
            equip = equipTable,
            model = modelsTable
        }
        net.Start("PD.JOBS.Admin")
        net.WriteString("job")
        net.WriteTable(Table)
        net.SendToServer()
        
        frame:Remove()
        surface.PlaySound("buttons/button14.wav")
    end)
    saveBtn:Dock(TOP)
    saveBtn:SetTall(PD.H(50))
    saveBtn:DockMargin(0, PD.H(15), 0, 0)
    saveBtn:SetAccentColor(PD.Theme.Colors.StatusActive)
end
