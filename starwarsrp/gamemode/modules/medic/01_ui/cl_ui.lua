PD.DM = PD.DM or {}
PD.DM.HUD = PD.DM.HUD or {}
PD.DM.UI = PD.DM.UI or {}

local medical_tbl = {}
local patient = nil
local triage_referenc_tbl = {
    [0] = {LANG.DM_UI_TRIAGE_NON, Color(255, 255, 255, 255), Color(0, 0, 0, 255)},
    [1] = {LANG.DM_UI_TRIAGE_DELAYED, Color(0, 150, 0, 255), Color(255, 255, 255, 255)},
    [2] = {LANG.DM_UI_TRIAGE_ASAP, Color(255, 125, 0, 255), Color(255, 255, 255, 255)},
    [3] = {LANG.DM_UI_TRIAGE_IMMEDIATELY, Color(255, 0, 0, 255), Color(255, 255, 255, 255)},
    [4] = {LANG.DM_UI_TRIAGE_DECEASED, Color(0, 0, 0, 255), Color(255, 255, 255, 255)}
}

local body_background = "medical/body/background.png"

local body_part_reference_btn_tbl = {
    [1] = {LANG.DM_UI_BODY_HEAD, PD.W(52), PD.H(70), PD.W(230), PD.H(34)}, -- Name, Width, Height, PosX, PosY
    [2] = {LANG.DM_UI_BODY_TORSO, PD.W(72), PD.H(150), PD.W(220), PD.H(100)},
    [4] = {LANG.DM_UI_BODY_LEFT_ARM, PD.W(53), PD.H(200), PD.W(292), PD.H(100)},
    [5] = {LANG.DM_UI_BODY_RIGHT_ARM, PD.W(53), PD.H(200), PD.W(168), PD.H(100)},
    [6] = {LANG.DM_UI_BODY_LEFT_LEG, PD.W(50), PD.H(250), PD.W(255), PD.H(250)},
    [7] = {LANG.DM_UI_BODY_RIGHT_LEG, PD.W(50), PD.H(250), PD.W(210), PD.H(250)}
}
local body_part_index = 0
local action_panel = 1
local interacting = false
local body_part_index_changed = false
local old_triage = -1
local medical_tbl_old = {}

net.Receive("PD.DM.UI.OpenTreatmentInterface", function()
    medical_tbl = {}

    medical_tbl = net.ReadTable()
    patient = net.ReadEntity()

    if not IsValid(patient) or not medical_tbl or not medical_tbl.puls or interacting then
        return
    end

    local in_list = false
    
    for k, v in pairs(medical_tbl.activ_interaktion) do
        if v == LocalPlayer():SteamID64() then
            in_list = true
            break
        end
    end

    medical_tbl_old = table.Copy(medical_tbl)

    if in_list and LocalPlayer():Alive() then
        PD.DM.UI.OpenTreatmentInterface()
    end
end)

local function interact(task_class, task_index, task_tbl, task_name)
    interacting = true
    PD.DM.UI.Frame:Remove()
    PD.DM.UI.Frame = nil

    local interaction_panel = PD.Frame("", ScrW() / 1.5, PD.H(150), false, {noPaint = true})
    interaction_panel:SetPos(ScrW() / 2 - interaction_panel:GetWide() / 2, ScrH() / 4)
    interaction_panel:MakePopup()

    local prog = PD.Progress(interaction_panel, 0, {label = task_name .. " | ".. LANG.DM_UI_TIME_LEFT .. " " .. task_tbl.time .. " " .. LANG.DM_UI_SECONDS})
    prog:Dock(FILL)
    prog:DockMargin(0, 0, 0, 0)

    

    timer.Create("PD.DM.interact." .. task_index .. patient:SteamID64(), 1, task_tbl.time, function()
        local progress = prog:GetValue()

        if progress < 1.0 then
            prog:SetValue(progress + 1 / task_tbl.time)
            prog:SetLabel(task_name .. " | ".. LANG.DM_UI_TIME_LEFT .. " " .. math.Round(task_tbl.time - (prog:GetValue() * task_tbl.time), 1) .. " " .. LANG.DM_UI_SECONDS)
        end

        if math.Round(prog:GetValue(), 1) >= 1.0 then
            interaction_panel:Remove()
            PD.DM.Main.Interact(task_class, task_index, patient, body_part_index)
            timer.Remove("PD.DM.interact." .. task_index .. patient:SteamID64())
            interacting = false
        end

        if not IsValid(LocalPlayer()) or not LocalPlayer():Alive() then
            interaction_panel:Remove()
            timer.Remove("PD.DM.interact." .. task_index .. patient:SteamID64())
            interacting = false
        end
    end)
end

local function time_format(seconds)
    return os.date("%H:%M:%S", seconds)
end

local function CreateButtons(tbl, content_scrl, action, no_action_text)
    local has_injury = false

    local i = 0

    if body_part_index == 0 then
        PD.Label(LANG.DM_UI_SELECT_BODY_PART, content_scrl, Color(255, 255, 255, 255))
        return
    end

    for k, v in SortedPairs(tbl) do
        if v.condition(LocalPlayer(), medical_tbl, body_part_index, patient) then
            local btn = PD.Button(v.name, content_scrl, function()
                interact(action_panel, k, v, v.name)
            end)
            btn:Dock(TOP)
            btn:SetTall(PD.H(40))

            i = i + 1
        end
    end

    if tbl == nil or table.IsEmpty(tbl) or i == 0 then

        PD.Label(no_action_text, content_scrl, Color(255, 255, 255, 255))
        return
    end
end

local function create_treatment_content(treatment_pnl)
    local top_pnl = PD.Panel(treatment_pnl)
    top_pnl:Dock(TOP)
    top_pnl:SetTall(PD.H(64))

    local btn_list = {
        [1] = {"medical/symbol1.png", Color(0, 255, 0, 255)},
        [2] = {"medical/symbol2.png", Color(0, 0, 255, 255)},
        [3] = {"medical/symbol3.png", Color(255, 0, 0, 255)},
        [4] = {"medical/symbol4.png", Color(255, 0, 0, 255)}
    }

    for k, v in SortedPairs(btn_list) do
        local btn = PD.ImageButton(top_pnl, v[1], PD.W(64), PD.H(64), function()
            action_panel = k
            body_part_index_changed = true
            PD.DM.UI.OpenTreatmentInterface()
        end)
        btn:Dock(LEFT)
    end

    local content_scrl = PD.Scroll(treatment_pnl)
    content_scrl:Dock(FILL)
    content_scrl:DockMargin(PD.W(0), PD.H(10), PD.W(0), PD.H(0))
    content_scrl:SetSize(treatment_pnl:GetWide(), treatment_pnl:GetTall() - top_pnl:GetTall())
    content_scrl:Clear()
    if action_panel == 1 then
        CreateButtons(PD.DM.Diagnostics.tbl, content_scrl, LANG.DM_UI_DIAGNOSIS, LANG.DM_UI_NO_DIAGNOSIS_AVAILABLE)
    elseif action_panel == 2 then
        CreateButtons(PD.DM.Medication.tbl, content_scrl, LANG.DM_UI_MEDICATION, LANG.DM_UI_NO_MEDICATION_AVAILABLE)
    elseif action_panel == 3 then
        CreateButtons(PD.DM.Treatments.tbl, content_scrl, LANG.DM_UI_TREATMENT, LANG.DM_UI_NO_TREATMENT_AVAILABLE)
    elseif action_panel == 4 then
        CreateButtons(PD.DM.Other.tbl, content_scrl, LANG.DM_UI_OTHER, LANG.DM_UI_NO_OTHER_AVAILABLE)
    end
end

local function create_body(body_pnl)
    local body_part_reference_img_tbl = {
        [1] = {"medical/body/head", false, false, false}, -- Name, Image, IsInjured, IsTourniquet, IsFractured
        [2] = {"medical/body/torso", false, false, false},
        [4] = {"medical/body/arm_left", false, false, false},
        [5] = {"medical/body/arm_right", false, false, false},
        [6] = {"medical/body/leg_left", false, false, false},
        [7] = {"medical/body/leg_right", false, false, false}
    }

    for k, v in SortedPairs(medical_tbl.injuries) do
        if v.wo == 3 then
            v.wo = 2
        end

        if v.wo ~= nil and v.wo ~= 0 then
            body_part_reference_img_tbl[v.wo][2] = true
        end
    end

    for k, v in SortedPairs(medical_tbl.body_part) do
        if v.tourniquet then
            body_part_reference_img_tbl[k][3] = true
        end

        if v.fractured then
            body_part_reference_img_tbl[k][4] = true
        end
    end

    -- Definieren, wie viele logische Zeilen und Spalten Ihr Bild hat

    if PD.DM.UI.ImgBase and IsValid(PD.DM.UI.ImgBase) then
        PD.DM.UI.ImgBase:Remove()
    end

    PD.DM.UI.ImgBase = PD.Panel(body_pnl)
    PD.DM.UI.ImgBase:Dock(NODOCK)
    PD.DM.UI.ImgBase:SetSize(body_pnl:GetWide(), body_pnl:GetTall() - PD.H(50)) -- btn:GetTall())
    PD.DM.UI.ImgBase:SetPos(0, PD.H(50) - PD.H(15))
    PD.DM.UI.ImgBase:SetBackColor(Color(0, 0, 0, 0))

    local backgroundImage = PD.Image(PD.DM.UI.ImgBase, "", body_background)
    backgroundImage:Dock(FILL)

    for _, v in SortedPairs(body_part_reference_img_tbl) do

        if body_part_index == _ then
            local body_frame_pnl, body_frame = PD.Image(PD.DM.UI.ImgBase, "", v[1] .. "_s.png")
            body_frame_pnl:Dock(FILL)
        end

        if v[2] then
            local body_injured_pnl, body_injured = PD.Image(PD.DM.UI.ImgBase, "", v[1] .. ".png")
            body_injured_pnl:Dock(FILL)
            body_injured:SetImageColor(Color(255, 125, 0, 255))
        end

        if v[4] then
            local body_bone_pnl, body_bone = PD.Image(PD.DM.UI.ImgBase, "", v[1] .. "_b.png")
            body_bone_pnl:Dock(FILL)
            body_bone:SetImageColor(Color(255, 0, 0, 255))
        end

        if v[3] then
            local body_tourniquet_pnl, body_tourniquet = PD.Image(PD.DM.UI.ImgBase, "", v[1] .. "_t.png")
            body_tourniquet_pnl:Dock(FILL)
            body_tourniquet:SetImageColor(Color(0, 0, 255, 255))
        end
    end

    for _, v in SortedPairs(body_part_reference_btn_tbl) do
        local btn = PD.Button("", PD.DM.UI.ImgBase, function()
            body_part_index_changed = true
            body_part_index = _
            PD.DM.UI.OpenTreatmentInterface()
        end, {hideBox = true, disableSound = true})
        btn:Dock(NODOCK)
        btn:SetSize(v[2], v[3])
        btn:SetPos(v[4], v[5])
        btn:SetToolTip(v[1])
    end
end

local function create_body_content(body_pnl)
    -- Triage
    if not PD.DM.IsMedic(LocalPlayer()) then
        local label = PD.Label(triage_referenc_tbl[medical_tbl.triage_card][1], body_pnl, Color(255, 255, 255, 255))
        label:Dock(NODOCK)
        label:SetFont("MLIB.30")
        label:SizeToContents()
        label:SetPos(body_pnl:GetWide() / 2 - label:GetWide() / 2, PD.H(10))
        label:SetTextColor(triage_referenc_tbl[medical_tbl.triage_card][2])
    else
        local btn = PD.Dropdown(body_pnl, triage_referenc_tbl[medical_tbl.triage_card][1], function(value)
            for k, v in pairs(triage_referenc_tbl) do
                if v[1] == value then
                    PD.DM.Main.Interact(0, k, patient)
                    return
                end
            end
        end)
        btn:Dock(TOP)

        for k, v in SortedPairs(triage_referenc_tbl) do
            btn:AddOption(v[1])
        end

        btn:SetTextColor(triage_referenc_tbl[medical_tbl.triage_card][3])
        --btn:SetBackColor(triage_referenc_tbl[medical_tbl.triage_card][2])
    end

    create_body(body_pnl)
    old_triage = medical_tbl.triage_card

    local l = PD.Label("L", body_pnl, Color(255, 255, 255, 125))
    l:SetFont("MLIB.75")
    l:SizeToContents()
    l:Dock(RIGHT)
    local r = PD.Label("R", body_pnl, Color(255, 255, 255, 125))
    r:SetFont("MLIB.75")
    r:SizeToContents()
    r:Dock(LEFT)
end

local function create_overview_content(overwive_pnl)

    if medical_tbl.vital_monitoring then
        PD.Label(LANG.DM_UI_VITALS .. ":", overwive_pnl, Color(255, 255, 255, 255))
        PD.Label(LANG.DM_UI_PULS .. ": " .. medical_tbl.puls .. " bpm", overwive_pnl, Color(255, 255, 255, 255))
        PD.Label(LANG.DM_UI_BLOOD_PRESSURE .. ": " .. medical_tbl.bp[1] .. "/" .. medical_tbl.bp[2] .. " mmHg", overwive_pnl, Color(255, 255, 255, 255))
        PD.Label(LANG.DM_UI_SPO2 .. ": " .. medical_tbl.spo2 .. " %", overwive_pnl, Color(255, 255, 255, 255))
        PD.Label(LANG.DM_UI_BREATHING_RATE .. ": " .. medical_tbl.respiratory_system.breathing_rate, overwive_pnl, Color(255, 255, 255, 255))
        local spacer1 = PD.Label("", overwive_pnl, Color(255, 255, 255, 255)) -- Spacer
        spacer1:SetTall(PD.H(2))
    end


    PD.Label(LANG.DM_UI_BODY_STATUS .. ":", overwive_pnl, Color(255, 255, 255, 255))

    local blood_loss = PD.Label(LANG.DM_UI_BLOOD_LOSS_NONE, overwive_pnl, Color(0, 255, 0, 255))
    if medical_tbl.blood_amount < 5.5 and medical_tbl.blood_amount > 4.0 then
        blood_loss:SetText(LANG.DM_UI_BLOOD_LOSS_MINOR)
        blood_loss:SetTextColor(Color(255, 200, 0, 255))
    elseif medical_tbl.blood_amount < 4.0 and medical_tbl.blood_amount > 3.0 then
        blood_loss:SetText(LANG.DM_UI_BLOOD_LOSS_SEVERE)
        blood_loss:SetTextColor(Color(255, 125, 0, 255))
    elseif medical_tbl.blood_amount < 3.0 then
        blood_loss:SetText(LANG.DM_UI_BLOOD_LOSS_FATAL)
        blood_loss:SetTextColor(Color(255, 50, 0, 255))
    end

    local pain_level = PD.Label(LANG.DM_UI_PAIN_NONE, overwive_pnl, Color(0, 255, 0, 255))
    if not patient:Alive() then
        pain_level:SetText(LANG.DM_UI_PAIN_UNCONSCIOUS)
        pain_level:SetTextColor(Color(255, 0, 0, 255))
    elseif medical_tbl.pain_level <= 1 and medical_tbl.pain_level > 0 then
        pain_level:SetText(LANG.DM_UI_PAIN_MINOR)
        pain_level:SetTextColor(Color(255, 200, 0, 255))
    elseif medical_tbl.pain_level == 2 then
        pain_level:SetText(LANG.DM_UI_PAIN_MODERATE)
        pain_level:SetTextColor(Color(255, 125, 0, 255))
    elseif medical_tbl.pain_level >= 3 then
        pain_level:SetText(LANG.DM_UI_PAIN_SEVERE)
        pain_level:SetTextColor(Color(255, 50, 0, 255))
    end

    local spacer2 = PD.Label("", overwive_pnl, Color(255, 255, 255, 255)) -- Spacer
    spacer2:SetTall(PD.H(2))

    if body_part_index == 0 then
        PD.Label(LANG.DM_UI_NO_BODY_PART_SELECTED, overwive_pnl, Color(255, 255, 255, 255))
        return
    end

    PD.Label(body_part_reference_btn_tbl[body_part_index][1], overwive_pnl,
        Color(255, 255, 255, 255))

    if medical_tbl.body_part[body_part_index].bleading_level ~= 0 then
        PD.Label(LANG.DM_UI_BLEEDING, overwive_pnl, Color(255, 255 / (medical_tbl.body_part[body_part_index].bleading_level * 10), 0, 255))
    end

    if medical_tbl.body_part[body_part_index].fractured then
        PD.Label(LANG.DM_UI_FRACTURE_PRESENT, overwive_pnl, Color(255, 0, 0, 255))
    end

    if medical_tbl.body_part[body_part_index].tourniquet ~= nil and medical_tbl.body_part[body_part_index].tourniquet then
        PD.Label(LANG.DM_UI_TOURNIQUET_APPLIED, overwive_pnl, Color(0, 0, 255, 255))
    end

    if medical_tbl.body_part[body_part_index].has_iv ~= nil and medical_tbl.body_part[body_part_index].has_iv then
        PD.Label(LANG.DM_UI_IV_APPLIED, overwive_pnl, Color(0, 0, 255, 255)):SetTextColor(Color(0, 0, 255, 255))
    end

    local spacer3 = PD.Label("", overwive_pnl, Color(255, 255, 255, 255)) -- Spacer
    spacer3:SetTall(PD.H(2))

    local tbl_injuries = {}
    for k, v in SortedPairs(medical_tbl.injuries) do
        if v.wo == body_part_index then
            if not tbl_injuries[v.name] then
                tbl_injuries[v.name] = 1
            else
                tbl_injuries[v.name] = tbl_injuries[v.name] + 1
            end
        end
        if  body_part_index == 2 and v.wo == 3 then
            if not tbl_injuries[v.name] then
                tbl_injuries[v.name] = 1
            else
                tbl_injuries[v.name] = tbl_injuries[v.name] + 1
            end
        end
    end

    if not table.IsEmpty(tbl_injuries) then
        PD.Label(LANG.DM_UI_INJURY_PRESENT .. ":", overwive_pnl, Color(255, 255, 255, 255))
    else
        return
    end

    local injury_scrl = PD.Scroll(overwive_pnl)

    for k, v in SortedPairs(tbl_injuries) do
        PD.Label(k .. ": x" .. v, injury_scrl, Color(255, 255, 255, 255))
    end
end

local function create_content(pnl)
    PD.DM.UI.TreatmentPanel = PD.Panel(pnl, {hideBox = true})
    PD.DM.UI.TreatmentPanel:Dock(LEFT)
    PD.DM.UI.TreatmentPanel:DockMargin(PD.W(0), PD.H(30), PD.W(0), PD.H(0))
    PD.DM.UI.TreatmentPanel:SetSize(pnl:GetWide() / 3, pnl:GetTall())
    create_treatment_content(PD.DM.UI.TreatmentPanel)

    -- module 2 Body & Triage
    PD.DM.UI.BodyPanel = PD.Panel(pnl, {hideBox = true})
    PD.DM.UI.BodyPanel:Dock(LEFT)
    PD.DM.UI.BodyPanel:DockMargin(PD.W(0), PD.H(30), PD.W(0), PD.H(0))
    PD.DM.UI.BodyPanel:SetSize(pnl:GetWide() / 3, pnl:GetTall())
    create_body_content(PD.DM.UI.BodyPanel)

    -- module 3 Overview & Vitals
    PD.DM.UI.OverviewPanel = PD.Panel(pnl, {hideBox = true})
    PD.DM.UI.OverviewPanel:Dock(LEFT)
    PD.DM.UI.OverviewPanel:DockMargin(PD.W(0), PD.H(30), PD.W(0), PD.H(0))
    PD.DM.UI.OverviewPanel:SetSize(pnl:GetWide() / 3, pnl:GetTall())
    create_overview_content(PD.DM.UI.OverviewPanel)
end

local function create_footer(pnl)

    local activity_scrl = PD.Scroll(pnl)
    activity_scrl:Dock(FILL)
    activity_scrl:SetWide(pnl:GetWide() / 2)
    activity_scrl:DockMargin(PD.W(0), PD.H(30), pnl:GetWide() / 2, PD.H(0))

    if not table.IsEmpty(medical_tbl.activity_log) then
        for k, v in pairs(medical_tbl.activity_log) do
            PD.Label(time_format(v.time) .. " | " .. v.str, activity_scrl)
        end
    end

    local quick_overview_scrl = PD.Scroll(pnl)
    quick_overview_scrl:Dock(FILL)
    quick_overview_scrl:SetWide(pnl:GetWide() / 2)
    quick_overview_scrl:DockMargin(pnl:GetWide() / 2, PD.H(30), PD.W(0), PD.H(0))

    if not table.IsEmpty(medical_tbl.quick_overview_log) then
        for k, v in pairs(medical_tbl.quick_overview_log) do
            PD.Label(time_format(v.time) .. " | " .. v.str, quick_overview_scrl)
        end
    end
end

local SpeakInMenu = false

local function ToggleSpeakInMenu()
    SpeakInMenu = not SpeakInMenu
    permissions.EnableVoiceChat(SpeakInMenu)
end

function PD.DM.UI.OpenTreatmentInterface()
    if IsValid(PD.DM.UI.Frame) then
        if IsValid(PD.DM.UI.TreatmentPanel) and IsValid(PD.DM.UI.BodyPanel) and (body_part_index_changed or old_triage ~= medical_tbl.triage_card) then
            PD.DM.UI.TreatmentPanel:Clear()
            create_treatment_content(PD.DM.UI.TreatmentPanel)

            body_part_index_changed = false
            PD.DM.UI.BodyPanel:Clear()
            create_body_content(PD.DM.UI.BodyPanel)
        end

        if IsValid(PD.DM.UI.OverviewPanel) then
            PD.DM.UI.OverviewPanel:Clear()
            create_overview_content(PD.DM.UI.OverviewPanel)
        end

        return
    end

    PD.DM.UI.Frame = PD.Frame(LANG.DM_UI_TITLE, ScrW() / 1.25,ScrH() / 1.25, true)
    PD.DM.UI.Frame.OnClose = function()
        PD.DM.Main.EndInteraction(patient)
        SpeakInMenu = false
        permissions.EnableVoiceChat( false )
    end

    PD.DM.UI.SpeakButton = vgui.Create("DButton", PD.DM.UI.Frame)
    PD.DM.UI.SpeakButton:SetSize(PD.W(30), PD.H(30))
    PD.DM.UI.SpeakButton:SetPos(PD.W(10), PD.H(8))
    PD.DM.UI.SpeakButton:SetText("")
    PD.DM.UI.SpeakButton._hover = 0
    PD.DM.UI.SpeakButton.Paint = function(self, w, h)
        local icon
        if SpeakInMenu then
            icon = "medical/mic_off.png"
        else
            icon = "medical/mic_on.png"
        end

        local hover = self:IsHovered()
        self._hover = Lerp(FrameTime() * 10, self._hover, hover and 1 or 0)

        local bgAlpha = 50 + self._hover * 150
        local col = PD.LerpColor(PD.Theme.Colors.AccentGray, PD.Theme.Colors.AccentRed, self._hover)
        draw.RoundedBox(0, 0, 0, w, h, Color(col.r, col.g, col.b, bgAlpha))

        surface.SetDrawColor(255, 255, 255, 255)
        surface.SetMaterial(Material(icon))
        surface.DrawTexturedRect(0, 0, w, h)
    end

    PD.DM.UI.SpeakButton.DoClick = function()
        ToggleSpeakInMenu()
    end

    PD.DM.UI.SpeakButton.OnCursorEntered = function()
            surface.PlaySound("UI/buttonrollover.wav")
        end

    PD.DM.UI.ContentPanel = PD.Panel(PD.DM.UI.Frame, nil, function(self, w, h)
        draw.DrawText(LANG.DM_UI_ACTIONS, "MLIB.25", w / 6, 0, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER)
        draw.DrawText(patient:Nick(), "MLIB.25", (w / 6) * 3, 0, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER)
        draw.DrawText(LANG.DM_UI_OVERVIEW, "MLIB.25", (w / 6) * 5, 0, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawLine(0, PD.H(30), w, PD.H(30))
    end)
    PD.DM.UI.ContentPanel:Dock(TOP)
    PD.DM.UI.ContentPanel:SetTall((PD.DM.UI.Frame:GetTall() - PD.H(5)) / 1.4) -- - PD.DM.UI.Frame.TopPanel:GetTall() - PD.H(5)) / 1.4)
    PD.DM.UI.ContentPanel:SetWide(PD.DM.UI.Frame:GetWide())
    PD.DM.UI.ContentPanel:DockMargin(PD.W(0), PD.H(5), PD.W(0), PD.H(0))

    PD.DM.UI.FooterPanel = PD.Panel(PD.DM.UI.Frame,  nil, function(self, w, h)
        draw.DrawText(LANG.DM_UI_ACTIVITY_LOG, "MLIB.25", w / 4, 0, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER)
        draw.DrawText(LANG.DM_UI_QUICK_INFO, "MLIB.25", (w / 4) * 3, 0, Color(255, 255, 255, 255), TEXT_ALIGN_CENTER)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawLine(0, PD.H(30), w, PD.H(30))
        surface.DrawLine(w / 2, PD.H(40), w / 2, h - PD.H(45))
    end)
    PD.DM.UI.FooterPanel:Dock(TOP)
    PD.DM.UI.FooterPanel:SetTall(PD.DM.UI.Frame:GetTall() - PD.DM.UI.ContentPanel:GetTall() - PD.H(5)) --  - PD.DM.UI.Frame.TopPanel:GetTall() - PD.DM.UI.ContentPanel:GetTall() - PD.H(5))
    PD.DM.UI.FooterPanel:SetWide(PD.DM.UI.Frame:GetWide())
    PD.DM.UI.FooterPanel:DockMargin(PD.W(0), PD.H(5), PD.W(0), PD.H(0))

    create_content(PD.DM.UI.ContentPanel)

    create_footer(PD.DM.UI.FooterPanel)
end

-- Vitalwerte Indikator

local puls = 0
local spo2 = 0
local last_check = 0
local delay = 1

AddSmoothElement(ScrW() - PD.W(170), ScrH() - PD.H(205), PD.W(150), PD.H(100), function(smoothX, smoothY)
    if PD.FOV.thirdPerson then return end

    local ply = LocalPlayer()

    if CurTime() - last_check >= delay then
        puls = ply:GetNW2Int("PD.DM.Puls")
        spo2 = ply:GetNW2Int("PD.DM.SPO2")
        last_check = CurTime()
    end
    
    if PD.IsBetween(puls, 60, 180) and PD.IsBetween(spo2, 60, 180) then
        if IsValid(PD.DM.IndikatorFrame) then
            PD.DM.IndikatorFrame:Remove()
        end
        return
    end

    local ply = LocalPlayer()
    surface.SetFont("MLIB.24")
    local panelW = PD.W(150)
    local panelH = PD.H(100)

    -- Hintergrund Panel
    PD.DrawPanel(smoothX, smoothY, panelW, panelH, {
        background = PD.Theme.Colors.BackgroundLight,
        accent = PD.Theme.Colors.AccentRed,
        accentTop = false,
        accentBottom = false,
        corners = false,
        borders = false
    })

    -- Linke Akzentlinie (Imperial Red)
    surface.SetDrawColor(PD.Theme.Colors.AccentRed)
    surface.DrawRect(smoothX + panelW - PD.W(4), smoothY,PD.W(4), panelH)

    -- Obere Linie
    surface.SetDrawColor(PD.Theme.Colors.AccentGray)
    surface.DrawRect(smoothX + PD.W(4), smoothY, panelW - PD.W(4), 1)

    -- Untere Linie
    surface.DrawRect(smoothX + PD.W(4), smoothY + panelH - 1, panelW - PD.W(4), 1)

    -- Trennlinie unter dem Namen
    PD.DrawDivider(smoothX + PD.W(15), smoothY + PD.H(38), panelW - PD.W(30))

    -- Linke Eck-Dekor
        local cornerSize = PD.W(8)
        surface.DrawLine(smoothX, smoothY, smoothX + cornerSize, smoothY)
        surface.DrawLine(smoothX, smoothY, smoothX, smoothY + cornerSize)
        surface.DrawLine(smoothX, smoothY + panelH - 1, smoothX + cornerSize, smoothY + panelH - 1)
        surface.DrawLine(smoothX, smoothY + panelH - cornerSize, smoothX, smoothY + panelH - 1)

    -- Titel
    draw.DrawText("Vitalwerte", "MLIB.24", smoothX + panelW / 2, smoothY + PD.H(10), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)

    -- Puls Anzeige
    draw.DrawText("Puls: " .. puls .. " bpm", "MLIB.18", smoothX + panelW / 2, smoothY + PD.H(45), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)

    -- SPO2 Anzeige
    draw.DrawText("SPO2: " .. spo2 .. " %", "MLIB.18", smoothX + panelW / 2, smoothY + PD.H(70), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
end)

hook.Add("OnPauseMenuShow", "PD.Chat.CloseOnPauseMenuShow", function()
    if IsValid(PD.DM.UI.Frame) then
        PD.DM.Main.EndInteraction(patient)

        PD.DM.UI.Frame:Remove()
    end
end)