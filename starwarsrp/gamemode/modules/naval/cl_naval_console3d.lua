--[[
    Naval - Konsolen als 3D2D direkt auf dem Modell (Client).

    Statt eines Menues zeichnen Stationen mit ui3d = true ihre Anzeigen und
    Knoepfe auf die Flaechen, die an den Demo-Konsolen je Modell festgelegt
    wurden (Naval.Layouts, cl_naval_layouts.lua). Rollen der Flaechen:
      main   groesste Anzeige (Hauptbildschirm)
      s1, s2 weitere Anzeigen (kleine Bildschirme, von links nach rechts)
      keys   groesste Knopf-Flaeche (Tastenfeld)
    Bedienung: mit dem Fadenkreuz zielen, E oder Linksklick. Halten wird
    unterstuetzt (z. B. Drehen an der Steuer).

    Eine Station meldet sich an mit Naval.Console3D[station] = {
        draw = function(role, w, h, ui, ent) ... end }
    ui:Button(x, y, w, h, text, opts) -> true beim Druecken;
    ui:Holding(x, y, w, h) -> true, solange gedrueckt gehalten.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

Naval.Console3D = Naval.Console3D or {}

local SCALE = 0.025          -- Einheiten pro Pixel
local DRAW_DIST = 450 * 450
local USE_DIST = 110          -- so nah muss man zum Bedienen sein

surface.CreateFont("PD.N3D.Huge", {font = "Roboto", size = 96, weight = 800, extended = true})
surface.CreateFont("PD.N3D.Big", {font = "Roboto", size = 52, weight = 700, extended = true})
surface.CreateFont("PD.N3D.Med", {font = "Roboto", size = 38, weight = 600, extended = true})
surface.CreateFont("PD.N3D.Small", {font = "Roboto", size = 30, weight = 500, extended = true})
surface.CreateFont("PD.N3D.Btn", {font = "Roboto", size = 34, weight = 700, extended = true})

local COL = {
    bg = Color(8, 14, 22, 235), panel = Color(18, 28, 40, 240), line = Color(60, 120, 170),
    text = Color(215, 232, 245), dim = Color(120, 150, 175), accent = Color(90, 180, 255),
    ok = Color(90, 220, 130), warn = Color(240, 190, 70), bad = Color(240, 90, 80),
}
Naval.Console3DColors = COL

--------------------------------------------------------------------------------
-- Eingabe (E oder Linksklick)
--------------------------------------------------------------------------------

local input3d = {down = false, pressed = false}

hook.Add("Think", "PD.Naval.Console3D.Input", function()
    local was = input3d.down
    local down = false
    if not vgui.CursorVisible() and not gui.IsGameUIVisible() then
        down = input.IsKeyDown(input.GetKeyCode(input.LookupBinding("+use") or "e") or KEY_E)
            or input.IsMouseDown(MOUSE_LEFT)
    end
    input3d.down = down
    input3d.pressed = down and not was
end)

--------------------------------------------------------------------------------
-- Rollen der Flaechen je Modell
--------------------------------------------------------------------------------

local roleCache = {}

local function Roles(model)
    local areas = Naval.Layouts and Naval.Layouts[model]
    if not areas then return nil end
    local cached = roleCache[model]
    if cached and cached.src == areas then return cached.roles end

    local displays, keys = {}, nil
    for _, a in ipairs(areas) do
        if a.kind == "button" then
            if not keys or a.w * a.h > keys.w * keys.h then keys = a end
        else
            displays[#displays + 1] = a
        end
    end
    table.sort(displays, function(a, b) return a.w * a.h > b.w * b.h end)
    local roles = {main = displays[1], keys = keys}
    local rest = {}
    for i = 2, #displays do rest[#rest + 1] = displays[i] end
    table.sort(rest, function(a, b) return a.pos.y > b.pos.y end)
    roles.s1, roles.s2 = rest[1], rest[2]

    roleCache[model] = {src = areas, roles = roles}
    return roles
end

--------------------------------------------------------------------------------
-- Zeichnen und Zeiger
--------------------------------------------------------------------------------

local UI = {}
UI.__index = UI

function UI:Hover(x, y, w, h)
    return self.mx ~= nil and self.mx >= x and self.mx <= x + w and self.my >= y and self.my <= y + h
end

function UI:Holding(x, y, w, h)
    return self.active and input3d.down and self:Hover(x, y, w, h)
end

-- Knopf; opts: {col, active (hervorgehoben), disabled, font}
function UI:Button(x, y, w, h, text, opts)
    opts = opts or {}
    local hover = self.active and self:Hover(x, y, w, h) and not opts.disabled
    local held = hover and input3d.down
    local col = opts.disabled and COL.dim or (opts.col or COL.accent)

    local bg = opts.active and Color(col.r * 0.45, col.g * 0.45, col.b * 0.45, 245)
        or (held and Color(col.r * 0.5, col.g * 0.5, col.b * 0.5, 245))
        or (hover and Color(col.r * 0.25, col.g * 0.25, col.b * 0.25, 245)) or COL.panel
    draw.RoundedBox(6, x, y, w, h, bg)
    surface.SetDrawColor(col)
    surface.DrawOutlinedRect(x, y, w, h, (hover or opts.active) and 4 or 2)
    draw.SimpleText(text, opts.font or "PD.N3D.Btn", x + w / 2, y + h / 2, opts.disabled and COL.dim or COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    if hover and input3d.pressed then
        surface.PlaySound("buttons/button15.wav")
        return true
    end
    return false
end

function UI:Bar(x, y, w, h, frac, col)
    draw.RoundedBox(4, x, y, w, h, Color(30, 40, 52))
    draw.RoundedBox(4, x, y, w * math.Clamp(frac, 0, 1), h, col or COL.accent)
end

function UI:Frame(w, h, title)
    draw.RoundedBox(8, 0, 0, w, h, COL.bg)
    surface.SetDrawColor(COL.line)
    surface.DrawOutlinedRect(0, 0, w, h, 2)
    if title then draw.SimpleText(title, "PD.N3D.Small", 14, 8, COL.dim) end
end

local function DrawArea(ent, def, role, a, eye, aim, canUse)
    local pos = ent:LocalToWorld(Vector(a.pos.x, a.pos.y, a.pos.z))
    local ang = ent:LocalToWorldAngles(Angle(a.ang.p, a.ang.y, a.ang.r))
    local normal = ang:Up()
    if (pos - eye):Dot(normal) >= 0 then return end -- von hinten

    local w, h = a.w / SCALE, a.h / SCALE
    local ui = setmetatable({active = canUse}, UI)

    -- Zeiger: Schnittpunkt Blickstrahl / Flaeche (Mittelpunkt der Flaeche = pos)
    if canUse then
        local hit = util.IntersectRayWithPlane(eye, aim, pos, normal)
        if hit and hit:DistToSqr(eye) <= USE_DIST * USE_DIST then
            local d = hit - pos
            ui.mx = d:Dot(ang:Forward()) / SCALE + w / 2
            ui.my = d:Dot(ang:Right()) / SCALE + h / 2
            if ui.mx < 0 or ui.mx > w or ui.my < 0 or ui.my > h then ui.mx, ui.my = nil, nil end
        end
    end

    -- Ursprung oben links: Flaechenmitte minus halbe Groesse
    local origin = pos - ang:Forward() * (a.w / 2) - ang:Right() * (a.h / 2)
    cam.Start3D2D(origin, ang, SCALE)
        local ok, err = pcall(def.draw, role, w, h, ui, ent)
        if not ok then
            draw.SimpleText("Fehler", "PD.N3D.Med", 10, 10, COL.bad)
            ErrorNoHaltWithStack(err)
        end
        if ui.mx then
            surface.SetDrawColor(255, 255, 255, 200)
            surface.DrawRect(ui.mx - 6, ui.my - 1, 12, 2)
            surface.DrawRect(ui.mx - 1, ui.my - 6, 2, 12)
        end
    cam.End3D2D()
    return ui.mx ~= nil
end

local hovering = false

hook.Add("PostDrawTranslucentRenderables", "PD.Naval.Console3D", function(depth, sky)
    if depth or sky or Naval.ClientShutdown then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local eye, aim = ply:EyePos(), ply:GetAimVector()
    local any = false

    for _, ent in ipairs(ents.FindByClass("pd_naval_console")) do
        local station = ent.GetStation and ent:GetStation()
        local def = station and Naval.Console3D[station]
        if def and eye:DistToSqr(ent:GetPos()) < DRAW_DIST then
            local roles = Roles(string.lower(ent:GetModel() or ""))
            if roles then
                local canUse = not ent:GetLocked() or ply:IsAdmin()
                for _, role in ipairs({"main", "s1", "s2", "keys"}) do
                    if roles[role] and DrawArea(ent, def, role, roles[role], eye, aim, canUse) then any = true end
                end
            end
        end
    end
    hovering = any
end)

-- Waehrend man auf eine Konsolenflaeche zeigt: Linksklick nicht als Schuss
hook.Add("PlayerBindPress", "PD.Naval.Console3D", function(_, bind, pressed)
    if hovering and pressed and string.find(bind, "+attack", 1, true) and not string.find(bind, "+attack2", 1, true) then
        return true
    end
end)

-- Rueckmeldung des Servers (Naval.Feedback) auf dem Hauptbildschirm
function Naval.Console3DFeedback(ui, w, y)
    local f = Naval.LastFeedback
    if not f or CurTime() - f.t > 6 then return end
    draw.SimpleText(f.text, "PD.N3D.Small", w / 2, y, f.ok and COL.ok or COL.bad, TEXT_ALIGN_CENTER)
end

--------------------------------------------------------------------------------
-- Steuer
--------------------------------------------------------------------------------

local helm = {throttle = nil, p = 0, y = 0, r = 0, ty = 0, tz = 0}
local sent = {}

local function SendHelm(align, cancelAuto, manualThrottle)
    local st = C.status or {}
    local throttle = helm.throttle or st.throttle or 0
    net.Start("PD.Naval.Helm")
        net.WriteFloat(throttle)
        net.WriteFloat(helm.p) net.WriteFloat(helm.y) net.WriteFloat(helm.r)
        net.WriteFloat(helm.ty) net.WriteFloat(helm.tz)
        net.WriteBool(align == true)
        net.WriteBool(cancelAuto == true)
        net.WriteBool(manualThrottle == true)
    net.SendToServer()
    sent = {p = helm.p, y = helm.y, r = helm.r, ty = helm.ty, tz = helm.tz}
end

local function FmtTime(s)
    s = math.max(0, math.floor(tonumber(s) or 0))
    return s >= 60 and ("%d:%02d min"):format(math.floor(s / 60), s % 60) or (s .. " s")
end

local THROTTLE = {{"Zurück", -0.25}, {"Stopp", 0}, {"1/4", 0.25}, {"1/2", 0.5}, {"3/4", 0.75}, {"Voll", 1}}
local ROTATE = {
    {"Nase ▲", "p", -1}, {"Nase ▼", "p", 1}, {"◄ Links", "y", 1}, {"Rechts ►", "y", -1},
    {"↺ Rollen", "r", -1}, {"Rollen ↻", "r", 1},
}
local THRUST = {{"Düse ◄", "ty", 1}, {"Düse ►", "ty", -1}, {"Düse ▲", "tz", 1}, {"Düse ▼", "tz", -1}}

local function DrawMain(w, h, ui)
    local st = C.status or {}
    ui:Frame(w, h, "STEUER")
    local x, y = 18, 48

    draw.SimpleText(Naval.SystemName and Naval.SystemName(st.system) or "?", "PD.N3D.Med", x, y, COL.text)
    y = y + 50
    draw.SimpleText(("%d m/s"):format(st.speed or 0), "PD.N3D.Big", x, y, COL.text)
    draw.SimpleText(("von %d"):format(st.maxSpeed or 0), "PD.N3D.Small", w - 18, y + 18, COL.dim, TEXT_ALIGN_RIGHT)
    y = y + 62
    ui:Bar(x, y, w - 36, 14, (st.speed or 0) / math.max(st.maxSpeed or 1, 1), COL.ok)
    y = y + 30

    local view = C.View and C.View()
    if view and view.rot then
        local a = Naval.Q.ToAngle(view.rot)
        draw.SimpleText(("Kurs %03.0f°"):format((a.y + 360) % 360), "PD.N3D.Med", x, y, COL.text)
        draw.SimpleText(("Neig. %.0f°  Rolle %.0f°"):format(-a.p, a.r), "PD.N3D.Small", w - 18, y + 6, COL.dim, TEXT_ALIGN_RIGHT)
        y = y + 48
    end

    if st.nav and st.align then
        draw.SimpleText(("Sprungvektor: %.1f°"):format(st.align), "PD.N3D.Small", x, y, st.align <= 2 and COL.ok or COL.warn)
        y = y + 36
    end
    if st.shadow then
        draw.SimpleText(("Massenschatten %s: %.0f km"):format(st.shadow.name, st.shadow.dist / 1000), "PD.N3D.Small", x, y, COL.warn)
        y = y + 36
    end
    if st.state and st.state ~= "normal" then
        draw.SimpleText("Hyperantrieb führt: " .. st.state, "PD.N3D.Small", x, y, COL.warn)
    end

    Naval.Console3DFeedback(ui, w, h - 40)
end

local function DrawThrottle(w, h, ui)
    local st = C.status or {}
    local t = helm.throttle or st.throttle or 0
    ui:Frame(w, h, "SCHUB")
    draw.SimpleText(math.Round(t * 100) .. "%", "PD.N3D.Huge", w / 2, h / 2 + 4, t < 0 and COL.warn or COL.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    ui:Bar(14, h - 26, w - 28, 12, (t + 0.25) / 1.25, t < 0 and COL.warn or COL.accent)
end

local function DrawAuto(w, h, ui)
    local st = C.status or {}
    ui:Frame(w, h, "AUTOPILOT")
    local text, col = "AUS", COL.dim
    if st.auto then
        text = st.auto.arrived and "ERREICHT" or FmtTime(st.auto.eta)
        col = COL.ok
        draw.SimpleText(string.sub(st.auto.label or "", 1, 14), "PD.N3D.Small", w / 2, h - 44, COL.text, TEXT_ALIGN_CENTER)
    elseif st.autopilot then
        text, col = "RICHTET AUS", COL.accent
    end
    draw.SimpleText(text, "PD.N3D.Big", w / 2, h / 2 - 4, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

local function DrawKeys(w, h, ui)
    local st = C.status or {}
    helm.keysFrame = FrameNumber()
    ui:Frame(w, h)
    local pad, cols = 12, 6
    local bw = (w - pad * (cols + 1)) / cols
    local bh = (h - pad * 4) / 3
    local function Cell(c, r) return pad + (c - 1) * (bw + pad), pad + (r - 1) * (bh + pad) end

    -- Reihe 1: Schubstufen
    local cur = helm.throttle or st.throttle or 0
    for i, t in ipairs(THROTTLE) do
        local bx, by = Cell(i, 1)
        if ui:Button(bx, by, bw, bh, t[1], {active = math.abs(cur - t[2]) < 0.01, col = t[2] <= 0 and COL.warn or COL.accent}) then
            helm.throttle = t[2]
            SendHelm(false, false, true)
        end
    end

    -- Reihe 2: Drehen (gedrueckt halten), Reihe 3: Duesen + Autopilot
    local axes = {p = 0, y = 0, r = 0, ty = 0, tz = 0}
    for i, b in ipairs(ROTATE) do
        local bx, by = Cell(i, 2)
        local held = ui:Holding(bx, by, bw, bh)
        ui:Button(bx, by, bw, bh, b[1], {active = held})
        if held then axes[b[2]] = b[3] end
    end
    for i, b in ipairs(THRUST) do
        local bx, by = Cell(i, 3)
        local held = ui:Holding(bx, by, bw, bh)
        ui:Button(bx, by, bw, bh, b[1], {active = held, col = COL.ok})
        if held then axes[b[2]] = b[3] end
    end
    local bx, by = Cell(5, 3)
    if ui:Button(bx, by, bw, bh, "Ausrichten", {disabled = not st.nav}) then SendHelm(true) end
    bx, by = Cell(6, 3)
    if ui:Button(bx, by, bw, bh, "Autopilot aus", {col = COL.warn, disabled = not (st.auto or st.autopilot)}) then SendHelm(false, true) end

    -- Drehung nur senden, wenn sie sich aendert (loslassen = 0)
    local changed = false
    for k, v in pairs(axes) do
        helm[k] = v
        if (sent[k] or 0) ~= v then changed = true end
    end
    if changed then SendHelm() end
end

-- Tastenfeld nicht mehr im Blick (weggedreht, weggegangen): Drehung beenden
hook.Add("Think", "PD.Naval.Console3D.HelmRelease", function()
    if FrameNumber() - (helm.keysFrame or 0) < 3 then return end
    local any = false
    for _, k in ipairs({"p", "y", "r", "ty", "tz"}) do
        if (sent[k] or 0) ~= 0 then any = true end
        helm[k] = 0
    end
    if any then SendHelm() end
end)

Naval.Console3D.helm = {
    draw = function(role, w, h, ui)
        -- Schub vom Server uebernehmen, solange niemand hier umstellt
        if role == "main" and C.status and C.status.throttle and helm.throttle and math.abs(helm.throttle - C.status.throttle) > 0.001
            and not input3d.down then
            helm.throttle = C.status.throttle
        end
        if role == "main" then DrawMain(w, h, ui)
        elseif role == "s1" then DrawThrottle(w, h, ui)
        elseif role == "s2" then DrawAuto(w, h, ui)
        elseif role == "keys" then DrawKeys(w, h, ui) end
    end,
}
