



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
            model = {},
            equip = {}
        }
    end

    print("Vorher Test Data")
    PrintTable(data)

    if not data.equip or not data.equip[1] then
        data.equip = {"Keine Ausrüstung angegeben"}
    end

    if not data.model then
        data.model = {"Kein Model angegeben"}
    end

    print("Nachher Test Data")
    PrintTable(data)

    tbl = table.Copy(data)

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

        local color = PD.ColorPicker(contentPanel, "Color", data.color or Color(255, 255, 255), function(val)
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
        local num = #data.model
        num = num - 1

        local setModel = PD.ComboBox(" | " .. num .. " weitere", contentPanel, function(val)
            tbl.model = val
        end)
        setModel:SetSearch(true)

        for k, v in SortedPairs(player_manager.AllValidModels()) do
            setModel:AddChoice(v)
        end

        local num = #data.equip
        num = num - 1

        local setWeps = PD.ComboBox(data.equip[1] .. " | " .. num .. " weitere", contentPanel, function(val)
            tbl.equip = val
        end)
        setWeps:SetSearch(true)

        for k, v in SortedPairs(weapons.GetList()) do
            setWeps:AddChoice(v.ClassName)
        end
    end

    local saveBtn = PD.Button("Save", contentPanel, function()
        if name:GetValue() == "" then
            PD.Notify("Bitte einen Namen angeben!", Color(255, 0, 0), false)
            return
        end

        if #tbl.model == 0 then
            PD.Notify("Bitte ein Model angeben!", Color(255, 0, 0), false)
            return
        end

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
    if IsValid(mainFrame) then
        return
    end

    mainFrame = PD.Frame("Job Editors", PD.W(1250), PD.H(700), true)

    local conpanel = PD.Panel("", mainFrame)
    conpanel:Dock(FILL)

    local scrl = PD.Scroll(conpanel)

    local createUnitBtn = PD.Button("Unit Erstellen", scrl, function()
        conpanel:Clear()

        local scrl = PD.Scroll(conpanel)

        PD.JOBS.CreateSachen(scrl, "unit")
    end)
    createUnitBtn:SetTall(PD.H(50))
    createUnitBtn:Dock(TOP)
    createUnitBtn:SetRadius(50)

    local name = ""
    for k, v in SortedPairs(PD.JOBS.Jobs) do
        name = k

        if v.default then
            name = name .. "\n(Default)"
        end

        local unitBtn = PD.Button(name, scrl, function()
            conpanel:Clear()

            selectedUnit = k

            PD.JOBS.SubUnitFrame(v, conpanel)
        end)
        unitBtn:SetTall(PD.H(100))
        unitBtn:Dock(TOP)
        unitBtn:SetOutlineColor(v.color)
        unitBtn:SetRadius(50)
        unitBtn.DoRightClick = function()
            conpanel:Clear()

            local scrl = PD.Scroll(conpanel)

            v.name = k
            PD.JOBS.CreateSachen(scrl, "unit", v)
        end
    end
end

function PD.JOBS.SubUnitFrame(tbl, conpanel)

    local scrl = PD.Scroll(conpanel)

    local createUnitBtn = PD.Button("Zurück", conpanel, function()
        mainFrame:Remove()

        PD.JOBS.CreateMainFrame()
    end)
    createUnitBtn:SetTall(PD.H(50))
    createUnitBtn:Dock(BOTTOM)
    createUnitBtn:SetRadius(50)

    local createUnitBtn = PD.Button("SubUnit Erstellen", conpanel, function()
        conpanel:Clear()

        local scrl = PD.Scroll(conpanel)

        PD.JOBS.CreateSachen(scrl, "subunit")
    end)
    createUnitBtn:SetTall(PD.H(50))
    createUnitBtn:Dock(BOTTOM)
    createUnitBtn:SetRadius(50)

    for k, v in SortedPairs(tbl.subunits) do
        local subunitBtn = PD.Button(k, scrl, function()
            conpanel:Clear()

            PD.JOBS.Menu.subunit = v.unit

            PD.JOBS.JobFrame(v, conpanel)
        end)
        subunitBtn:SetTall(PD.H(100))
        subunitBtn:Dock(TOP)
        subunitBtn:SetOutlineColor(v.color)
        subunitBtn:SetRadius(50)

        subunitBtn.DoRightClick = function()
            conpanel:Clear()

            local scrl = PD.Scroll(conpanel)

            v.name = k
            PD.JOBS.CreateSachen(scrl, "subunit", v)
        end
    end
end

function PD.JOBS.JobFrame(tbl, conpanel)
    local scrl = PD.Scroll(conpanel)

    local createUnitBtn = PD.Button("Zurück", conpanel, function()
        conpanel:Clear()

        chat.AddText(PD.JOBS.Menu.subunit)

        PD.JOBS.SubUnitFrame(PD.JOBS.Jobs[PD.JOBS.Menu.subunit], conpanel)
    end)
    createUnitBtn:SetTall(PD.H(50))
    createUnitBtn:Dock(BOTTOM)
    createUnitBtn:SetRadius(50)

    local createUnitBtn = PD.Button("Job Erstellen", conpanel, function()
        conpanel:Clear()

        local scrl = PD.Scroll(conpanel)

        PD.JOBS.CreateSachen(scrl, "job")
    end)
    createUnitBtn:SetTall(PD.H(50))
    createUnitBtn:Dock(BOTTOM)
    createUnitBtn:SetRadius(50)

    for k, v in SortedPairs(tbl.jobs) do
        local jobBtn = PD.Button(k, scrl, function()
            conpanel:Clear()

            local scrl = PD.Scroll(conpanel)

            v.name = k
            PD.JOBS.CreateSachen(scrl, "job", v)
        end)
        jobBtn:SetTall(PD.H(100))
        jobBtn:Dock(TOP)
        jobBtn:SetOutlineColor(v.color or Color(255, 255, 255))
        jobBtn:SetRadius(50)
    end
end

