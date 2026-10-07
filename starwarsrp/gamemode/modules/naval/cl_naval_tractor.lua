--[[
    Naval - Traktorstrahl und Entern (Client, Stufe 4e): Strahl im Weltraum,
    Leitstand "Traktorstrahl & Entern". Daten: C.status.tractor
    (sv_naval_tractor.lua).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

local MAT_BEAM = Material("sprites/physbeama")
local MAT_GLOW = Material("sprites/light_glow02_add")
local BEAM_COL = Color(120, 200, 255, 200)

local function Held()
    local t = C.status and C.status.tractor
    return t and t.held
end

-- Vom Renderpass (cl_naval_render.lua) im Skybox-Pass gerufen
function Naval.DrawTractor(view, toRender)
    local held = Held()
    local s = held and view.ships and view.ships[held.id]
    if not s then return end

    local rel = Naval.V3.Sub(s.pos, view.pos)
    local len = Naval.V3.Len(rel)
    if len < 30 then return end
    local b = toRender(s.pos)
    local a = toRender(Naval.V3.Add(view.pos, Naval.V3.Scale(rel, 20 / len)))
    if not a or not b then return end

    local pulse = 0.75 + math.sin(CurTime() * 6) * 0.25
    local width = math.max(b:Length() * 0.012, 0.4)
    render.SetMaterial(MAT_BEAM)
    render.DrawBeam(a, b, width, CurTime() * -2, CurTime() * -2 + 4, Color(BEAM_COL.r, BEAM_COL.g, BEAM_COL.b, 200 * pulse))
    render.SetMaterial(MAT_GLOW)
    render.DrawSprite(b, width * 4, width * 4, Color(BEAM_COL.r, BEAM_COL.g, BEAM_COL.b, 160 * pulse))
end

--------------------------------------------------------------------------------
-- Leitstand
--------------------------------------------------------------------------------

local function Dist(m)
    if Naval.FormatDist then return Naval.FormatDist(m) end
    return m >= 1000 and ("%.1f km"):format(m / 1000) or ("%d m"):format(m)
end

local function OpenTractor(console)
    local UI = Naval.UI
    local COL = UI.COL
    local frame = UI.Frame("TRAKTORSTRAHL & ENTERKOMMANDO", 980, 660)
    frame.Console = console

    local function T() return C.status and C.status.tractor end
    local function Cmd(action, args) Naval.CombatCmd("tractor", action, args or {}) end

    local top = vgui.Create("DPanel", frame)
    top:SetPos(20, 55)
    top:SetSize(frame:GetWide() - 40, 220)
    top.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL.panel)
        local t = T()
        if not t then
            draw.SimpleText("Dieses Schiff hat keinen Traktorstrahl.", "MLIB.18", 14, 14, COL.dim)
            return
        end

        draw.SimpleText("TRAKTORSTRAHL  -  Reichweite " .. Dist(t.range), "MLIB.14", 14, 8, COL.dim)
        local held = t.held
        if held then
            draw.SimpleText(("Hält: %s  -  %s"):format(held.name, Dist(held.dist)), "MLIB.18", 14, 30, COL.accent)
            local state = held.docked and "angedockt" or (held.pull and "wird herangezogen" or "gehalten")
            local notes = {state}
            if held.shields then notes[#notes + 1] = "Schilde oben" end
            if not held.defenseless then notes[#notes + 1] = "wehrt sich" end
            draw.SimpleText(table.concat(notes, "  -  "), "MLIB.14", 14, 54, held.shields and COL.warn or COL.dim)
            local frac = math.Clamp(1 - (held.dist - held.dock) / math.max(t.range, 1), 0, 1)
            UI.Bar(14, 76, 440, 8, frac, held.docked and COL.ok or COL.accent)
        else
            draw.SimpleText("Strahl frei - Ziel unten auswählen", "MLIB.18", 14, 30, COL.dim)
        end

        draw.SimpleText("ENTERKOMMANDO", "MLIB.14", 14, 110, COL.dim)
        local b = t.boarding
        if b then
            local text = ("Drüben auf %s  -  Erfolgsaussicht %d %%"):format(b.name, b.chance)
            if b.remaining > 0 then text = text .. ("  -  noch %d s"):format(b.remaining)
            elseif b.live then text = text .. "  -  wartet auf die Spielleitung" end
            draw.SimpleText(text, "MLIB.16", 14, 132, COL.text)
            UI.Bar(14, 156, 440, 8, b.progress, COL.warn)
        elseif t.cooldown > 0 then
            draw.SimpleText(("Kommando sammelt sich: %d s"):format(t.cooldown), "MLIB.16", 14, 132, COL.warn)
        else
            draw.SimpleText(held and (held.docked and "Bereit zum Entern" or "Ziel erst heranziehen") or "Bereit", "MLIB.16", 14, 132, COL.dim)
        end
    end

    local pull = UI.Button(top, "Heranziehen", function()
        local held = Held()
        Cmd("pull", {on = not (held and held.pull)})
    end, function() local h = Held() return h and h.pull and COL.ok or COL.dim end)
    pull:SetPos(500, 30) pull:SetSize(210, 36)

    local release = UI.Button(top, "Strahl lösen", function() Cmd("release") end, function() return COL.bad end)
    release:SetPos(720, 30) release:SetSize(210, 36)

    local board = UI.Button(top, "Enterkommando entsenden", function() Cmd("board") end, function() return COL.warn end)
    board:SetPos(500, 120) board:SetSize(430, 36)

    local ok = UI.Button(top, "Spielleitung: Erfolg", function() Cmd("resolve", {ok = true}) end, function() return COL.ok end)
    ok:SetPos(500, 166) ok:SetSize(210, 32)
    local fail = UI.Button(top, "Spielleitung: abgewehrt", function() Cmd("resolve", {ok = false}) end, function() return COL.bad end)
    fail:SetPos(720, 166) fail:SetSize(210, 32)

    -- Ziele in der Naehe
    local head = vgui.Create("DPanel", frame)
    head:SetPos(20, 282)
    head:SetSize(frame:GetWide() - 40, 22)
    head.Paint = function()
        draw.SimpleText("SCHIFFE IN DER NÄHE  -  greifbar: wehrlose Schiffe oder kleine ohne Schilde", "MLIB.12", 4, 4, COL.dim)
    end

    local list = vgui.Create("DScrollPanel", frame)
    list:SetPos(20, 308)
    list:SetSize(frame:GetWide() - 40, frame:GetTall() - 328)

    local rows = {}
    for i = 1, 12 do
        local row = list:Add("DPanel")
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 4)
        row:SetTall(40)
        row.Paint = function(s, w, h)
            local c = s.Contact
            if not c then return end
            draw.RoundedBox(0, 0, 0, w, h, COL.panel)
            draw.SimpleText(c.name .. "  -  " .. Dist(c.dist), "MLIB.16", 10, 3, c.ok and COL.text or COL.dim)
            draw.SimpleText(c.ok and (c.defenseless and "wehrlos - greifbar" or "greifbar") or (c.reason or ""), "MLIB.12", 10, 22, c.ok and COL.ok or COL.dim)
        end
        local grab = UI.Button(row, "Greifen", function()
            if row.Contact then Cmd("lock", {id = row.Contact.id}) end
        end, function() return row.Contact and row.Contact.ok and COL.accent or COL.dim end)
        grab:SetSize(120, 30)
        grab:SetPos(list:GetWide() - 140, 5)
        row.Grab = grab
        rows[i] = row
    end

    local baseThink = frame.Think
    frame.Think = function(s)
        if baseThink then baseThink(s) end
        if not IsValid(s) then return end
        local t = T()
        local held = t and t.held
        local contacts = t and t.contacts or {}
        for i, row in ipairs(rows) do
            row.Contact = contacts[i]
            row:SetVisible(contacts[i] ~= nil)
            row.Grab.Disabled = held ~= nil or not (contacts[i] and contacts[i].ok)
        end
        pull.Disabled = not held
        release.Disabled = not held or (t and t.boarding ~= nil)
        board.Disabled = not (held and held.docked) or held.shields or (t.boarding ~= nil) or t.cooldown > 0
        local judge = LocalPlayer():IsAdmin() and t and t.boarding and t.boarding.live and t.boarding.remaining <= 0
        ok:SetVisible(judge == true)
        fail:SetVisible(judge == true)
    end
end

Naval.StationUI = Naval.StationUI or {}
Naval.StationUI.tractor = OpenTractor
