WarningSystem = WarningSystem or {}
WarningSystem.ConfigGUI = WarningSystem.ConfigGUI or {}

local configFrame = nil

net.Receive("WarningSystem_OpenConfig", function()
    WarningSystem.ConfigGUI:OpenMenu()
end)

function WarningSystem.ConfigGUI:OpenMenu()
    if IsValid(configFrame) then
        configFrame:Remove()
    end

    configFrame = self:CreateConfigFrame()
end

function WarningSystem.ConfigGUI:CreateConfigFrame()
    local frame = PD.Frame("Warning System - Configuration", PD.W(700), PD.H(600), true)
    frame:SetDraggable(true)

    local scroll = PD.Scroll(frame.FillPanel)

    -- Warning Settings Header
    self:CreateHeader(scroll, "Warning Settings")

    -- Maximum Warnings
    local maxWarnsPanel, maxWarnsSlider = PD.NumSlider(
        "Maximum Warnings",
        scroll,
        1,
        20,
        WarningSystem.Config:Get("MaxWarns"),
        function(value)
            WarningSystem.Config.Current.MaxWarns = value
        end
    )

    local maxWarnsDesc = PD.Label("Number of warnings before automatic action", maxWarnsPanel, getColor("Text"))
    maxWarnsDesc:SetFont("MLIB.15")

    -- Warn Decay Enabled
    local warnDecayPanel, warnDecayCheck = PD.SimpleCheck(
        scroll,
        "Enable Warn Decay - Warnings become inactive after a set time",
        WarningSystem.Config:Get("WarnDecayEnabled"),
        function(value)
            WarningSystem.Config.Current.WarnDecayEnabled = value
        end
    )
    warnDecayPanel:SetTall(PD.H(60))

    -- Warn Decay Time
    local warnDecayTimePanel = PD.Panel("Warn Decay Time", scroll)
    warnDecayTimePanel:SetTall(PD.H(90))

    local warnDecayDesc = PD.Label("Time until warnings become inactive", warnDecayTimePanel, getColor("Text"))
    warnDecayDesc:SetFont("MLIB.15")

    local warnDecayCombo = PD.ComboBox("1 Day", warnDecayTimePanel, function(choice, value)
        WarningSystem.Config.Current.WarnDecayTime = value
    end)
    warnDecayCombo:Dock(FILL)

    local timeOptions = {
        {label = "1 Hour", value = 3600},
        {label = "6 Hours", value = 21600},
        {label = "12 Hours", value = 43200},
        {label = "1 Day", value = 86400},
        {label = "3 Days", value = 259200},
        {label = "1 Week", value = 604800},
        {label = "2 Weeks", value = 1209600},
        {label = "1 Month", value = 2592000}
    }

    local currentDecayValue = WarningSystem.Config:Get("WarnDecayTime")
    for _, option in ipairs(timeOptions) do
        warnDecayCombo:AddChoice(option.label, option.value)
        if option.value == currentDecayValue then
            warnDecayCombo:SetText(option.label)
        end
    end

    -- Spacer
    self:CreateSpacer(scroll, PD.H(20))

    -- Ban Settings Header
    self:CreateHeader(scroll, "Ban Settings")

    -- Auto-Ban Enabled
    local autoBanPanel, autoBanCheck = PD.SimpleCheck(
        scroll,
        "Enable Auto-Ban - Automatically ban players after reaching max warnings",
        WarningSystem.Config:Get("AutoBanEnabled"),
        function(value)
            WarningSystem.Config.Current.AutoBanEnabled = value
        end
    )
    autoBanPanel:SetTall(PD.H(60))

    -- Ban Duration
    local banDurationPanel = PD.Panel("Auto-Ban Duration", scroll)
    banDurationPanel:SetTall(PD.H(90))

    local banDurationDesc = PD.Label("Duration of automatic bans", banDurationPanel, getColor("Text"))
    banDurationDesc:SetFont("MLIB.15")

    local banDurationCombo = PD.ComboBox("1 Day", banDurationPanel, function(choice, value)
        WarningSystem.Config.Current.BanDuration = value
    end)
    banDurationCombo:Dock(FILL)

    local currentBanValue = WarningSystem.Config:Get("BanDuration")
    for _, option in ipairs(timeOptions) do
        banDurationCombo:AddChoice(option.label, option.value)
        if option.value == currentBanValue then
            banDurationCombo:SetText(option.label)
        end
    end

    -- Spacer
    self:CreateSpacer(scroll, PD.H(20))

    -- Permission Settings Header
    self:CreateHeader(scroll, "Permission Settings")

    -- Permissions Panel
    local permPanel = PD.Panel("Allowed User Groups", scroll)
    permPanel:SetTall(PD.H(90))

    local permDesc = PD.Label("Comma separated (superadmin, admin, moderator)", permPanel, getColor("Text"))
    permDesc:SetFont("MLIB.15")

    -- Build current permissions string
    local perms = {}
    for group, _ in pairs(WarningSystem.Config.Current.AdminFlags) do
        table.insert(perms, group)
    end

    local permEntry = PD.TextEntry("superadmin, admin, moderator", permPanel, table.concat(perms, ", "))
    permEntry:Dock(FILL)

    -- Spacer
    self:CreateSpacer(scroll, PD.H(20))

    -- Save Button
    local saveBtn = PD.Button("Save Configuration", scroll, function()
        -- Parse and save permissions
        local permString = permEntry:GetValue()
        local newPerms = {}
        for group in string.gmatch(permString, "([^,]+)") do
            group = string.Trim(group)
            if group ~= "" then
                newPerms[group] = true
            end
        end

        WarningSystem.Config.Current.AdminFlags = newPerms

        -- Send all settings to server
        for key, value in pairs(WarningSystem.Config.Current) do
            if key ~= "AdminFlags" then
                self:SendConfigUpdate(key, value)
            end
        end

        -- Send permissions separately
        self:SendConfigUpdate("AdminFlags", newPerms)

        chat.AddText(getColor("Green"), "[Warning System] ", getColor("Text"), "Configuration saved!")
        frame:Close()
    end)
    saveBtn:Dock(TOP)
    saveBtn:SetTall(PD.H(50))
    saveBtn:SetHoverColor(getColor("Green"))

    -- Reset Button
    local resetBtn = PD.Button("Reset to Defaults", scroll, function()
        Derma_Query("Reset all settings to default values?", "Confirm Reset", "Yes", function()
            for key, value in pairs(WarningSystem.Config.Defaults) do
                self:SendConfigUpdate(key, value)
            end
            frame:Close()
        end, "No")
    end)
    resetBtn:Dock(TOP)
    resetBtn:SetTall(PD.H(40))
    resetBtn:SetHoverColor(getColor("SithRed"))

    return frame
end

function WarningSystem.ConfigGUI:CreateHeader(parent, text)
    local header = PD.Panel("", parent)
    header:SetTall(PD.H(35))
    header:DockMargin(PD.H(0), PD.H(15), PD.H(0), PD.H(15))
    header:SetBackColor(Color(0, 0, 0, 0))

    local headerLabel = PD.Label(text, header, getColor("Text"))
    headerLabel:SetFont("MLIB.25")
    headerLabel:Dock(FILL)
    headerLabel:SetContentAlignment(4) -- Left align

    -- Override paint to add accent bar and line
    local oldPaint = header.Paint
    header.Paint = function(self, w, h)
        -- Left accent bar
        surface.SetDrawColor(getColor("SithRed"))
        surface.DrawRect(0, 0, PD.W(4), h)

        -- Bottom line
        surface.SetDrawColor(ColorAlpha(getColor("SithRed"), 50))
        surface.DrawRect(0, h - 1, w, 1)
    end
end

function WarningSystem.ConfigGUI:CreateSpacer(parent, height)
    local spacer = PD.Panel("", parent)
    spacer:SetTall(height)
    spacer:SetBackColor(Color(0, 0, 0, 0))
end

function WarningSystem.ConfigGUI:SendConfigUpdate(key, value)
    net.Start("WarningSystem_ConfigUpdate")
    net.WriteString(key)

    if type(value) == "number" then
        net.WriteString("number")
        net.WriteFloat(value)
    elseif type(value) == "boolean" then
        net.WriteString("bool")
        net.WriteBool(value)
    elseif type(value) == "string" then
        net.WriteString("string")
        net.WriteString(value)
    elseif type(value) == "table" then
        net.WriteString("table")
        net.WriteTable(value)
    end

    net.SendToServer()
end

-- Console Command
concommand.Add("warnsystem_config", function()
    WarningSystem.ConfigGUI:OpenMenu()
end)
