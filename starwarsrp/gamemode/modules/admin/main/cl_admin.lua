-- Admin Menu - Star Wars Andor Imperial Style (Zentral über PD.Theme)

PD.Admin = PD.Admin or {}
PD.Admin.Job_Edit_Whitelist = PD.Admin.Job_Edit_Whitelist or {"superadmin", "Developer", "Projektleitung", "Projektleitung", "Teamverwaltung"}

-- Hilfsfunktion: Text-Animation
local function TextFunctionPanel(panel, str, speed, callback)
    if not IsValid(panel) then return end
    panel:SetText("")
    panel:SizeToContents()

    local index = 1
    timer.Create("TextFunction_" .. math.random(1, 10000), speed or 0.05, #str, function()
        if not IsValid(panel) then return end
        panel:SetText(string.sub(str, 1, index))
        panel:SizeToContents()
        index = index + 1
        if index > #str and callback then
            callback(str)
        end
    end)
end

-- Spieler-Charakter-Verwaltung Panel
local function PlayerAdminInteract(data, panel)
    if not IsValid(panel) then return end
    panel:Clear()
    
    local charadminData = data
    if not charadminData then
        return print("Char Admin Daten Kaputt")
    end

    local scroll = PD.Scroll(panel)

    -- ========================================
    -- CHARAKTER SEKTION
    -- ========================================
    local charSection = vgui.Create("DPanel", scroll)
    charSection:Dock(TOP)
    charSection:SetTall(PD.H(50))
    charSection:DockMargin(0, 0, 0, PD.H(10))
    charSection.Paint = function(s, w, h)
        -- Hintergrund
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        
        -- Linke Akzentlinie
        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
        surface.DrawRect(0, 0, PD.W(4), h)
        
        -- Obere/Untere Linie
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(PD.W(4), 0, w - PD.W(4), 1)
        surface.DrawRect(PD.W(4), h - 1, w - PD.W(4), 1)
        
        -- Titel
        draw.DrawText(LANG.ADMIN_MENU_CHAR, "MLIB.18", PD.W(20), h / 2 - PD.H(9), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
        
        -- Anzahl
        draw.DrawText(#charadminData .. " Charaktere", "MLIB.12", w - PD.W(15), h / 2 - PD.H(6), PD.Theme.Colors.TextDim, TEXT_ALIGN_RIGHT)
    end

    -- Charakter-Liste
    for _, char in ipairs(charadminData) do
        local charBtn = PD.Button(char.name .. " (ID: " .. char.id .. ")", scroll, function()
            -- Detail-Panel für diesen Charakter
            panel:Clear()
            
            -- Header
            local header = vgui.Create("DPanel", panel)
            header:Dock(TOP)
            header:SetTall(PD.H(60))
            header:DockMargin(0, 0, 0, PD.H(15))
            header.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
                surface.SetDrawColor(PD.Theme.Colors.AccentRed)
                surface.DrawRect(0, 0, w, PD.H(3))
                
                draw.DrawText("CHARAKTER BEARBEITEN", "MLIB.12", PD.W(15), PD.H(12), PD.Theme.Colors.AccentGray, TEXT_ALIGN_LEFT)
                draw.DrawText(char.name .. " (ID: " .. char.id .. ")", "MLIB.20", PD.W(15), PD.H(30), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
            end

            local detailScroll = PD.Scroll(panel)

            -- Info Panel
            local infoPanel = vgui.Create("DPanel", detailScroll)
            infoPanel:Dock(TOP)
            infoPanel:SetTall(PD.H(120))
            infoPanel:DockMargin(0, 0, 0, PD.H(15))
            infoPanel.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
                
                -- Linke Akzentlinie
                surface.SetDrawColor(PD.Theme.Colors.AccentBlue)
                surface.DrawRect(0, 0, PD.W(3), h)
                
                -- Info Label
                PD.DrawLabel("CHARAKTER INFO", "MLIB.10", PD.W(15), PD.H(10), PD.Theme.Colors.AccentGray)
                
                -- Erstelldatum
                draw.DrawText("Erstellt:", "MLIB.12", PD.W(15), PD.H(35), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
                draw.DrawText(char.cratedate or "Unbekannt", "MLIB.14", PD.W(120), PD.H(33), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
                
                -- Letztes Spiel
                draw.DrawText("Zuletzt gespielt:", "MLIB.12", PD.W(15), PD.H(58), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
                draw.DrawText(char.lastplaytime or "Unbekannt", "MLIB.14", PD.W(120), PD.H(56), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
                
                -- Spielzeit
                draw.DrawText("Spielzeit:", "MLIB.12", PD.W(15), PD.H(81), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
                draw.DrawText(Mario.FormatTime(char.playtime or 0), "MLIB.14", PD.W(120), PD.H(79), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
            end
            
            -- ID Label
            local idLabel = vgui.Create("DLabel", detailScroll)
            idLabel:Dock(TOP)
            idLabel:SetText("ID")
            idLabel:SetFont("MLIB.12")
            idLabel:SetTextColor(PD.Theme.Colors.TextDim)
            idLabel:DockMargin(PD.W(5), PD.H(10), 0, 0)

            -- Eingabefelder
            local idEntry = PD.TextEntry(detailScroll, "ID", char.id, function(val)
                char.id = val
            end)
            idEntry:DockMargin(0, 0, 0, PD.H(5))
            
            local nameLabel = vgui.Create("DLabel", detailScroll)
            nameLabel:Dock(TOP)
            nameLabel:SetText(LANG.CHAR_UI_NAME)
            nameLabel:SetFont("MLIB.12")
            nameLabel:SetTextColor(PD.Theme.Colors.TextDim)
            nameLabel:DockMargin(PD.W(5), PD.H(10), 0, 0)

            local nameEntry = PD.TextEntry(detailScroll, "Name", char.name, function(val)
                char.name = val
            end)
            nameEntry:DockMargin(0, 0, 0, PD.H(5))
            
            local moneyLabel = vgui.Create("DLabel", detailScroll)
            moneyLabel:Dock(TOP)
            moneyLabel:SetText(LANG.ADMIN_MENU_CREDITS)
            moneyLabel:SetFont("MLIB.12")
            moneyLabel:SetTextColor(PD.Theme.Colors.TextDim)
            moneyLabel:DockMargin(PD.W(5), PD.H(10), 0, 0)

            local moneyEntry = PD.TextEntry(detailScroll, "Credits", tostring(char.money or 0), function(val)
                char.money = tonumber(val) or 0
            end)
            moneyEntry:DockMargin(0, 0, 0, PD.H(15))

            -- Aktions-Buttons
            local saveBtn = PD.Button(LANG.GENERIC_SAVE, detailScroll, function()
                net.Start("PD.Char.Admin")
                net.WriteString("save")
                net.WriteString(data.steamid)
                net.WriteTable(char)
                net.SendToServer()
                
                surface.PlaySound("buttons/button14.wav")
            end)
            saveBtn:Dock(TOP)
            saveBtn:SetTall(PD.H(45))
            saveBtn:SetAccentColor(PD.Theme.Colors.StatusActive)

            local setBtn = PD.Button(LANG.ADMIN_MENU_SET, detailScroll, function()
                net.Start("PD.Char.Admin")
                net.WriteString("set")
                net.WriteString(data.steamid)
                net.WriteTable(char)
                net.SendToServer()
                
                surface.PlaySound("buttons/button14.wav")
            end)
            setBtn:Dock(TOP)
            setBtn:SetTall(PD.H(45))

            local deleteBtn = PD.Button(LANG.GENERIC_DELETE, detailScroll, function()
                net.Start("PD.Char.Admin")
                net.WriteString("delete")
                net.WriteString(data.steamid)
                net.WriteTable(char)
                net.SendToServer()
                
                surface.PlaySound("buttons/button14.wav")
            end)
            deleteBtn:Dock(TOP)
            deleteBtn:SetTall(PD.H(45))
            deleteBtn:SetAccentColor(PD.Theme.Colors.StatusCritical)

            -- ========================================
            -- FRAKTION SEKTION
            -- ========================================
            local spacer = vgui.Create("DPanel", detailScroll)
            spacer:Dock(TOP)
            spacer:SetTall(PD.H(20))
            spacer.Paint = function() end

            local factionSection = vgui.Create("DPanel", detailScroll)
            factionSection:Dock(TOP)
            factionSection:SetTall(PD.H(50))
            factionSection:DockMargin(0, 0, 0, PD.H(10))
            factionSection.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
                surface.SetDrawColor(PD.Theme.Colors.AccentOrange)
                surface.DrawRect(0, 0, PD.W(4), h)
                surface.SetDrawColor(PD.Theme.Colors.AccentGray)
                surface.DrawRect(PD.W(4), 0, w - PD.W(4), 1)
                surface.DrawRect(PD.W(4), h - 1, w - PD.W(4), 1)
                draw.DrawText(LANG.CHAR_UI_UNIT, "MLIB.18", PD.W(20), h / 2 - PD.H(9), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
            end

            -- Aktuelle Fraktion Info
            local plyCharsTable = PD.Char:GetAdminData(FindPlayerbyID(data.steamid))
            local player = FindPlayerbyID(data.steamid)
            local factionUnit, factionSubUnit, factionJob = char.faction.unit or "Keine", char.faction.subunit or "Keine", char.faction.job or "Kein Job"

            local factionInfo = vgui.Create("DPanel", detailScroll)
            factionInfo:Dock(TOP)
            factionInfo:SetTall(PD.H(90))
            factionInfo:DockMargin(0, 0, 0, PD.H(10))
            factionInfo.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
                surface.SetDrawColor(PD.Theme.Colors.AccentGray)
                surface.DrawRect(0, 0, PD.W(3), h)
                
                PD.DrawLabel("AKTUELLE ZUWEISUNG", "MLIB.10", PD.W(15), PD.H(10), PD.Theme.Colors.AccentGray)
                
                draw.DrawText("Einheit:", "MLIB.12", PD.W(15), PD.H(32), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
                draw.DrawText(factionUnit, "MLIB.14", PD.W(100), PD.H(30), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
                
                draw.DrawText("Untereinheit:", "MLIB.12", PD.W(15), PD.H(52), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
                draw.DrawText(factionSubUnit, "MLIB.14", PD.W(100), PD.H(50), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
                
                draw.DrawText("Job:", "MLIB.12", PD.W(15), PD.H(72), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
                draw.DrawText(factionJob, "MLIB.14", PD.W(100), PD.H(70), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
            end

            -- Fraktions-Dropdown
            local faction = {
                unit = factionUnit,
                subunit = factionSubUnit,
                job = factionJob
            }
            
            local factionLabel = vgui.Create("DLabel", detailScroll)
            factionLabel:Dock(TOP)
            factionLabel:SetText("NEUE FRAKTION ZUWEISEN")
            factionLabel:SetFont("MLIB.12")
            factionLabel:SetTextColor(PD.Theme.Colors.AccentGray)
            factionLabel:DockMargin(PD.W(5), PD.H(10), 0, PD.H(5))

            local factionUnitDropdown = PD.Dropdown(detailScroll, factionUnit, function(val, data)
                faction.unit = val

                showValidSubUnits(val)
            end)
            factionUnitDropdown:Dock(TOP)
            factionUnitDropdown:SetTall(PD.H(45))
            
            for k, v in pairs(PD.JOBS.GetUnit(false, true)) do
                factionUnitDropdown:AddOption(k, {
                    unit = v
                })
            end

            local factionSubUnitDropdown = PD.Dropdown(detailScroll, factionSubUnit, function(val, data)
                    faction.subunit = val

                    showValidJobs(val)
                end)
                factionSubUnitDropdown:Dock(TOP)
                factionSubUnitDropdown:SetTall(PD.H(45))

            function showValidSubUnits(unit)
                factionSubUnitDropdown:Clear()
                faction.job = nil
                factionSubUnit = nil
                faction.job = nil

                for k, v in pairs(PD.JOBS.GetSubUnit(false, true)) do
                    if v.unit == unit then
                        factionSubUnitDropdown:AddOption(k, {
                            subunit = v,
                        })
                    end
                end
            end

            local factionJobDropdown = PD.Dropdown(detailScroll, factionJob, function(val, data)
                    if data then
                        faction.job = val
                    end
                end)
                factionJobDropdown:Dock(TOP)
                factionJobDropdown:SetTall(PD.H(45))

            function showValidJobs(subunit)
                factionJobDropdown:Clear()
                faction.job = nil
                factionJob = nil

                for k, v in pairs(PD.JOBS.GetJob(false, true)) do
                    if v.unit == subunit then
                        factionJobDropdown:AddOption(k, {
                            job = v,
                        })
                    end
                end
            end

            -- Speichern Button
            local saveFactionBtn = PD.Button("Fraktion Speichern", detailScroll, function()
                local unit, subunit, job = faction.unit, faction.subunit, faction.job
                if unit and subunit and job then
                    net.Start("PD.List.AdminChange")
                    net.WriteString(data.steamid)
                    net.WriteString(char.id)
                    net.WriteString(unit)
                    net.WriteString(subunit)
                    net.WriteString(job)
                    net.SendToServer()

                    if IsValid(AdminmainFrame) then
                        AdminmainFrame:Remove()
                    end
                    
                    surface.PlaySound("buttons/button14.wav")
                else
                    print("Fraktion nicht vollständig ausgewählt!")
                    print("Unit:", unit)
                    print("Subunit:", subunit)
                    print("Job:", job)
                end
            end)
            saveFactionBtn:Dock(TOP)
            saveFactionBtn:SetTall(PD.H(50))
            saveFactionBtn:DockMargin(0, PD.H(10), 0, 0)
            saveFactionBtn:SetAccentColor(PD.Theme.Colors.StatusActive)

            -- Zurück Button
            local backBtn = PD.Button("‹ Zurück zur Übersicht", detailScroll, function()
                PlayerAdminInteract(data, panel)
            end)
            backBtn:Dock(TOP)
            backBtn:SetTall(PD.H(40))
            backBtn:DockMargin(0, PD.H(20), 0, 0)
        end)
        charBtn:Dock(TOP)
        charBtn:SetTall(PD.H(45))
    end
end

-- Hauptmenü
function PD.Admin:Menu(wo)
    if IsValid(AdminmainFrame) then
        AdminmainFrame:Remove()
        return
    end

    -- Frame erstellen mit neuem Theme
    AdminmainFrame = PD.Frame("IMPERIAL ADMINISTRATION", PD.W(1100), PD.H(750), true, {
        accent = PD.Theme.Colors.AccentRed,
        grid = true
    })
    
    local content = AdminmainFrame:GetContentPanel()

    -- Header mit Begrüßung
    local headerPanel = vgui.Create("DPanel", content)
    headerPanel:Dock(TOP)
    headerPanel:SetTall(PD.H(60))
    headerPanel:DockMargin(0, 0, 0, PD.H(15))
    
    local welcomeText = LANG.ADMIN_MENU_WELCOME .. LocalPlayer():Nick() .. "!"
    local welcomeIndex = 0
    local welcomeDisplayed = ""
    
    headerPanel.Paint = function(s, w, h)
        -- Hintergrund
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        
        -- Linke Akzentlinie
        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
        surface.DrawRect(0, 0, PD.W(4), h)
        
        -- Obere/Untere Linie
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(PD.W(4), 0, w - PD.W(4), 1)
        surface.DrawRect(PD.W(4), h - 1, w - PD.W(4), 1)
        
        -- Imperial Ecken
        local cornerSize = PD.W(12)
        surface.DrawLine(w - cornerSize, 0, w, 0)
        surface.DrawLine(w - 1, 0, w - 1, cornerSize)
        surface.DrawLine(w - cornerSize, h - 1, w, h - 1)
        surface.DrawLine(w - 1, h - cornerSize, w - 1, h)
        
        -- Begrüßungstext (animiert)
        draw.DrawText(welcomeDisplayed, "MLIB.22", PD.W(20), h / 2 - PD.H(11), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
        
        -- Status rechts
        draw.DrawText("ADMIN TERMINAL", "MLIB.12", w - PD.W(15), PD.H(12), PD.Theme.Colors.AccentGray, TEXT_ALIGN_RIGHT)
        draw.DrawText("ZUGRIFF GEWÄHRT", "MLIB.14", w - PD.W(15), PD.H(30), PD.Theme.Colors.StatusActive, TEXT_ALIGN_RIGHT)
    end
    
    -- Text-Animation
    timer.Create("AdminWelcomeAnim", 0.03, #welcomeText, function()
        welcomeIndex = welcomeIndex + 1
        welcomeDisplayed = string.sub(welcomeText, 1, welcomeIndex)
    end)

    -- Tab-Leiste
    local tabBar = vgui.Create("DPanel", content)
    tabBar:Dock(TOP)
    tabBar:SetTall(PD.H(50))
    tabBar:DockMargin(0, 0, 0, PD.H(10))
    tabBar.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(0, h - 1, w, 1)
    end

    -- Content Panel
    local rightPanel = vgui.Create("DPanel", content)
    rightPanel:Dock(FILL)
    rightPanel.Paint = function() end

    -- Tab-System
    local tabs = {}
    local activeTab = nil
    
    local function CreateTab(name, id, func)
        local tabBtn = vgui.Create("DButton", tabBar)
        tabBtn:SetText("")
        tabBtn:Dock(LEFT)
        tabBtn:SetWide(PD.W(180))
        
        tabBtn._active = false
        tabBtn._hover = 0
        
        tabBtn.Paint = function(s, w, h)
            s._hover = Lerp(FrameTime() * 10, s._hover, s:IsHovered() and 1 or 0)
            
            -- Hintergrund bei aktiv/hover
            if s._active then
                draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
            elseif s._hover > 0.1 then
                draw.RoundedBox(0, 0, 0, w, h, Color(PD.Theme.Colors.BackgroundLight.r, PD.Theme.Colors.BackgroundLight.g, PD.Theme.Colors.BackgroundLight.b, 100 * s._hover))
            end
            
            -- Untere Akzentlinie bei aktiv
            if s._active then
                surface.SetDrawColor(PD.Theme.Colors.AccentRed)
                surface.DrawRect(0, h - PD.H(3), w, PD.H(3))
            end
            
            -- Text
            local textColor = s._active and PD.Theme.Colors.Text or PD.Theme.Colors.TextDim
            draw.DrawText(name, "MLIB.14", w / 2, h / 2 - PD.H(7), textColor, TEXT_ALIGN_CENTER)
        end
        
        tabBtn.OnCursorEntered = function()
            surface.PlaySound("UI/buttonrollover.wav")
        end
        
        tabBtn.DoClick = function()
            surface.PlaySound("UI/buttonclick.wav")
            
            -- Alle Tabs deaktivieren
            for _, tab in pairs(tabs) do
                tab._active = false
            end
            
            -- Diesen Tab aktivieren
            tabBtn._active = true
            activeTab = id
            
            -- Content Panel leeren und neu füllen
            rightPanel:Clear()
            func(rightPanel)
        end
        
        tabs[id] = tabBtn
        return tabBtn
    end

    -- Tabs erstellen
    CreateTab(LANG.ADMIN_MENU_PLAYER_MANAGEMENT, "admin", function(base)
        -- Header
        local listHeader = vgui.Create("DPanel", base)
        listHeader:Dock(TOP)
        listHeader:SetTall(PD.H(40))
        listHeader:DockMargin(0, 0, 0, PD.H(10))
        listHeader.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
            surface.SetDrawColor(PD.Theme.Colors.AccentGray)
            surface.DrawRect(0, 0, w, 1)
            surface.DrawRect(0, h - 1, w, 1)
            
            draw.DrawText("SPIELER DATENBANK", "MLIB.14", PD.W(15), h / 2 - PD.H(7), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
            draw.DrawText(table.Count(PD.Char.AdminData) .. " Einträge", "MLIB.12", w - PD.W(15), h / 2 - PD.H(6), PD.Theme.Colors.TextDim, TEXT_ALIGN_RIGHT)
        end

        PrintTable(PD.Char.AdminData)

        local plySearch = PD.TextEntry(base, "Spieler suchen...", "")
        plySearch:Dock(TOP)

        local scroll = PD.Scroll(base)

        local function listPLayers()
            local searchString = plySearch:GetValue()

            scroll:GetCanvas():Clear()

            for k, v in pairs(PD.Char.AdminData) do
                local ply = FindPlayerbyID(k)
                local isOnline = IsValid(ply)
                local name = isOnline and (ply:Nick() .. " | Online") or (steamworks.GetPlayerName(k) .. " (Steam) | Offline")

                if string.len(searchString) == 0 or string.find(string.lower(name), string.lower(searchString)) then
                    local btn = PD.Button(name, scroll, function()
                        v.steamid = k
                        PlayerAdminInteract(v, rightPanel)
                    end)
                    btn:Dock(TOP)
                    btn:SetTall(PD.H(45))
                    btn:SetAccentColor(isOnline and PD.Theme.Colors.StatusActive or PD.Theme.Colors.StatusInactive)
                end
            end
        end

        plySearch.OnChange = function(self)
            listPLayers()
        end

        listPLayers()
    end)

    for k, v in pairs(PD.Admin.Job_Edit_Whitelist) do
        if LocalPlayer():GetUserGroup() == v then
            CreateTab("Jobs", "jobs", function(base)
                PD.JOBS.AdminMenu(base)
            end)
            break
        end
    end

    CreateTab("Logs", "logs", function(base)
        PD.LOGS:Menu(base)
    end)

    CreateTab("Playerspawns", "spawns", function(base)
        PlayerSpawnMenu(base)
    end)

    -- Ersten Tab aktivieren
    if tabs["admin"] then
        tabs["admin"]:DoClick()
    end
end

concommand.Add("pd_admin_print_data", function()
    PrintTable(PD.Char.AdminData[Entity(1):SteamID64()])
end)

