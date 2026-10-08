--[[
    Naval - Flaechen auf den Konsolenmodellen (Client).

    Demo-Konsolen (demo_large / demo_medium): Admins oeffnen mit E einen
    Editor, legen Flaechen an (Knopf oder Anzeige), platzieren sie am
    Fadenkreuz auf der Konsole, verschieben/drehen/skalieren sie und
    speichern. Die Flaechen werden per 3D2D auf den Demo-Konsolen gezeigt.
    Daten: Naval.Layouts[modell] (sv_naval_layouts.lua).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.Layouts = Naval.Layouts or {}

local SCALE = 0.05 -- 3D2D: Einheiten pro Pixel
local DRAW_DIST = 700 * 700
local DEMO = {demo_large = true, demo_medium = true}

surface.CreateFont("PD.Naval.Layout", {font = "Roboto", size = 34, weight = 700, extended = true})
surface.CreateFont("PD.Naval.LayoutSmall", {font = "Roboto", size = 22, weight = 500, extended = true})

local editing -- {ent, model, areas, sel}

net.Receive("PD.Naval.Layouts", function()
    local len = net.ReadUInt(32)
    local t = util.JSONToTable(util.Decompress(net.ReadData(len)) or "")
    if istable(t) then Naval.Layouts = t end
end)

local function ModelKey(ent)
    return string.lower(ent:GetModel() or "")
end

local function AreaTransform(ent, a)
    local pos = ent:LocalToWorld(Vector(a.pos.x, a.pos.y, a.pos.z))
    local ang = ent:LocalToWorldAngles(Angle(a.ang.p, a.ang.y, a.ang.r))
    return pos, ang
end

--------------------------------------------------------------------------------
-- Darstellung
--------------------------------------------------------------------------------

local function DrawArea(ent, a, selected)
    local pos, ang = AreaTransform(ent, a)
    local w, h = a.w / SCALE, a.h / SCALE
    local c = a.color or {90, 170, 255}
    local col = Color(c[1], c[2], c[3])

    cam.Start3D2D(pos, ang, SCALE)
        if a.kind == "button" then
            draw.RoundedBox(4, -w / 2, -h / 2, w, h, Color(62, 66, 72, 250))
        else
            draw.RoundedBox(math.min(16, h * 0.12), -w / 2, -h / 2, w, h, Color(0, 0, 0, 250))
        end
        if selected then
            surface.SetDrawColor(255, 230, 90)
            surface.DrawOutlinedRect(-w / 2, -h / 2, w, h, 4)
        end
        draw.SimpleText(a.label ~= "" and a.label or a.id, "PD.Naval.Layout", 0, -6, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(a.kind == "button" and "KNOPF" or "ANZEIGE", "PD.Naval.LayoutSmall", 0, 22, Color(col.r, col.g, col.b, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()

    -- Achsen der gewaehlten Flaeche: rot = Breite, gruen = Hoehe, blau = Normale
    if selected then
        render.DrawLine(pos, pos + ang:Forward() * 4, Color(255, 60, 60), false)
        render.DrawLine(pos, pos - ang:Right() * 4, Color(60, 255, 60), false)
        render.DrawLine(pos, pos + ang:Up() * 4, Color(80, 140, 255), false)
    end
end

hook.Add("PostDrawTranslucentRenderables", "PD.Naval.Layouts", function(depth, sky)
    if depth or sky or Naval.ClientShutdown then return end
    local eye = EyePos()
    for _, ent in ipairs(ents.FindByClass("pd_naval_console")) do
        if ent.GetStation and DEMO[ent:GetStation()] and eye:DistToSqr(ent:GetPos()) < DRAW_DIST then
            local isEdit = editing and editing.ent == ent
            local areas = isEdit and editing.areas or Naval.Layouts[ModelKey(ent)] or {}
            for i, a in ipairs(areas) do
                DrawArea(ent, a, isEdit and editing.sel == i)
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- Editor
--------------------------------------------------------------------------------

local COLORS = {
    {"Blau", {90, 170, 255}}, {"Grün", {90, 220, 130}}, {"Gelb", {240, 200, 70}},
    {"Rot", {240, 90, 80}}, {"Weiß", {225, 230, 240}}, {"Violett", {180, 120, 255}},
}

-- Platzieren am Fadenkreuz / Umsehen: Fenster weg, Maus frei
local pickMode -- "pick" | "look"
local frameRef

local function Resume()
    pickMode = nil
    if IsValid(frameRef) then
        frameRef:SetVisible(true)
        frameRef:MakePopup()
    end
end

local function PlaceAtCrosshair()
    local ply = LocalPlayer()
    local tr = util.TraceLine({start = ply:EyePos(), endpos = ply:EyePos() + ply:GetAimVector() * 300, filter = ply})
    local area = editing and editing.areas[editing.sel]
    if not tr.Hit or not area then return end
    local ent = editing.ent

    local n = tr.HitNormal
    local ang = n:Angle()
    ang:RotateAroundAxis(ang:Up(), 90)
    ang:RotateAroundAxis(ang:Forward(), 90)
    local lp = ent:WorldToLocal(tr.HitPos + n * 0.15)
    local la = ent:WorldToLocalAngles(ang)
    area.pos = {x = math.Round(lp.x, 2), y = math.Round(lp.y, 2), z = math.Round(lp.z, 2)}
    area.ang = {p = math.Round(la.p, 1), y = math.Round(la.y, 1), r = math.Round(la.r, 1)}
end

hook.Add("PlayerBindPress", "PD.Naval.LayoutPick", function(_, bind, pressed)
    if not pickMode or not pressed then return end
    if pickMode == "pick" and string.find(bind, "+attack", 1, true) and not string.find(bind, "+attack2", 1, true) then
        PlaceAtCrosshair()
        Resume()
        return true
    end
    if string.find(bind, "+reload", 1, true) or string.find(bind, "+attack2", 1, true) then
        Resume()
        return true
    end
end)

hook.Add("HUDPaint", "PD.Naval.LayoutPick", function()
    if not pickMode then return end
    local text = pickMode == "pick" and "Linksklick: Fläche hier auf die Konsole setzen   ·   R / Rechtsklick: zurück zum Editor"
        or "Umsehen   ·   R: zurück zum Editor"
    draw.SimpleTextOutlined(text, "MLIB.16", ScrW() / 2, ScrH() - 120, Color(255, 230, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
end)

local function NewArea(n)
    return {id = "flaeche" .. n, kind = "display", label = "", pos = {x = 0, y = 0, z = 40}, ang = {p = 0, y = 90, r = 90},
        w = 12, h = 6, color = {90, 170, 255}}
end

local function OpenEditor(console)
    if not LocalPlayer():IsAdmin() then
        Naval.LooseFeedback = {text = "Demo-Konsole: nur für Admins", ok = false, t = CurTime()}
        return
    end

    local UI = Naval.UI
    local COL = UI.COL
    local model = ModelKey(console)
    editing = {ent = console, model = model, areas = table.Copy(Naval.Layouts[model] or {}), sel = 1}

    local frame = UI.Frame("FLÄCHEN: " .. string.upper(string.GetFileFromFilename(model)), 420, math.min(ScrH() - 40, 900))
    frame:SetPos(20, 20)
    frame.Console = console
    frameRef = frame
    frame.OnRemove = function()
        if editing and editing.ent == console then editing = nil end
        pickMode = nil
    end

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:SetPos(10, 50)
    scroll:SetSize(frame:GetWide() - 20, frame:GetTall() - 90)

    local function Label(text)
        local l = scroll:Add("DLabel")
        l:Dock(TOP)
        l:DockMargin(4, 8, 4, 2)
        l:SetText(text)
        l:SetFont("MLIB.14")
        l:SetTextColor(COL.dim)
        return l
    end

    -- Liste der Flaechen
    Label("FLÄCHEN")
    local list = scroll:Add("DListView")
    list:Dock(TOP)
    list:SetTall(150)
    list:SetMultiSelect(false)
    list:AddColumn("ID")
    list:AddColumn("Art"):SetFixedWidth(80)
    list:AddColumn("Beschriftung")

    local syncing = false
    local controls = {}

    local function Sel() return editing.areas[editing.sel] end

    local function Refresh()
        syncing = true
        list:Clear()
        for i, a in ipairs(editing.areas) do
            local line = list:AddLine(a.id, a.kind == "button" and "Knopf" or "Anzeige", a.label)
            line.Index = i
            if i == editing.sel then list:SelectItem(line) end
        end
        local a = Sel()
        for _, c in ipairs(controls) do c.Load(a) end
        syncing = false
    end

    list.OnRowSelected = function(_, _, line)
        if syncing then return end
        editing.sel = line.Index
        Refresh()
    end

    local row = scroll:Add("DPanel")
    row:Dock(TOP)
    row:DockMargin(0, 4, 0, 0)
    row:SetTall(30)
    row.Paint = nil
    local function RowButton(text, x, w, fn, colFn)
        local b = UI.Button(row, text, fn, colFn or function() return COL.accent end)
        b:SetPos(x, 0) b:SetSize(w, 28)
        return b
    end
    RowButton("Neu", 0, 120, function()
        table.insert(editing.areas, NewArea(#editing.areas + 1))
        editing.sel = #editing.areas
        Refresh()
    end)
    RowButton("Kopie", 128, 120, function()
        local a = Sel()
        if not a then return end
        local c = table.Copy(a)
        c.id = a.id .. "_2"
        c.pos.z = c.pos.z + a.h + 1
        table.insert(editing.areas, c)
        editing.sel = #editing.areas
        Refresh()
    end)
    RowButton("Löschen", 256, 120, function()
        if not Sel() then return end
        table.remove(editing.areas, editing.sel)
        editing.sel = math.max(1, editing.sel - 1)
        Refresh()
    end, function() return COL.bad end)

    -- Eigenschaften
    local function Text(title, key)
        Label(title)
        local e = scroll:Add("DTextEntry")
        e:Dock(TOP)
        e:SetTall(26)
        e.OnChange = function(s)
            local a = Sel()
            if syncing or not a then return end
            a[key] = string.sub(s:GetValue(), 1, key == "id" and 32 or 64)
            for _, line in ipairs(list:GetLines()) do
                if line.Index == editing.sel then line:SetColumnText(key == "id" and 1 or 3, a[key]) end
            end
        end
        controls[#controls + 1] = {Load = function(a) e:SetValue(a and a[key] or "") e:SetEnabled(a ~= nil) end}
    end
    Text("ID (für die spätere Belegung)", "id")
    Text("Beschriftung", "label")

    Label("ART")
    local kind = scroll:Add("DComboBox")
    kind:Dock(TOP)
    kind:SetTall(26)
    kind:AddChoice("Anzeige (Information)", "display")
    kind:AddChoice("Knopf", "button")
    kind.OnSelect = function(_, _, _, value)
        local a = Sel()
        if syncing or not a then return end
        a.kind = value
        Refresh()
    end
    controls[#controls + 1] = {Load = function(a) kind:ChooseOptionID(a and a.kind == "button" and 2 or 1) end}

    Label("FARBE")
    local color = scroll:Add("DComboBox")
    color:Dock(TOP)
    color:SetTall(26)
    for i, c in ipairs(COLORS) do color:AddChoice(c[1], i) end
    color.OnSelect = function(_, _, _, value)
        local a = Sel()
        if syncing or not a then return end
        a.color = table.Copy(COLORS[value][2])
    end
    controls[#controls + 1] = {Load = function(a)
        local idx = 1
        for i, c in ipairs(COLORS) do
            if a and a.color and c[2][1] == a.color[1] and c[2][2] == a.color[2] and c[2][3] == a.color[3] then idx = i end
        end
        color:ChooseOptionID(idx)
    end}

    local function Slider(title, lo, hi, dec, get, set)
        local s = scroll:Add("DNumSlider")
        s:Dock(TOP)
        s:DockMargin(4, 0, 0, 0)
        s:SetTall(26)
        s:SetText(title)
        s:SetMinMax(lo, hi)
        s:SetDecimals(dec)
        s.Label:SetTextColor(COL.text)
        s.OnValueChanged = function(_, v)
            local a = Sel()
            if syncing or not a then return end
            set(a, math.Round(v, dec))
        end
        controls[#controls + 1] = {Load = function(a) if a then s:SetValue(get(a)) end end}
    end

    Label("POSITION (relativ zur Konsole, Einheiten)")
    Slider("X", -120, 120, 2, function(a) return a.pos.x end, function(a, v) a.pos.x = v end)
    Slider("Y", -120, 120, 2, function(a) return a.pos.y end, function(a, v) a.pos.y = v end)
    Slider("Z (Höhe)", -20, 160, 2, function(a) return a.pos.z end, function(a, v) a.pos.z = v end)
    Label("DREHUNG (Grad)")
    Slider("Neigung", -180, 180, 1, function(a) return a.ang.p end, function(a, v) a.ang.p = v end)
    Slider("Gieren", -180, 180, 1, function(a) return a.ang.y end, function(a, v) a.ang.y = v end)
    Slider("Rollen", -180, 180, 1, function(a) return a.ang.r end, function(a, v) a.ang.r = v end)
    Label("GRÖSSE (Einheiten)")
    Slider("Breite", 0.5, 120, 1, function(a) return a.w end, function(a, v) a.w = v end)
    Slider("Höhe", 0.5, 120, 1, function(a) return a.h end, function(a, v) a.h = v end)

    local tools = scroll:Add("DPanel")
    tools:Dock(TOP)
    tools:DockMargin(0, 10, 0, 0)
    tools:SetTall(64)
    tools.Paint = nil
    local pick = UI.Button(tools, "Am Fadenkreuz platzieren", function()
        if not Sel() then return end
        pickMode = "pick"
        frame:SetVisible(false)
    end, function() return COL.accent end)
    pick:SetPos(0, 0) pick:SetSize(250, 28)
    local look = UI.Button(tools, "Umsehen", function()
        pickMode = "look"
        frame:SetVisible(false)
    end, function() return COL.dim end)
    look:SetPos(258, 0) look:SetSize(118, 28)

    -- Speichern / Verwerfen
    local save = UI.Button(frame, "Speichern", function()
        local data = util.Compress(util.TableToJSON(editing.areas) or "[]") or ""
        net.Start("PD.Naval.LayoutSave")
        net.WriteString(model)
        net.WriteUInt(#data, 32)
        net.WriteData(data, #data)
        net.SendToServer()
    end, function() return COL.ok end)
    save:SetPos(10, frame:GetTall() - 36) save:SetSize(196, 28)
    local revert = UI.Button(frame, "Verwerfen", function()
        editing.areas = table.Copy(Naval.Layouts[model] or {})
        editing.sel = 1
        Refresh()
    end, function() return COL.warn end)
    revert:SetPos(214, frame:GetTall() - 36) revert:SetSize(196, 28)

    -- Nicht wegen Entfernung schliessen, solange man sich umsieht
    local baseThink = frame.Think
    frame.Think = function(s)
        if pickMode then return end
        if baseThink then baseThink(s) end
    end

    Refresh()
end

Naval.StationUI = Naval.StationUI or {}
Naval.StationUI.demo_large = OpenEditor
Naval.StationUI.demo_medium = OpenEditor
