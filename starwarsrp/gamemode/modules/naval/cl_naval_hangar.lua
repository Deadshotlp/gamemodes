--[[
    Naval - Staffeln (Client, Stufe 4e): Darstellung im Weltraum (Leucht-
    punkte in Formation, je Maschine einer), Hangar-Leitstand.
    Daten: PD.Naval.Squadrons (sv_naval_hangar.lua), Status C.status.hangar.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

local MAT_GLOW = Material("sprites/light_glow02_add")

C.squadrons = C.squadrons or {}

net.Receive("PD.Naval.Squadrons", function()
    local view = C.View and C.View()
    local base = view and view.pos or {x = 0, y = 0, z = 0}
    local now = CurTime()
    local list = {}

    for _ = 1, net.ReadUInt(8) do
        local sq = {id = net.ReadUInt(16), bomber = net.ReadBool(), factionId = net.ReadString(), craft = net.ReadUInt(6)}
        local rel = {x = net.ReadFloat(), y = net.ReadFloat(), z = net.ReadFloat()}
        sq.vel = {x = net.ReadFloat(), y = net.ReadFloat(), z = net.ReadFloat()}
        sq.pos = Naval.V3.Add(base, rel)
        sq.t = now
        list[#list + 1] = sq
    end

    C.squadrons = list
end)

-- Aktuelle Lage einer Staffel (fortgeschrieben)
function Naval.SquadronPos(sq)
    return Naval.V3.Add(sq.pos, Naval.V3.Scale(sq.vel, math.min(CurTime() - sq.t, 1)))
end

local function SquadColor(fid, bomber)
    local f = C.static and C.static.factions and C.static.factions[fid]
    local c = f and f.color or {200, 200, 200}
    if bomber then return Color(math.min(255, c[1] + 90), math.min(255, c[2] + 40), c[3], 255) end
    return Color(math.min(255, c[1] + 60), math.min(255, c[2] + 60), math.min(255, c[3] + 60), 255)
end

-- Vom Renderpass (cl_naval_render.lua) im Skybox-Pass gerufen
function Naval.DrawSquadrons(view, toRender)
    if not C.squadrons or #C.squadrons == 0 then return end
    render.SetMaterial(MAT_GLOW)
    local now = CurTime()

    for _, sq in ipairs(C.squadrons) do
        local center = Naval.SquadronPos(sq)
        local col = SquadColor(sq.factionId, sq.bomber)
        local n = math.min(sq.craft, 12)
        for i = 1, n do
            -- Formation in Dreiergruppen, leicht schwankend
            local ring = math.floor((i - 1) / 3)
            local a = (i - 1) % 3 * 2.1 + ring * 0.7 + now * 0.3 + sq.id
            local off = {x = math.cos(a) * (120 + ring * 90), y = math.sin(a) * (120 + ring * 90), z = math.sin(a * 2 + now) * 60}
            local p = toRender(Naval.V3.Add(center, off))
            if p then
                local size = math.max(p:Length() * 0.006, 0.25) * (sq.bomber and 1.4 or 1)
                render.DrawSprite(p, size, size, col)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Hangar-Leitstand
--------------------------------------------------------------------------------

local function OpenHangar(console)
    local UI = Naval.UI
    local COL = UI.COL
    local frame = UI.Frame("HANGAR-LEITSTAND", 980, 640)
    frame.Console = console

    local function H() return C.status and C.status.hangar end
    local task = "escort"

    local top = vgui.Create("DPanel", frame)
    top:SetPos(20, 55)
    top:SetSize(frame:GetWide() - 40, 170)
    top.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL.panel)
        local hg = H()
        if not hg then
            draw.SimpleText("Dieses Schiff hat keinen Hangar.", "MLIB.18", 14, 14, COL.dim)
            return
        end
        draw.SimpleText("BEREIT IM HANGAR", "MLIB.14", 14, 8, COL.dim)
        local y = 32
        for _, kind in ipairs({"fighter", "bomber"}) do
            local def = Naval.SquadronTypes[kind]
            local ready, max = hg.ready[kind] or 0, hg.max[kind] or 0
            draw.SimpleText(("%s: %d / %d Maschinen"):format(def.name, ready, max), "MLIB.16", 14, y, max > 0 and COL.text or COL.dim)
            UI.Bar(14, y + 22, 360, 8, max > 0 and ready / max or 0, kind == "bomber" and COL.warn or COL.accent)
            y = y + 46
        end
        draw.SimpleText("Auftrag beim Start:", "MLIB.14", 400, 8, COL.dim)
    end

    -- Auftrag beim Start
    for i, t in ipairs(Naval.SquadronTasks) do
        local b = UI.Button(top, t.name, function() task = t.id end, function() return task == t.id and COL.ok or COL.dim end)
        b:SetPos(400 + (i - 1) * 180, 30)
        b:SetSize(172, 32)
    end
    local launchF = UI.Button(top, "Jägerstaffel starten", function() Naval.CombatCmd("hangar", "launch", {kind = "fighter", task = task}) end, function() return COL.ok end)
    launchF:SetPos(400, 74) launchF:SetSize(260, 36)
    local launchB = UI.Button(top, "Bomberstaffel starten", function() Naval.CombatCmd("hangar", "launch", {kind = "bomber", task = task}) end, function() return COL.warn end)
    launchB:SetPos(670, 74) launchB:SetSize(260, 36)
    local recallAll = UI.Button(top, "Alle zurückrufen", function() Naval.CombatCmd("hangar", "recall", {all = true}) end, function() return COL.bad end)
    recallAll:SetPos(400, 120) recallAll:SetSize(530, 36)

    local hint = vgui.Create("DPanel", frame)
    hint:SetPos(20, 232)
    hint:SetSize(frame:GetWide() - 40, 22)
    hint.Paint = function(s, w, h)
        draw.SimpleText("\"Ziel angreifen\" nimmt das Ziel des Waffenleitstands. Springen geht erst, wenn alle Staffeln gelandet sind.", "MLIB.12", 4, 4, COL.dim)
    end

    -- Staffeln draussen
    local list = vgui.Create("DScrollPanel", frame)
    list:SetPos(20, 260)
    list:SetSize(frame:GetWide() - 40, frame:GetTall() - 280)

    local rows = {}
    for i = 1, 16 do
        local row = list:Add("DPanel")
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 4)
        row:SetTall(44)
        row.Paint = function(s, w, h)
            local sq = s.Squadron
            if not sq then return end
            draw.RoundedBox(0, 0, 0, w, h, COL.panel)
            local def = Naval.SquadronTypes[sq.kind] or {}
            local state = sq.state == "launching" and "startet" or (sq.state == "returning" and "kehrt zurück" or "im Einsatz")
            local taskName = sq.task
            for _, t in ipairs(Naval.SquadronTasks) do if t.id == sq.task then taskName = t.name end end
            draw.SimpleText(("%s %d  -  %d Maschinen"):format(def.name or sq.kind, sq.id, sq.craft), "MLIB.16", 10, 4, COL.text)
            draw.SimpleText(("%s  -  %s%s  -  %s"):format(state, taskName, sq.target and (": " .. sq.target) or "",
                Naval.FormatDist and Naval.FormatDist(sq.dist or 0) or ""), "MLIB.12", 10, 24, COL.dim)
        end

        local buttons = {{"Begleiten", "escort"}, {"Angriff", "attack"}, {"Abfangen", "intercept"}}
        for k, b in ipairs(buttons) do
            local btn = UI.Button(row, b[1], function()
                if row.Squadron then Naval.CombatCmd("hangar", "task", {id = row.Squadron.id, task = b[2]}) end
            end, function() return row.Squadron and row.Squadron.task == b[2] and COL.ok or COL.dim end)
            btn:SetSize(96, 30)
            btn:SetPos(list:GetWide() - 420 + (k - 1) * 100, 7)
        end
        local back = UI.Button(row, "Zurück", function()
            if row.Squadron then Naval.CombatCmd("hangar", "recall", {id = row.Squadron.id}) end
        end, function() return COL.bad end)
        back:SetSize(90, 30)
        back:SetPos(list:GetWide() - 116, 7)
        rows[i] = row
    end

    local baseThink = frame.Think
    frame.Think = function(s)
        if baseThink then baseThink(s) end
        if not IsValid(s) then return end
        local hg = H()
        local active = hg and hg.active or {}
        for i, row in ipairs(rows) do
            row.Squadron = active[i]
            row:SetVisible(active[i] ~= nil)
        end
        launchF.Disabled = not hg or (hg.ready.fighter or 0) < 1
        launchB.Disabled = not hg or (hg.ready.bomber or 0) < 1
        recallAll.Disabled = #active == 0
    end
end

Naval.StationUI = Naval.StationUI or {}
Naval.StationUI.hangar = OpenHangar
