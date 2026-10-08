--[[
    Naval - Konsolen Kommunikation und Flottenfuehrung (Client, Stufe 3).
    Zustand aus C.status.comms / .fleet (2 Hz), Befehle ueber Naval.CombatCmd.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

local function Cmd(station, action, args)
    if Naval.CombatCmd then Naval.CombatCmd(station, action, args) end
end

local function DistText(m)
    return Naval.FormatDist and Naval.FormatDist(m) or (math.Round(m / 1000) .. " km")
end

local function Contacts()
    local view = C.View and C.View()
    local list = {}
    if not view then return list end

    local myFaction = Naval.MapShipFaction and Naval.MapShipFaction()
    local sens = C.status and C.status.sensors and C.status.sensors.contacts or {}
    for id, s in pairs(view.ships or {}) do
        local info = C.info[id]
        if info and s.state ~= "destroyed" and s.det ~= false then
            local c = sens[tostring(id)] or {}
            list[#list + 1] = {id = id, name = info.name, classId = info.classId, dist = Naval.V3.Dist(s.pos, view.pos),
                relation = Naval.ClientRelation and Naval.ClientRelation(myFaction, info.factionId) or "neutral",
                surrendered = c.surrendered}
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

--------------------------------------------------------------------------------
-- Kommunikation
--------------------------------------------------------------------------------

local function OpenComms(console)
    local UI = Naval.UI
    local COL = UI.COL
    local REL = Naval.RelationColors or {}
    local frame = UI.Frame("KOMMUNIKATION", 1180, 720)
    frame.Console = console
    local selected

    local listPanel = vgui.Create("DScrollPanel", frame)
    listPanel:SetPos(20, 55)
    listPanel:SetSize(340, frame:GetTall() - 75)

    local rows = {}
    for i = 1, 40 do
        local row = listPanel:Add("DButton")
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 3)
        row:SetTall(42)
        row:SetText("")
        row.DoClick = function(s)
            if not s.Contact then return end
            surface.PlaySound("buttons/button15.wav")
            selected = selected ~= s.Contact.id and s.Contact.id or nil
        end
        row.Paint = function(s, w, h)
            local c = s.Contact
            if not c then return end
            draw.RoundedBox(0, 0, 0, w, h, selected == c.id and Color(40, 52, 70) or COL.panel)
            surface.SetDrawColor(REL[c.relation] or COL.text)
            surface.DrawRect(0, 0, 4, h)
            draw.SimpleText(c.name, "MLIB.16", 12, 4, COL.text)
            draw.SimpleText(c.surrendered and "kapituliert" or DistText(c.dist), "MLIB.12", 12, 24, c.surrendered and COL.warn or COL.dim)
        end
        rows[i] = row
    end

    -- Funkprotokoll
    local logPanel = vgui.Create("DPanel", frame)
    logPanel:SetPos(375, 55)
    logPanel:SetSize(frame:GetWide() - 395, frame:GetTall() - 255)
    logPanel.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(8, 12, 18))
        draw.SimpleText("FUNKPROTOKOLL", "MLIB.14", 10, 6, COL.dim)
        local log = C.status and C.status.comms and C.status.comms.log or {}

        local y = h - 8
        for i = #log, 1, -1 do
            local e = log[i]
            local head = os.date("%H:%M", e.t or 0) .. "  " .. (e.from or "?") .. (e.to and (" -> " .. e.to) or "")
            local col = e.own and COL.accent or (e.kind == "distress" and COL.bad or (e.kind == "surrender" and COL.warn or COL.text))

            -- Text umbrechen
            local lines = {}
            local line = ""
            for word in string.gmatch(e.text or "", "%S+") do
                if #line + #word > 95 then lines[#lines + 1] = line line = word else line = line == "" and word or (line .. " " .. word) end
            end
            if line ~= "" then lines[#lines + 1] = line end

            y = y - (#lines * 18 + 20)
            if y < 26 then break end
            draw.SimpleText(head, "MLIB.12", 10, y, COL.dim)
            for k, l in ipairs(lines) do draw.SimpleText(l, "MLIB.16", 10, y + 2 + k * 18 - 4, col) end
        end
    end

    -- Eingabe
    local entry = vgui.Create("DTextEntry", frame)
    entry:SetPos(375, frame:GetTall() - 190)
    entry:SetSize(frame:GetWide() - 545, 38)
    entry:SetFont("MLIB.16")
    entry:SetPlaceholderText("Nachricht (an den gewählten Kontakt, sonst an alle) ...")

    local send = UI.Button(frame, "Senden", function()
        local text = entry:GetValue()
        if string.Trim(text) == "" then return end
        Cmd("comms", "say", {id = selected or 0, text = text})
        entry:SetValue("")
    end, function() return COL.ok end)
    send:SetPos(frame:GetWide() - 160, frame:GetTall() - 190)
    send:SetSize(140, 38)
    entry.OnEnter = function() send:DoClick() end

    local bw = (frame:GetWide() - 395 - 20) / 3
    local function Btn(label, x, y, fn, col)
        local b = UI.Button(frame, label, fn, col and function() return col end)
        b:SetPos(375 + x * (bw + 10), frame:GetTall() - 140 + y * 50)
        b:SetSize(bw, 42)
        return b
    end

    local hail = Btn("Rufen", 0, 0, function() if selected then Cmd("comms", "hail", {id = selected}) end end)
    local demand = Btn("Kapitulation fordern", 1, 0, function() if selected then Cmd("comms", "demand", {id = selected}) end end, COL.warn)
    local accept = Btn("Kapitulation annehmen", 2, 0, function() if selected then Cmd("comms", "accept", {id = selected}) end end, COL.ok)
    local distress = Btn("NOTRUF", 0, 1, function() Cmd("comms", "distress", {}) end, COL.bad)
    local offer = Btn("Eigene Kapitulation anbieten", 1, 1, function()
        Derma_Query("Wirklich die Kapitulation des Schiffs anbieten?", "Kommunikation", "Anbieten", function()
            Cmd("comms", "offer", {})
        end, "Abbrechen")
    end, COL.warn)

    local baseThink = frame.Think
    frame.Think = function(s)
        if baseThink then baseThink(s) end
        if not IsValid(s) then return end

        local list = Contacts()
        local found
        for i, row in ipairs(rows) do
            row.Contact = list[i]
            row:SetVisible(list[i] ~= nil)
            if list[i] and list[i].id == selected then found = list[i] end
        end
        if selected and not found then selected = nil end

        hail.Disabled = not found
        demand.Disabled = not found or found.surrendered
        accept.Disabled = not found or not found.surrendered
        local comms = C.status and C.status.comms or {}
        distress.Disabled = (comms.distressIn or 0) > 0
        distress.Label = (comms.distressIn or 0) > 0 and ("NOTRUF (%d s)"):format(comms.distressIn) or "NOTRUF"
        offer.Disabled = false
    end
end

--------------------------------------------------------------------------------
-- Flottenfuehrung
--------------------------------------------------------------------------------

local function OpenFleetCommand(console)
    local UI = Naval.UI
    local COL = UI.COL
    local frame = UI.Frame("FLOTTENFÜHRUNG", 1100, 720)
    frame.Console = console

    local function Fleet()
        return C.status and C.status.fleet
    end

    local head = vgui.Create("DPanel", frame)
    head:SetPos(20, 55)
    head:SetSize(frame:GetWide() - 40, 60)
    head.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL.panel)
        local f = Fleet()
        if not f then
            draw.SimpleText("Dieses Schiff führt keine Flotte. Begleitschiffe teilt die Spielleitung zu.", "MLIB.18", 14, h / 2, COL.dim, nil, TEXT_ALIGN_CENTER)
            return
        end
        draw.SimpleText(f.name, "MLIB.22", 14, 8, COL.text)
        local text = f.isFlagship and ("Flaggschiff - %d Begleitschiffe - Abstand %s"):format(#(f.members or {}), DistText(f.spacing or 0))
            or ("Flaggschiff ist " .. (f.flagship or "?") .. " - wir folgen")
        draw.SimpleText(text, "MLIB.14", 14, 36, f.isFlagship and COL.dim or COL.warn)
    end

    local function Row(y, label, entries, current, action)
        local holder = vgui.Create("DPanel", frame)
        holder:SetPos(20, y)
        holder:SetSize(frame:GetWide() - 40, 40)
        holder.Paint = function(s, w, h)
            draw.SimpleText(label, "MLIB.16", 0, h / 2, COL.text, nil, TEXT_ALIGN_CENTER)
        end
        local bw = (holder:GetWide() - 170) / #entries - 6
        for i, e in ipairs(entries) do
            local b = UI.Button(holder, e.name, function() action(e) end, function()
                local f = Fleet()
                return f and current(f) == e.id and COL.ok or COL.dim
            end)
            b:SetPos(170 + (i - 1) * (bw + 6), 2)
            b:SetSize(bw, 36)
            b.Think = function(btn) local f = Fleet() btn.Disabled = not f or not f.isFlagship end
        end
    end

    Row(130, "Formation", Naval.Formations, function(f) return f.formation end, function(e) Cmd("fleetcmd", "formation", {id = e.id}) end)
    Row(176, "Befehl", Naval.FleetModes, function(f) return f.mode end, function(e) Cmd("fleetcmd", "mode", {id = e.id}) end)
    Row(222, "Feuerbefehl", {{id = "hold", name = "Feuer halten"}, {id = "return", name = "Nur zurückschießen"}, {id = "free", name = "Feuer frei"}},
        function() return nil end, function(e) Cmd("fleetcmd", "roe", {roe = e.id}) end)
    Row(268, "Abstand", {{id = "closer", name = "Enger (−25 %)", factor = 0.75}, {id = "wider", name = "Weiter (+33 %)", factor = 1.33}},
        function() return nil end, function(e) Cmd("fleetcmd", "spacing", {factor = e.factor}) end)

    local members = vgui.Create("DPanel", frame)
    members:SetPos(20, 320)
    members:SetSize(frame:GetWide() - 40, frame:GetTall() - 340)
    members.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL.panel)
        local f = Fleet()
        if not f then return end

        draw.SimpleText("Schiff", "MLIB.14", 14, 8, COL.dim)
        draw.SimpleText("Hülle", "MLIB.14", w * 0.42, 8, COL.dim)
        draw.SimpleText("Moral", "MLIB.14", w * 0.6, 8, COL.dim)
        draw.SimpleText("Lage", "MLIB.14", w * 0.75, 8, COL.dim)

        local y = 32
        for _, m in ipairs(f.members or {}) do
            if y > h - 30 then break end
            local class = C.static and C.static.classes[m.classId]
            draw.SimpleText(m.name, "MLIB.16", 14, y, m.surrendered and COL.warn or COL.text)
            draw.SimpleText(class and class.name or m.classId, "MLIB.12", 14, y + 18, COL.dim)
            local hf = (m.hull or 0) / 100
            UI.Bar(w * 0.42, y + 8, w * 0.15, 10, hf, hf > 0.5 and COL.ok or (hf > 0.25 and COL.warn or COL.bad))
            if m.morale then
                UI.Bar(w * 0.6, y + 8, w * 0.12, 10, m.morale / 100, m.morale > 50 and COL.accent or (m.morale > 25 and COL.warn or COL.bad))
            end

            local where
            if m.surrendered then where = "kapituliert"
            elseif m.state ~= "normal" then where = m.state == "hyperspace" and "im Hyperraum" or "springt"
            elseif not m.dist then where = "anderes System"
            elseif m.slotDist and m.slotDist < 3000 then where = "in Formation"
            elseif m.slotDist then where = "schließt auf (" .. DistText(m.slotDist) .. ")"
            else where = DistText(m.dist) end
            draw.SimpleText(where, "MLIB.14", w * 0.75, y + 4, COL.text)
            y = y + 42
        end
    end
end

Naval.StationUI = Naval.StationUI or {}
Naval.StationUI.comms = OpenComms
Naval.StationUI.fleetcmd = OpenFleetCommand
