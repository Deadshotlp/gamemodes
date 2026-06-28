local selectedUnit, selectedSubunit, selectedJob

local function GetNextJobIndex(tbl)
    local highest = 0

    local function scan(t)
        for k, v in pairs(t or {}) do
            if isstring(k) then
                local num = tonumber(string.match(k, "^JOB_(%d+)$"))
                if num and num > highest then
                    highest = num
                end
            end

            if istable(v) then
                if istable(v.subunits) then
                    scan(v.subunits)
                end

                if istable(v.jobs) then
                    scan(v.jobs)
                end
            end
        end
    end

    scan(tbl or {})
    return "JOB_" .. (highest + 1)
end

local function GetUnitByIndex(index)
    if not PD.JOBS.Jobs then return nil end
    return PD.JOBS.Jobs[index]
end

local function GetSubunitByIndex(unitIndex, subIndex)
    local unit = GetUnitByIndex(unitIndex)
    if not unit or not unit.subunits then return nil end
    return unit.subunits[subIndex]
end

local function GetJobByIndex(unitIndex, subIndex, jobIndex)
    local sub = GetSubunitByIndex(unitIndex, subIndex)
    if not sub or not sub.jobs then return nil end
    return sub.jobs[jobIndex]
end

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

local function UnitsETC(panel, search, onSelect)
    if not IsValid(panel) then return end

    for _, child in pairs(panel:GetCanvas():GetChildren()) do
        child:Remove()
    end

    local q = search and string.lower(string.Trim(search)) or ""
    local function match(line)
        if q == "" then return true end
        return string.find(string.lower(line or ""), q, 1, true) ~= nil
    end

    for unitIndex, unit in SortedPairs(PD.JOBS.Jobs or {}) do
        local unitDisplay = unit.name or unitIndex

        if match(unitDisplay) then
            local unitBtn = PD.Button(unitDisplay, panel, function()
                if onSelect then onSelect("unit", unitIndex) end
            end)
            unitBtn:Dock(TOP)
            unitBtn:SetTall(PD.H(40))
            unitBtn:SetAccentColor(unit.color or PD.Theme.Colors.AccentGray)
        end

        if selectedUnit ~= unitIndex and search == "" then continue end

        for subIndex, sub in SortedPairs(unit.subunits or {}) do
            local subDisplay = sub.name or subIndex

            if match(unitDisplay .. " " .. subDisplay) then
                local subBtn = PD.Button("  ├ " .. subDisplay, panel, function()
                    if onSelect then onSelect("subunit", unitIndex, subIndex) end
                end)
                subBtn:Dock(TOP)
                subBtn:SetTall(PD.H(35))
                subBtn:DockMargin(PD.W(15), 0, 0, 0)
            end

            if selectedSubunit ~= subIndex and search == "" then continue end

            for jobIndex, job in SortedPairs(sub.jobs or {}) do
                local jobDisplay = job.name or jobIndex

                if match(unitDisplay .. " " .. subDisplay .. " " .. jobDisplay) then
                    local jobBtn = PD.Button("     └ " .. jobDisplay, panel, function()
                        if onSelect then onSelect("job", unitIndex, subIndex, jobIndex) end
                    end)
                    jobBtn:Dock(TOP)
                    jobBtn:SetTall(PD.H(32))
                    jobBtn:DockMargin(PD.W(30), 0, 0, 0)
                end
            end
        end
    end
end

function PD.JOBS.OpenUnitEditor(parent, unitIndex)
    if not IsValid(parent) then return end
    local unit = GetUnitByIndex(unitIndex)
    if not unit then return end

    parent:Clear()

    CreateSectionHeader(parent, "UNIT BEARBEITEN: " .. (unit.name or unitIndex), unit.color)

    local scroll = PD.Scroll(parent)

    local nameLabel = vgui.Create("DLabel", scroll)
    nameLabel:Dock(TOP)
    nameLabel:SetText("NAME")
    nameLabel:SetFont("MLIB.12")
    nameLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    nameLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))

    local name = PD.TextEntry(scroll, "Unit Name", unit.name or "")
    name:Dock(TOP)
    name:SetTall(PD.H(40))

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

    local save = PD.Button("Speichern", scroll, function()
        local data = {
            index = unitIndex,
            name = name:GetValue(),
            color = pickedColor
        }
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
        local data = { index = unitIndex }
        net.Start("PD.JOBS.unit_delete")
        net.WriteTable(data)
        net.SendToServer()
        surface.PlaySound("buttons/button14.wav")
    end)
    del:Dock(TOP)
    del:SetTall(PD.H(45))
    del:SetAccentColor(PD.Theme.Colors.StatusCritical)
end

function PD.JOBS.OpenSubunitEditor(parent, unitIndex, subIndex)
    if not IsValid(parent) then return end
    local unit = GetUnitByIndex(unitIndex)
    if not unit then return end
    local sub = GetSubunitByIndex(unitIndex, subIndex)
    if not sub then return end

    parent:Clear()

    CreateSectionHeader(parent, "SUBUNIT BEARBEITEN: " .. (sub.name or subIndex), unit.color)

    local scroll = PD.Scroll(parent)

    local nameLabel = vgui.Create("DLabel", scroll)
    nameLabel:Dock(TOP)
    nameLabel:SetText("NAME")
    nameLabel:SetFont("MLIB.12")
    nameLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    nameLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))

    local name = PD.TextEntry(scroll, "SubUnit Name", sub.name or "")
    name:Dock(TOP)
    name:SetTall(PD.H(40))

    local currentUnit = unitIndex

    local unitLabel = vgui.Create("DLabel", scroll)
    unitLabel:Dock(TOP)
    unitLabel:SetText("ÜBERGEORDNETE UNIT")
    unitLabel:SetFont("MLIB.12")
    unitLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    unitLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))

    local unitBox = PD.Dropdown(scroll, unit.name or unitIndex, function(v)
        currentUnit = v
    end)
    unitBox:Dock(TOP)
    unitBox:SetTall(PD.H(40))
    for idx, data in SortedPairs(PD.JOBS.Jobs or {}) do
        unitBox:AddOption(idx, idx)
    end

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

    local medicCheck = PD.Checkbox(scroll, "Ist Medic", ismedic, function(v) ismedic = v end)
    local leoCheck = PD.Checkbox(scroll, "Ist Law Enforcement", isleo, function(v) isleo = v end)
    local engCheck = PD.Checkbox(scroll, "Ist Engineer", isengineer, function(v) isengineer = v end)

    CreateSectionHeader(scroll, "AUSRÜSTUNG", PD.Theme.Colors.AccentBlue)

    local equip = table.Copy(sub.equip or {})
    local equipWrap = vgui.Create("DPanel", scroll)
    equipWrap:Dock(TOP)
    equipWrap:SetTall(PD.H(320))
    equipWrap.Paint = function() end
    PD.JOBS.EquipSection(equipWrap, equip)

    CreateSectionHeader(scroll, "MODELS", PD.Theme.Colors.AccentOrange)

    local models = table.Copy(sub.model or sub.models or {})
    local modelWrap = vgui.Create("DPanel", scroll)
    modelWrap:Dock(TOP)
    modelWrap:SetTall(PD.H(320))
    modelWrap.Paint = function() end
    PD.JOBS.ModelSection(modelWrap, models)

    local save = PD.Button("Speichern", scroll, function()
        local data = {
            unitIndex = currentUnit,
            oldUnitIndex = unitIndex,
            index = subIndex,
            name = name:GetValue(),
            color = pickedColor,
            maxmembers = maxmembers,
            ismedic = ismedic,
            isleo = isleo,
            isengineer = isengineer,
            equip = equip,
            model = models
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
        local data = {
            unitIndex = unitIndex,
            index = subIndex
        }
        net.Start("PD.JOBS.subunit_delete")
        net.WriteTable(data)
        net.SendToServer()
        surface.PlaySound("buttons/button14.wav")
    end)
    del:Dock(TOP)
    del:SetTall(PD.H(45))
    del:SetAccentColor(PD.Theme.Colors.StatusCritical)
end

function PD.JOBS.OpenJobEditor(parent, unitIndex, subIndex, jobIndex)
    if not IsValid(parent) then return end
    local unit = GetUnitByIndex(unitIndex)
    if not unit then return end
    local sub = GetSubunitByIndex(unitIndex, subIndex)
    if not sub then return end
    local job = GetJobByIndex(unitIndex, subIndex, jobIndex)
    if not job then return end

    parent:Clear()

    CreateSectionHeader(parent, "JOB BEARBEITEN: " .. (job.name or jobIndex), job.color or unit.color)

    local scroll = PD.Scroll(parent)

    local nameLabel = vgui.Create("DLabel", scroll)
    nameLabel:Dock(TOP)
    nameLabel:SetText("NAME")
    nameLabel:SetFont("MLIB.12")
    nameLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    nameLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))

    local name = PD.TextEntry(scroll, "Job Name", job.name or "")
    name:Dock(TOP)
    name:SetTall(PD.H(40))

    local curUnit, curSub = unitIndex, subIndex

    local unitLabel = vgui.Create("DLabel", scroll)
    unitLabel:Dock(TOP)
    unitLabel:SetText("UNIT")
    unitLabel:SetFont("MLIB.12")
    unitLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    unitLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))

    local unitBox = PD.Dropdown(scroll, unit.name or unitIndex, function(v)
        curUnit = v
    end)
    unitBox:Dock(TOP)
    unitBox:SetTall(PD.H(40))
    for idx, _ in SortedPairs(PD.JOBS.Jobs or {}) do
        unitBox:AddOption(idx, idx)
    end

    local subLabel = vgui.Create("DLabel", scroll)
    subLabel:Dock(TOP)
    subLabel:SetText("SUBUNIT")
    subLabel:SetFont("MLIB.12")
    subLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    subLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))

    local subBox = PD.Dropdown(scroll, sub.name or subIndex, function(v)
        curSub = v
    end)
    subBox:Dock(TOP)
    subBox:SetTall(PD.H(40))
    for idx, _ in SortedPairs((PD.JOBS.Jobs[curUnit] and PD.JOBS.Jobs[curUnit].subunits) or {}) do
        subBox:AddOption(idx, idx)
    end

    local pickedColor = job.color or Color(255, 255, 255)
    local salary = job.salary or 100
    local speed = job.speed or 100

    -- local salarySlider = PD.Slider(scroll, "Gehalt", 0, 10000, salary, function(v) salary = v end)
    -- salarySlider:Dock(TOP)
    -- salarySlider:DockMargin(0, PD.H(10), 0, 0)

    -- local speedSlider = PD.Slider(scroll, "Geschwindigkeit", 0, 500, speed, function(v) speed = v end)
    -- speedSlider:Dock(TOP)

    local ismedic = job.ismedic or false
    local isleo = job.isleo or false
    local isengineer = job.isengineer or false
    local showid = job.showid or false

    local medicCheck = PD.Checkbox(scroll, "Ist Medic", ismedic, function(v) ismedic = v end)
    local leoCheck = PD.Checkbox(scroll, "Ist Law Enforcement", isleo, function(v) isleo = v end)
    local engCheck = PD.Checkbox(scroll, "Ist Engineer", isengineer, function(v) isengineer = v end)
    local showidCheck = PD.Checkbox(scroll, "ID Anzeigen (Bei Aktivierung wird die ID nicht angezeigt)", showid, function(v) showid = v end)

    CreateSectionHeader(scroll, "AUSRÜSTUNG", PD.Theme.Colors.AccentBlue)

    local equip = table.Copy(job.equip or {})
    local equipWrap = vgui.Create("DPanel", scroll)
    equipWrap:Dock(TOP)
    equipWrap:SetTall(PD.H(320))
    equipWrap.Paint = function() end
    PD.JOBS.EquipSection(equipWrap, equip)

    CreateSectionHeader(scroll, "MODELS", PD.Theme.Colors.AccentOrange)

    local models = table.Copy(job.model or job.models or {})
    local modelWrap = vgui.Create("DPanel", scroll)
    modelWrap:Dock(TOP)
    modelWrap:SetTall(PD.H(320))
    modelWrap.Paint = function() end
    PD.JOBS.ModelSection(modelWrap, models)

    local save = PD.Button("Speichern", scroll, function()
        local data = {
            unitIndex = unitIndex,
            subIndex = subIndex,
            index = jobIndex,
            newUnitIndex = curUnit,
            newSubIndex = curSub,
            name = name:GetValue(),
            color = pickedColor,
            salary = salary,
            speed = speed,
            equip = equip,
            model = models,
            default = false,
            ismedic = ismedic,
            isleo = isleo,
            isengineer = isengineer,
            showid = showid,
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
        local data = {
            unitIndex = unitIndex,
            subIndex = subIndex,
            index = jobIndex
        }
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

    local function GetSortedEntriesByPosition(tbl)
        local entries = {}

        for k, v in pairs(tbl or {}) do
            table.insert(entries, {
                index = k,
                data = v
            })
        end

        table.sort(entries, function(a, b)
            local aPos = tonumber(a.data.position) or 999999
            local bPos = tonumber(b.data.position) or 999999

            if aPos == bPos then
                return tostring(a.index) < tostring(b.index)
            end

            return aPos < bPos
        end)

        return entries
    end

    local function drawJobPanel()
        panel:Clear()

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

        local toppnl = vgui.Create("DPanel", panel)
        toppnl:Dock(TOP)
        toppnl:SetTall(PD.H(45))
        toppnl:DockMargin(0, 0, 0, PD.H(10))
        toppnl.Paint = function() end

        local addbtn = PD.Button("+ Hinzufügen", toppnl, function()
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

        local searchBox = PD.TextEntry(toppnl, "Suchen...", "")
        searchBox:Dock(FILL)
        searchBox:DockMargin(PD.W(10), 0, 0, 0)

        local body = vgui.Create("DPanel", panel)
        body:Dock(FILL)
        body.Paint = function() end

        local left = vgui.Create("DPanel", body)
        left:Dock(LEFT)
        left:SetWide(PD.W(350))
        left.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
            surface.SetDrawColor(PD.Theme.Colors.AccentGray)
            surface.DrawRect(w - 1, 0, 1, h)
        end

        local right = vgui.Create("DPanel", body)
        right:Dock(FILL)
        right:DockMargin(PD.W(10), 0, 0, 0)
        right.Paint = function() end

        local scrl = PD.Scroll(left)

        local function UnitsETC(panelRef, search, onSelect)
            if not IsValid(panelRef) then return end

            local canvas = panelRef:GetCanvas()

            for _, child in pairs(canvas:GetChildren()) do
                child:Remove()
            end

            local q = search and string.lower(string.Trim(search)) or ""
            local function match(line)
                if q == "" then return true end
                return string.find(string.lower(line or ""), q, 1, true) ~= nil
            end

            for unitIndex, unit in SortedPairs(PD.JOBS.Jobs or {}) do
                local unitDisplay = unit.name or unitIndex

                if match(unitDisplay) then
                    local unitBtn = PD.Button(unitDisplay, canvas, function()
                        if onSelect then onSelect("unit", unitIndex) end
                    end)
                    unitBtn:Dock(TOP)
                    unitBtn:SetTall(PD.H(40))
                    unitBtn:SetAccentColor(unit.color or PD.Theme.Colors.AccentGray)
                end

                if selectedUnit ~= unitIndex and search == "" then continue end

                for subIndex, sub in SortedPairs(unit.subunits or {}) do
                    local subDisplay = sub.name or subIndex

                    if match(unitDisplay .. " " .. subDisplay) then
                        local subBtn = PD.Button("  ├ " .. subDisplay, canvas, function()
                            if onSelect then onSelect("subunit", unitIndex, subIndex) end
                        end)
                        subBtn:Dock(TOP)
                        subBtn:SetTall(PD.H(35))
                        subBtn:DockMargin(PD.W(15), 0, 0, 0)
                    end

                    if selectedSubunit ~= subIndex and search == "" then continue end

                    local jobEntries = GetSortedEntriesByPosition(sub.jobs or {})
                    local visibleJobs = {}

                    for _, entry in ipairs(jobEntries) do
                        local jobIndex = entry.index
                        local job = entry.data
                        local jobDisplay = job.name or jobIndex

                        if match(unitDisplay .. " " .. subDisplay .. " " .. jobDisplay) then
                            table.insert(visibleJobs, {
                                index = jobIndex,
                                data = job
                            })
                        end
                    end

                    if #visibleJobs <= 0 then continue end

                    local jobHolder = vgui.Create("DPanel", canvas)
                    jobHolder:Dock(TOP)
                    jobHolder:DockMargin(PD.W(30), 0, 0, 0)
                    jobHolder.Paint = function() end
                    jobHolder.PerformLayout = function(self)
                        local h = 0

                        for _, child in ipairs(self:GetChildren()) do
                            if IsValid(child) then
                                local _, top, _, bottom = child:GetDockMargin()
                                h = h + child:GetTall() + top + bottom
                            end
                        end

                        self:SetTall(h)
                    end

                    jobHolder:Receiver("PD_JOBS_REORDER", function(self, panels, dropped, menuIndex, x, y)
                        if not dropped then return end
                        if not panels or not panels[1] or not IsValid(panels[1]) then return end

                        local dragged = panels[1]

                        if dragged.dragType ~= "job" then return end
                        if dragged.unitIndex ~= unitIndex or dragged.subIndex ~= subIndex then return end

                        local children = {}
                        for _, child in ipairs(self:GetChildren()) do
                            if IsValid(child) and child.IsJobDragButton and child ~= dragged then
                                table.insert(children, child)
                            end
                        end

                        table.sort(children, function(a, b)
                            return a:GetY() < b:GetY()
                        end)

                        local newOrder = {}
                        local inserted = false

                        for _, child in ipairs(children) do
                            if not inserted and y < (child:GetY() + child:GetTall() * 0.5) then
                                table.insert(newOrder, dragged.jobIndex)
                                inserted = true
                            end

                            table.insert(newOrder, child.jobIndex)
                        end

                        if not inserted then
                            table.insert(newOrder, dragged.jobIndex)
                        end

                        net.Start("PD.JOBS.job_reorder")
                        net.WriteTable({
                            unitIndex = unitIndex,
                            subIndex = subIndex,
                            order = newOrder
                        })
                        net.SendToServer()

                        surface.PlaySound("buttons/button14.wav")
                    end)

                    for _, entry in ipairs(visibleJobs) do
                        local jobIndex = entry.index
                        local job = entry.data
                        local pos = tonumber(job.position) or 0
                        local jobDisplay = job.name or jobIndex

                        local jobBtn = PD.Button("     └ [" .. pos .. "] " .. jobDisplay, jobHolder, function()
                            if onSelect then onSelect("job", unitIndex, subIndex, jobIndex) end
                        end)
                        jobBtn:Dock(TOP)
                        jobBtn:SetTall(PD.H(32))
                        jobBtn:DockMargin(0, 0, 0, 0)
                        jobBtn.IsJobDragButton = true
                        jobBtn.dragType = "job"
                        jobBtn.unitIndex = unitIndex
                        jobBtn.subIndex = subIndex
                        jobBtn.jobIndex = jobIndex
                        jobBtn:Droppable("PD_JOBS_REORDER")
                    end

                    jobHolder:InvalidateLayout(true)
                end
            end
        end

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

        searchBox.OnEnter = function()
            refreshList()
        end

        searchBox.OnChange = function()
            refreshList()
        end

        refreshList()
    end

    drawJobPanel()

    net.Receive("PD.JOBS.UpdateTabel", function()
        PD.JOBS.Jobs = net.ReadTable()
        drawJobPanel()
    end)
end

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

        local Table = {
            index = GetNextJobIndex(PD.JOBS.Jobs),
            name = name:GetValue(),
            color = unitTable.color
        }

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
        subunitTable.unitIndex = v
    end)
    unitBox:Dock(TOP)
    unitBox:SetTall(PD.H(40))
    for idx, data in SortedPairs(PD.JOBS.Jobs or {}) do
        unitBox:AddOption(idx, idx)
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

        if not subunitTable.unitIndex then
            PD.Popup("Bitte eine Unit auswählen!", PD.Theme.Colors.StatusCritical)
            return
        end

        local Table = {
            index = GetNextJobIndex(PD.JOBS.Jobs),
            unitIndex = subunitTable.unitIndex,
            name = name:GetValue(),
            color = Color(255, 255, 255),
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

    local unitLabel = vgui.Create("DLabel", scroll)
    unitLabel:Dock(TOP)
    unitLabel:SetText("UNIT")
    unitLabel:SetFont("MLIB.12")
    unitLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    unitLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))

    local unitBox = PD.Dropdown(scroll, "Unit wählen...", function(v)
        jobTable.unitIndex = v
        if IsValid(jobTable.subBox) then
            jobTable.subBox:Clear()
            for subIdx, subData in SortedPairs((PD.JOBS.Jobs[v] and PD.JOBS.Jobs[v].subunits) or {}) do
                jobTable.subBox:AddOption(subIdx, subIdx)
            end
        end
    end)
    unitBox:Dock(TOP)
    unitBox:SetTall(PD.H(40))
    for idx, _ in SortedPairs(PD.JOBS.Jobs or {}) do
        unitBox:AddOption(idx, idx)
    end

    local subLabel = vgui.Create("DLabel", scroll)
    subLabel:Dock(TOP)
    subLabel:SetText("SUBUNIT")
    subLabel:SetFont("MLIB.12")
    subLabel:SetTextColor(PD.Theme.Colors.AccentGray)
    subLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(3))

    local subBox = PD.Dropdown(scroll, "SubUnit wählen...", function(v)
        jobTable.subIndex = v
    end)
    subBox:Dock(TOP)
    subBox:SetTall(PD.H(40))
    jobTable.subBox = subBox

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

        if not jobTable.unitIndex or not jobTable.subIndex then
            PD.Popup("Bitte Unit und SubUnit auswählen!", PD.Theme.Colors.StatusCritical)
            return
        end

        local Table = {
            index = GetNextJobIndex(PD.JOBS.Jobs),
            unitIndex = jobTable.unitIndex,
            subIndex = jobTable.subIndex,
            name = name:GetValue(),
            color = Color(255, 255, 255),
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

-- for k, v in pairs(player.GetAll()) do
--     print("Player: " .. v:Nick())
--     local index, jobTable = v:GetJob()
--     print("Job Index: " .. tostring(index))
--     PrintTable(jobTable)
-- end