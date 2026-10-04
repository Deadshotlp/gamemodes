--[[
    Naval - Admin-Tab "Raumflotte" (Client).

    Links die Taktik-Ansicht mit allen Schiffen im System, rechts die
    Werkzeuge: Simulation pausieren, Schiffe erzeugen (vor dem Map-Schiff
    oder per Klick), auswaehlen, bearbeiten, Befehle (halten, bewegen,
    Patrouille, anfliegen, Orbit, springen), loeschen, Map-Schiff versetzen,
    Konsolen sperren. Gegenstueck: sv_naval_admintool.lua.

    Klicks in der Ansicht treffen die Ebene des Map-Schiffs; die Ansicht
    dafuer etwas schraeg stellen (ziehen).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

net.Receive("PD.Naval.AdminData", function()
    local size = net.ReadUInt(16)
    local json = util.Decompress(net.ReadData(size))
    C.admin = json and util.JSONToTable(json) or C.admin
    hook.Run("PD.Naval.AdminData")
end)

local function Send(action, args)
    net.Start("PD.Naval.Admin")
    net.WriteString(action)
    net.WriteString(util.TableToJSON(args or {}) or "{}")
    net.SendToServer()
end

local function FindSystem(text)
    local static = C.static
    text = string.lower(string.Trim(text or ""))
    if not static or text == "" then return nil end

    for _, s in ipairs(static.systemList) do
        if string.lower(s.name) == text then return s end
    end
    for _, s in ipairs(static.systemList) do
        for planet in string.gmatch(string.lower(s.planets or ""), "[^,]+") do
            if string.Trim(planet) == text then return s end
        end
    end
    for _, s in ipairs(static.systemList) do
        if string.find(s.search or string.lower(s.name), text, 1, true) then return s end
    end
end

local function AdminShip(id)
    for _, row in ipairs((C.admin and C.admin.ships) or {}) do
        if row.id == id then return row end
    end
end

local STATE_LABEL = {normal = "normal", spooling = "fährt hoch", jumping = "springt", hyperspace = "Hyperraum",
    exiting = "Austritt", disabled = "kampfunfähig", destroyed = "zerstört"}

function Naval.AdminMenu(base)
    local UI = Naval.UI
    local COL = UI.COL

    if not Naval.IsNavalMap() or not C.static then
        local label = vgui.Create("DLabel", base)
        label:Dock(TOP)
        label:SetTall(40)
        label:SetFont("MLIB.18")
        label:SetText("Das Naval-System ist auf dieser Map nicht aktiv (pd_naval_active 1 und Map-Neustart).")
        return
    end

    local holder = vgui.Create("DPanel", base)
    holder:Dock(FILL)
    holder.Paint = nil
    Send("watch", {on = true})
    holder.OnRemove = function() Send("watch", {on = false}) end

    local side = vgui.Create("DScrollPanel", holder)
    side:Dock(RIGHT)
    side:SetWide(math.min(420, ScrW() * 0.3))
    side:DockMargin(8, 0, 0, 0)

    local tac = vgui.Create("PD_NavalTactical", holder)
    tac:Dock(FILL)
    tac.AdminMode = true
    tac.Range = 100000

    local selected
    local pickMode

    local function SetPick(mode, hint, onPick)
        pickMode = mode
        tac.PickHint = hint
        tac.OnPick = onPick
        if not mode then tac.Marks = nil end
    end

    tac.OnRightClick = function()
        if pickMode == "patrol" and tac.Marks and #tac.Marks >= 2 and selected then
            Send("order", {id = selected, type = "patrol", points = tac.Marks})
        end
        SetPick(nil)
    end

    ----------------------------------------------------------------------------
    -- Bausteine
    ----------------------------------------------------------------------------

    local function Header(text)
        local p = side:Add("DPanel")
        p:Dock(TOP)
        p:DockMargin(0, 10, 0, 4)
        p:SetTall(26)
        p.Paint = function(s, w, h)
            surface.SetDrawColor(COL.accent)
            surface.DrawRect(0, h - 2, w, 2)
            draw.SimpleText(text, "MLIB.18", 2, 2, COL.text)
        end
    end

    local function Row(height)
        local p = side:Add("DPanel")
        p:Dock(TOP)
        p:DockMargin(0, 0, 0, 4)
        p:SetTall(height or 32)
        p.Paint = nil
        return p
    end

    local function Buttons(defs)
        local row = Row(32)
        local buttons = {}
        for i, d in ipairs(defs) do
            local b = UI.Button(row, d[1], d[2], d[3] and function() return d[3] end)
            buttons[i] = b
        end
        row.PerformLayout = function(s, w, h)
            local bw = (w - (#buttons - 1) * 4) / #buttons
            for i, b in ipairs(buttons) do
                b:SetPos((i - 1) * (bw + 4), 0)
                b:SetSize(bw, h)
            end
        end
        return buttons
    end

    local function Entry(placeholder, value)
        local e = vgui.Create("DTextEntry", Row(30))
        e:Dock(FILL)
        e:SetFont("MLIB.16")
        e:SetPlaceholderText(placeholder)
        if value then e:SetValue(value) end
        return e
    end

    local function Combo(entries, default)
        local c = vgui.Create("DComboBox", Row(30))
        c:Dock(FILL)
        c:SetFont("MLIB.16")
        for _, e in ipairs(entries) do c:AddChoice(e[2], e[1], e[1] == default) end
        return c
    end

    local function Info(height, paint)
        local p = Row(height)
        p.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, COL.panel)
            paint(s, w, h)
        end
        return p
    end

    local static = C.static

    local classes, factions = {}, {}
    for id, c in SortedPairsByMemberValue(static.classes, "name") do classes[#classes + 1] = {id, c.name} end
    for id, f in SortedPairsByMemberValue(static.factions, "name") do factions[#factions + 1] = {id, f.name} end

    local function ComboValue(c)
        local _, data = c:GetSelected()
        return data
    end

    ----------------------------------------------------------------------------
    -- Status
    ----------------------------------------------------------------------------

    Header("Lage")
    Info(64, function(s, w, h)
        local a = C.admin or {}
        local inSystem = 0
        for _, row in ipairs(a.ships or {}) do
            if row.systemId == a.systemId then inSystem = inSystem + 1 end
        end
        draw.SimpleText("Map-Schiff in: " .. Naval.SystemName(a.systemId), "MLIB.16", 8, 6, COL.text)
        draw.SimpleText(("%d Schiffe gesamt, %d im System"):format(#(a.ships or {}), inSystem), "MLIB.16", 8, 26, COL.dim)
        draw.SimpleText(a.paused and "SIMULATION PAUSIERT" or "Simulation läuft", "MLIB.14", 8, 46, a.paused and COL.warn or COL.ok)
    end)
    Buttons({{"Pause an/aus", function() Send("pause") end, COL.warn}})

    ----------------------------------------------------------------------------
    -- Erzeugen
    ----------------------------------------------------------------------------

    Header("Schiff erzeugen")
    local cClass = Combo(classes, "acclamator")
    local cFaction = Combo({{"", "Fraktion der Klasse"}, unpack(factions)}, "")
    local eName = Entry("Name (optional)")
    local eDist = Entry("Abstand voraus in km", "10")

    local function SpawnArgs(rel)
        local faction = ComboValue(cFaction)
        return {classId = ComboValue(cClass), factionId = faction ~= "" and faction or nil, name = eName:GetValue(),
            distanceKm = tonumber(eDist:GetValue()) or 10, rel = rel}
    end

    Buttons({
        {"Vor dem Map-Schiff", function() Send("spawn", SpawnArgs()) end, COL.ok},
        {"Per Klick", function()
            SetPick("spawn", "Klick: Schiff hier erzeugen  -  Rechtsklick: fertig", function(_, p)
                Send("spawn", SpawnArgs(p))
            end)
        end},
    })

    ----------------------------------------------------------------------------
    -- Alle Schiffe
    ----------------------------------------------------------------------------

    Header("Schiffe")
    local list = vgui.Create("DListView", Row(200))
    list:Dock(FILL)
    list:SetMultiSelect(false)
    list:AddColumn("Name")
    list:AddColumn("System")
    list:AddColumn("Zustand"):SetFixedWidth(80)

    local function Select(id)
        selected = id
        tac.Selected = id
    end

    list.OnRowSelected = function(_, _, line) Select(line.ShipId) end
    tac.OnSelect = function(_, id) if id then Select(id) end end

    local listKey
    local function RefreshList()
        if not IsValid(list) then return end
        local rows = (C.admin and C.admin.ships) or {}
        local parts = {}
        for _, r in ipairs(rows) do parts[#parts + 1] = r.id .. r.name .. r.systemId .. r.state end
        local key = table.concat(parts, "|")
        if key == listKey then return end
        listKey = key

        list:Clear()
        table.sort(rows, function(a, b) return a.id < b.id end)
        for _, r in ipairs(rows) do
            local line = list:AddLine((r.map and "★ " or "") .. r.name, Naval.SystemName(r.systemId), STATE_LABEL[r.state] or r.state)
            line.ShipId = r.id
            if r.id == selected then line:SetSelected(true) end
        end
    end
    hook.Add("PD.Naval.AdminData", holder, RefreshList)
    RefreshList()

    ----------------------------------------------------------------------------
    -- Ausgewaehltes Schiff
    ----------------------------------------------------------------------------

    Header("Ausgewähltes Schiff")
    Info(70, function(s, w, h)
        local r = selected and AdminShip(selected)
        if not r then
            draw.SimpleText("In der Ansicht oder Liste auswählen", "MLIB.16", 8, 8, COL.dim)
            return
        end
        local class = static.classes[r.classId]
        local faction = static.factions[r.factionId]
        draw.SimpleText(("#%d %s"):format(r.id, r.name), "MLIB.18", 8, 4, COL.text)
        draw.SimpleText((class and class.name or r.classId) .. " - " .. (faction and faction.name or r.factionId), "MLIB.14", 8, 26, COL.dim)
        local line = (STATE_LABEL[r.state] or r.state) .. ", " .. r.speed .. " m/s"
        if r.order then line = line .. ", Befehl: " .. r.order .. (r.orders > 1 and (" (+" .. (r.orders - 1) .. ")") or "") end
        if r.to then line = line .. " -> " .. Naval.SystemName(r.to) end
        draw.SimpleText(line, "MLIB.14", 8, 46, COL.text)
    end)

    local eEditName = Entry("Neuer Name")
    local cEditFaction = Combo({{"", "Fraktion unverändert"}, unpack(factions)}, "")
    Buttons({{"Übernehmen", function()
        if not selected then return end
        Send("edit", {id = selected, name = eEditName:GetValue(), factionId = ComboValue(cEditFaction)})
        eEditName:SetValue("")
    end}})

    Buttons({
        {"Halten", function() if selected then Send("order", {id = selected, type = "hold"}) end end},
        {"Bewegen (Klick)", function()
            if not selected then return end
            SetPick("move", "Klick: Ziel  -  Rechtsklick: abbrechen", function(_, p)
                Send("order", {id = selected, type = "move", rel = p})
                SetPick(nil)
            end)
        end},
        {"Patrouille", function()
            if not selected then return end
            tac.Marks = {}
            SetPick("patrol", "Klicks: Wegpunkte  -  Rechtsklick: Patrouille starten", function(_, p)
                tac.Marks[#tac.Marks + 1] = p
            end)
            tac.Marks = {}
        end},
    })

    local bodies = {}
    if C.system then
        for _, b in ipairs(C.system.bodies or {}) do bodies[#bodies + 1] = {b.id, b.name .. " (" .. b.type .. ")"} end
        table.sort(bodies, function(a, b) return a[2] < b[2] end)
    end
    local cBody = Combo(bodies)
    local eRadius = Entry("Orbit-Radius in km (leer = automatisch)")
    Buttons({
        {"Anfliegen", function()
            if selected and ComboValue(cBody) then Send("order", {id = selected, type = "approach", bodyId = ComboValue(cBody)}) end
        end},
        {"Orbit", function()
            if selected and ComboValue(cBody) then
                Send("order", {id = selected, type = "orbit", bodyId = ComboValue(cBody), radiusKm = tonumber(eRadius:GetValue())})
            end
        end},
    })

    local eJump = Entry("Sprungziel (System oder Planet)")
    Buttons({
        {"Springen", function()
            local sys = FindSystem(eJump:GetValue())
            if not sys then notification.AddLegacy("System nicht gefunden", NOTIFY_ERROR, 3) return end
            if selected then Send("order", {id = selected, type = "jump", systemId = sys.id}) end
        end},
        {"Löschen", function()
            local r = selected and AdminShip(selected)
            if not r or r.map then return end
            Derma_Query(r.name .. " wirklich löschen?", "Raumflotte", "Löschen", function()
                Send("delete", {id = r.id})
                Select(nil)
            end, "Abbrechen")
        end, COL.bad},
    })

    ----------------------------------------------------------------------------
    -- Map-Schiff
    ----------------------------------------------------------------------------

    Header("Map-Schiff")
    local eRelocate = Entry("Zielsystem")
    Buttons({{"Ohne Sprung versetzen", function()
        local sys = FindSystem(eRelocate:GetValue())
        if not sys then notification.AddLegacy("System nicht gefunden", NOTIFY_ERROR, 3) return end
        Derma_Query("Map-Schiff sofort nach " .. sys.name .. " versetzen?", "Raumflotte", "Versetzen", function()
            Send("relocate", {systemId = sys.id})
        end, "Abbrechen")
    end, COL.warn}})

    ----------------------------------------------------------------------------
    -- Konsolen
    ----------------------------------------------------------------------------

    Header("Konsolen")
    for _, ent in ipairs(ents.FindByClass("pd_naval_console")) do
        local def = ent:StationDef()
        if def and not def.noUse then
            local b = Buttons({{"", function() Send("console_lock", {ent = ent:EntIndex()}) end}})[1]
            b.Think = function(s)
                if not IsValid(ent) then s.Label = "(entfernt)" return end
                s.Label = def.name .. " #" .. ent:GetConsoleId() .. ": " .. (ent:GetLocked() and "GESPERRT" or "frei")
            end
        end
    end
end

if PD.Admin and PD.Admin.AddTab then
    PD.Admin:AddTab("naval", "Raumflotte", function(base)
        Naval.AdminMenu(base)
    end, nil, 60)
end
