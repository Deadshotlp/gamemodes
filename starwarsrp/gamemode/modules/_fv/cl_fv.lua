PD.FV = PD.FV or {}
PD.FV.PlayerInfo = PD.FV.PlayerInfo or {}

local selectedUnit, selectedSubunit, selectedJob

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
            local unitBtn = PD.Button(unit.name, panel, function()
                if onSelect then onSelect("unit", unitName) end
            end)
            unitBtn:Dock(TOP)
            unitBtn:SetTall(PD.H(40))
            unitBtn:SetAccentColor(unit.color or PD.Theme.Colors.AccentGray)
        end

        if selectedUnit ~= unitName and search == "" then continue end

        for subName, sub in SortedPairs(unit.subunits or {}) do
            if match(unit.name .. " " .. sub.name) then
                local subBtn = PD.Button("  ├ " .. sub.name, panel, function()
                    if onSelect then onSelect("subunit", unitName, subName) end
                end)
                subBtn:Dock(TOP)
                subBtn:SetTall(PD.H(35))
                subBtn:DockMargin(PD.W(15), 0, 0, 0)
            end

            if selectedSubunit ~= subName and search == "" then continue end
            
            for jobName, job in SortedPairs(sub.jobs or {}) do
                if match(unit.name .. " " .. sub.name .. " " .. job.name) then
                    local jobBtn = PD.Button("     └ " .. job.name, panel, function()
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

local function ShowPlayerInfo(pnl)
    if not IsValid(pnl) then return end

    pnl:Clear()
    if table.IsEmpty(PD.FV.PlayerInfo) then
        local lbl = PD.Label("Keine Spieler gefunden.", pnl)
        lbl:Dock(TOP)
        lbl:SetContentAlignment(5)
        return
    else
        local srcl = PD.Scroll(pnl)
        srcl:Dock(FILL)
        srcl:SetWide(pnl:GetWide() - PD.W(20))

        for _, char in pairs(PD.FV.PlayerInfo) do
            local str = string.Split(char.faction, ",")
                char.faction = {unit = str[1], subunit = str[2], job = str[3]}
            for k, v in pairs(player.GetAll()) do 
                print(v:Nick(), char.name)
                if v:Nick() == char.name then
                    char.status = "Online"
                end
            end

            local char_pnl = PD.Panel(srcl, {}, function(self, w, h)
                draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
                surface.SetDrawColor(PD.Theme.Colors.AccentGray)
                surface.DrawOutlinedRect(0, 0, w, h, 2)
                
            end)
            char_pnl:Dock(TOP)
            char_pnl:SetTall(PD.H(100))
            char_pnl:SetWide(srcl:GetWide() - PD.W(20))
            char_pnl:DockMargin(0, 0, 0, PD.H(5))

            local name = PD.Label(char.name, char_pnl, {})
            name:DockMargin(PD.W(5), PD.H(5), 0, 0)
            local lastPlayed = PD.Label("Zuletzt gespielt: " .. char.lastplaytime, char_pnl, {TextColor = PD.Theme.Colors.AccentGray})
            lastPlayed:DockMargin(PD.W(5), PD.H(5), 0, 0)
            local status = PD.Label("Status: " .. (char.status or "Offline"), char_pnl, {TextColor = PD.Theme.Colors.AccentGray})
            status:DockMargin(PD.W(5), PD.H(5), 0, 0)
            status.Paint = function(self, w, h)
                if char.status == "Online" then
                    draw.RoundedBox(8, PD.H(90), h / 2 - PD.H(4), PD.H(10), PD.H(10), PD.Theme.Colors.AccentGreen)
                else
                    draw.RoundedBox(8, PD.H(90), h / 2 - PD.H(4), PD.H(10), PD.H(10), PD.Theme.Colors.AccentRed)
                end
            end

            local unit = PD.Label("Einheit: " .. char.faction.unit, char_pnl)
            unit:Dock(NODOCK)
            unit:SizeToContents()
            unit:SetPos(char_pnl:GetWide() / 2, PD.H(5))
            local subunit = PD.Label("Untereinheit: " .. char.faction.subunit, char_pnl)
            subunit:Dock(NODOCK)
            subunit:SizeToContents()
            subunit:SetPos(char_pnl:GetWide() / 2, PD.H(25))
            local job = PD.Label("Rang: " .. char.faction.job, char_pnl)
            job:Dock(NODOCK)
            job:SizeToContents()
            job:SetPos(char_pnl:GetWide() / 2, PD.H(45))
        end
    end
end

function PD.FV:Menu()
    if IsValid(FrakVerwaltungFrame) then 
        FrakVerwaltungFrame:Remove()
        return
    end

    FrakVerwaltungFrame = PD.Frame("Fraktions Verwaltung", PD.W(1100), PD.H(750) , true)

    local content = FrakVerwaltungFrame:GetContentPanel()

    -- Body mit zwei Spalten
    local body = vgui.Create("DPanel", content)
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

    -- Suchfeld
    local searchBox = PD.TextEntry(left, "Suchen...", "")
    searchBox:Dock(TOP)
    searchBox:DockMargin(PD.W(10), 0, 0, 0)
    

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
                else
                    selectedUnit = u
                    selectedSubunit = nil
                    selectedJob = nil
                end
            elseif kind == "subunit" then
                if selectedSubunit == s then
                    selectedUnit = u
                    selectedSubunit = nil
                    selectedJob = nil
                else
                    selectedUnit = u
                    selectedSubunit = s
                    selectedJob = nil
                end
            elseif kind == "job" then
                if selectedJob == j then
                    selectedUnit = u
                    selectedSubunit = s
                    selectedJob = nil
                else
                    selectedUnit = u
                    selectedSubunit = s
                    selectedJob = j
                end
            end
            refreshList()

            net.Start("PD.FV.RequestPlayerInfo")
            net.WriteString((selectedUnit or "") .. "," .. (selectedSubunit or "") .. "," .. (selectedJob or ""))
            net.SendToServer()
        end)
    end
    
    searchBox.OnEnter = function() refreshList() end
    searchBox.OnChange = function() refreshList() end

    net.Receive("PD.FV.SendPlayerInfo", function()
        local hasData = net.ReadBool()
        if hasData then
            local data = net.ReadTable()
            PD.FV.PlayerInfo = data
        else
            PD.FV.PlayerInfo = {}
        end
        ShowPlayerInfo(right)
    end)
    
    refreshList()
end