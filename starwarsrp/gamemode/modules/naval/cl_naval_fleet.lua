--[[
    Naval - Flottenkommando (Client, nur Admins).

    Eigenes Fenster fuer Schiffe und Befehle: links die Taktik-Ansicht mit
    allen Schiffen im System des Map-Schiffs, rechts Liste aller Schiffe
    (alle Systeme), Erzeugen, Bearbeiten, Befehle, Map-Schiff versetzen.

    Oeffnen: Konsole pd_naval_flottenkommando, Taste (Tastenbelegung
    "Flottenkommando oeffnen"), Admin-Menue Raumflotte.
    Server: sv_naval_admintool.lua.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

local STATE_LABEL = {normal = "normal", spooling = "fährt hoch", jumping = "springt", hyperspace = "Hyperraum",
    exiting = "Austritt", disabled = "kampfunfähig", destroyed = "zerstört"}

local ORDER_LABEL = {hold = "halten", move = "fliegt", patrol = "Patrouille", orbit = "Orbit", jump = "Sprung", attack = "Angriff"}
local ROE_LABEL = {hold = "Feuer halten", ["return"] = "Nur zurückschießen", free = "Feuer frei (alle Feinde)"}

function Naval.FindSystemByText(text)
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

local frame

function Naval.OpenFleetCommand()
    if IsValid(frame) then frame:Close() return end
    if not LocalPlayer():IsAdmin() then return end

    local UI = Naval.UI
    local COL = UI.COL
    local Send = Naval.AdminSend
    local static = C.static

    if not Naval.IsNavalMap() or not static then
        notification.AddLegacy("Naval-System auf dieser Map nicht aktiv", NOTIFY_ERROR, 4)
        return
    end

    -- Admin-Menue schliessen, falls offen
    if IsValid(AdminmainFrame) then AdminmainFrame:Remove() end

    frame = UI.Frame("FLOTTENKOMMANDO", ScrW() - 60, ScrH() - 60)
    frame.Think = nil
    Send("watch", {on = true})
    frame.OnRemove = function() Send("watch", {on = false}) end

    local side = vgui.Create("DScrollPanel", frame)
    side:SetPos(frame:GetWide() - 440, 50)
    side:SetSize(420, frame:GetTall() - 66)

    local tac = vgui.Create("PD_NavalTactical", frame)
    tac:SetPos(16, 50)
    tac:SetSize(frame:GetWide() - 470, frame:GetTall() - 66)
    tac.AdminMode = true
    tac.Range = 100000

    local B = Naval.UIBuilder(side)
    local selected

    local function SetPick(mode, hint, onPick)
        tac.PickMode = mode
        tac.PickHint = hint
        tac.OnPick = onPick
        if not mode then tac.Marks = nil end
    end

    tac.OnRightClick = function()
        if tac.PickMode == "patrol" and tac.Marks and #tac.Marks >= 2 and selected then
            Send("order", {id = selected, type = "patrol", points = tac.Marks})
        end
        SetPick(nil)
    end

    local classes, factions = {}, {}
    for id, c in SortedPairsByMemberValue(static.classes, "name") do classes[#classes + 1] = {id, c.name} end
    for id, f in SortedPairsByMemberValue(static.factions, "name") do factions[#factions + 1] = {id, f.name} end

    ----------------------------------------------------------------------------
    -- Lage
    ----------------------------------------------------------------------------

    B.Header("Lage")
    B.Info(64, function(s, w, h)
        local a = C.admin or {}
        local inSystem = 0
        for _, row in ipairs(a.ships or {}) do
            if row.systemId == a.systemId then inSystem = inSystem + 1 end
        end
        draw.SimpleText("Map-Schiff in: " .. Naval.SystemName(a.systemId), "MLIB.16", 8, 6, COL.text)
        draw.SimpleText(("%d Schiffe gesamt, %d im System"):format(#(a.ships or {}), inSystem), "MLIB.16", 8, 26, COL.dim)
        draw.SimpleText(a.paused and "SIMULATION PAUSIERT" or "Simulation läuft", "MLIB.14", 8, 46, a.paused and COL.warn or COL.ok)
    end)
    B.Buttons({{"Pause an/aus", function() Send("pause") end, COL.warn}})

    ----------------------------------------------------------------------------
    -- Alle Schiffe
    ----------------------------------------------------------------------------

    B.Header("Schiffe")
    local list = vgui.Create("DListView", B.Row(230))
    list:Dock(FILL)
    list:SetMultiSelect(false)
    list:AddColumn("Name")
    list:AddColumn("System")
    list:AddColumn("Befehl"):SetFixedWidth(80)
    list:AddColumn("Zustand"):SetFixedWidth(75)

    local function Select(id)
        selected = id
        tac.Selected = id
    end

    -- Angriffsmodus: der naechste gewaehlte Kontakt wird Ziel
    local attackMode = false
    local function Choose(id)
        if attackMode and selected and id and id ~= selected then
            Send("order", {id = selected, type = "attack", targetId = id})
            attackMode = false
            tac.PickHint = nil
            return
        end
        Select(id)
    end

    list.OnRowSelected = function(_, _, line) Choose(line.ShipId) end
    tac.OnSelect = function(_, id) if id then Choose(id) end end

    local listKey
    local function RefreshList()
        if not IsValid(list) then return end
        local rows = table.Copy((C.admin and C.admin.ships) or {})
        local parts = {}
        for _, r in ipairs(rows) do parts[#parts + 1] = r.id .. r.name .. r.systemId .. r.state .. tostring(r.order) end
        local key = table.concat(parts, "|")
        if key == listKey then return end
        listKey = key

        list:Clear()
        table.sort(rows, function(a, b) return a.id < b.id end)
        for _, r in ipairs(rows) do
            local line = list:AddLine((r.map and "★ " or "") .. r.name, Naval.SystemName(r.systemId),
                ORDER_LABEL[r.order] or r.order or "-", STATE_LABEL[r.state] or r.state)
            line.ShipId = r.id
            if r.id == selected then line:SetSelected(true) end
        end
    end
    hook.Add("PD.Naval.AdminData", frame, RefreshList)
    RefreshList()

    ----------------------------------------------------------------------------
    -- Erzeugen
    ----------------------------------------------------------------------------

    B.Header("Schiff erzeugen")
    local cClass = B.Combo(classes, "acclamator")
    local cFaction = B.Combo({{"", "Fraktion der Klasse"}, unpack(factions)}, "")
    local eName = B.Entry("Name (optional)")
    local eDist = B.Entry("Abstand voraus in km", "10")

    local function SpawnArgs(rel)
        local faction = B.ComboValue(cFaction)
        return {classId = B.ComboValue(cClass), factionId = faction ~= "" and faction or nil, name = eName:GetValue(),
            distanceKm = tonumber(eDist:GetValue()) or 10, rel = rel}
    end

    B.Buttons({
        {"Vor dem Map-Schiff", function() Send("spawn", SpawnArgs()) end, COL.ok},
        {"Per Klick", function()
            SetPick("spawn", "Klick: Schiff hier erzeugen  -  Rechtsklick: fertig", function(_, p)
                Send("spawn", SpawnArgs(p))
            end)
        end},
    })

    ----------------------------------------------------------------------------
    -- Ausgewaehltes Schiff
    ----------------------------------------------------------------------------

    B.Header("Ausgewähltes Schiff")
    B.Info(70, function(s, w, h)
        local r = selected and AdminShip(selected)
        if not r then
            draw.SimpleText("In der Karte oder Liste auswählen", "MLIB.16", 8, 8, COL.dim)
            return
        end
        local class = static.classes[r.classId]
        local faction = static.factions[r.factionId]
        draw.SimpleText(("#%d %s"):format(r.id, r.name), "MLIB.18", 8, 4, COL.text)
        draw.SimpleText((class and class.name or r.classId) .. " - " .. (faction and faction.name or r.factionId)
            .. " - " .. Naval.SystemName(r.systemId), "MLIB.14", 8, 26, COL.dim)
        local line = (STATE_LABEL[r.state] or r.state) .. ", " .. r.speed .. " m/s, Hülle " .. (r.hull or 100) .. " %"
        if r.order then line = line .. ", " .. (ORDER_LABEL[r.order] or r.order) .. (r.orders > 1 and (" (+" .. (r.orders - 1) .. ")") or "") end
        if r.to then line = line .. " -> " .. Naval.SystemName(r.to) end
        draw.SimpleText(line, "MLIB.14", 8, 46, COL.text)
    end)

    B.Info(26, function(s, w, h)
        local r = selected and AdminShip(selected)
        if not r or r.map then return end
        local target = r.target and AdminShip(r.target)
        draw.SimpleText((ROE_LABEL[r.roe] or "-") .. (target and ("  -  Ziel: " .. target.name) or ""), "MLIB.14", 8, 5, COL.text)
    end)

    local cRoe = B.Combo({{"hold", ROE_LABEL.hold}, {"return", ROE_LABEL["return"]}, {"free", ROE_LABEL.free}}, "return")
    cRoe.OnSelect = function(_, _, _, value)
        if selected then Send("roe", {id = selected, roe = value}) end
    end

    B.Buttons({
        {"Angreifen (Ziel wählen)", function()
            if not selected then return end
            attackMode = true
            tac.PickHint = "Ziel in der Karte oder Liste anklicken"
        end, COL.bad},
        {"Reparieren", function()
            local r = selected and AdminShip(selected)
            if not r then return end
            Derma_Query(r.name .. " vollständig reparieren?", "Flottenkommando", "Reparieren", function()
                Send("repair", {id = r.id})
            end, "Abbrechen")
        end, COL.ok},
    })

    B.Buttons({
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

    -- Himmelskoerper des aktuellen Systems
    local cBody = B.Combo({})
    local function FillBodies()
        if not IsValid(cBody) then return end
        cBody:Clear()
        local bodies = {}
        for _, b in ipairs((C.system and C.system.bodies) or {}) do bodies[#bodies + 1] = {b.id, b.name .. " (" .. b.type .. ")"} end
        table.sort(bodies, function(a, b) return a[2] < b[2] end)
        for _, e in ipairs(bodies) do cBody:AddChoice(e[2], e[1]) end
    end
    FillBodies()
    hook.Add("PD.Naval.SystemReceived", frame, FillBodies)

    local eRadius = B.Entry("Orbit-Radius in km (leer = automatisch)")
    B.Buttons({
        {"Anfliegen", function()
            if selected and B.ComboValue(cBody) then Send("order", {id = selected, type = "approach", bodyId = B.ComboValue(cBody)}) end
        end},
        {"Orbit", function()
            if selected and B.ComboValue(cBody) then
                Send("order", {id = selected, type = "orbit", bodyId = B.ComboValue(cBody), radiusKm = tonumber(eRadius:GetValue())})
            end
        end},
    })

    local eJump = B.Entry("Sprungziel (System oder Planet)")
    B.Buttons({
        {"Springen", function()
            local sys = Naval.FindSystemByText(eJump:GetValue())
            if not sys then notification.AddLegacy("System nicht gefunden", NOTIFY_ERROR, 3) return end
            if selected then Send("order", {id = selected, type = "jump", systemId = sys.id}) end
        end},
        {"Zum Map-Schiff springen", function()
            if selected then Send("order", {id = selected, type = "jumpnear"}) end
        end, COL.ok},
    })

    local eEditName = B.Entry("Neuer Name")
    local cEditFaction = B.Combo({{"", "Fraktion unverändert"}, unpack(factions)}, "")
    B.Buttons({
        {"Übernehmen", function()
            if not selected then return end
            Send("edit", {id = selected, name = eEditName:GetValue(), factionId = B.ComboValue(cEditFaction)})
            eEditName:SetValue("")
        end},
        {"Löschen", function()
            local r = selected and AdminShip(selected)
            if not r or r.map then return end
            Derma_Query(r.name .. " wirklich löschen?", "Flottenkommando", "Löschen", function()
                Send("delete", {id = r.id})
                Select(nil)
            end, "Abbrechen")
        end, COL.bad},
    })

    ----------------------------------------------------------------------------
    -- Map-Schiff
    ----------------------------------------------------------------------------

    B.Header("Map-Schiff")
    local eRelocate = B.Entry("Zielsystem")
    B.Buttons({{"Ohne Sprung versetzen", function()
        local sys = Naval.FindSystemByText(eRelocate:GetValue())
        if not sys then notification.AddLegacy("System nicht gefunden", NOTIFY_ERROR, 3) return end
        Derma_Query("Map-Schiff sofort nach " .. sys.name .. " versetzen?", "Flottenkommando", "Versetzen", function()
            Send("relocate", {systemId = sys.id})
        end, "Abbrechen")
    end, COL.warn}})
end

concommand.Add("pd_naval_flottenkommando", function() Naval.OpenFleetCommand() end)

-- Taste in der Tastenbelegung (Kategorie Admin)
if PD.Binds and PD.Binds.btn then
    PD.Binds.btn["navalflotte"] = {
        name = "Flottenkommando öffnen",
        desc = "Öffnet das Flottenkommando der Raumflotte.",
        category = "Admin",
        defaultkey = KEY_NONE,
        admin = true,
        downFunc = function() Naval.OpenFleetCommand() end,
        upFunc = function() end,
        holdFunc = function() end,
    }
end
