--[[
    Naval - Konsolen Schadenskontrolle, Sensoren, Alarmstufe (Client).
    Zustand aus C.status.dc / .sensors / .alert / .combat (2 Hz), Befehle
    ueber Naval.CombatCmd (cl_naval_combat_ui.lua).
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

local function FracColor(COL, frac)
    return frac > 0.5 and COL.ok or (frac > 0.25 and COL.warn or COL.bad)
end

--------------------------------------------------------------------------------
-- Schadenskontrolle
--------------------------------------------------------------------------------

local KIND_COLOR = {sparks = Color(255, 220, 120), smoke = Color(180, 180, 190), fire = Color(255, 120, 60)}

local function OpenDamageControl(console)
    local UI = Naval.UI
    local COL = UI.COL
    local frame = UI.Frame("SCHADENSKONTROLLE", 1180, 720)
    frame.Console = console

    -- Links: Huelle und Subsysteme
    local left = vgui.Create("DPanel", frame)
    left:SetPos(20, 55)
    left:SetSize(560, frame:GetTall() - 75)
    left.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL.panel)
        local cs = C.status and C.status.combat
        draw.SimpleText("SCHIFFSZUSTAND", "MLIB.18", 14, 10, COL.text)
        if not cs then return end

        local frac = cs.hull / math.max(cs.hullMax, 1)
        draw.SimpleText(("Hülle %d / %d (%d %%)"):format(cs.hull, cs.hullMax, math.Round(frac * 100)), "MLIB.16", 14, 42, COL.text)
        UI.Bar(14, 66, w - 28, 14, frac, FracColor(COL, frac))

        local dc = C.status.dc or {}
        local teams = dc.teams or {}
        local y = 100
        for _, sub in ipairs(cs.systems or {}) do
            local f = sub.hp / math.max(sub.max, 1)
            local working = {}
            for i = 1, dc.teamCount or 0 do
                if teams[i] == sub.id then working[#working + 1] = "Trupp " .. i end
            end

            draw.SimpleText(Naval.SubsystemNames[sub.id] or sub.id, "MLIB.14", 14, y, f <= 0 and COL.bad or COL.text)
            draw.SimpleText(f <= 0 and "AUSGEFALLEN" or (math.Round(f * 100) .. " %"), "MLIB.12", w - 14, y + 2, FracColor(COL, f), TEXT_ALIGN_RIGHT)
            if #working > 0 then draw.SimpleText(table.concat(working, ", "), "MLIB.12", w * 0.5, y + 2, COL.accent, TEXT_ALIGN_CENTER) end
            UI.Bar(14, y + 20, w - 28, 8, f, FracColor(COL, f))
            y = y + 40
        end
    end

    -- Rechts oben: offene Schaeden
    local right = vgui.Create("DPanel", frame)
    right:SetPos(595, 55)
    right:SetSize(frame:GetWide() - 615, 330)
    right.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL.panel)
        local dc = C.status and C.status.dc
        draw.SimpleText("SCHÄDEN AN BORD", "MLIB.18", 14, 10, COL.text)
        if not dc then return end

        if (dc.points or 0) == 0 then
            draw.SimpleText("Keine Schadenspunkte aufgestellt (Admin-Tab -> Konsolen).", "MLIB.14", 14, 44, COL.warn)
            return
        end

        local list = dc.incidents or {}
        if #list == 0 then
            draw.SimpleText("Keine Schäden gemeldet.", "MLIB.16", 14, 44, COL.ok)
            return
        end

        local y = 42
        for i = 1, math.min(#list, 7) do
            local inc = list[i]
            local kind = Naval.IncidentKinds[inc.kind] or {}
            draw.RoundedBox(0, 10, y, w - 20, 36, Color(30, 36, 46))
            surface.SetDrawColor(KIND_COLOR[inc.kind] or COL.text)
            surface.DrawRect(10, y, 4, 36)
            draw.SimpleText((kind.name or inc.kind) .. " - " .. (inc.where or "?"), "MLIB.14", 22, y + 3, COL.text)
            draw.SimpleText(("seit %d s%s"):format(inc.age or 0, inc.sub and ("  -  " .. (Naval.SubsystemNames[inc.sub] or inc.sub)) or ""),
                "MLIB.12", 22, y + 20, COL.dim)
            if (inc.progress or 0) > 0 then
                UI.Bar(w - 130, y + 14, 110, 8, inc.progress, COL.ok)
            end
            y = y + 40
        end
        if #list > 7 then draw.SimpleText(("... und %d weitere"):format(#list - 7), "MLIB.12", 14, y, COL.dim) end
    end

    local hint = vgui.Create("DPanel", frame)
    hint:SetPos(595, 392)
    hint:SetSize(frame:GetWide() - 615, 44)
    hint.Paint = function(s, w, h)
        draw.SimpleText("Schäden vor Ort beheben: hinschauen und E gedrückt halten.", "MLIB.14", 4, 4, COL.dim)
        draw.SimpleText("Brände verletzen Umstehende und greifen über.", "MLIB.14", 4, 22, COL.dim)
    end

    -- Rechts unten: Reparaturtrupps
    local teamsPanel = vgui.Create("DPanel", frame)
    teamsPanel:SetPos(595, 445)
    teamsPanel:SetSize(frame:GetWide() - 615, frame:GetTall() - 465)
    teamsPanel.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL.panel)
        draw.SimpleText("REPARATURTRUPPS", "MLIB.18", 14, 10, COL.text)
    end

    local combos = {}
    local function Targets()
        local list = {{"", "Bereitschaft"}, {"hull", "Hülle (Notreparatur bis 50 %)"}}
        local cs = C.status and C.status.combat
        for _, sub in ipairs(cs and cs.systems or {}) do
            list[#list + 1] = {sub.id, Naval.SubsystemNames[sub.id] or sub.id}
        end
        return list
    end

    for i = 1, 8 do
        local row = vgui.Create("DPanel", teamsPanel)
        row:SetPos(14, 40 + (i - 1) * 36)
        row:SetSize(teamsPanel:GetWide() - 28, 32)
        row.Paint = function(s, w, h)
            draw.SimpleText("Trupp " .. i, "MLIB.16", 0, h / 2, COL.text, nil, TEXT_ALIGN_CENTER)
        end

        local combo = vgui.Create("DComboBox", row)
        combo:SetPos(90, 2)
        combo:SetSize(row:GetWide() - 90, 28)
        combo:SetFont("MLIB.14")
        combo.OnSelect = function(_, _, _, data)
            Cmd("damagecontrol", "assign", {team = i, target = data})
        end
        combo.Key = nil
        combo.Think = function(c)
            local dc = C.status and C.status.dc
            row:SetVisible(dc ~= nil and i <= (dc.teamCount or 0))
            if not dc or c:IsMenuOpen() then return end

            local current = (dc.teams or {})[i] or ""
            local cs = C.status.combat
            local key = current .. ":" .. #(cs and cs.systems or {})
            if key == c.Key then return end
            c.Key = key

            c:Clear()
            for _, t in ipairs(Targets()) do c:AddChoice(t[2], t[1], t[1] == current) end
        end
        combos[i] = combo
    end
end

--------------------------------------------------------------------------------
-- Sensoren
--------------------------------------------------------------------------------

local LEVEL_TEXT = {[0] = "UNBEKANNT", [1] = "identifiziert", [2] = "genau gescannt"}

local function OpenSensors(console)
    local UI = Naval.UI
    local COL = UI.COL
    local frame = UI.Frame("SENSOREN", 1180, 720)
    frame.Console = console
    local selected

    local function Contacts()
        local view = C.View and C.View()
        local list = {}
        if not view then return list end

        local myFaction = Naval.MapShipFaction and Naval.MapShipFaction()
        for id, s in pairs(view.ships or {}) do
            local info = C.info[id]
            if info and s.state ~= "destroyed" and s.det ~= false then
                list[#list + 1] = {id = id, name = info.name, classId = info.classId, level = info.ident or 2,
                    dist = Naval.V3.Dist(s.pos, view.pos), hull = s.hull or 100, state = s.state,
                    relation = Naval.ClientRelation and Naval.ClientRelation(myFaction, info.factionId) or "neutral", factionId = info.factionId}
            end
        end
        table.sort(list, function(a, b)
            if (a.level == 0) ~= (b.level == 0) then return a.level == 0 end
            return a.dist < b.dist
        end)
        return list
    end

    local REL = Naval.RelationColors or {}

    local listPanel = vgui.Create("DScrollPanel", frame)
    listPanel:SetPos(20, 55)
    listPanel:SetSize(400, frame:GetTall() - 75)

    local rows = {}
    for i = 1, 40 do
        local row = listPanel:Add("DButton")
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 3)
        row:SetTall(46)
        row:SetText("")
        row.DoClick = function(s)
            if s.Contact then
                surface.PlaySound("buttons/button15.wav")
                selected = s.Contact.id
            end
        end
        row.Paint = function(s, w, h)
            local c = s.Contact
            if not c then return end
            draw.RoundedBox(0, 0, 0, w, h, selected == c.id and Color(40, 52, 70) or COL.panel)
            surface.SetDrawColor(REL[c.relation] or COL.text)
            surface.DrawRect(0, 0, 4, h)
            draw.SimpleText(c.name, "MLIB.16", 12, 4, COL.text)
            draw.SimpleText(LEVEL_TEXT[c.level] or "", "MLIB.12", 12, 25, c.level == 0 and COL.warn or COL.dim)
            draw.SimpleText(DistText(c.dist), "MLIB.14", w - 8, 4, COL.text, TEXT_ALIGN_RIGHT)

            local scan = C.status and C.status.sensors and C.status.sensors.scan
            if scan and scan.id == c.id then
                UI.Bar(w - 108, 28, 100, 8, (Naval.Now() - scan.start) / math.max(scan.finish - scan.start, 1), COL.accent)
            end
        end
        rows[i] = row
    end

    local detail = vgui.Create("DPanel", frame)
    detail:SetPos(435, 55)
    detail:SetSize(frame:GetWide() - 455, frame:GetTall() - 145)
    detail.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL.panel)
        local sens = C.status and C.status.sensors
        if sens then
            draw.SimpleText("Reichweite " .. DistText(sens.range or 0), "MLIB.14", w - 14, 12, COL.dim, TEXT_ALIGN_RIGHT)
        end

        local info = selected and C.info[selected]
        local view = C.View and C.View()
        local ship = view and selected and view.ships[selected]
        if not info or not ship then
            draw.SimpleText("Kontakt links wählen", "MLIB.18", 14, 14, COL.dim)
            return
        end

        local level = info.ident or 2
        local class = C.static and C.static.classes[info.classId]
        local y = 14
        local function Line(text, col, font)
            draw.SimpleText(text, font or "MLIB.16", 14, y, col or COL.text)
            y = y + (font == "MLIB.22" and 34 or 26)
        end

        Line(info.name, COL.text, "MLIB.22")
        Line("Entfernung: " .. DistText(Naval.V3.Dist(ship.pos, view.pos)))

        if level == 0 then
            Line("Größe ca. " .. math.Round((class and class.lengthM or 0) / 50) * 50 .. " m", COL.dim)
            Line("Kennung, Klasse und Fraktion unbekannt - scannen.", COL.warn)
            return
        end

        local faction = C.static.factions[info.factionId]
        Line("Klasse: " .. (class and class.name or info.classId))
        Line("Fraktion: " .. (faction and faction.name or info.factionId), REL[Naval.ClientRelation(Naval.MapShipFaction(), info.factionId)] or COL.text)
        Line(("Hülle: %d %%"):format(ship.hull or 100), FracColor(COL, (ship.hull or 100) / 100))

        local c = sens and sens.contacts and sens.contacts[tostring(selected)]
        if level < 2 or not c then
            y = y + 8
            Line("Schilde und Subsysteme: genauer Scan nötig.", COL.dim)
            return
        end

        Line(("Schilde: %d %% (%s)"):format(c.shield or 0, c.up and "oben" or "unten"), c.up and COL.accent or COL.warn)
        if c.morale then Line(("Moral der Besatzung: %d %%"):format(c.morale), c.morale > 50 and COL.ok or (c.morale > 25 and COL.warn or COL.bad)) end
        if c.surrendered then Line("Hat kapituliert", COL.warn) end
        if c.interdictor then Line("Abfangkreuzer (Abfangfeld)", COL.bad) end
        y = y + 8
        Line("SUBSYSTEME", COL.dim, "MLIB.14")
        for _, sub in ipairs(c.subs or {}) do
            draw.SimpleText(Naval.SubsystemNames[sub.id] or sub.id, "MLIB.14", 14, y, COL.text)
            UI.Bar(w * 0.45, y + 4, w * 0.45, 8, sub.pct / 100, FracColor(COL, sub.pct / 100))
            y = y + 22
        end
    end

    local scanBtn = UI.Button(frame, "SCANNEN", function()
        if selected then Cmd("sensors", "scan", {id = selected}) end
    end, function() return COL.ok end)
    scanBtn:SetPos(435, frame:GetTall() - 80)
    scanBtn:SetSize((frame:GetWide() - 465) / 2, 60)

    local cancelBtn = UI.Button(frame, "Scan abbrechen", function()
        Cmd("sensors", "cancel", {})
    end, function() return COL.bad end)
    cancelBtn:SetPos(445 + (frame:GetWide() - 465) / 2, frame:GetTall() - 80)
    cancelBtn:SetSize((frame:GetWide() - 465) / 2, 60)

    local baseThink = frame.Think
    frame.Think = function(s)
        if baseThink then baseThink(s) end
        if not IsValid(s) then return end

        local list = Contacts()
        for i, row in ipairs(rows) do
            row.Contact = list[i]
            row:SetVisible(list[i] ~= nil)
        end

        local scan = C.status and C.status.sensors and C.status.sensors.scan
        local info = selected and C.info[selected]
        scanBtn.Disabled = not info or (info.ident or 2) >= 2 or scan ~= nil
        cancelBtn.Disabled = scan == nil
        scanBtn.Label = info and (info.ident or 2) == 0 and "IDENTIFIZIEREN" or "GENAU SCANNEN"
    end
end

--------------------------------------------------------------------------------
-- Alarmstufe
--------------------------------------------------------------------------------

local ALERT_COLORS = {[0] = Color(90, 210, 130), [1] = Color(240, 200, 60), [2] = Color(240, 70, 60)}
Naval.AlertColors = ALERT_COLORS

local function OpenAlert(console)
    local UI = Naval.UI
    local COL = UI.COL
    local frame = UI.Frame("ALARMSTUFE", 640, 420)
    frame.Console = console

    local info = vgui.Create("DPanel", frame)
    info:SetPos(20, 55)
    info:SetSize(frame:GetWide() - 40, 90)
    info.Paint = function(s, w, h)
        local level = GetGlobalInt("PD.Naval.Alert", 0)
        draw.RoundedBox(0, 0, 0, w, h, COL.panel)
        surface.SetDrawColor(ALERT_COLORS[level])
        surface.DrawOutlinedRect(0, 0, w, h, 3)
        draw.SimpleText(string.upper(Naval.AlertNames[level] or ""), "MLIB.22", w / 2, h / 2 - 10, ALERT_COLORS[level], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(level == 2 and "Schilde automatisch oben" or (level == 1 and "Gefechtsbereitschaft" or "Normalbetrieb"),
            "MLIB.14", w / 2, h / 2 + 18, COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    for level = 0, 2 do
        local b = UI.Button(frame, Naval.AlertNames[level], function()
            Cmd("alert", "set", {level = level})
        end, function() return ALERT_COLORS[level] end)
        b:SetPos(20, 160 + level * 72)
        b:SetSize(frame:GetWide() - 40, 62)
    end
end

--------------------------------------------------------------------------------
-- Hologramm-Steuerung (ersetzt die einzelnen Schalter)
--------------------------------------------------------------------------------

local function OpenHoloControl(console)
    local UI = Naval.UI
    local COL = UI.COL
    local frame = UI.Frame("HOLOGRAMM-STEUERUNG", 780, 690)
    frame.Console = console

    local function Galaxy() return GetGlobalInt("PD.Naval.HoloMode", 0) == 1 end

    local function Section(y, h, title)
        local p = vgui.Create("DPanel", frame)
        p:SetPos(20, y)
        p:SetSize(frame:GetWide() - 40, h)
        p.Paint = function(s, w, hh)
            draw.RoundedBox(0, 0, 0, w, hh, COL.panel)
            draw.SimpleText(title, "MLIB.14", 10, 6, COL.dim)
        end
        return p
    end

    local function Btn(parent, label, x, y, w, fn, colFn)
        local b = UI.Button(parent, label, fn, colFn)
        b:SetPos(x, y)
        b:SetSize(w, 34)
        return b
    end

    -- An/aus und Ansicht
    local top = Section(55, 70, "HOLOGRAMM")
    local power = Btn(top, "", 10, 28, 220, function() Naval.CombatCmd("holo_control", "power", {on = not GetGlobalBool("PD.Naval.HoloOn", false)}) end,
        function() return GetGlobalBool("PD.Naval.HoloOn", false) and COL.ok or COL.bad end)
    power.Think = function(b) b.Label = GetGlobalBool("PD.Naval.HoloOn", false) and "AN  (ausschalten)" or "AUS  (einschalten)" end
    Btn(top, "Taktik (System)", 250, 28, 200, function() Naval.CombatCmd("holo_control", "mode", {id = "tactical"}) end,
        function() return Galaxy() and COL.dim or COL.ok end)
    Btn(top, "Galaxie", 460, 28, 200, function() Naval.CombatCmd("holo_control", "mode", {id = "galaxy"}) end,
        function() return Galaxy() and COL.ok or COL.dim end)

    -- Zoom und Ausschnitt
    local zoom = Section(135, 70, "ZOOM UND AUSSCHNITT")
    Btn(zoom, "− weiter", 10, 28, 110, function() Naval.CombatCmd("holo_control", "zoom", {delta = 1}) end)
    Btn(zoom, "+ näher", 240, 28, 110, function() Naval.CombatCmd("holo_control", "zoom", {delta = -1}) end)
    local zl = vgui.Create("DPanel", zoom)
    zl:SetPos(124, 28) zl:SetSize(112, 34)
    zl.Paint = function(s, w, h)
        local text
        if Galaxy() then
            text = (Naval.HoloGalaxyRanges[GetGlobalInt("PD.Naval.HoloGalaxyZoom", Naval.HoloGalaxyDefaultZoom)] or 0) .. " pc"
        else
            local r = Naval.HoloRanges[GetGlobalInt("PD.Naval.HoloZoom", Naval.HoloDefaultZoom)] or 0
            text = Naval.FormatDist and Naval.FormatDist(r) or (math.Round(r / 1000) .. " km")
        end
        draw.SimpleText(text, "MLIB.16", w / 2, h / 2, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    local focusInfo = vgui.Create("DPanel", zoom)
    focusInfo:SetPos(370, 28) focusInfo:SetSize(200, 34)
    focusInfo.Paint = function(s, w, h)
        local id = GetGlobalString("PD.Naval.HoloFocus", "")
        draw.SimpleText("Mitte: " .. (id ~= "" and Naval.SystemName(id) or "unsere Position"), "MLIB.14", 0, h / 2, COL.text, nil, TEXT_ALIGN_CENTER)
    end
    Btn(zoom, "Unsere Position", zoom:GetWide() - 170, 28, 160, function() Naval.CombatCmd("holo_control", "focus", {}) end)

    -- Drehen
    local rot = Section(215, 170, "DREHEN (45°-SCHRITTE, UM DIE ACHSEN DES PROJEKTORS)")
    local axes = {{"p", "Kippen (90° = Wand)", "PD.Naval.HoloRotP"}, {"y", "Drehen", "PD.Naval.HoloRotY"}, {"r", "Rollen", "PD.Naval.HoloRotR"}}
    for i, a in ipairs(axes) do
        local y = 28 + (i - 1) * 42
        local lbl = vgui.Create("DPanel", rot)
        lbl:SetPos(10, y) lbl:SetSize(260, 34)
        lbl.Paint = function(s, w, h)
            draw.SimpleText(a[2], "MLIB.16", 0, h / 2, COL.text, nil, TEXT_ALIGN_CENTER)
            draw.SimpleText(GetGlobalInt(a[3], 0) .. "°", "MLIB.16", w, h / 2, COL.accent, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        Btn(rot, "− 45°", 290, y, 100, function() Naval.CombatCmd("holo_control", "rotate", {axis = a[1], delta = -1}) end)
        Btn(rot, "+ 45°", 400, y, 100, function() Naval.CombatCmd("holo_control", "rotate", {axis = a[1], delta = 1}) end)
    end
    Btn(rot, "Zurücksetzen", rot:GetWide() - 170, 28, 160, function() Naval.CombatCmd("holo_control", "reset", {}) end, function() return COL.warn end)
    Btn(rot, "Als Wand", rot:GetWide() - 170, 70, 160, function()
        Naval.CombatCmd("holo_control", "reset", {})
        timer.Simple(0.2, function() Naval.CombatCmd("holo_control", "rotate", {axis = "p", delta = 1}) end)
        timer.Simple(0.4, function() Naval.CombatCmd("holo_control", "rotate", {axis = "p", delta = 1}) end)
    end)

    -- Dauerrotation
    local spin = Section(395, 80, "DAUERROTATION (BEIM STOPPEN RASTET SIE AUF DEN NÄCHSTEN 45°-SCHRITT EIN)")
    local spinState = {speed = 20}
    local function SpinAxis() return GetGlobalString("PD.Naval.HoloSpinAxis", "") end
    local function StartSpin(axis) Naval.CombatCmd("holo_control", "spin", {axis = axis, speed = spinState.speed}) end
    local spinAxes = {{"", "Aus"}, {"y", "Drehen"}, {"p", "Kippen"}, {"r", "Rollen"}}
    for i, a in ipairs(spinAxes) do
        Btn(spin, a[2], 10 + (i - 1) * 92, 34, 86, function() StartSpin(a[1]) end, function()
            return SpinAxis() == a[1] and (a[1] == "" and COL.warn or COL.ok) or COL.dim
        end)
    end
    local speeds = {{10, "langsam"}, {20, "mittel"}, {45, "schnell"}}
    for i, sp in ipairs(speeds) do
        Btn(spin, sp[2], 390 + (i - 1) * 86, 34, 80, function()
            spinState.speed = (spinState.speed < 0 and -1 or 1) * sp[1]
            if SpinAxis() ~= "" then StartSpin(SpinAxis()) end
        end, function() return math.abs(spinState.speed) == sp[1] and COL.ok or COL.dim end)
    end
    local dir = Btn(spin, "", spin:GetWide() - 100, 34, 90, function()
        spinState.speed = -spinState.speed
        if SpinAxis() ~= "" then StartSpin(SpinAxis()) end
    end)
    dir.Think = function(b) b.Label = spinState.speed < 0 and "↻ rechts" or "↺ links" end
    -- Laufende Rotation uebernehmen (Tempo/Richtung)
    if SpinAxis() ~= "" then spinState.speed = math.Round(GetGlobalFloat("PD.Naval.HoloSpinSpeed", 20)) end

    -- Ebenen
    local layers = Section(485, 130, "EBENEN")
    for i, l in ipairs(Naval.HoloLayers) do
        local col = (i - 1) % 3
        local row = math.floor((i - 1) / 3)
        local b = Btn(layers, l.name, 10 + col * 240, 28 + row * 44, 230, function()
            Naval.CombatCmd("holo_control", "layer", {id = l.id, on = not Naval.HoloLayer(l.id)})
        end, function() return Naval.HoloLayer(l.id) and COL.ok or COL.dim end)
        b.Think = function(btn) btn.Label = (Naval.HoloLayer(l.id) and "[x] " or "[ ] ") .. l.name end
    end
end

Naval.StationUI = Naval.StationUI or {}
Naval.StationUI.damagecontrol = OpenDamageControl
Naval.StationUI.holo_control = OpenHoloControl
Naval.StationUI.sensors = OpenSensors
Naval.StationUI.alert = OpenAlert
