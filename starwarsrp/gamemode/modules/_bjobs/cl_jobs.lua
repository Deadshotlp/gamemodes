PD.JOBS = PD.JOBS or {}

PD.JOBS.Jobs = PD.JOBS.Jobs or {}

PD.JOBS.Menu = {
    unit = "",
    subunit = "",
    job = ""
}

local selectedUnit = ""

local sampel = {
    ["Test Unit"] = {
        default = false,
        equip = {},
        color = Color(255, 255, 255),
        subunits = {
            ["Test Subunit"] = {
                default = false,
                equip = {},
                color = Color(255, 255, 255),
                maxmembers = 10,
                unit = "Test Unit",
                ismedic = false,
                isleo = false,
                isengineer = false,
                jobs = {
                    ["Test Job"] = {
                        default = false,
                        equip = {},
                        model = {},
                        unit = "Test Subunit",
                        salary = 100,
                        speed = 100,
                        id = 1
                    }
                }
            }
        }
    }
}

timer.Simple(1, function()
    net.Start("PD.JOBS.SyncJobs")
    net.SendToServer()
end)

net.Receive("PD.JOBS.UpdateTabel", function()
    PD.JOBS.Jobs = net.ReadTable()
end)

net.Receive("PD.JOBS.OpenUnitEditor", function()
    PD.JOBS.CreateMainFrame()
end)

function PD.JOBS.CreateSachen(contentPanel, type, data)
    local tbl = {}

    if not istable(data) then
        data = {
            name = "N/A",
            default = false,
            color = Color(255, 255, 255),
            unit = "Unit",
            subunit = "SubUnit",
            maxmembers = 10,
            ismedic = false,
            isleo = false,
            isengineer = false,
            salary = 100,
            speed = 100,
            id = 1,
            model = {""},
            equip = {}
        }
    end

    if not data.equip then
        data.equip = {}
    end

    function PD.JOBS.EquipSection(contentPanel, equip)
        local main_panel = PD.Panel("", contentPanel)
        main_panel:Dock(TOP)
        main_panel:SetTall(PD.H(300))
    
        local panel1, panel2 = PD.Panel("", main_panel), PD.Panel("", main_panel) -- TODO:
        panel1:Dock(LEFT)
        panel1:SetWide(contentPanel:GetWide()/2)
        panel2:Dock(FILL)
    
        local possible_equip = PD.Scroll(panel1)
    
        local weaponList = {}
    
        for k, v in pairs(weapons.GetList()) do
            local a = true
    
            for _, i in ipairs(equip) do
                if i == v.ClassName then
                    a = false
                end
            end
    
            if a then
                table.insert(weaponList, v.ClassName)
            end
        end
    
        table.sort(weaponList)
        table.sort(equip)
    
        for k, v in pairs(weaponList) do
            local btn = PD.Button(v, possible_equip, function()
                table.insert(data.equip, v)
                panel1:Remove()
                panel2:Remove()
                PD.JOBS.EquipSection(contentPanel, data.equip)
            end)
            btn:Dock(TOP)
            btn:SetRadius(50)
        end
    
        local current_equip = PD.Scroll(panel2)
        for k, v in pairs(equip) do
            local btn = PD.Button(v, current_equip, function()
                table.remove(data.equip, k)
                panel1:Remove()
                panel2:Remove()
                PD.JOBS.EquipSection(contentPanel, data.equip)
            end)
            btn:Dock(TOP)
            btn:SetRadius(50)
        end
    end

    local name = PD.TextEntry("Name", contentPanel, data.name)
    name:Dock(TOP)

    if type == "unit" then
        PD.JOBS.EquipSection(contentPanel, data.equip)

        local color = PD.ColorPicker(contentPanel, "Color", data.color, function(val)
            tbl.color = val
        end)
    elseif type == "subunit" then

        local allUnits = PD.JOBS.GetUnit(false, true)

        local combobox = PD.ComboBox(data.unit, contentPanel, function(val)
            tbl.unit = val
        end)

        for k, v in SortedPairs(allUnits) do
            combobox:AddChoice(k)
        end

        local color = PD.ColorPicker(contentPanel, "Color", data.color, function(val)
            tbl.color = val
        end)

        local maxmembers = PD.NumSlider("Maxmembers", contentPanel, 0, 100, data.maxmembers, function(val)
            tbl.maxmembers = val
        end)

        local ismedic = PD.SimpleCheck(contentPanel, "Is Medic", data.ismedic, function(val)
            tbl.ismedic = val
        end)

        local isleo = PD.SimpleCheck(contentPanel, "Is Leo", data.isleo, function(val)
            tbl.isleo = val
        end)

        local isengineer = PD.SimpleCheck(contentPanel, "Is Engineer", data.isengineer, function(val)
            tbl.isengineer = val
        end)

        PD.JOBS.EquipSection(contentPanel, data.equip)

    elseif type == "job" then

        local allSubunits = PD.JOBS.GetSubUnit(false, true)

        local combobox = PD.ComboBox(data.unit, contentPanel, function(val)
            tbl.subunit = val
            tbl.unit = selectedUnit
        end)

        local color = PD.ColorPicker(contentPanel, "Color", data.color, function(val)
            tbl.color = val
        end)

        for k, v in SortedPairs(allSubunits) do
            combobox:AddChoice(k)
        end

        local salary = PD.NumSlider("Salary", contentPanel, 0, 1000, data.salary, function(val)
            tbl.salary = val
        end)

        local speed = PD.NumSlider("Speed", contentPanel, 0, 1000, data.speed, function(val)
            tbl.speed = val
        end)

        -- local id = PD.NumSlider("ID", contentPanel, 0, 1000, data.id, function(val)
        --     tbl.id = val
        -- end)

        local setModel = PD.ComboBox(data.model[1], contentPanel, function(val)
            tbl.model = val
        end)
        setModel:SetSearch(true)

        for k, v in SortedPairs(player_manager.AllValidModels()) do
            setModel:AddChoice(v)
        end

        PD.JOBS.EquipSection(contentPanel, data.equip)
    end

    local saveBtn = PD.Button("Save", contentPanel, function()
        -- if type == "job" then
        --     tbl.model = setModel:GetChoice()
        -- end

        -- if type == "subunit" or type == "job" then
        --     tbl.unit = combobox:GetChoice()
        -- end

        local Table = {}
        Table[name:GetValue()] = tbl

        net.Start("PD.JOBS.SaveJob")
        net.WriteString(type)
        net.WriteTable(Table)
        net.SendToServer()

        mainFrame:Remove()
        PD.JOBS.CreateMainFrame()
    end)
    saveBtn:Dock(TOP)
    saveBtn:SetTall(PD.H(50))
    saveBtn:SetRadius(50)

    local deleteBtn = PD.Button("Delete", contentPanel, function()
        local Table = {}
        Table[name:GetValue()] = tbl

        net.Start("PD.JOBS.DeleteJob")
        net.WriteString(type)
        net.WriteTable(Table)
        net.SendToServer()
    end)
    deleteBtn:Dock(TOP)
    deleteBtn:SetTall(PD.H(50))
    deleteBtn:SetOutlineColor(Color(255, 0, 0))
    deleteBtn:SetRadius(50)

end

function PD.JOBS.CreateMainFrame()
    if IsValid(mainFrame) then return end

    mainFrame = PD.Frame("Job Editors", PD.W(1250), PD.H(700), true)

    local conpanel = PD.Panel("", mainFrame)
    conpanel:Dock(FILL)

    local createUnitBtn = PD.Button("Unit Erstellen", conpanel, function()
        conpanel:Clear()

        local scrl = PD.Scroll(conpanel)

        PD.JOBS.CreateSachen(scrl, "unit")
    end)
    createUnitBtn:SetSize(PD.W(150), PD.H(150))
    createUnitBtn:SetPos(PD.W(10), PD.H(10))
    createUnitBtn:SetRadius(50)

    local x, y = PD.W(170), PD.H(10)
    local name = ""

    for k, v in SortedPairs(PD.JOBS.Jobs) do
        name = k

        if string.find(k, " ") then
            name = string.Split(k, " ")
            name = name[1] .. "\n" .. name[2]
        end

        if v.default then
            name = name .. "\n(Default)"
        end

        local unitBtn = PD.Button(name, conpanel, function()
            conpanel:Clear()

            selectedUnit = k

            PD.JOBS.SubUnitFrame(v, conpanel)
        end)
        unitBtn:SetSize(PD.W(150), PD.H(150))
        unitBtn:SetPos(x, y)
        unitBtn:SetOutlineColor(v.color)
        unitBtn:SetRadius(50)

        unitBtn.DoRightClick = function()
            conpanel:Clear()

            local scrl = PD.Scroll(conpanel)

            v.name = k
            PD.JOBS.CreateSachen(scrl, "unit", v)
        end

        x = x + PD.W(160)

        if x > PD.W(1250) then
            x = PD.W(170)
            y = y + PD.H(160)
        end
    end
end

function PD.JOBS.SubUnitFrame(tbl, conpanel)
    local x, y = PD.W(330), PD.H(10)

    local createUnitBtn = PD.Button("Zurück", conpanel, function()
        mainFrame:Remove()

        PD.JOBS.CreateMainFrame()
    end)
    createUnitBtn:SetSize(PD.W(150), PD.H(150))
    createUnitBtn:SetPos(PD.W(10), PD.H(10))
    createUnitBtn:SetRadius(50)

    local createUnitBtn = PD.Button("SubUnit\nErstellen", conpanel, function()
        conpanel:Clear()

        local scrl = PD.Scroll(conpanel)

        PD.JOBS.CreateSachen(scrl, "subunit")
    end)
    createUnitBtn:SetSize(PD.W(150), PD.H(150))
    createUnitBtn:SetPos(PD.W(170), PD.H(10))
    createUnitBtn:SetRadius(50)

    for k, v in SortedPairs(tbl.subunits) do
        local name = k --string.Split(k, " ")

        -- if name then
        --     name = name[1] .. "\n" .. name[2]
        -- else
        --     name = k
        -- end

        -- if v.default then
        --     name = name .. "\n(Default)"
        -- end

        local subunitBtn = PD.Button(name, conpanel, function()
            conpanel:Clear()

            PD.JOBS.Menu.subunit = v.unit

            PD.JOBS.JobFrame(v, conpanel)
        end)
        subunitBtn:SetSize(PD.W(150), PD.H(150))
        subunitBtn:SetPos(x, y)
        subunitBtn:SetOutlineColor(v.color)
        subunitBtn:SetRadius(50)

        subunitBtn.DoRightClick = function()
            conpanel:Clear()

            local scrl = PD.Scroll(conpanel)

            v.name = k
            PD.JOBS.CreateSachen(scrl, "subunit", v)
        end

        x = x + PD.W(160)

        if x > PD.W(1250) then
            x = PD.W(170)
            y = y + PD.H(160)
        end
    end
end

function PD.JOBS.JobFrame(tbl, conpanel)
    local x, y = PD.W(330), PD.H(10)

    local createUnitBtn = PD.Button("Zurück", conpanel, function()
        conpanel:Clear()

        chat.AddText(PD.JOBS.Menu.subunit)

        PD.JOBS.SubUnitFrame(PD.JOBS.Jobs[PD.JOBS.Menu.subunit], conpanel)
    end)
    createUnitBtn:SetSize(PD.W(150), PD.H(150))
    createUnitBtn:SetPos(PD.W(10), PD.H(10))
    createUnitBtn:SetRadius(50)

    local createUnitBtn = PD.Button("Job Erstellen", conpanel, function()
        conpanel:Clear()

        local scrl = PD.Scroll(conpanel)

        PD.JOBS.CreateSachen(scrl, "job")
    end)
    createUnitBtn:SetSize(PD.W(150), PD.H(150))
    createUnitBtn:SetPos(PD.W(170), PD.H(10))
    createUnitBtn:SetRadius(50)

    for k, v in SortedPairs(tbl.jobs) do
        local name = k -- string.Split(k, " ")

        -- if name then
        --     name = name[1] .. "\n" .. name[2]
        -- else
        --     name = k
        -- end

        -- if v.default then
        --     name = name .. "\n(Default)"
        -- end

        local jobBtn = PD.Button(name, conpanel, function()
            conpanel:Clear()

            local scrl = PD.Scroll(conpanel)

            v.name = k
            PD.JOBS.CreateSachen(scrl, "job", v)
        end)
        jobBtn:SetSize(PD.W(150), PD.H(150))
        jobBtn:SetPos(x, y)
        jobBtn:SetOutlineColor(v.color)
        jobBtn:SetRadius(50)

        x = x + PD.W(160)

        if x > PD.W(1250) then
            x = PD.W(170)
            y = y + PD.H(160)
        end
    end
end

local fallback = {
    ["Fallback Unit!"] = {
        default = false,
        equip = {},
        color = Color(255, 0, 0),
        subunits = {
            ["Fallback Subunit!"] = {
                maxmembers = 10,
                default = false,
                equip = {},
                color = Color(255, 0, 0),
                unit = "Fallback Unit!",
                ismedic = false,
                isleo = false,
                isengineer = false,
                jobs = {
                    ["Fallback Job!"] = {
                        color = Color(255, 0, 0),
                        model = {"models/player/skeleton.mdl"},
                        equip = {},
                        default = false,
                        unit = "Fallback Subunit!",
                        salary = 100,
                        speed = 100,
                        id = 1
                    }
                }
            }
        }
    }
}

function PD.JOBS.GetUnit(name, all)
    if all then
        return PD.JOBS.Jobs
    end

    if name then
        for _, i in SortedPairs(PD.JOBS.Jobs) do
            if _ == name then
                return _, i
            end
        end
    end

    for _, i in SortedPairs(PD.JOBS.Jobs) do
        if i.default then
            return _, i
        end
    end

    return "Fallback Unit!", fallback["Fallback Unit!"]
end

function PD.JOBS.GetSubUnit(name, all)
    local subunits = {}

    for _, i in SortedPairs(PD.JOBS.Jobs) do
        for _, j in SortedPairs(i.subunits) do
            subunits[_] = j
        end
    end

    if all then
        return subunits
    end

    if name then
        for _, i in SortedPairs(subunits) do
            if _ == name then
                return _, i
            end
        end
    end

    for _, i in SortedPairs(subunits) do
        if i.default then
            return _, i
        end
    end

    return "Fallback Subunit!", fallback["Fallback Unit!"].subunits["Fallback Subunit!"]
end

function PD.JOBS.GetJob(name, all)
    local subunits = PD.JOBS.GetSubUnit(false, true)
    local jobs = {}

    for _, i in SortedPairs(subunits) do
        for _, j in SortedPairs(i.jobs) do
            jobs[_] = j
        end
    end

    if all then
        return jobs
    end

    if name then
        for _, i in SortedPairs(jobs) do
            if _ == name then
                return _, i
            end
        end
    end

    for _, i in SortedPairs(jobs) do
        if i.default then
            return _, i
        end
    end

    return "Fallback Job!", fallback["Fallback Unit!"].subunits["Fallback Subunit!"].jobs["Fallback Job!"]
end

