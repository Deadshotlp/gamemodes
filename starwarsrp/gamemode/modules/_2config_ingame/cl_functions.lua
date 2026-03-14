PD.Config = PD.Config or {}
-- PD.Config.Table = {}


function PD.Config:EquipSection(contentPanel, tbl)
    local main_panel = contentPanel.equipPanel
    if not IsValid(main_panel) then
        main_panel = PD.Panel("", contentPanel)
        contentPanel.equipPanel = main_panel
        main_panel:Dock(TOP)
        main_panel:SetTall(PD.H(300))
        main_panel:SetBackColor(getColor("Background3"))

        contentPanel.scroll = PD.Scroll(main_panel)
    end

    local scroll = contentPanel.scroll
    for _, c in pairs(scroll:GetCanvas():GetChildren()) do c:Remove() end

    local isList = true
    local count = 0

    for k in pairs(tbl) do
        count = count + 1
        if not isnumber(k) then
            isList = false
            break
        end
    end

    if isList then
        for i, v in ipairs(tbl) do
            local btn = PD.Button(tostring(v), scroll, function()
                table.remove(tbl, i)
                PD.Config:EquipSection(contentPanel, tbl)
            end)
            btn:Dock(TOP)
            btn:SetRadius(50)
        end

        local addBtn = PD.Button("+ Eintrag hinzufügen", scroll, function()
            Derma_StringRequest("Neuer Eintrag", "", "", function(text)
                if text ~= "" then
                    table.insert(tbl, text)
                    PD.Config:EquipSection(contentPanel, tbl)
                end
            end)
        end)
        addBtn:Dock(TOP)

        return tbl
    end

    for k, v in pairs(tbl) do
        local row = PD.Panel("", scroll)
        row:Dock(TOP)
        row:SetTall(PD.H(40))

        local keyBtn = PD.Button(tostring(k), row, function()
            tbl[k] = nil
            PD.Config:EquipSection(contentPanel, tbl)
        end)
        keyBtn:Dock(LEFT)
        keyBtn:SetWide(row:GetWide() / 2)
        keyBtn:SetRadius(50)

        local valBtn = PD.Button(tostring(v), row, function()
            Derma_StringRequest("Wert ändern", k, tostring(v), function(text)
                if isnumber(v) then
                    tbl[k] = tonumber(text)
                elseif isbool(v) then
                    tbl[k] = tobool(text)
                else
                    tbl[k] = text
                end
                PD.Config:EquipSection(contentPanel, tbl)
            end)
        end)
        valBtn:Dock(FILL)
        valBtn:SetRadius(50)
    end

    local addBtn = PD.Button("+ Key hinzufügen", scroll, function()
        Derma_StringRequest("Key", "", "", function(key)
            if key == "" or tbl[key] ~= nil then return end
            Derma_StringRequest("Value", "", "", function(val)
                if val == "true" or val == "false" then
                    tbl[key] = tobool(val)
                elseif tonumber(val) then
                    tbl[key] = tonumber(val)
                else
                    tbl[key] = val
                end
                PD.Config:EquipSection(contentPanel, tbl)
            end)
        end)
    end)
    addBtn:Dock(TOP)

    return tbl
end

local function getCategorySettings(category)
    local tbl = {}
    for addon, settings in pairs(PD.Config.Table) do
        if addon == category then
            for settingName, settingData in pairs(settings) do
                tbl[settingName] = {
                    type = settingData.type,
                    default = settingData.default
                }
            end
        end
    end
    return tbl
end

function PD.Config:Menu()
    if IsValid(mainFrame) then return end

    mainFrame = PD.Frame("Config Menu", PD.W(1000), PD.H(800), true)
    local scrl = PD.Scroll(mainFrame)

    local reloadButton = PD.Button("Reload Config", mainFrame, function()
        mainFrame:Remove()
        PD.Config:Menu()
    end)
    reloadButton:Dock(BOTTOM)
    reloadButton:SetTall(PD.H(50))

    for addon, settings in pairs(self.Table) do
        local catLabel = PD.Label(addon, scrl)
        catLabel:Dock(TOP)
        catLabel:DockMargin(PD.W(5), PD.H(10), PD.W(5), PD.H(5))
        catLabel:SetFont("MLIB.30")
        catLabel:SizeToContents()

        for settingName, settingData in pairs(settings) do
            if settingData.type == "boolean" then
                PD.SimpleCheck(scrl, settingName, settingData.default, function() end):SetTall(PD.H(40))
            elseif settingData.type == "number" then
                PD.NumSlider(settingName, scrl, 0, 100, settingData.default, function() end)
            elseif settingData.type == "string" then
                PD.TextEntryLabel(settingName, scrl, "", settingData.default)
            elseif settingData.type == "table" then
                local pnl = PD.Panel("", scrl)
                pnl:Dock(TOP)
                pnl:SetTall(PD.H(320))
                self:EquipSection(pnl, settingData.default)
            end
        end
    end
end

if mainFrame then mainFrame:Remove() end

-- PD.Config:Menu()

