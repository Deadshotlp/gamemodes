-- Logs System - Star Wars Andor Imperial Style (Zentral über PD.Theme)

PD.LOGS = PD.LOGS or {}

local Logs = {}
net.Receive("PD.LOGS.Add", function()
    Logs = net.ReadTable()
end)

timer.Simple(1, function()
    net.Start("PD.LOGS.Sync")
    net.SendToServer()
end)

function PD.LOGS:Menu(panel)
    if not IsValid(panel) then return end
    panel:Clear()

    -- Header
    local header = vgui.Create("DPanel", panel)
    header:Dock(TOP)
    header:SetTall(PD.H(50))
    header:DockMargin(0, 0, 0, PD.H(10))
    header.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        
        -- Linke Akzentlinie
        surface.SetDrawColor(PD.Theme.Colors.AccentBlue)
        surface.DrawRect(0, 0, PD.W(4), h)
        
        -- Obere/Untere Linie
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(PD.W(4), 0, w - PD.W(4), 1)
        surface.DrawRect(PD.W(4), h - 1, w - PD.W(4), 1)
        
        -- Titel
        draw.DrawText("SYSTEM LOGS", "MLIB.18", PD.W(20), h / 2 - PD.H(9), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
        
        -- Anzahl
        draw.DrawText(#Logs .. " Einträge", "MLIB.12", w - PD.W(15), h / 2 - PD.H(6), PD.Theme.Colors.TextDim, TEXT_ALIGN_RIGHT)
    end

    -- Linke Spalte (Liste)
    local left = vgui.Create("DPanel", panel)
    left:Dock(LEFT)
    left:SetWide(PD.W(200))
    left.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(w - 1, 0, 1, h)
    end

    -- Rechte Spalte (Editor)
    local right = vgui.Create("DPanel", panel)
    right:Dock(FILL)
    right:DockMargin(PD.W(10), 0, 0, 0)
    right.Paint = function() end

    -- Suchfeld
    local search = PD.TextEntry(left, "Log durchsuchen...", "", function() end)
    search:Dock(TOP)
    search:SetTall(PD.H(40))
    search:DockMargin(0, 0, 0, PD.H(10))

    -- Scroll-Container
    local scroll = PD.Scroll(right)

    local tag_tbl = {}


    -- Funktion zum Anzeigen der Logs
    local function DisplayLogs(filter)
        -- Scroll leeren
        for _, child in pairs(scroll:GetCanvas():GetChildren()) do
            child:Remove()
        end

        local filterLower = filter and string.lower(filter) or ""
        local count = 0

        for k, v in pairs(Logs) do
            local matchText = v.text and string.lower(v.text) or ""
            local matchTyp = v.typ and string.lower(v.typ) or ""

            if not table.HasValue(tag_tbl, v.typ) then
                table.insert(tag_tbl, v.typ)
            end
            
            if filterLower == "" or string.find(matchText, filterLower, 1, true) or string.find(matchTyp, filterLower, 1, true) then
                count = count + 1
                
                local log = vgui.Create("DPanel", scroll)
                log:Dock(TOP)
                log:DockMargin(0, 0, 0, PD.H(3))
                log:SetTall(PD.H(40))
                
                local logColor = v.color or PD.Theme.Colors.Text
                
                log.Paint = function(s, w, h)
                    -- Hintergrund
                    draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
                    
                    -- Linke Farbmarkierung (Log-Typ Farbe)
                    surface.SetDrawColor(logColor)
                    surface.DrawRect(0, 0, PD.W(3), h)
                    
                    -- Untere Linie
                    surface.SetDrawColor(PD.Theme.Colors.AccentGray.r, PD.Theme.Colors.AccentGray.g, PD.Theme.Colors.AccentGray.b, 50)
                    surface.DrawRect(PD.W(3), h - 1, w - PD.W(3), 1)
                    
                    -- Typ Badge
                    local typ = v.typ or "INFO"
                    surface.SetFont("MLIB.12")
                    local typW, _ = surface.GetTextSize(typ)
                    
                    -- Badge Hintergrund
                    draw.RoundedBox(0, PD.W(12), PD.H(10), typW + PD.W(16), PD.H(20), PD.ColorAlpha(logColor, 0.3))
                    surface.SetDrawColor(logColor)
                    surface.DrawOutlinedRect(PD.W(12), PD.H(10), typW + PD.W(16), PD.H(20), 1)
                    
                    -- Typ Text
                    draw.DrawText(typ, "MLIB.12", PD.W(20), PD.H(13), logColor, TEXT_ALIGN_LEFT)
                    
                    -- Log Text
                    local textX = PD.W(12) + typW + PD.W(30)
                    local text = v.text or ""
                    if #text > 60 then
                        text = string.sub(text, 1, 57) .. "..."
                    end
                    draw.DrawText(text, "MLIB.14", textX, h / 2 - PD.H(7), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
                    
                    -- Datum rechts
                    draw.DrawText(v.date or "", "MLIB.12", w - PD.W(10), h / 2 - PD.H(6), PD.Theme.Colors.TextDim, TEXT_ALIGN_RIGHT)
                end
            end
        end

        -- Keine Ergebnisse
        if count == 0 then
            local noResults = vgui.Create("DPanel", scroll)
            noResults:Dock(TOP)
            noResults:SetTall(PD.H(60))
            noResults.Paint = function(s, w, h)
                draw.DrawText("Keine Logs gefunden", "MLIB.16", w / 2, h / 2 - PD.H(8), PD.Theme.Colors.TextMuted, TEXT_ALIGN_CENTER)
            end
        end
    end

    local function DisplayTags()
        -- Scroll leeren
        for _, child in pairs(left:GetChildren()) do
            if child ~= search then
                child:Remove()
            end
        end

        for _, tag in pairs(tag_tbl) do
            local btn = PD.Button(tag, left, function()
                search:SetValue(tag)
                DisplayLogs(tag)
            end)

            btn:Dock(TOP)
        end
    end

    -- Initial anzeigen
    DisplayLogs("")
    DisplayTags()

    -- Suche aktualisieren
    search.OnChange = function(self)
        DisplayLogs(self:GetValue())
    end

    search.OnEnter = function(self)
        DisplayLogs(self:GetValue())
    end
end
