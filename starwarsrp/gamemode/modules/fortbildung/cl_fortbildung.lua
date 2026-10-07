PD.FB = PD.FB or {}

-- Laufender Kurs, den der lokale Spieler leitet. nil wenn keiner offen ist.
PD.FB.CurrentSession = nil
PD.FB.History = PD.FB.History or {}

local activeTab = "own"

--------------------------------------------------------------------------------
-- Netzwerk
--------------------------------------------------------------------------------

net.Receive("PD.FB.SyncCatalog", function()
    PD.FB.Courses = net.ReadTable()
    PD.FB:RefreshInterface()
end)

net.Receive("PD.FB.CourseDelta", function()
    local key = net.ReadString()
    local exists = net.ReadBool()

    if exists then
        PD.FB.Courses[key] = net.ReadTable()
    else
        PD.FB.Courses[key] = nil
    end

    PD.FB:RefreshInterface()
end)

net.Receive("PD.FB.SyncPlayer", function()
    -- Vom Server mitgeschickt, siehe PD.FB.SyncPlayer.
    local charID = net.ReadString()

    PD.FB.Granted = {}

    if charID ~= "" then
        PD.FB.Granted[charID] = net.ReadTable()
    else
        net.ReadTable()
    end

    PD.FB.Eligible = net.ReadTable()
    PD.FB:RefreshInterface()
end)

net.Receive("PD.FB.PublicBadges", function()
    PD.FB.PublicBadges = net.ReadTable()
end)

net.Receive("PD.FB.SessionState", function()
    local open = net.ReadBool()

    PD.FB.CurrentSession = open and net.ReadTable() or nil

    PD.FB:RefreshInterface()
end)

net.Receive("PD.FB.History", function()
    local charID = net.ReadString()

    PD.FB.History[charID] = net.ReadTable()
    PD.FB:RefreshInterface()
end)

--------------------------------------------------------------------------------
-- Abzeichen für fremde Ansichten (Scoreboard)
--------------------------------------------------------------------------------

-- Zeichnet kleine Farbmarker für die aktiven Fortbildungen eines Spielers und
-- gibt die belegte Breite zurück. Quelle ist die kompakte PublicBadges-Liste,
-- nicht die vollen Vergabedaten.
function PD.FB.DrawBadges(ply, x, y, size)
    if not IsValid(ply) then return 0 end

    local charID = PD.FB.GetCharID(ply)
    if not charID then return 0 end

    local keys = PD.FB.PublicBadges[charID]
    if not keys then return 0 end

    size = size or PD.H(10)

    local gap = PD.W(4)
    local drawn = 0

    for _, course in ipairs(PD.FB.GetSortedCourses()) do
        if table.HasValue(keys, course.fb_key) then
            local color = PD.FB.ToColor(course.color)

            surface.SetDrawColor(color.r, color.g, color.b, color.a)
            surface.DrawRect(x + drawn * (size + gap), y, size, size)

            drawn = drawn + 1

            if drawn >= 8 then break end
        end
    end

    return drawn * (size + gap)
end

local function requestSync()
    net.Start("PD.FB.SyncCatalog")
    net.SendToServer()
end

local function sendSession(action, writer)
    net.Start("PD.FB.Session")
        net.WriteString(action)

        if writer then writer() end
    net.SendToServer()
end

--------------------------------------------------------------------------------
-- Bausteine
--------------------------------------------------------------------------------

local function sectionHeader(parent, text)
    local header = vgui.Create("DPanel", parent)
    header:Dock(TOP)
    header:SetTall(PD.H(32))
    header:DockMargin(0, 0, 0, PD.H(8))

    header.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
        surface.DrawRect(0, 0, PD.W(3), h)
        draw.DrawText(text, "MLIB.14", PD.W(12), h / 2 - PD.H(7), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
    end

    return header
end

-- Eine Zeile mit farbigem Streifen links, Titel und Untertitel. Wird für
-- Fortbildungen, Teilnehmer und Historieneinträge gleichermaßen benutzt.
local function infoRow(parent, title, subtitle, color, height, course)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:SetTall(height or PD.H(52))
    row:DockMargin(0, 0, 0, PD.H(5))

    row.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
        surface.SetDrawColor(color or PD.Theme.Colors.AccentGray)
        surface.DrawRect(0, 0, PD.W(3), h)

        local ix = course and PD.FB.DrawIcon(course, PD.W(15), PD.H(8), PD.H(18)) or 0
        draw.DrawText(title, "MLIB.16", PD.W(15) + ix, PD.H(8), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)

        if subtitle and subtitle ~= "" then
            draw.DrawText(subtitle, "MLIB.12", PD.W(15), PD.H(28), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
        end
    end

    return row
end

local function emptyHint(parent, text)
    local lbl = PD.Label(text, parent, {
        height = PD.H(30),
        color = PD.Theme.Colors.TextMuted,
        font = "MLIB.14",
        align = 5
    })

    return lbl
end

--------------------------------------------------------------------------------
-- Reiter: Meine Fortbildungen
--------------------------------------------------------------------------------

local function buildOwnTab(base)
    local charID = PD.FB.GetCharID(LocalPlayer())

    sectionHeader(base, "MEINE FORTBILDUNGEN")

    local scroll = PD.Scroll(base)
    local active = PD.FB.GetActiveCourses(charID)

    if table.Count(active) == 0 then
        emptyHint(scroll, "Du hast noch keine Fortbildungen abgeschlossen.")
        return
    end

    for _, course in ipairs(PD.FB.GetSortedCourses()) do
        local entry = active[course.fb_key]

        if entry then
            local subtitle = PD.FB.FormatRemaining(entry) .. "  |  erhalten am " .. PD.FB.FormatDate(entry.granted_at)
            local row = infoRow(scroll, course.name, subtitle, PD.FB.ToColor(course.color), nil, course)

            if course.description and course.description ~= "" then
                row:SetTall(PD.H(72))

                local desc = course.description
                local oldPaint = row.Paint

                row.Paint = function(s, w, h)
                    oldPaint(s, w, h)
                    draw.DrawText(desc, "MLIB.12", PD.W(15), PD.H(48), PD.Theme.Colors.TextMuted, TEXT_ALIGN_LEFT)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Reiter: Katalog
--------------------------------------------------------------------------------

local function buildCatalogTab(base)
    local charID = PD.FB.GetCharID(LocalPlayer())

    sectionHeader(base, "ALLE FORTBILDUNGEN")

    local search = PD.TextEntry(base, "Fortbildung suchen...", "")
    search:Dock(TOP)

    local scroll = PD.Scroll(base)

    local function rebuild()
        scroll:GetCanvas():Clear()

        local filter = string.lower(search:GetValue() or "")
        local shown = 0

        for _, course in ipairs(PD.FB.GetSortedCourses()) do
            if filter == "" or string.find(string.lower(course.name), filter, 1, true) then
                shown = shown + 1

                local status, color

                if PD.FB.HasCourse(charID, course.fb_key) then
                    status = "Abgeschlossen"
                    color = PD.Theme.Colors.StatusActive
                elseif PD.FB.Eligible[course.fb_key] then
                    status = "Kann absolviert werden"
                    color = PD.Theme.Colors.AccentBlue
                else
                    local ok, reason = PD.FB.HasRequirements(charID, course.fb_key)
                    status = ok and "Nicht freigegeben" or reason
                    color = PD.Theme.Colors.StatusInactive
                end

                local details = {}

                if #(course.equip or {}) > 0 then
                    table.insert(details, #course.equip .. " Ausrüstung")
                end

                if #(course.model or {}) > 0 then
                    table.insert(details, #course.model .. " Model(s)")
                end

                if course.duration_days and course.duration_days > 0 then
                    table.insert(details, "gültig " .. course.duration_days .. " Tage")
                end

                local subtitle = status

                if #details > 0 then
                    subtitle = subtitle .. "  |  " .. table.concat(details, ", ")
                end

                infoRow(scroll, course.name, subtitle, color, nil, course)
            end
        end

        if shown == 0 then
            emptyHint(scroll, "Keine Fortbildung gefunden.")
        end
    end

    search.OnChange = function()
        rebuild()
    end

    rebuild()
end

--------------------------------------------------------------------------------
-- Reiter: Historie
--------------------------------------------------------------------------------

local function buildHistoryTab(base)
    local charID = PD.FB.GetCharID(LocalPlayer())

    sectionHeader(base, "KURSHISTORIE")

    local scroll = PD.Scroll(base)

    if not charID then
        emptyHint(scroll, "Kein Charakter aktiv.")
        return
    end

    local rows = PD.FB.History[charID]

    if not rows then
        emptyHint(scroll, "Historie wird geladen...")

        net.Start("PD.FB.History")
            net.WriteString(charID)
        net.SendToServer()

        return
    end

    if #rows == 0 then
        emptyHint(scroll, "Noch an keinem Kurs teilgenommen.")
        return
    end

    for _, row in ipairs(rows) do
        local result = tonumber(row.result) or PD.FB.RESULT_OPEN
        local color = PD.Theme.Colors.AccentGray

        if result == PD.FB.RESULT_PASSED then
            color = PD.Theme.Colors.StatusActive
        elseif result == PD.FB.RESULT_FAILED then
            color = PD.Theme.Colors.StatusCritical
        end

        local subtitle = PD.FB.ResultNames[result] .. "  |  Ausbilder: " .. (row.instructor_name or "?")
            .. "  |  " .. PD.FB.FormatDate(tonumber(row.started_at))

        infoRow(scroll, PD.FB.GetCourseName(row.fb_key), subtitle, color)
    end
end

--------------------------------------------------------------------------------
-- Reiter: Ausbildung
--------------------------------------------------------------------------------

local function buildStartCourse(base, teachable)
    sectionHeader(base, "KURS ERÖFFNEN")

    local selected = nil

    local dropdown = PD.Dropdown(base, "Fortbildung wählen...", function(text, data)
        selected = data
    end)
    dropdown:Dock(TOP)

    for _, course in ipairs(PD.FB.GetSortedCourses()) do
        if teachable[course.fb_key] then
            dropdown:AddOption(course.name, course.fb_key)
        end
    end

    local startBtn = PD.Button("Kurs eröffnen", base, function()
        if not selected then
            PD.Popup("Bitte zuerst eine Fortbildung wählen.", PD.Theme.Colors.AccentOrange)
            return
        end

        sendSession("start", function()
            net.WriteString(selected)
        end)
    end)
    startBtn:Dock(TOP)
    startBtn:SetAccentColor(PD.Theme.Colors.AccentGreen)
end

local function buildParticipantList(parent, session)
    sectionHeader(parent, "TEILNEHMER")

    local scroll = PD.Scroll(parent)

    if table.Count(session.participants or {}) == 0 then
        emptyHint(scroll, "Noch keine Teilnehmer eingetragen.")
        return
    end

    for charID, participant in SortedPairs(session.participants) do
        local result = participant.result or PD.FB.RESULT_OPEN
        local color = PD.Theme.Colors.AccentGray

        if result == PD.FB.RESULT_PASSED then
            color = PD.Theme.Colors.StatusActive
        elseif result == PD.FB.RESULT_FAILED then
            color = PD.Theme.Colors.StatusCritical
        end

        local row = infoRow(scroll, participant.name or charID, PD.FB.ResultNames[result], color, PD.H(48))

        local removeBtn = PD.Button("Entfernen", row, function()
            sendSession("remove", function()
                net.WriteString(charID)
            end)
        end)
        removeBtn:Dock(RIGHT)
        removeBtn:SetWide(PD.W(100))
        removeBtn:DockMargin(0, PD.H(6), PD.W(5), PD.H(6))
        removeBtn:SetAccentColor(PD.Theme.Colors.AccentGray)

        local failBtn = PD.Button("Durchgefallen", row, function()
            sendSession("result", function()
                net.WriteString(charID)
                net.WriteUInt(PD.FB.RESULT_FAILED, 4)
                net.WriteString("")
            end)
        end)
        failBtn:Dock(RIGHT)
        failBtn:SetWide(PD.W(130))
        failBtn:DockMargin(0, PD.H(6), PD.W(5), PD.H(6))
        failBtn:SetAccentColor(PD.Theme.Colors.AccentRed)

        local passBtn = PD.Button("Bestanden", row, function()
            sendSession("result", function()
                net.WriteString(charID)
                net.WriteUInt(PD.FB.RESULT_PASSED, 4)
                net.WriteString("")
            end)
        end)
        passBtn:Dock(RIGHT)
        passBtn:SetWide(PD.W(120))
        passBtn:DockMargin(0, PD.H(6), PD.W(5), PD.H(6))
        passBtn:SetAccentColor(PD.Theme.Colors.AccentGreen)
    end
end

local function buildAddPlayer(parent, session)
    sectionHeader(parent, "SPIELER HINZUFÜGEN")

    local search = PD.TextEntry(parent, "Spieler suchen...", "")
    search:Dock(TOP)

    local scroll = PD.Scroll(parent)

    local function rebuild()
        scroll:GetCanvas():Clear()

        local filter = string.lower(search:GetValue() or "")
        local shown = 0

        for _, target in ipairs(player.GetAll()) do
            local charID = PD.FB.GetCharID(target)
            local name = target:Nick()

            if charID and not (session.participants or {})[charID] then
                if filter == "" or string.find(string.lower(name), filter, 1, true) then
                    shown = shown + 1

                    local btn = PD.Button(name, scroll, function()
                        sendSession("add", function()
                            net.WriteEntity(target)
                        end)
                    end)
                    btn:Dock(TOP)
                    btn:SetTall(PD.H(38))
                    btn:SetAccentColor(PD.Theme.Colors.AccentBlue)
                end
            end
        end

        if shown == 0 then
            emptyHint(scroll, "Keine passenden Spieler online.")
        end
    end

    search.OnChange = function()
        rebuild()
    end

    rebuild()
end

local function buildInstructorTab(base)
    local charID = PD.FB.GetCharID(LocalPlayer())
    local teachable = PD.FB.GetTeachableCourses(charID)
    local session = PD.FB.CurrentSession

    if not session then
        if table.Count(teachable) == 0 then
            sectionHeader(base, "AUSBILDUNG")
            emptyHint(PD.Scroll(base), "Du bist für keine Fortbildung als Ausbilder freigegeben.")
            return
        end

        buildStartCourse(base, teachable)
        return
    end

    -- Kopfzeile mit laufendem Kurs und den Abschlussaktionen
    local head = vgui.Create("DPanel", base)
    head:Dock(TOP)
    head:SetTall(PD.H(60))
    head:DockMargin(0, 0, 0, PD.H(10))

    head.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        surface.SetDrawColor(PD.Theme.Colors.AccentGreen)
        surface.DrawRect(0, 0, PD.W(3), h)

        draw.DrawText("Laufender Kurs: " .. PD.FB.GetCourseName(session.fb_key), "MLIB.16", PD.W(15), PD.H(10), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
        draw.DrawText("gestartet " .. PD.FB.FormatDate(session.started_at), "MLIB.12", PD.W(15), PD.H(34), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
    end

    local cancelBtn = PD.Button("Abbrechen", head, function()
        sendSession("cancel")
    end)
    cancelBtn:Dock(RIGHT)
    cancelBtn:SetWide(PD.W(130))
    cancelBtn:DockMargin(0, PD.H(10), PD.W(10), PD.H(10))
    cancelBtn:SetAccentColor(PD.Theme.Colors.AccentRed)

    local finishBtn = PD.Button("Kurs abschließen", head, function()
        sendSession("finish")
    end)
    finishBtn:Dock(RIGHT)
    finishBtn:SetWide(PD.W(180))
    finishBtn:DockMargin(0, PD.H(10), PD.W(5), PD.H(10))
    finishBtn:SetAccentColor(PD.Theme.Colors.AccentGreen)

    -- Zwei Spalten: links Teilnehmer, rechts Spielerauswahl
    local left = vgui.Create("DPanel", base)
    left:Dock(LEFT)
    left:SetWide(PD.W(520))
    left:DockMargin(0, 0, PD.W(10), 0)
    left.Paint = function() end

    local right = vgui.Create("DPanel", base)
    right:Dock(FILL)
    right.Paint = function() end

    buildParticipantList(left, session)
    buildAddPlayer(right, session)
end

--------------------------------------------------------------------------------
-- Hauptfenster
--------------------------------------------------------------------------------

local tabBuilders = {
    own = {name = "Meine Fortbildungen", order = 10, func = buildOwnTab},
    catalog = {name = "Katalog", order = 20, func = buildCatalogTab},
    history = {name = "Historie", order = 30, func = buildHistoryTab},
    instructor = {name = "Ausbildung", order = 40, func = buildInstructorTab}
}

local function getVisibleTabs()
    local charID = PD.FB.GetCharID(LocalPlayer())
    local canTeach = table.Count(PD.FB.GetTeachableCourses(charID)) > 0 or PD.FB.CurrentSession ~= nil

    local list = {}

    for id, tab in pairs(tabBuilders) do
        if id ~= "instructor" or canTeach then
            table.insert(list, {id = id, name = tab.name, order = tab.order, func = tab.func})
        end
    end

    table.sort(list, function(a, b) return a.order < b.order end)

    return list
end

function PD.FB:OpenInterface()
    if IsValid(PD.FB.Frame) then
        PD.FB.Frame:Remove()
        PD.FB.Frame = nil
        return
    end

    requestSync()

    local frame = PD.Frame("FORTBILDUNGEN", PD.W(1100), PD.H(720), true, {
        accent = PD.Theme.Colors.AccentGreen,
        grid = true
    })

    PD.FB.Frame = frame

    local content = frame:GetContentPanel()

    local tabBar = vgui.Create("DPanel", content)
    tabBar:Dock(TOP)
    tabBar:SetTall(PD.H(40))
    tabBar:DockMargin(0, 0, 0, PD.H(12))

    tabBar.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(0, h - 1, w, 1)
    end

    local body = vgui.Create("DPanel", content)
    body:Dock(FILL)
    body.Paint = function() end

    frame._tabBar = tabBar
    frame._body = body

    PD.FB:RefreshInterface()
end

-- Baut Tableiste und Inhalt neu auf. Wird nach jedem Sync gerufen, damit die
-- Ansicht nicht auf veralteten Daten stehen bleibt.
function PD.FB:RefreshInterface()
    local frame = PD.FB.Frame

    if not IsValid(frame) or not IsValid(frame._tabBar) or not IsValid(frame._body) then return end

    local tabs = getVisibleTabs()

    -- Aktiver Reiter kann verschwunden sein (z.B. Ausbilderstatus verloren)
    local stillThere = false

    for _, tab in ipairs(tabs) do
        if tab.id == activeTab then
            stillThere = true
            break
        end
    end

    if not stillThere then
        activeTab = tabs[1] and tabs[1].id or "own"
    end

    frame._tabBar:Clear()

    for _, tab in ipairs(tabs) do
        local id = tab.id

        local btn = vgui.Create("DButton", frame._tabBar)
        btn:SetText("")
        btn:Dock(LEFT)
        btn:SetWide(PD.W(200))

        btn.Paint = function(s, w, h)
            local isActive = activeTab == id

            if isActive then
                draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
                surface.SetDrawColor(PD.Theme.Colors.AccentGreen)
                surface.DrawRect(0, h - PD.H(3), w, PD.H(3))
            elseif s:IsHovered() then
                draw.RoundedBox(0, 0, 0, w, h, Color(PD.Theme.Colors.BackgroundLight.r, PD.Theme.Colors.BackgroundLight.g, PD.Theme.Colors.BackgroundLight.b, 100))
            end

            local textColor = isActive and PD.Theme.Colors.Text or PD.Theme.Colors.TextDim
            draw.DrawText(tab.name, "MLIB.14", w / 2, h / 2 - PD.H(7), textColor, TEXT_ALIGN_CENTER)
        end

        btn.DoClick = function()
            surface.PlaySound("UI/buttonclick.wav")
            activeTab = id
            PD.FB:RefreshInterface()
        end
    end

    frame._body:Clear()

    for _, tab in ipairs(tabs) do
        if tab.id == activeTab then
            tab.func(frame._body)
            break
        end
    end
end

--------------------------------------------------------------------------------
-- Öffnungswege
--------------------------------------------------------------------------------

PD.Binds = PD.Binds or {}
PD.Binds.btn = PD.Binds.btn or {}

PD.Binds.btn["open_fortbildung"] = {
    name = "Fortbildungen öffnen",
    desc = "Öffnet die Übersicht der eigenen Fortbildungen und Kurse.",
    category = "Allgemein",
    defaultkey = KEY_NONE,
    admin = false,
    downFunc = function() PD.FB:OpenInterface() end,
    upFunc = function() end,
    holdFunc = function() end
}

PD.FB.Interactions = {
    ["player"] = {
        [1] = {
            id = "open_fortbildung",
            name = "Fortbildungen",
            icon = nil,
            func = function(ply, ent, bone)
                PD.FB:OpenInterface()
            end,
            ad = {"self"}
        }
    }
}

hook.Add("PD.Interaction.Requested", "PD.FB.Interaction.Answer", function(ent_class)
    PD.IA.AddEntityActions(PD.FB.Interactions[ent_class], "Fortbildung")
end)

concommand.Add("pd_fortbildung", function()
    PD.FB:OpenInterface()
end)

-- Katalog beim Verbinden anfordern; der Server schickt zusätzlich von sich aus.
timer.Simple(2, function()
    requestSync()
end)
