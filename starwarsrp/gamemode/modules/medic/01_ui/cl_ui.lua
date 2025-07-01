PD.DM = PD.DM or {}
PD.DM.HUD = PD.DM.HUD or {}
PD.DM.UI = PD.DM.UI or {}

local main_tbl

net.Receive("PD.DM.UI.OpenAdminInterface", function()
    main_tbl = net.ReadTable()

    PD.DM.UI.OpenEditor()
end)

function PD.DM.UI.OpenEditor()
    if IsValid(PD.DM.UI.Frame) then
        PD.DM.UI.Frame:Remove()
    end

    PD.DM.UI.Frame = PD.Frame("Medic", PD.W(ScrW() / 1.5), PD.H(ScrH() / 1.5), true)

    local scrl = PD.Scroll(PD.DM.UI.Frame)
    scrl:Dock(FILL)

    local combo = PD.ComboBox("Wähle Kategorie", PD.DM.UI.Frame, function(val)
        scrl:Clear()

        PD.DM.UI.AddTablVal(scrl, main_tbl[val], val)
    end)
    combo:Dock(TOP)

    for k, v in SortedPairs(main_tbl) do
        combo:AddChoice(k)
    end
end

function PD.DM.UI.AddTablVal(scrl, tbl, val)
    for k, v in pairs(tbl) do
        local parent_panel = PD.Panel("", scrl)
        parent_panel:DockMargin(PD.W(5), PD.H(10), PD.W(5), PD.H(10))

        local count, elements = PD.DM.UI.CreatePanelContant(parent_panel, v)

        local remove_button = PD.Button("Remove", parent_panel, function()
            tbl[k] = nil
            PD.DM.UI.SaveTable(tbl, val)
            parent_panel:Remove()
        end, false)
        remove_button:Dock(BOTTOM)

        local save_button = PD.Button("Save", parent_panel, function()
            for k2, v2 in pairs(v) do
                if type(v2) == "string" then
                    tbl[k][k2] = elements[k2]:GetValue()
                elseif type(v2) == "number" then
                    tbl[k][k2] = tonumber(elements[k2]:GetValue(), 10)
                    if tbl[k][k2] == nil then
                        tbl[k][k2] = v2
                        PD.Notify("Value mismatch", Color(255, 0, 0, 255))
                    end
                end
            end

            PD.DM.UI.SaveTable(tbl, val)
        end, false)
        save_button:Dock(BOTTOM)

        parent_panel:SetSize(parent_panel:GetWide(), count * save_button:GetTall())
    end
end

function PD.DM.UI.CreatePanelContant(parent_panel, v)
    local count = 2
    local elements = {}

    for k2, v2 in pairs(v) do
        local child_panel = PD.Panel("", parent_panel)
        child_panel:Dock(TOP)
        child_panel:SetTall(PD.H(35))

        if type(v2) == "table" then

            local btn = PD.Button("Show Subtable", child_panel, function()
                parent_panel:Clear()

                PD.DM.UI.CreatePanelContant(parent_panel, v2)
            end)
            btn:Dock(FILL)
        elseif type(v2) == "string" then
            local label = PD.Label(k2 .. ":", child_panel)
            label:Dock(LEFT)

            local te = PD.TextEntry(k2, child_panel, v2)
            te:Dock(FILL)

            elements[k2] = te
        elseif type(v2) == "number" then
            local ns = PD.NumSlider("nadnkjawdnk", child_panel, 0, 100, v2, function()

            end)

            elements[k2] = ns
        elseif type(v2) == "boolean" then

        end

        count = count + 1.4
    end

    return count, elements
end

function PD.DM.UI.SaveTable(tbl, val)
    main_tbl[val] = tbl

    net.Start("PD.DM.UI.SaveTable")
    net.WriteTable(main_tbl)
    net.SendToServer()
end

---------------------------------------------------------------------------------
local medical_tbl = {}
local patient = nil
local triage_referenc_tbl = {
    [0] = {"non", Color(255, 255, 255, 255)},
    [1] = {"delayed", Color(255, 255, 0, 255)},
    [2] = {"asap", Color(255, 150, 0, 255)},
    [3] = {"immediately", Color(255, 0, 0, 255)}
}
local body_part_index = 0
local action_panel = 1

net.Receive("PD.DM.UI.OpenTreatmentInterface", function()
    medical_tbl = net.ReadTable()
    patient = net.ReadEntity()

    PD.DM.UI.OpenTreatmentInterface()
end)
    
local function interact(task_class, task_tbl)
    local interaction_panel = PD.Panel("", PD.DM.UI.Frame)
    interaction_panel:Dock(NODOCK)

    local prog = PD.Progress(interaction_panel, 0)

    interaction_panel:SetSize(PD.DM.UI.Frame:GetWide(), interaction_panel:GetTall())
    interaction_panel:SetPos(0, PD.DM.UI.Frame:GetTall() / 2 - interaction_panel:GetTall() / 2)

    timer.Create("PD.DM.interact." .. task_tbl.name .. patient:SteamID64(), 1, task_tbl.task_time, function()
        if prog:GetProgress() < 1.0 then
            prog:SetProgress(prog:GetProgress() + 1 / task_tbl.task_time)
        end

        if math.Round(prog:GetProgress(), 1) >= 1.0 then
            PD.DM.UI.Frame:Remove()
            PD.DM.Main.Interact(task_class, task_tbl, patient)
            --PD.Notify("Medication administered: " .. task_tbl.name, Color(0, 255, 0, 255))
        end
    end)
end

local function time_format(seconds)
    return os.date( "%H:%M:%S - %d/%m/%Y" , seconds )
end

local function create_bottom_module(pnl_2)

    local scrl = PD.Scroll(pnl_2)

    if not table.IsEmpty(medical_tbl.activity_log) then
        for k, v in pairs(medical_tbl.activity_log) do
            PD.Label(time_format(v.time) .. " | " .. v.str, scrl)
        end
    end
end

local function CreateButtons(tbl, content_scrl, action)
    local i = 0

    for k, v in SortedPairs(tbl) do
        if not v.requires_medic or (v.requires_medic and PD.DM.IsMedic(LocalPlayer())) then
            if v.body_part and not table.HasValue(v.body_part, body_part_index) then
                continue
            end

            i = i + 1

            local btn = PD.Button(v.name, content_scrl, function()
                interact(action, v)
            end)
            btn:Dock(TOP)
            btn:SetTall(PD.H(30))
        end
    end

    if table.IsEmpty(tbl) or i == 0 then
        PD.Label("No " .. action .. " available", content_scrl, Color(255, 255, 255, 255))
    end
end

local function create_treatment_content(treatment_pnl)
    local top_pnl = PD.Panel("", treatment_pnl)
    top_pnl:Dock(TOP)
    top_pnl:SetTall(PD.H(50))

    local btn_list = {
        [1] = {"Diagnostics", Color(0, 255, 0, 255)},
        [2] = {"Treatment", Color(0, 0, 255, 255)},
        [3] = {"Medication", Color(255, 0, 0, 255)}
    }

    for k, v in SortedPairs(btn_list) do
        local btn = PD.Button(v[1], top_pnl, function()
            action_panel = k
            PD.DM.UI.OpenTreatmentInterface()
        end)
        btn:Dock(LEFT)
        btn:SetTextColor(v[2])
        btn:SetHoverColor(v[2])
        btn:SetOutlineColor(v[2])
    end

    local content_scrl = PD.Scroll(treatment_pnl)
    content_scrl:Dock(FILL)
    content_scrl:DockMargin(PD.W(0), PD.H(10), PD.W(0), PD.H(0))
    content_scrl:SetSize(treatment_pnl:GetWide(), treatment_pnl:GetTall() - top_pnl:GetTall())
    content_scrl:Clear()
    if action_panel == 1 then
        CreateButtons(PD.DM.Diagnostics.tbl, content_scrl, "Diagnostics")
    elseif action_panel == 2 then
        CreateButtons(PD.DM.Treatments.tbl, content_scrl, "Treatment")
    elseif action_panel == 3 then
        CreateButtons(PD.DM.Medication.tbl, content_scrl, "Medication")
    end
end

local function create_body_content(body_pnl)
    -- Body
    local head = PD.Button("1", body_pnl, function()
        body_part_index = 1
        PD.DM.UI.OpenTreatmentInterface()
    end)
    head:SetSize(PD.W(65), PD.H(75))
    head:SetPos(body_pnl:GetWide() / 2 - head:GetWide() / 2, PD.H(150))

    local torso = PD.Button("2", body_pnl, function()
        body_part_index = 2
        PD.DM.UI.OpenTreatmentInterface()
    end)
    torso:SetSize(PD.W(100), PD.H(100))
    torso:SetPos(body_pnl:GetWide() / 2 - torso:GetWide() / 2, head:GetTall() + PD.H(150))

    local stomach = PD.Button("3", body_pnl, function()
        body_part_index = 3
        PD.DM.UI.OpenTreatmentInterface()
    end)
    stomach:SetSize(PD.W(100), PD.H(75))
    stomach:SetPos(body_pnl:GetWide() / 2 - stomach:GetWide() / 2, head:GetTall() + torso:GetTall() + PD.H(150))

    local left_arm = PD.Button("5", body_pnl, function()
        body_part_index = 5
        PD.DM.UI.OpenTreatmentInterface()
    end)
    left_arm:SetSize(PD.W(30), PD.H(150))
    left_arm:SetPos(body_pnl:GetWide() / 2 - torso:GetWide() / 2 - left_arm:GetWide(), head:GetTall() + PD.H(175))
    if medical_tbl.body_part[5].tourniquet then
        left_arm:SetOutlineColor(Color(0, 0, 255, 255))
    end

    local right_arm = PD.Button("4", body_pnl, function()
        body_part_index = 4
        PD.DM.UI.OpenTreatmentInterface()
    end)
    right_arm:SetSize(PD.W(30), PD.H(150))
    right_arm:SetPos(body_pnl:GetWide() / 2 + torso:GetWide() / 2, head:GetTall() + PD.H(175))
    if medical_tbl.body_part[4].tourniquet then
        right_arm:SetOutlineColor(Color(0, 0, 255, 255))
    end

    local left_leg = PD.Button("7", body_pnl, function()
        body_part_index = 7
        PD.DM.UI.OpenTreatmentInterface()
    end)
    left_leg:SetSize(PD.W(45), PD.H(175))
    left_leg:SetPos(body_pnl:GetWide() / 2 - left_leg:GetWide(),
        head:GetTall() + torso:GetTall() + stomach:GetTall() + PD.H(150))
    if medical_tbl.body_part[7].tourniquet then
        left_leg:SetOutlineColor(Color(0, 0, 255, 255))
    end

    local right_leg = PD.Button("6", body_pnl, function()
        body_part_index = 6
        PD.DM.UI.OpenTreatmentInterface()
    end)
    right_leg:SetSize(PD.W(45), PD.H(175))
    right_leg:SetPos(body_pnl:GetWide() / 2 + PD.W(5), head:GetTall() + torso:GetTall() + stomach:GetTall() + PD.H(150))
    if medical_tbl.body_part[6].tourniquet then
        right_leg:SetOutlineColor(Color(0, 0, 255, 255))
    end

    -- Triage
    local traige_card, btn = PD.ComboBox(triage_referenc_tbl[medical_tbl.triage_card][1], body_pnl, function(value)
        for k, v in SortedPairs(triage_referenc_tbl) do
            if v[1] == value then
                PD.DM.Main.Interact("triage_card", k, patient)
                return
            end
        end
    end)
    traige_card:Dock(TOP)

    for k, v in SortedPairs(triage_referenc_tbl) do
        -- chat.AddText(v[1])
        traige_card:AddChoice(v[1])
    end

    btn:SetHoverColor(triage_referenc_tbl[medical_tbl.triage_card][2])
    btn:SetTextColor(triage_referenc_tbl[medical_tbl.triage_card][2])
    btn:SetOutlineColor(triage_referenc_tbl[medical_tbl.triage_card][2])

    local l = PD.Label("L", body_pnl, Color(255, 255, 255, 125))
    l:SetFont("MLIB.100")
    l:SizeToContents()
    l:Dock(RIGHT)
    local r = PD.Label("R", body_pnl, Color(255, 255, 255, 125))
    r:SetFont("MLIB.100")
    r:SizeToContents()
    r:Dock(LEFT)
end

local function create_overwive_content(overwive_pnl)
    local body_status = PD.Label("Body Status:" or "Kein Körperteil wurde Ausgewählt!", overwive_pnl,
        Color(255, 255, 255, 255))

    local blood_loss = PD.Label("Hat kein Blut verloren", overwive_pnl, Color(0, 255, 0, 255))
    if medical_tbl.blood_amount < 5.5 and medical_tbl.blood_amount > 5.3 then
        blood_loss:SetText("Hat eine kleine Menge Blut verloren")
        blood_loss:SetTextColor(Color(255, 200, 0, 255))
    elseif medical_tbl.blood_amount < 5.3 and medical_tbl.blood_amount > 4.8 then
        blood_loss:SetText("Hat eine große Menge Blut verloren")
        blood_loss:SetTextColor(Color(255, 125, 0, 255))
    elseif medical_tbl.blood_amount < 4.8 then
        blood_loss:SetText("Hat eine fatale Menge Blut verloren")
        blood_loss:SetTextColor(Color(255, 50, 0, 255))
    end

    local pain_level = PD.Label("Hat keine Schmerzen", overwive_pnl, Color(0, 255, 0, 255))
    if medical_tbl.pain_level == 1 then
        pain_level:SetText("Hat Leichte Schmerzen")
        pain_level:SetTextColor(Color(255, 200, 0, 255))
    elseif medical_tbl.pain_level == 2 then
        pain_level:SetText("Hat Mittlere Schmerzen")
        pain_level:SetTextColor(Color(255, 125, 0, 255))
    elseif medical_tbl.pain_level == 3 then
        pain_level:SetText("Hat Schwere Schmerzen")
        pain_level:SetTextColor(Color(255, 50, 0, 255))
    elseif medical_tbl.pain_level >= 4 then
        pain_level:SetText("Hat Kritische Schmerzen")
        pain_level:SetTextColor(Color(255, 0, 0, 255))
    end

    if body_part_index == 0 then
        return
    end

    local body_part_status = PD.Label(medical_tbl.body_part[body_part_index].name .. " Status:" or
                                          "Kein Körperteil wurde Ausgewählt!", overwive_pnl, Color(255, 255, 255, 255))

    local bleeding = PD.Label("Blutet nicht", overwive_pnl, Color(0, 255, 0, 255))
    if medical_tbl.body_part[body_part_index].bleading_level ~= 0 then
        bleeding:SetText("Blutet")
        bleeding:SetTextColor(Color(255, 255 / (medical_tbl.body_part[body_part_index].bleading_level * 10), 0, 255))
    end

    local fractured = PD.Label("Weißt keine Frakture auf", overwive_pnl, Color(0, 255, 0, 255))
    if medical_tbl.body_part[body_part_index].fractured then
        fractured:SetText("Weißt eine Frakture auf")
        fractured:SetTextColor(Color(255, 0, 0, 255))
    end

    if medical_tbl.body_part[body_part_index].tourniquet ~= nil then
        local tourniquet = PD.Label("Kein Tourniquet wurde angelegt", overwive_pnl, Color(0, 255, 0, 255))
        if medical_tbl.body_part[body_part_index].tourniquet then
            tourniquet:SetText("Ein Tourniquet wurde angelegt")
            tourniquet:SetTextColor(Color(0, 0, 255, 255))
        end
    end

    local fractured = PD.Label("Verletzungen:", overwive_pnl, Color(255, 255, 255, 255))

    local injury_scrl = PD.Scroll(overwive_pnl)

    for k, v in SortedPairs(medical_tbl.injureys) do
        if v.wo == body_part_index then
            PD.Label(v.name, injury_scrl, Color(255, 255, 255, 255))
        end
    end
end

local function create_top_modules(pnl_1)
    -- module 1 Treatment
    local treatment_pnl = PD.Panel("Treatment", pnl_1, function(self, w, h)
        surface.SetDrawColor(255, 255, 255, 128)
        surface.DrawOutlinedRect(0, 0, w, h, 5)
    end)
    treatment_pnl:Dock(LEFT)
    treatment_pnl:DockMargin(PD.W(0), PD.H(0), PD.W(0), PD.H(0))
    treatment_pnl:SetSize(pnl_1:GetWide() / 3, pnl_1:GetTall())

    create_treatment_content(treatment_pnl)

    -- module 2 Body & Triage
    local body_pnl = PD.Panel("Body & Triage", pnl_1, function(self, w, h)
        surface.SetDrawColor(255, 255, 255, 128)
        surface.DrawOutlinedRect(0, 0, w, h, 5)
    end)
    body_pnl:Dock(LEFT)
    body_pnl:DockMargin(PD.W(0), PD.H(0), PD.W(0), PD.H(0))
    body_pnl:SetSize(pnl_1:GetWide() / 3, pnl_1:GetTall())

    create_body_content(body_pnl)

    -- module 3 Overwive & Vitals
    local overwive_pnl = PD.Panel("Overwive & Vitals", pnl_1, function(self, w, h)
        surface.SetDrawColor(255, 255, 255, 128)
        surface.DrawOutlinedRect(0, 0, w, h, 5)
    end)
    overwive_pnl:Dock(LEFT)
    overwive_pnl:DockMargin(PD.W(0), PD.H(0), PD.W(0), PD.H(0))
    overwive_pnl:SetSize(pnl_1:GetWide() / 3, pnl_1:GetTall())

    create_overwive_content(overwive_pnl)
end

function PD.DM.UI.OpenTreatmentInterface()
    if PD.DM.IsMedic(LocalPlayer()) then
        print("Player is medic")
    else
        print("Player is not medic")
    end

    if IsValid(PD.DM.UI.Frame) then
        PD.DM.UI.Frame:Remove()
    end

    PD.DM.UI.Frame = PD.Frame(patient:Nick() or "Medical Interface", PD.W(ScrW() / 1.5), PD.H(ScrH() / 1.5), true)
    PD.DM.UI.Frame.OnClose = function()
        PD.DM.Main.Interact("activ_interaktion", {}, LocalPlayer())
    end

    local pnl_1 = PD.Panel("", PD.DM.UI.Frame)
    pnl_1:Dock(TOP)
    pnl_1:SetSize(PD.DM.UI.Frame:GetWide() - PD.W(20),
        (PD.DM.UI.Frame:GetTall() / 4) * 3 - PD.DM.UI.Frame:GetChild(5):GetTall())
    pnl_1:DockMargin(PD.W(10), PD.H(0), PD.W(10), PD.H(0))

    local pnl_2 = PD.Panel("Activity Log", PD.DM.UI.Frame, function(self, w, h)
        surface.SetDrawColor(255, 255, 255, 128)
        surface.DrawOutlinedRect(0, 0, w, h, 5)
    end)
    pnl_2:Dock(BOTTOM)
    pnl_2:SetSize(PD.DM.UI.Frame:GetWide() - PD.W(20), PD.DM.UI.Frame:GetTall() / 4)
    pnl_2:DockMargin(PD.W(10), PD.H(0), PD.W(10), PD.H(10))

    create_bottom_module(pnl_2)

    create_top_modules(pnl_1)
end