--[[
    Naval - Taktik-Ansicht (Client).

    3D-Lage um das Map-Schiff, orthografisch: Ziehen dreht die Ansicht,
    Mausrad zoomt (1 km ... Sensorreichweite). Farben nach Beziehung
    (Freund/Neutral/Feind). Der Baustein PD_NavalTactical wird auch vom
    Admin-Werkzeug benutzt.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

local function V3Add(a, b) return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z} end

local REL_COLOR = {
    ally = Color(90, 170, 255),
    neutral = Color(230, 220, 120),
    hostile = Color(240, 80, 70),
}

function Naval.MapShipFaction()
    for _, info in pairs(C.info or {}) do
        if info.mapShip then return info.factionId end
    end
end

function Naval.ClientRelation(a, b)
    if not a or not b then return "neutral" end
    if a == b then return "ally" end
    local rel = C.static and C.static.relations and C.static.relations[a]
    return rel and rel[b] or "neutral"
end

local function FormatDist(m)
    if m >= 1e9 then return ("%.2f Mio km"):format(m / 1e9) end
    if m >= 1e4 then return ("%.0f km"):format(m / 1000) end
    return ("%.1f km"):format(m / 1000)
end
Naval.FormatDist = FormatDist

local PANEL = {}

function PANEL:Init()
    self.Yaw = 30
    self.Pitch = 35
    self.Range = 50000     -- Meter vom Mittelpunkt bis zum Rand
    self.Contacts = {}
    self.Selected = nil
end

-- System-Meter (relativ zum Mittelpunkt) -> Bildschirm
function PANEL:Project(rel)
    local yaw, pitch = math.rad(self.Yaw), math.rad(self.Pitch)
    local cy, sy, cp, sp = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch)

    -- um z drehen, dann kippen
    local x = rel.x * cy - rel.y * sy
    local y = rel.x * sy + rel.y * cy
    local z = rel.z

    local sx = x
    local sy2 = y * sp - z * cp
    local depth = y * cp + z * sp

    local w, h = self:GetWide(), self:GetTall()
    local scale = math.min(w, h) / 2 / self.Range
    return w / 2 + sx * scale, h / 2 + sy2 * scale, depth
end

-- Bildschirm -> Punkt in der Ebene z = 0 (relativ zum Mittelpunkt) oder nil
function PANEL:ScreenToPlane(sx, sy)
    local yaw, pitch = math.rad(self.Yaw), math.rad(self.Pitch)
    local sp = math.sin(pitch)
    if math.abs(sp) < 0.2 then return nil end

    local w, h = self:GetWide(), self:GetTall()
    local scale = math.min(w, h) / 2 / self.Range
    local x = (sx - w / 2) / scale
    local y = (sy - h / 2) / scale / sp
    local cy, syaw = math.cos(yaw), math.sin(yaw)

    return {x = x * cy + y * syaw, y = -x * syaw + y * cy, z = 0}
end

-- Schiffe fuer die Anzeige: Sensorkontakte, im Admin-Modus alle im System
function PANEL:CollectShips(view)
    local out = {}

    for id, s in pairs(view.ships or {}) do
        out[id] = {pos = s.pos, state = s.state, info = C.info[id]}
    end

    local admin = self.AdminMode and C.admin
    if admin and admin.systemId == view.systemId then
        for _, row in ipairs(admin.ships or {}) do
            if row.rel and not row.map and not out[row.id] then
                out[row.id] = {pos = V3Add(view.pos, row.rel), state = row.state, info = row}
            elseif out[row.id] and not out[row.id].info then
                out[row.id].info = row
            end
        end
    end

    return out
end

function PANEL:Paint(w, h)
    local COL = Naval.UI.COL
    draw.RoundedBox(0, 0, 0, w, h, Color(5, 9, 14))

    local view = C.View and C.View()
    if not view or not view.pos then
        draw.SimpleText("Keine Sensordaten", "MLIB.18", w / 2, h / 2, COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        return
    end

    local px, py = self:LocalToScreen(0, 0)
    render.SetScissorRect(px, py, px + w, py + h, true)

    local origin = view.pos
    local function Rel(p) return {x = p.x - origin.x, y = p.y - origin.y, z = p.z - origin.z} end

    -- Distanzringe in der Ebene
    for i = 1, 4 do
        local r = self.Range * i / 4
        local last
        surface.SetDrawColor(30, 60, 90, 160)
        for a = 0, 360, 10 do
            local x, y = self:Project({x = math.cos(math.rad(a)) * r, y = math.sin(math.rad(a)) * r, z = 0})
            if last then surface.DrawLine(last[1], last[2], x, y) end
            last = {x, y}
        end
        local lx, ly = self:Project({x = r, y = 0, z = 0})
        draw.SimpleText(FormatDist(r), "MLIB.12", lx + 3, ly, Color(60, 100, 140))
    end

    local myFaction = Naval.MapShipFaction()
    local contacts = {}

    -- Himmelskoerper
    local system = C.system
    if system and system.bodiesById then
        local now = Naval.Now()
        for _, body in pairs(system.bodiesById) do
            local pos = Naval.BodyPos(body, system.bodiesById, now)
            local rel = Rel(pos)
            local x, y = self:Project(rel)
            local dist = math.sqrt(rel.x ^ 2 + rel.y ^ 2 + rel.z ^ 2)
            local scale = math.min(w, h) / 2 / self.Range
            local r = math.Clamp((body.radius or 1000) * scale, 3, 400)

            if x + r > 0 and x - r < w and y + r > 0 and y - r < h then
                surface.SetDrawColor(body.type == "star" and Color(255, 220, 120, 200) or Color(120, 160, 140, 160))
                surface.DrawCircle(x, y, r, body.type == "star" and Color(255, 220, 120) or Color(120, 170, 150))
                draw.SimpleText(body.name, "MLIB.14", x + r + 4, y - 7, Color(150, 180, 160))
            end

            contacts[#contacts + 1] = {kind = "body", name = body.name, dist = dist, col = Color(150, 180, 160)}
        end
    end

    -- Schiffe (hinten zuerst)
    local list = {}
    for id, s in pairs(self:CollectShips(view)) do
        local info = s.info
        local rel = Rel(s.pos)
        local x, y, depth = self:Project(rel)
        local relation = info and info.mapShip and "ally" or Naval.ClientRelation(myFaction, info and info.factionId)
        list[#list + 1] = {id = id, x = x, y = y, depth = depth, info = info, rel = rel, state = s.state, relation = relation}
    end
    table.sort(list, function(a, b) return a.depth < b.depth end)

    local mx, my = self:CursorPos()
    self.Hover = nil

    for _, s in ipairs(list) do
        local col = REL_COLOR[s.relation] or COL.text
        local dist = math.sqrt(s.rel.x ^ 2 + s.rel.y ^ 2 + s.rel.z ^ 2)

        -- Hoehenlinie zur Ebene
        local bx, by = self:Project({x = s.rel.x, y = s.rel.y, z = 0})
        surface.SetDrawColor(col.r, col.g, col.b, 60)
        surface.DrawLine(s.x, s.y, bx, by)

        local size = (self.Selected == s.id) and 7 or 5
        draw.RoundedBox(0, s.x - size / 2, s.y - size / 2, size, size, col)
        if self.Selected == s.id then
            surface.SetDrawColor(COL.text)
            surface.DrawOutlinedRect(s.x - 9, s.y - 9, 19, 19, 1)
        end

        local name = s.info and s.info.name or ("#" .. s.id)
        if s.state and s.state ~= "normal" then name = name .. " [" .. s.state .. "]" end
        draw.SimpleText(name, "MLIB.14", s.x + 8, s.y - 8, col)

        if (mx - s.x) ^ 2 + (my - s.y) ^ 2 < 100 then self.Hover = s.id end

        contacts[#contacts + 1] = {kind = "ship", id = s.id, name = name, dist = dist, col = col,
            classId = s.info and s.info.classId, factionId = s.info and s.info.factionId}
    end

    -- Eigenes Schiff in der Mitte mit Bugrichtung
    local fwd = Naval.Q.Forward(view.rot)
    local cx, cy = self:Project({x = 0, y = 0, z = 0})
    local fx, fy = self:Project({x = fwd.x * self.Range * 0.12, y = fwd.y * self.Range * 0.12, z = fwd.z * self.Range * 0.12})
    surface.SetDrawColor(COL.ok)
    surface.DrawLine(cx, cy, fx, fy)
    draw.RoundedBox(0, cx - 4, cy - 4, 9, 9, COL.ok)

    if view.vel then
        local vx, vy = self:Project({x = view.vel.x * 30, y = view.vel.y * 30, z = view.vel.z * 30})
        surface.SetDrawColor(COL.warn)
        surface.DrawLine(cx, cy, vx, vy)
    end

    -- Zusatzmarken (Admin: Patrouillenpunkte, Platzierung)
    for i, m in ipairs(self.Marks or {}) do
        local mx2, my2 = self:Project(m)
        surface.SetDrawColor(COL.warn)
        surface.DrawOutlinedRect(mx2 - 5, my2 - 5, 11, 11, 1)
        draw.SimpleText(tostring(i), "MLIB.12", mx2 + 7, my2 - 6, COL.warn)
    end

    if self.PickHint then
        draw.SimpleText(self.PickHint, "MLIB.16", w / 2, 10, COL.warn, TEXT_ALIGN_CENTER)
    end

    render.SetScissorRect(0, 0, 0, 0, false)

    table.sort(contacts, function(a, b) return a.dist < b.dist end)
    self.Contacts = contacts

    draw.SimpleText("Bereich " .. FormatDist(self.Range) .. "   grün: Bug   gelb: Bewegung (30 s)", "MLIB.14", 8, h - 22, COL.dim)
end

function PANEL:OnMousePressed(code)
    if code == MOUSE_RIGHT and self.OnRightClick then self:OnRightClick() return end
    if code ~= MOUSE_LEFT then return end
    self.DragStart = {self:CursorPos()}
    self.DragAngles = {self.Yaw, self.Pitch}
    self.Moved = false
    self:MouseCapture(true)
end

function PANEL:OnMouseReleased(code)
    if code ~= MOUSE_LEFT then return end
    self:MouseCapture(false)
    self.DragStart = nil

    if not self.Moved then
        if self.OnPick then
            local mx, my = self:CursorPos()
            local p = self:ScreenToPlane(mx, my)
            if p then self:OnPick(p) end
            return
        end

        self.Selected = self.Hover
        if self.OnSelect then self:OnSelect(self.Hover) end
    end
end

function PANEL:Think()
    if not self.DragStart then return end
    local mx, my = self:CursorPos()
    local dx, dy = mx - self.DragStart[1], my - self.DragStart[2]
    if math.abs(dx) + math.abs(dy) > 4 then self.Moved = true end
    self.Yaw = self.DragAngles[1] - dx * 0.4
    self.Pitch = math.Clamp(self.DragAngles[2] + dy * 0.4, -89, 89)
end

function PANEL:OnMouseWheeled(delta)
    local maxRange = (C.static and C.static.settings and C.static.settings.near_ship_range or 50000) * 20
    self.Range = math.Clamp(self.Range * (delta > 0 and 0.8 or 1.25), 1000, math.max(maxRange, 1e6))
    return true
end

vgui.Register("PD_NavalTactical", PANEL, "DPanel")
