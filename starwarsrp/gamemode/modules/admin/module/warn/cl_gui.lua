WarningSystem = WarningSystem or {}
WarningSystem.GUI = WarningSystem.GUI or {}

local mainFrame = nil

-- Open Menu
net.Receive("WarningSystem_OpenMenu", function()
    WarningSystem.GUI:OpenMenu()
end)

-- Receive data
net.Receive("WarningSystem_SendData", function()
    local onlinePlayers = net.ReadTable()
    local allPlayers = net.ReadTable()

    if IsValid(mainFrame) then
        mainFrame:PopulatePlayers(onlinePlayers, allPlayers)
    end
end)

-- Update trigger
net.Receive("WarningSystem_UpdateData", function()
    if IsValid(mainFrame) then
        mainFrame:RequestData()
    end
end)

function WarningSystem.GUI:OpenMenu()
    if IsValid(mainFrame) then
        mainFrame:Remove()
    end

    mainFrame = self:CreateMainFrame()
    mainFrame:RequestData()
end

function WarningSystem.GUI:CreateMainFrame()
    local frame = PD.Frame("Warning System", ScrW() * 0.8, ScrH() * 0.8, true)
    frame:SetDraggable(true)

    frame.selectedPlayer = nil
    frame.currentTab = "online"
    frame.allPlayersData = {}
    frame.onlinePlayersData = {}
    frame.searchFilter = ""

    -- Container
    local container = PD.Panel("", frame.FillPanel)
    container:Dock(FILL)
    container:DockMargin(0, 0, 0, 0)
    container:SetBackColor(getColor("Background1"))

    -- Left Panel (Player List)
    local leftPanel = PD.Panel("", container)
    leftPanel:Dock(LEFT)
    leftPanel:SetWide(PD.W(350))
    leftPanel:DockMargin(PD.H(10), PD.H(10), PD.H(5), PD.H(10))
    leftPanel:SetBackColor(getColor("Background2"))

    -- Search Box
    local searchBox = PD.TextEntry("Spieler durchsuchen...", leftPanel)
    searchBox:Dock(TOP)
    searchBox:DockMargin(PD.H(10), PD.H(10), PD.H(10), PD.H(5))
    searchBox:SetTall(PD.H(35))

    -- Live-Update bei jedem Tastendruck
    searchBox.OnChange = function(pnl)
        frame:FilterPlayers(pnl:GetValue())
    end

    -- Tab buttons
    local tabPanel = PD.Panel("", leftPanel)
    tabPanel:Dock(TOP)
    tabPanel:SetTall(PD.H(40))
    tabPanel:DockMargin(PD.H(10), PD.H(5), PD.H(10), PD.H(5))
    tabPanel:SetBackColor(Color(0, 0, 0, 0))

    -- Buttons vorher deklarieren, damit sie in den Callbacks verfügbar sind
    local onlineBtn, allBtn

    onlineBtn = PD.Button("Online", tabPanel, function(pnl)
        onlineBtn:Activate()
        allBtn:Deactivate()
        frame:SwitchTab("online")
    end)
    onlineBtn:Dock(LEFT)
    onlineBtn:SetWide(PD.W(165))
    onlineBtn:SetHoverColor(getColor("Green"))

    allBtn = PD.Button("Alle Spieler", tabPanel, function(pnl)
        onlineBtn:Deactivate()
        allBtn:Activate()
        frame:SwitchTab("all")
    end)
    allBtn:Dock(RIGHT)
    allBtn:SetWide(PD.W(165))
    allBtn:SetHoverColor(getColor("Green"))

    -- Online button startet aktiviert
    onlineBtn:Activate()

    -- Player List
    local playerList = PD.Scroll(leftPanel)
    playerList:Dock(FILL)
    playerList:DockMargin(PD.H(10), PD.H(5), PD.H(10), PD.H(10))
    frame.playerList = playerList

    -- Right Panel (Details)
    local rightPanel = PD.Panel("", container)
    rightPanel:Dock(FILL)
    rightPanel:DockMargin(PD.H(5), PD.H(10), PD.H(10), PD.H(10))
    rightPanel:SetBackColor(getColor("Background2"))
    frame.rightPanel = rightPanel

    local oldPaint = rightPanel.Paint
    rightPanel.Paint = function(pnl, w, h)
        oldPaint(pnl, w, h)

        if not frame.selectedPlayer then
            draw.SimpleText("Wähle einen Spieler aus, um Details anzuzeigen", "MLIB.25", w/2, h/2, getColor("Text"), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    -- Add methods to frame
    frame.RequestData = self.RequestData
    frame.PopulatePlayers = self.PopulatePlayers
    frame.SwitchTab = self.SwitchTab
    frame.FilterPlayers = self.FilterPlayers
    frame.RefreshPlayerList = self.RefreshPlayerList
    frame.SelectPlayer = self.SelectPlayer
    frame.ShowPlayerDetails = self.ShowPlayerDetails
    frame.CreateWarningEntry = self.CreateWarningEntry
    frame.CreateBanEntry = self.CreateBanEntry
    frame.OpenWarnDialog = self.OpenWarnDialog
    frame.OpenBanDialog = self.OpenBanDialog

    return frame
end

function WarningSystem.GUI:RequestData()
    net.Start("WarningSystem_RequestData")
    net.SendToServer()
end

function WarningSystem.GUI:PopulatePlayers(onlinePlayers, allPlayers)
    self.onlinePlayersData = onlinePlayers
    self.allPlayersData = allPlayers

    self:RefreshPlayerList()
end

function WarningSystem.GUI:SwitchTab(tab)
    self.currentTab = tab
    self:RefreshPlayerList()
end

function WarningSystem.GUI:FilterPlayers(search)
    self.searchFilter = string.lower(search)
    self:RefreshPlayerList()
end

function WarningSystem.GUI:RefreshPlayerList()
    self.playerList:Clear()

    local data = self.currentTab == "online" and self.onlinePlayersData or self.allPlayersData

    for _, playerData in ipairs(data) do
        -- Verschiedene Namensfelder versuchen, Steam-Name als Fallback
        local name = playerData.name or playerData.playername or playerData.steam_name or playerData.nick or "Unbekannter Spieler"
        local steamid = playerData.steamid

        -- Apply search filter
        if self.searchFilter and self.searchFilter ~= "" then
            if not string.find(string.lower(name), self.searchFilter, 1, true) and
               not string.find(string.lower(steamid), self.searchFilter, 1, true) then
                continue
            end
        end

        local warns = 0
        if self.currentTab == "online" then
            warns = playerData.warns or 0
        else
            warns = playerData.warns or "?"
        end

        local panel = PD.Button("", self.playerList, function()
            self:SelectPlayer(steamid, name)
        end, function(pnl, w, h)
            -- Custom paint for player entry
            draw.SimpleText(name, "MLIB.20", PD.W(10), PD.H(15), getColor("Text"), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(steamid, "MLIB.15", PD.W(10), PD.H(35), Color(150, 150, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            local warnText = warns == "?" and "?" or warns .. " Warns"
            local warnCol = getColor("Text")
            if warns ~= "?" then
                if warns == 0 then
                    warnCol = getColor("Green")
                elseif warns >= WarningSystem.Config:Get("MaxWarns") then
                    warnCol = getColor("SithRed")
                else
                    warnCol = Color(255, 180, 0)
                end
            end
            draw.SimpleText(warnText, "MLIB.15", w - PD.W(10), h/2, warnCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end)
        panel:Dock(TOP)
        panel:DockMargin(PD.H(5), PD.H(2), PD.H(5), PD.H(2))
        panel:SetTall(PD.H(60))

        if self.selectedPlayer and self.selectedPlayer.steamid == steamid then
            panel:Activate()
        end

        panel:SetHoverColor(getColor("Green"))
    end
end

function WarningSystem.GUI:SelectPlayer(steamid, name)
    self.selectedPlayer = {steamid = steamid, name = name}

    -- Request player details from server
    net.Start("WarningSystem_GetPlayerData")
    net.WriteString(steamid)
    net.SendToServer()

    -- Show loading state
    self:ShowPlayerDetails(nil)

    -- Refresh list to highlight selected player
    self:RefreshPlayerList()
end

function WarningSystem.GUI:ShowPlayerDetails(data)
    if IsValid(self.detailsPanel) then
        self.detailsPanel:Remove()
    end

    self.detailsPanel = PD.Panel("", self.rightPanel)
    self.detailsPanel:Dock(FILL)
    self.detailsPanel:DockMargin(PD.H(10), PD.H(10), PD.H(10), PD.H(10))
    self.detailsPanel:SetBackColor(Color(0, 0, 0, 0))

    if not data then
        -- Loading state
        local loading = PD.Label("Lade...", self.detailsPanel, getColor("Text"))
        loading:Dock(FILL)
        loading:SetFont("MLIB.25")
        loading:SetContentAlignment(5)
        return
    end

    -- Player Header
    local header = PD.Panel("", self.detailsPanel)
    header:Dock(TOP)
    header:SetTall(PD.H(80))
    header:DockMargin(0, 0, 0, PD.H(10))
    header:SetBackColor(getColor("Button"))

    local oldHeaderPaint = header.Paint
    header.Paint = function(pnl, w, h)
        oldHeaderPaint(pnl, w, h)
        draw.SimpleText(self.selectedPlayer.name, "MLIB.25", PD.W(15), PD.H(15), getColor("Text"), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(self.selectedPlayer.steamid, "MLIB.20", PD.W(15), PD.H(45), Color(150, 150, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

        if data.isBanned then
            draw.SimpleText("GEBANNT", "MLIB.25", w - PD.W(15), h/2, getColor("SithRed"), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    -- Action Buttons
    local actionPanel = PD.Panel("", self.detailsPanel)
    actionPanel:Dock(TOP)
    actionPanel:SetTall(PD.H(45))
    actionPanel:DockMargin(0, 0, 0, PD.H(10))
    actionPanel:SetBackColor(Color(0, 0, 0, 0))

    local warnBtn = PD.Button("Spieler verwarnen", actionPanel, function()
        self:OpenWarnDialog()
    end)
    warnBtn:Dock(LEFT)
    warnBtn:SetWide(PD.W(150))
    warnBtn:DockMargin(0, 0, PD.W(5), 0)
    warnBtn:SetHoverColor(Color(255, 180, 0))

    local banBtn = PD.Button("Spieler bannen", actionPanel, function()
        self:OpenBanDialog()
    end)
    banBtn:Dock(LEFT)
    banBtn:SetWide(PD.W(150))
    banBtn:DockMargin(0, 0, PD.W(5), 0)
    banBtn:SetHoverColor(getColor("SithRed"))

    if data.isBanned then
        local unbanBtn = PD.Button("Spieler entbannen", actionPanel, function()
            net.Start("WarningSystem_UnbanPlayer")
            net.WriteString(self.selectedPlayer.steamid)
            net.SendToServer()
        end)
        unbanBtn:Dock(LEFT)
        unbanBtn:SetWide(PD.W(150))
        unbanBtn:DockMargin(0, 0, PD.W(5), 0)
        unbanBtn:SetHoverColor(getColor("Green"))
    end

    local clearBtn = PD.Button("Alle Verwarnungen löschen", actionPanel, function()
        Derma_Query("Bist du sicher, dass du alle Verwarnungen löschen möchtest?", "Bestätigen",
            "Ja", function()
                net.Start("WarningSystem_ClearWarnings")
                net.WriteString(self.selectedPlayer.steamid)
                net.SendToServer()
            end,
            "Nein")
    end)
    clearBtn:Dock(RIGHT)
    clearBtn:SetWide(PD.W(200))
    clearBtn:SetHoverColor(getColor("SithRed"))

    -- Warnings List
    local warnLabel = PD.Label("Verwarnungen (" .. #data.warnings .. ")", self.detailsPanel, getColor("Text"))
    warnLabel:Dock(TOP)
    warnLabel:SetTall(PD.H(25))
    warnLabel:DockMargin(0, PD.H(10), 0, PD.H(5))
    warnLabel:SetFont("MLIB.20")

    local warnScroll = PD.Scroll(self.detailsPanel)
    warnScroll:Dock(TOP)
    warnScroll:SetTall(PD.H(250))
    warnScroll:DockMargin(0, 0, 0, PD.H(10))

    for _, warn in ipairs(data.warnings) do
        self:CreateWarningEntry(warnScroll, warn)
    end

    -- Bans List
    local banLabel = PD.Label("Banns (" .. #data.bans .. ")", self.detailsPanel, getColor("Text"))
    banLabel:Dock(TOP)
    banLabel:SetTall(PD.H(25))
    banLabel:DockMargin(0, PD.H(10), 0, PD.H(5))
    banLabel:SetFont("MLIB.20")

    local banScroll = PD.Scroll(self.detailsPanel)
    banScroll:Dock(FILL)

    for _, ban in ipairs(data.bans) do
        self:CreateBanEntry(banScroll, ban)
    end
end

function WarningSystem.GUI:CreateWarningEntry(parent, warn)
    local panel = PD.Panel("", parent)
    panel:Dock(TOP)
    panel:DockMargin(0, PD.H(2), 0, PD.H(2))
    panel:SetTall(PD.H(80))
    panel:SetBackColor(getColor("Button"))

    local oldPaint = panel.Paint
    panel.Paint = function(pnl, w, h)
        oldPaint(pnl, w, h)

        local date = os.date("%d.%m.%Y %H:%M", tonumber(warn.timestamp))
        draw.SimpleText("Teammitglied: " .. warn.admin_name, "MLIB.20", PD.W(10), PD.H(10), getColor("Text"))
        draw.SimpleText("Datum: " .. date, "MLIB.20", PD.W(10), PD.H(28), Color(150, 150, 150))
        draw.SimpleText("Grund: " .. warn.reason, "MLIB.20", PD.W(10), PD.H(46), Color(255, 180, 0))

        if warn.expires_at and tonumber(warn.expires_at) > 0 then
            local expiresDate = os.date("%d.%m.%Y", tonumber(warn.expires_at))
            draw.SimpleText("Läuft ab: " .. expiresDate, "MLIB.20", PD.W(10), PD.H(64), getColor("Green"))
        end
    end

    -- Delete button
    local delBtn = PD.Button("X", panel, function()
        Derma_Query("Diese Verwarnung entfernen?", "Bestätigen", "Ja", function()
            net.Start("WarningSystem_RemoveWarning")
            net.WriteUInt(tonumber(warn.id), 32)
            net.SendToServer()

            -- Reload player data after a short delay
            timer.Simple(0.3, function()
                if IsValid(self) and self.selectedPlayer then
                    net.Start("WarningSystem_GetPlayerData")
                    net.WriteString(self.selectedPlayer.steamid)
                    net.SendToServer()
                end
            end)
        end, "Nein")
    end)
    delBtn:SetSize(PD.W(30), PD.H(30))
    delBtn:SetFont(20)
    delBtn:SetHoverColor(getColor("SithRed"))

    -- Position buttons dynamically
    panel.PerformLayout = function(pnl, w, h)
        delBtn:SetPos(w - PD.W(35), PD.H(10))
    end
end

function WarningSystem.GUI:CreateBanEntry(parent, ban)
    local panel = PD.Panel("", parent)
    panel:Dock(TOP)
    panel:DockMargin(0, PD.H(2), 0, PD.H(2))
    panel:SetTall(PD.H(80))
    panel:SetBackColor(getColor("Button"))

    local oldPaint = panel.Paint
    panel.Paint = function(pnl, w, h)
        oldPaint(pnl, w, h)

        local date = os.date("%d.%m.%Y %H:%M", tonumber(ban.timestamp))
        draw.SimpleText("Teammitglied: " .. ban.admin_name, "MLIB.20", PD.W(10), PD.H(10), getColor("Text"))
        draw.SimpleText("Datum: " .. date, "MLIB.20", PD.W(10), PD.H(28), Color(150, 150, 150))
        draw.SimpleText("Grund: " .. ban.reason, "MLIB.20", PD.W(10), PD.H(46), getColor("SithRed"))

        if ban.unban_time and tonumber(ban.unban_time) > 0 then
            local unbanDate = os.date("%d.%m.%Y %H:%M", tonumber(ban.unban_time))
            draw.SimpleText("Läuft ab: " .. unbanDate, "MLIB.20", PD.W(10), PD.H(64), Color(255, 180, 0))
        else
            draw.SimpleText("Permanent", "MLIB.20", PD.W(10), PD.H(64), getColor("SithRed"))
        end
    end

    -- Delete button
    local delBtn = PD.Button("X", panel, function()
        Derma_Query("Diese Sperre entfernen?", "Bestätigen", "Ja", function()
            net.Start("WarningSystem_RemoveBan")
            net.WriteUInt(tonumber(ban.id), 32)
            net.SendToServer()

            -- Reload player data after a short delay
            timer.Simple(0.3, function()
                if IsValid(self) and self.selectedPlayer then
                    net.Start("WarningSystem_GetPlayerData")
                    net.WriteString(self.selectedPlayer.steamid)
                    net.SendToServer()
                end
            end)
        end, "Nein")
    end)
    delBtn:SetSize(PD.W(30), PD.H(30))
    delBtn:SetFont(20)
    delBtn:SetHoverColor(getColor("SithRed"))

    -- Position buttons dynamically
    panel.PerformLayout = function(pnl, w, h)
        delBtn:SetPos(w - PD.W(35), PD.H(10))
    end
end

function WarningSystem.GUI:OpenWarnDialog()
    local frame = PD.Frame("Verwarnung für Spieler: " .. self.selectedPlayer.name, PD.W(400), PD.H(280), true)

    local reasonLabel = PD.Label("Grund:", frame.FillPanel, getColor("Text"))
    reasonLabel:Dock(TOP)
    reasonLabel:SetFont("MLIB.20")

    local reasonEntry = PD.TextEntry("Grund der Verwarnung eingeben...", frame.FillPanel)
    reasonEntry:Dock(TOP)
    reasonEntry:SetTall(PD.H(40))

    local tempCheckPanel, tempCheck = PD.SimpleCheck(
        frame.FillPanel,
        "Temporäre Verwarnung (läuft nach konfigurierter Zeit ab)",
        true,
        function(val) end
    )
    tempCheckPanel:SetTall(PD.H(60))

    local submitBtn = PD.Button("Verwarnung absenden", frame.FillPanel, function()
        local reason = reasonEntry:GetValue()
        if reason == "" then
            Derma_Message("Bitte geben Sie einen Grund ein!", "Fehler", "OK")
            return
        end

        net.Start("WarningSystem_WarnPlayer")
        net.WriteString(self.selectedPlayer.steamid)
        net.WriteString(self.selectedPlayer.name)
        net.WriteString(reason)
        net.WriteBool(tempCheck:GetChecked())
        net.SendToServer()

        frame:Close()

        -- Reload player data after a short delay to show the new warning
        timer.Simple(0.3, function()
            if IsValid(self) and self.selectedPlayer then
                net.Start("WarningSystem_GetPlayerData")
                net.WriteString(self.selectedPlayer.steamid)
                net.SendToServer()
            end
        end)
    end)
    submitBtn:Dock(BOTTOM)
    submitBtn:SetTall(PD.H(45))
    submitBtn:SetHoverColor(getColor("Green"))
end

function WarningSystem.GUI:OpenBanDialog()
    local frame = PD.Frame("Ban für Spieler: " .. self.selectedPlayer.name, PD.W(400), PD.H(320), true)

    local reasonLabel = PD.Label("Grund:", frame.FillPanel, getColor("Text"))
    reasonLabel:Dock(TOP)
    reasonLabel:SetFont("MLIB.20")

    local reasonEntry = PD.TextEntry("Grund des Bans eingeben...", frame.FillPanel)
    reasonEntry:Dock(TOP)
    reasonEntry:SetTall(PD.H(40))

    local durationLabel = PD.Label("Dauer (0 = permanent):", frame.FillPanel, getColor("Text"))
    durationLabel:Dock(TOP)
    durationLabel:SetFont("MLIB.20")
    durationLabel:DockMargin(0, PD.H(10), 0, 0)

    local durationCombo = PD.ComboBox("1 Tag", frame.FillPanel, function(choice, value) end)
    durationCombo:Dock(TOP)
    durationCombo:SetTall(PD.H(50))

    durationCombo:AddChoice("1 Stunde", 3600)
    durationCombo:AddChoice("6 Stunden", 21600)
    durationCombo:AddChoice("12 Stunden", 43200)
    durationCombo:AddChoice("1 Tag", 86400)
    durationCombo:AddChoice("3 Tage", 259200)
    durationCombo:AddChoice("1 Woche", 604800)
    durationCombo:AddChoice("Permanent", 0)

    local submitBtn = PD.Button("Ban absenden", frame.FillPanel, function()
        local reason = reasonEntry:GetValue()
        if reason == "" then
            Derma_Message("Bitte geben Sie einen Grund ein!", "Fehler", "OK")
            return
        end

        local duration = durationCombo:GetChoice()

        net.Start("WarningSystem_BanPlayer")
        net.WriteString(self.selectedPlayer.steamid)
        net.WriteString(self.selectedPlayer.name)
        net.WriteString(reason)
        net.WriteUInt(duration or 0, 32)
        net.SendToServer()

        frame:Close()

        -- Reload player data after a short delay
        timer.Simple(0.3, function()
            if IsValid(self) and self.selectedPlayer then
                net.Start("WarningSystem_GetPlayerData")
                net.WriteString(self.selectedPlayer.steamid)
                net.SendToServer()
            end
        end)
    end)
    submitBtn:Dock(BOTTOM)
    submitBtn:SetTall(PD.H(45))
    submitBtn:DockMargin(0, PD.H(10), 0, 0)
    submitBtn:SetHoverColor(getColor("SithRed"))
end

-- Receive player data
net.Receive("WarningSystem_SendPlayerData", function()
    local steamid = net.ReadString()
    local warnings = net.ReadTable()
    local bans = net.ReadTable()
    local isBanned = net.ReadBool()
    local activeBan = isBanned and net.ReadTable() or nil

    if IsValid(mainFrame) and mainFrame.selectedPlayer and mainFrame.selectedPlayer.steamid == steamid then
        mainFrame:ShowPlayerDetails({
            warnings = warnings,
            bans = bans,
            isBanned = isBanned,
            activeBan = activeBan
        })
    end
end)

-- Console Command
concommand.Add("warnsystem", function()
    WarningSystem.GUI:OpenMenu()
end)
