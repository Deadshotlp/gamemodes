--[[
    Naval - Bedienoberflaechen der Stationen (Client).

    Steuer, Hyperantrieb, Logbuch hier; Navigationscomputer in
    cl_naval_navmap.lua, Taktik in cl_naval_tactical.lua. Den Zustand liefert
    PD.Naval.Status (2 Hz) in Naval.C.status.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

local COL_BG = Color(14, 18, 24, 245)
local COL_PANEL = Color(24, 30, 40, 255)
local COL_ACCENT = Color(120, 190, 255)
local COL_OK = Color(90, 210, 130)
local COL_WARN = Color(240, 190, 70)
local COL_BAD = Color(240, 90, 80)
local COL_TEXT = Color(225, 230, 240)
local COL_DIM = Color(140, 150, 165)

Naval.UI = Naval.UI or {}
local UI = Naval.UI
UI.COL = {bg = COL_BG, panel = COL_PANEL, accent = COL_ACCENT, ok = COL_OK, warn = COL_WARN, bad = COL_BAD, text = COL_TEXT, dim = COL_DIM}

--------------------------------------------------------------------------------
-- Status
--------------------------------------------------------------------------------

net.Receive("PD.Naval.Status", function()
    local size = net.ReadUInt(16)
    local json = util.Decompress(net.ReadData(size))
    C.status = json and util.JSONToTable(json) or C.status or {}
    C.statusTime = CurTime()
end)

function Naval.SystemName(id)
    local s = C.static and C.static.systemsById[id or ""]
    return s and s.name or "?"
end

local function Fmt(seconds)
    seconds = math.max(0, math.floor(seconds or 0))
    return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end
UI.Fmt = Fmt

-- Zeilen fuer die Kurzanzeige ueber den Konsolen
function Naval.ConsoleSummary(station)
    local st = C.status
    if not st then return {"Kein Signal"} end

    local now = Naval.Now()
    local lines = {}

    if station == "helm" or station == "bridgescreen" then
        lines[#lines + 1] = ("%s - %d m/s (%d%%)"):format(Naval.SystemName(st.system), st.speed or 0, math.Round((st.throttle or 0) * 100))
    end

    if station == "navcomputer" or station == "hyperdrive" or station == "bridgescreen" then
        local nav = st.nav
        if nav then
            if not nav.ready then
                lines[#lines + 1] = ("Berechne Kurs nach %s ... %s"):format(Naval.SystemName(nav.target), Fmt(nav.finish - now))
            else
                lines[#lines + 1] = ("Kurs %s: %s"):format(Naval.SystemName(nav.target), nav.valid and "bereit" or "ungueltig")
            end
        end
    end

    if st.state == "spooling" and st.hyper and st.hyper.tJump then
        lines[#lines + 1] = "Hyperantrieb faehrt hoch: " .. Fmt(st.hyper.tJump - now)
    elseif st.state == "hyperspace" and st.hyper and st.hyper.tExit then
        lines[#lines + 1] = ("Hyperraum nach %s - Ankunft in %s"):format(Naval.SystemName(st.hyper.to), Fmt(st.hyper.tExit - now))
    end

    return lines
end

--------------------------------------------------------------------------------
-- Gemeinsame Bausteine
--------------------------------------------------------------------------------

-- Rueckmeldungen des Servers zur Bedienung (Naval.Feedback)
net.Receive("PD.Naval.Feedback", function()
    local text, ok = net.ReadString(), net.ReadBool()
    Naval.LastFeedback = {text = text, ok = ok, t = CurTime()}
    -- Kein Konsolenfenster offen (z. B. gesperrte Konsole): kurz am Fadenkreuz
    if not IsValid(Naval.OpenFrame) then Naval.LooseFeedback = Naval.LastFeedback end
end)

-- Ohne offenes Fenster: Text kurz unter dem Fadenkreuz (nur Antwort auf eigene Bedienung)
hook.Add("HUDPaint", "PD.Naval.Feedback", function()
    local f = Naval.LooseFeedback
    if not f then return end
    local age = CurTime() - f.t
    if age > 3 then Naval.LooseFeedback = nil return end
    local a = math.Clamp((3 - age) * 255, 0, 255)
    draw.SimpleTextOutlined(f.text, "MLIB.16", ScrW() / 2, ScrH() / 2 + 40, Color(255, 120, 110, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, a * 0.7))
end)

function UI.Frame(title, w, h)
    local frame = vgui.Create("DFrame")
    Naval.OpenFrame = frame
    local opened = CurTime()
    frame:SetSize(math.min(w, ScrW() - 40), math.min(h, ScrH() - 40))
    frame:Center()
    frame:SetTitle("")
    frame:ShowCloseButton(false)
    frame:MakePopup()

    frame.Paint = function(s, pw, ph)
        draw.RoundedBox(0, 0, 0, pw, ph, COL_BG)
        surface.SetDrawColor(COL_ACCENT)
        surface.DrawRect(0, 0, pw, 3)
        draw.SimpleText(title, "MLIB.22", 14, 14, COL_TEXT)
    end

    -- Statuszeile: letzte Rueckmeldung (6 s)
    frame.PaintOver = function(s, pw, ph)
        local f = Naval.LastFeedback
        if not f or f.t < opened or CurTime() - f.t > 6 then return end
        local col = f.ok and COL_OK or COL_BAD
        draw.RoundedBox(0, 0, ph - 30, pw, 30, Color(14, 18, 24, 235))
        surface.SetDrawColor(col)
        surface.DrawRect(0, ph - 30, 4, 30)
        draw.SimpleText(f.text, "MLIB.16", 14, ph - 15, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", frame)
    close:SetText("")
    close:SetSize(32, 28)
    close:SetPos(frame:GetWide() - 40, 8)
    close.DoClick = function() frame:Close() end
    close.Paint = function(s, pw, ph)
        draw.SimpleText("✕", "MLIB.22", pw / 2, ph / 2, s:IsHovered() and COL_BAD or COL_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Weggegangen: schliessen
    frame.Think = function(s)
        if IsValid(s.Console) and LocalPlayer():GetPos():Distance(s.Console:GetPos()) > (Naval.StationUseRange or 160) * 1.5 then
            s:Close()
        end
    end

    return frame
end

function UI.Button(parent, text, onClick, colorFn)
    local btn = vgui.Create("DButton", parent)
    btn:SetText("")
    btn.Label = text
    btn.DoClick = function(s)
        if s.Disabled then return end
        surface.PlaySound("buttons/button15.wav")
        onClick(s)
    end
    btn.Paint = function(s, pw, ph)
        local col = colorFn and colorFn(s) or COL_ACCENT
        local bg = s.Disabled and Color(30, 34, 42) or (s:IsHovered() and Color(col.r * 0.35, col.g * 0.35, col.b * 0.35) or COL_PANEL)
        draw.RoundedBox(0, 0, 0, pw, ph, bg)
        surface.SetDrawColor(s.Disabled and Color(60, 64, 72) or col)
        surface.DrawOutlinedRect(0, 0, pw, ph, 1)
        draw.SimpleText(s.Label, "MLIB.16", pw / 2, ph / 2, s.Disabled and COL_DIM or COL_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    return btn
end

function UI.Bar(x, y, w, h, frac, col)
    draw.RoundedBox(0, x, y, w, h, Color(40, 46, 56))
    draw.RoundedBox(0, x, y, w * math.Clamp(frac, 0, 1), h, col or COL_ACCENT)
end

--------------------------------------------------------------------------------
-- Steuer
--------------------------------------------------------------------------------

local helm = {throttle = 0, p = 0, y = 0, r = 0, ty = 0, tz = 0, keys = {}}

local function SendHelm(align, cancelAuto, manualThrottle)
    net.Start("PD.Naval.Helm")
        net.WriteFloat(helm.throttle)
        net.WriteFloat(helm.p) net.WriteFloat(helm.y) net.WriteFloat(helm.r)
        net.WriteFloat(helm.ty) net.WriteFloat(helm.tz)
        net.WriteBool(align == true)
        net.WriteBool(cancelAuto == true)
        net.WriteBool(manualThrottle == true)
    net.SendToServer()
end

local KEYMAP = {
    [KEY_W] = {"p", 1}, [KEY_S] = {"p", -1},      -- W = Nase runter, S = Nase hoch
    [KEY_A] = {"y", 1}, [KEY_D] = {"y", -1},      -- A = links, D = rechts
    [KEY_Q] = {"r", -1}, [KEY_E] = {"r", 1},      -- Q/E rollen
    [KEY_LEFT] = {"ty", 1}, [KEY_RIGHT] = {"ty", -1},
    [KEY_UP] = {"tz", 1}, [KEY_DOWN] = {"tz", -1},
}

local function RecomputeKeys()
    local axes = {p = 0, y = 0, r = 0, ty = 0, tz = 0}
    for key, map in pairs(KEYMAP) do
        if helm.keys[key] then axes[map[1]] = axes[map[1]] + map[2] end
    end
    for axis, v in pairs(axes) do helm[axis] = math.Clamp(v, -1, 1) end
end

local function OpenHelm(console)
    local st = C.status or {}
    helm.throttle = st.throttle or 0
    helm.p, helm.y, helm.r, helm.ty, helm.tz = 0, 0, 0, 0, 0
    helm.keys = {}

    local frame = UI.Frame("STEUER", 760, 520)
    frame.Console = console
    frame.SteerMode = false

    local function SetThrottle(v)
        helm.throttle = math.Clamp(math.Round(v, 2), -0.25, 1)
        SendHelm(false, false, true)
    end

    -- Schubhebel
    local lever = vgui.Create("DPanel", frame)
    lever:SetPos(20, 60)
    lever:SetSize(110, 380)
    lever.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL_PANEL)
        local zeroY = h - 20 - (0.25 / 1.25) * (h - 40)
        local y = h - 20 - ((helm.throttle + 0.25) / 1.25) * (h - 40)

        surface.SetDrawColor(COL_DIM)
        surface.DrawLine(w / 2, 20, w / 2, h - 20)
        surface.SetDrawColor(COL_WARN)
        surface.DrawLine(10, zeroY, w - 10, zeroY)

        draw.RoundedBox(0, 15, y - 8, w - 30, 16, helm.throttle < 0 and COL_WARN or COL_ACCENT)
        draw.SimpleText(math.Round(helm.throttle * 100) .. " %", "MLIB.18", w / 2, 6, COL_TEXT, TEXT_ALIGN_CENTER)
    end
    lever.OnMousePressed = function(s) s.Dragging = true s:MouseCapture(true) end
    lever.OnMouseReleased = function(s) s.Dragging = false s:MouseCapture(false) SendHelm(false, false, true) end
    lever.Think = function(s)
        if not s.Dragging then
            if C.status and C.status.auto then helm.throttle = C.status.throttle or helm.throttle end
            return
        end
        local _, my = s:CursorPos()
        local f = 1 - math.Clamp((my - 20) / (s:GetTall() - 40), 0, 1)
        helm.throttle = math.Clamp(math.Round(f * 1.25 - 0.25, 2), -0.25, 1)
    end

    local presets = {{"Voll", 1}, {"3/4", 0.75}, {"1/2", 0.5}, {"1/4", 0.25}, {"Stopp", 0}, {"Zurück", -0.25}}
    for i, p in ipairs(presets) do
        local b = UI.Button(frame, p[1], function() SetThrottle(p[2]) end, function() return p[2] == 0 and COL_WARN or COL_ACCENT end)
        b:SetPos(140, 60 + (i - 1) * 46)
        b:SetSize(90, 38)
    end

    -- Anzeige
    local info = vgui.Create("DPanel", frame)
    info:SetPos(250, 60)
    info:SetSize(frame:GetWide() - 270, 210)
    info.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL_PANEL)
        local status = C.status or {}
        local view = C.View and C.View()

        draw.SimpleText("System: " .. Naval.SystemName(status.system), "MLIB.18", 12, 10, COL_TEXT)
        draw.SimpleText(("Geschwindigkeit: %d / %d m/s"):format(status.speed or 0, status.maxSpeed or 0), "MLIB.18", 12, 36, COL_TEXT)
        UI.Bar(12, 62, w - 24, 10, (status.speed or 0) / math.max(status.maxSpeed or 1, 1), COL_OK)

        if view and view.rot then
            local a = Naval.Q.ToAngle(view.rot)
            draw.SimpleText(("Kurs %.0f°   Neigung %.0f°   Rolle %.0f°"):format((a.y + 360) % 360, -a.p, a.r), "MLIB.18", 12, 84, COL_TEXT)
        end

        local auto = status.autopilot and "Autopilot: richtet aus" or "Autopilot: aus"
        if status.auto then
            auto = "Autopilot: " .. (status.auto.label or "?") .. (status.auto.arrived and " (erreicht)" or (" - " .. Fmt(status.auto.eta)))
        end
        draw.SimpleText(auto, "MLIB.16", 12, 112, (status.autopilot or status.auto) and COL_ACCENT or COL_DIM)

        if status.nav and status.align then
            draw.SimpleText(("Sprungvektor %s: %.1f° Abweichung"):format(Naval.SystemName(status.nav.target), status.align), "MLIB.16", 12, 136,
                status.align <= 2 and COL_OK or COL_WARN)
        end

        if status.shadow then
            draw.SimpleText(("Massenschatten %s: %.0f / %.0f km"):format(status.shadow.name, status.shadow.dist / 1000, status.shadow.limit / 1000), "MLIB.16", 12, 160, COL_WARN)
        end

        if status.state and status.state ~= "normal" then
            draw.SimpleText("Hyperantrieb führt: " .. status.state, "MLIB.16", 12, 184, COL_WARN)
        end
    end

    -- Steuermodus
    local steer = UI.Button(frame, "Steuermodus: AUS (Tastatur)", function(s)
        frame.SteerMode = not frame.SteerMode
        s.Label = frame.SteerMode and "Steuermodus: AN - W/S A/D Q/E, Pfeile" or "Steuermodus: AUS (Tastatur)"
        helm.keys = {}
        RecomputeKeys()
        SendHelm()
        frame:RequestFocus()
    end, function() return frame.SteerMode and COL_OK or COL_ACCENT end)
    steer:SetPos(250, 285)
    steer:SetSize(frame:GetWide() - 270, 40)

    local alignBtn = UI.Button(frame, "Auf Sprungvektor ausrichten", function() SendHelm(true) end)
    alignBtn:SetPos(250, 335)
    alignBtn:SetSize((frame:GetWide() - 280) / 2, 40)

    local manualBtn = UI.Button(frame, "Autopilot aus", function() SendHelm(false, true) end, function() return COL_WARN end)
    manualBtn:SetPos(250 + (frame:GetWide() - 280) / 2 + 10, 335)
    manualBtn:SetSize((frame:GetWide() - 280) / 2, 40)

    -- Drehraten-Anzeige
    local rates = vgui.Create("DPanel", frame)
    rates:SetPos(250, 390)
    rates:SetSize(frame:GetWide() - 270, 50)
    rates.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL_PANEL)
        local labels = {{"Nicken", helm.p}, {"Gieren", helm.y}, {"Rollen", helm.r}, {"Düsen ↔", helm.ty}, {"Düsen ↕", helm.tz}}
        local cw = w / #labels
        for i, l in ipairs(labels) do
            local x = (i - 1) * cw
            draw.SimpleText(l[1], "MLIB.14", x + cw / 2, 6, COL_DIM, TEXT_ALIGN_CENTER)
            draw.SimpleText(l[2] == 0 and "-" or (l[2] > 0 and "+" or "−"), "MLIB.20", x + cw / 2, 24, l[2] == 0 and COL_DIM or COL_ACCENT, TEXT_ALIGN_CENTER)
        end
    end

    frame.OnKeyCodePressed = function(s, key)
        if not s.SteerMode or not KEYMAP[key] then return end
        helm.keys[key] = true
        RecomputeKeys()
        SendHelm()
    end

    frame.OnKeyCodeReleased = function(s, key)
        if not KEYMAP[key] then return end
        helm.keys[key] = nil
        RecomputeKeys()
        SendHelm()
    end

    -- Beim Schliessen Drehung beenden (Schub bleibt)
    frame.OnClose = function()
        helm.keys = {}
        RecomputeKeys()
        SendHelm()
    end
end

--------------------------------------------------------------------------------
-- Hyperantrieb
--------------------------------------------------------------------------------

local function SendHyper(action)
    net.Start("PD.Naval.Hyper")
    net.WriteString(action)
    net.SendToServer()
end

local function OpenHyperdrive(console)
    local frame = UI.Frame("HYPERANTRIEB", 620, 430)
    frame.Console = console

    local info = vgui.Create("DPanel", frame)
    info:SetPos(20, 55)
    info:SetSize(frame:GetWide() - 40, 250)
    info.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL_PANEL)
        local st = C.status or {}
        local now = Naval.Now()
        local y = 12

        local function Line(text, col)
            draw.SimpleText(text, "MLIB.18", 14, y, col or COL_TEXT)
            y = y + 28
        end

        local nav = st.nav
        if not nav then
            Line("Keine Kursloesung - am Navigationscomputer berechnen.", COL_DIM)
        elseif not nav.ready then
            Line("Kurs nach " .. Naval.SystemName(nav.target) .. " wird berechnet ...", COL_WARN)
            UI.Bar(14, y, w - 28, 10, (now - nav.start) / math.max(nav.finish - nav.start, 1), COL_WARN)
            y = y + 22
        else
            Line("Ziel: " .. Naval.SystemName(nav.target) .. "   Sprungdauer: " .. Fmt(nav.duration), nav.valid and COL_OK or COL_BAD)
            Line(nav.routes and #nav.routes > 0 and ("Über " .. table.concat(nav.routes, " -> ")) or "Direktsprung abseits der Routen", COL_DIM)
            if not nav.valid then Line(nav.reason or "Ungueltig", COL_BAD) end
        end

        if st.align then
            Line(("Ausrichtung: %.1f° Abweichung (erlaubt %.0f°)"):format(st.align, (C.static and C.static.settings.jump_align_tolerance) or 2),
                st.align <= ((C.static and C.static.settings.jump_align_tolerance) or 2) and COL_OK or COL_WARN)
        end

        if st.shadow then
            Line(("Massenschatten %s - noch %.0f km"):format(st.shadow.name, (st.shadow.limit - st.shadow.dist) / 1000), COL_BAD)
        elseif st.interdict then
            Line("Abfangfeld aktiv: " .. st.interdict, COL_BAD)
        else
            Line("Kein Massenschatten", COL_OK)
        end

        local hy = st.hyper or {}
        if st.state == "spooling" and hy.tJump then
            Line("Antrieb faehrt hoch: " .. Fmt(hy.tJump - now), COL_WARN)
            UI.Bar(14, y, w - 28, 10, (now - hy.tSpool) / math.max(hy.tJump - hy.tSpool, 1), COL_WARN)
        elseif st.state == "hyperspace" and hy.tExit then
            Line("Im Hyperraum nach " .. Naval.SystemName(hy.to) .. " - Ankunft in " .. Fmt(hy.tExit - now), COL_ACCENT)
            UI.Bar(14, y, w - 28, 10, (now - hy.tTunnel) / math.max(hy.tExit - hy.tTunnel, 1), COL_ACCENT)
        elseif st.state == "jumping" or st.state == "exiting" then
            Line(st.state == "jumping" and "Eintritt in den Hyperraum" or "Austritt aus dem Hyperraum", COL_ACCENT)
        end
    end

    local bw = (frame:GetWide() - 60) / 3
    local align = UI.Button(frame, "Ausrichten", function() SendHyper("align") end)
    align:SetPos(20, 320) align:SetSize(bw, 50)

    local jump = UI.Button(frame, "SPRINGEN", function() SendHyper("jump") end, function() return COL_OK end)
    jump:SetPos(30 + bw, 320) jump:SetSize(bw, 50)

    local abort = UI.Button(frame, "Abbrechen", function() SendHyper("abort") end, function() return COL_BAD end)
    abort:SetPos(40 + bw * 2, 320) abort:SetSize(bw, 50)

    frame.Think = function(s)
        if IsValid(s.Console) and LocalPlayer():GetPos():Distance(s.Console:GetPos()) > (Naval.StationUseRange or 160) * 1.5 then
            s:Close()
            return
        end

        local st = C.status or {}
        local tol = (C.static and C.static.settings.jump_align_tolerance) or 2
        local ready = st.state == "normal" and st.nav and st.nav.ready and st.nav.valid and not st.shadow and not st.interdict and (st.align or 99) <= tol
        jump.Disabled = not ready
        align.Disabled = not (st.state == "normal" and st.nav and st.nav.ready and st.nav.valid)
        abort.Disabled = st.state ~= "spooling"
    end
end

--------------------------------------------------------------------------------
-- Logbuch
--------------------------------------------------------------------------------

local logFrame

net.Receive("PD.Naval.ShipLog", function()
    local rows = util.JSONToTable(net.ReadString()) or {}
    if IsValid(logFrame) and logFrame.SetRows then logFrame.SetRows(rows) end
end)

local KIND_LABEL = {nav = "Navigation", manual = "Eintrag", admin = "Kommando", contact = "Kontakt", damage = "Schaden", combat = "Gefecht"}

local function OpenShipLog(console)
    local frame = UI.Frame("LOGBUCH", 760, 560)
    frame.Console = console
    logFrame = frame

    local list = vgui.Create("DScrollPanel", frame)
    list:SetPos(20, 55)
    list:SetSize(frame:GetWide() - 40, frame:GetTall() - 140)

    frame.SetRows = function(rows)
        list:Clear()
        for _, row in ipairs(rows) do
            local line = list:Add("DPanel")
            line:Dock(TOP)
            line:DockMargin(0, 0, 0, 4)
            line:SetTall(46)
            line.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, COL_PANEL)
                draw.SimpleText(os.date("%d.%m. %H:%M", tonumber(row.ts) or 0) .. "  " .. (KIND_LABEL[row.kind] or row.kind)
                    .. (row.author ~= "" and ("  - " .. row.author) or ""), "MLIB.14", 10, 5, COL_DIM)
                draw.SimpleText(row.text or "", "MLIB.16", 10, 22, COL_TEXT)
            end
        end
    end

    local entry = vgui.Create("DTextEntry", frame)
    entry:SetPos(20, frame:GetTall() - 70)
    entry:SetSize(frame:GetWide() - 170, 40)
    entry:SetFont("MLIB.16")
    entry:SetPlaceholderText("Neuer Eintrag ...")

    local add = UI.Button(frame, "Eintragen", function()
        local text = entry:GetValue()
        if string.Trim(text) == "" then return end
        net.Start("PD.Naval.ShipLog") net.WriteString("add") net.WriteString(text) net.SendToServer()
        entry:SetValue("")
    end, function() return COL_OK end)
    add:SetPos(frame:GetWide() - 140, frame:GetTall() - 70)
    add:SetSize(120, 40)

    net.Start("PD.Naval.ShipLog") net.WriteString("list") net.SendToServer()
end

--------------------------------------------------------------------------------
-- Oeffnen
--------------------------------------------------------------------------------

Naval.StationUI = Naval.StationUI or {}
Naval.StationUI.helm = OpenHelm
Naval.StationUI.hyperdrive = OpenHyperdrive
Naval.StationUI.shiplog = OpenShipLog

net.Receive("PD.Naval.Station.Open", function()
    local station = net.ReadString()
    local console = net.ReadEntity()

    -- Stationen mit 3D2D-Bedienung oeffnen kein Menue mehr (das alte bleibt
    -- im Code, bis alle Konsolen umgestellt sind)
    local def = Naval.Stations and Naval.Stations[station]
    if def and def.ui3d and Naval.Console3D and Naval.Console3D[station] then return end

    local open = Naval.StationUI[station]
    if open then open(console) end
end)
