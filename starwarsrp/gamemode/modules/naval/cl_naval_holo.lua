--[[
    Naval - Taktik-Hologramm (Client).

    Erscheint ueber dem Projektor (Station holo_projector), solange es per
    Schalter (holo_power) an ist. Zoom ueber die Schalter holo_zoom_in/out.
    Zustand: GetGlobalBool("PD.Naval.HoloOn"), GetGlobalInt("PD.Naval.HoloZoom").

    Ausgerichtet wie das Schiff: was im Hologramm vorn liegt, liegt auch vor
    dem Bug. Um das eigene Schiff die sechs Schildzonen (blau = voll,
    rot = schwach), das Ziel des Waffenleitstands mit rotem Ring, unbekannte
    Kontakte grau.

    Stufe 4d: Schalter holo_mode wechselt Taktik <-> Galaxie (Umkreis um das
    System aus "Im Hologramm zeigen" am Navigationscomputer, sonst um unsere
    Position; Routen, Gebiete, Frontlinien, umkaempfte Systeme, geplanter
    Sprungweg). Schalter holo_tilt stellt das Hologramm als Wand auf: um die
    Querachse des Projektors gekippt, Norden/Bug oben, Hoehen zum Betrachter. Mitte = Map-Schiff, Ringe in der Schiffsebene, Kontakte in
    Fraktions-/Beziehungsfarben mit Hoehenlinie, Himmelskoerper als
    Drahtkugeln; ausserhalb des Bereichs Richtungsmarken am Rand.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

local COL_HOLO = Color(90, 190, 255)
local REL_COLOR = {ally = Color(90, 170, 255), neutral = Color(235, 220, 120), hostile = Color(255, 80, 70), unknown = Color(190, 190, 200)}
local MAT_WHITE = Material("models/debug/debugwhite")
local MAT_WIRE = Material("models/wireframe")
local MAT_GLOW = Material("sprites/light_glow02_add")
local DRAW_DIST = 2500

local projector
local models = {}

timer.Create("PD.Naval.HoloFind", 1, 0, function()
    if IsValid(projector) and projector:GetStation() == "holo_projector" then return end
    projector = nil
    for _, ent in ipairs(ents.FindByClass("pd_naval_console")) do
        if ent:GetStation() == "holo_projector" then projector = ent break end
    end
end)

local function HoloModel(key, path)
    local m = models[key]
    if IsValid(m) and m:GetModel() == path then return m end
    if IsValid(m) then m:Remove() end

    m = ClientsideModel(path, RENDERGROUP_TRANSLUCENT)
    if not IsValid(m) then return nil end
    m:SetNoDraw(true)
    m.PD_Length = Naval.ModelLength(m)
    models[key] = m
    return m
end

-- Wand-Stellung (DrawHolo setzt es): Modelle uebernehmen die gekippte
-- Modellmatrix nicht, daher Lage und Ausrichtung hier selbst kippen und
-- ausserhalb der Matrix zeichnen
local tilt

local function DrawShipModel(key, path, pos, ang, length, col, alpha)
    local m = HoloModel(key, path)
    if not m then return end

    if tilt then
        pos = tilt.Tilt(pos)
        local am = Matrix()
        am:SetAngles(ang)
        ang = (tilt.B * am):GetAngles()
        cam.PopModelMatrix()
    end

    local f = length / m.PD_Length
    local mat = Matrix()
    mat:Scale(Vector(f, f, f))
    m:EnableMatrix("RenderMultiply", mat)
    m:SetPos(pos)
    m:SetAngles(ang)
    m:SetupBones()

    render.SetColorModulation(col.r / 255, col.g / 255, col.b / 255)
    render.SetBlend(alpha)
    m:DrawModel()

    if tilt then cam.PushModelMatrix(tilt.M, true) end
end

local function Label(pos, text, col, size)
    local ang = EyeAngles()
    ang:RotateAroundAxis(ang:Up(), -90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    cam.Start3D2D(pos, ang, size or 0.06)
        draw.SimpleTextOutlined(text, "MLIB_ENTS.40", 0, 0, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, 1, Color(0, 0, 0, 160))
    cam.End3D2D()
end

local function Ring(center, radius, col)
    local last
    for a = 0, 360, 8 do
        local p = center + Vector(math.cos(math.rad(a)) * radius, math.sin(math.rad(a)) * radius, 0)
        if last then render.DrawLine(last, p, col, true) end
        last = p
    end
end

local function FormatDist(m)
    return Naval.FormatDist and Naval.FormatDist(m) or (math.Round(m / 1000) .. " km")
end

local function DrawTactical(center, radius, labels, flicker)
    local view = C.View and C.View()
    local static = C.static
    if not view or not view.rot or not static then return end

    local range = Naval.HoloRanges[GetGlobalInt("PD.Naval.HoloZoom", Naval.HoloDefaultZoom)] or 50000
    local scale = radius / range

    -- Schiffe: echtes Verhaeltnis zueinander, aber mindestens so gross, dass
    -- eine Venator 15 % des Radius lang ist (sonst bei grossem Bereich unsichtbar)
    local shipScale = math.max(scale, radius * 0.15 / 1137)

    local M, qbm = Naval.UniverseToMap(view.rot)
    local Q = Naval.Q

    local function ToHolo(rel)
        local r = Q.RotateVec(M, rel)
        return center + Vector(r.x, r.y, r.z) * scale
    end

    local holoCol = Color(COL_HOLO.r, COL_HOLO.g, COL_HOLO.b, 140 * flicker)

    -- Ringe
    render.SetColorMaterial()
    for i = 1, 4 do Ring(center, radius * i / 4, Color(holoCol.r, holoCol.g, holoCol.b, (i == 4 and 120 or 50) * flicker)) end

    if view.state == "hyperspace" then
        labels[#labels + 1] = {pos = center + Vector(0, 0, 10), text = "HYPERRAUM", col = holoCol, size = 0.08}
        return
    end

    local myFaction = Naval.MapShipFaction and Naval.MapShipFaction()

    render.SuppressEngineLighting(true)
    render.MaterialOverride(MAT_WHITE)

    -- Map-Schiff in der Mitte (Mindestgroesse, damit erkennbar)
    local mapLen = 0
    for _, info in pairs(C.info or {}) do
        if info.mapShip then
            local class = static.classes[info.classId]
            if class and class.model then
                mapLen = class.lengthM * shipScale
                DrawShipModel("map", class.model, center, Q.ToAngle(qbm), mapLen,
                    Color(120, 255, 160), 0.55 * flicker)
            end
        end
    end

    local combat = C.status and C.status.combat
    local targetId = combat and combat.target and combat.target.id
    local targetMark

    -- Schiffe
    local seen = {map = true}
    for id, s in pairs(view.ships or {}) do
        local info = C.info[id]
        local class = info and static.classes[info.classId]
        local rel = Naval.V3.Sub(s.pos, view.pos)
        local dist = Naval.V3.Len(rel)

        if class and dist <= range * 1.02 then
            local relation = Naval.ClientRelation and Naval.ClientRelation(myFaction, info.factionId) or "neutral"
            local col = REL_COLOR[relation] or COL_HOLO
            local pos = ToHolo(rel)

            seen[id] = true
            DrawShipModel(id, class.model, pos, Q.ToAngle(Q.Mul(M, s.rot)), class.lengthM * shipScale, col, 0.6 * flicker)

            local text = info.name .. "  " .. FormatDist(dist)
            if (info.ident or 2) >= 1 and s.hull then text = text .. "  " .. s.hull .. " %" end
            local sc = C.status and C.status.sensors and C.status.sensors.contacts and C.status.sensors.contacts[tostring(id)]
            if sc and sc.surrendered then text = text .. "  [kapituliert]" end
            labels[#labels + 1] = {pos = pos, text = text, col = col, stem = true}
            if id == targetId then targetMark = {pos = pos, r = math.max(class.lengthM * shipScale * 0.7, 2.5)} end
        end
    end

    render.MaterialOverride()
    render.SetColorModulation(1, 1, 1)
    render.SetBlend(1)
    render.SuppressEngineLighting(false)

    for key, m in pairs(models) do
        if not seen[key] then
            if IsValid(m) then m:Remove() end
            models[key] = nil
        end
    end

    -- Himmelskoerper
    local system = C.system
    if system and system.systemId == view.systemId and system.bodiesById then
        local now = Naval.Now()
        render.SetMaterial(MAT_WIRE)

        for _, body in pairs(system.bodiesById) do
            local rel = Naval.V3.Sub(Naval.BodyPos(body, system.bodiesById, now), view.pos)
            local dist = Naval.V3.Len(rel)
            local col = body.type == "star" and Color(255, 220, 130, 150 * flicker) or Color(130, 210, 190, 130 * flicker)

            if dist - (body.radius or 0) <= range then
                local pos = ToHolo(rel)
                local r = math.Clamp((body.radius or 1000) * scale, 0.6, radius * 1.2)
                render.DrawWireframeSphere(pos, r, 14, 10, col, true)
                labels[#labels + 1] = {pos = pos + Vector(0, 0, r), text = body.name, col = col}
            elseif body.type == "star" or body.type == "planet" then
                -- Richtungsmarke am Rand
                local pos = ToHolo(Naval.V3.Scale(rel, range / dist))
                render.SetColorMaterial()
                render.DrawSphere(pos, 0.8, 8, 6, col)
                render.SetMaterial(MAT_WIRE)
                labels[#labels + 1] = {pos = pos, text = body.name .. "  " .. FormatDist(dist), col = col}
            end
        end
    end

    -- Kurs aus dem Navigationscomputer: laufender Autopilot gruen, nur
    -- geplanter Kurs gelb. Auf die Hologramm-Kugel zugeschnitten.
    local route, routeCol = {}, Color(90, 235, 140, 220 * flicker)
    local st = C.status or {}
    if st.auto then
        for _, p in ipairs(st.auto.path or {}) do route[#route + 1] = {x = p[1], y = p[2], z = p[3]} end
        for _, q in ipairs(st.auto.queue or {}) do route[#route + 1] = {x = q.p[1], y = q.p[2], z = q.p[3], mark = q.label} end
        if #route > 0 then route[1] = view.pos end
    elseif st.navPlan and istable(st.navPlan.legs) then
        routeCol = Color(240, 200, 70, 200 * flicker)
        route[1] = view.pos
        for _, leg in ipairs(st.navPlan.legs) do
            local p = leg.pos
            if leg.kind == "body" and system and system.bodiesById and system.bodiesById[leg.id] then
                p = Naval.BodyPos(system.bodiesById[leg.id], system.bodiesById, Naval.Now())
            elseif leg.kind == "ship" and view.ships[leg.id] then
                p = view.ships[leg.id].pos
            end
            if p then route[#route + 1] = {x = p.x, y = p.y, z = p.z or view.pos.z, mark = leg.name} end
        end
    end

    if #route > 1 then
        render.SetColorMaterial()
        local function Clip(a, b)
            -- Strecke a->b (relativ zum Schiff) auf die Kugel mit Radius range
            local d = Naval.V3.Sub(b, a)
            local A = Naval.V3.Dot(d, d)
            if A < 1 then return nil end
            local B = 2 * Naval.V3.Dot(a, d)
            local Cc = Naval.V3.Dot(a, a) - range * range
            local disc = B * B - 4 * A * Cc
            if disc <= 0 then return nil end
            local sq = math.sqrt(disc)
            local t0, t1 = math.max(0, (-B - sq) / (2 * A)), math.min(1, (-B + sq) / (2 * A))
            if t0 >= t1 then return nil end
            return Naval.V3.Add(a, Naval.V3.Scale(d, t0)), Naval.V3.Add(a, Naval.V3.Scale(d, t1)), t1 >= 1
        end

        for i = 2, #route do
            local a, b, endInside = Clip(Naval.V3.Sub(route[i - 1], view.pos), Naval.V3.Sub(route[i], view.pos))
            if a then
                local ha, hb = ToHolo(a), ToHolo(b)
                render.DrawLine(ha, hb, routeCol, true)
                render.DrawLine(ha + Vector(0, 0, 0.15), hb + Vector(0, 0, 0.15), routeCol, true)
                if endInside and route[i].mark then
                    render.DrawSphere(hb, 0.5, 8, 6, routeCol)
                    labels[#labels + 1] = {pos = hb, text = route[i].mark, col = routeCol}
                end
            end
        end
    end

    -- Schildzonen um das eigene Schiff
    if combat and combat.zones and mapLen > 0 then
        render.SetMaterial(MAT_GLOW)
        local axes = {front = {1, 0, 0}, back = {-1, 0, 0}, left = {0, 1, 0}, right = {0, -1, 0}, top = {0, 0, 1}, bottom = {0, 0, -1}}
        for zone, a in pairs(axes) do
            local z = combat.zones[zone]
            if z then
                local frac = (z.e + z.m) / math.max(z.ce + z.cm, 1)
                local d = Q.RotateVec(qbm, {x = a[1], y = a[2], z = a[3]})
                local reach = (zone == "front" or zone == "back") and mapLen * 0.62 or mapLen * 0.32
                local p = center + Vector(d.x, d.y, d.z) * reach
                local col = combat.up and Color(255 - frac * 175, 80 + frac * 110, 80 + frac * 175, 200 * flicker) or Color(255, 60, 50, 90 * flicker)
                local size = math.max(mapLen * 0.25, 3) * (0.5 + frac * 0.7)
                render.DrawSprite(p, size, size, col)
            end
        end
    end

    -- Ziel: drehender roter Ring
    if targetMark then
        render.SetColorMaterial()
        local spin = CurTime() * 90
        local last
        for a = 0, 360, 15 do
            local ang = math.rad(a + spin)
            local p = targetMark.pos + Vector(math.cos(ang) * targetMark.r, math.sin(ang) * targetMark.r, 0)
            if last and a % 30 ~= 0 then render.DrawLine(last, p, Color(255, 60, 50, 230 * flicker), true) end
            last = p
        end
        labels[#labels + 1] = {pos = targetMark.pos + Vector(0, 0, targetMark.r), text = "ZIEL", col = Color(255, 70, 60)}
    end

    -- Hoehenlinien und Beschriftungen
    render.SetColorMaterial()
    for _, l in ipairs(labels) do
        if l.stem then
            local base = Vector(l.pos.x, l.pos.y, center.z)
            render.DrawLine(l.pos, base, Color(l.col.r, l.col.g, l.col.b, 70), true)
        end
    end

    labels[#labels + 1] = {pos = center + Vector(radius, 0, 0), text = FormatDist(range), col = holoCol, size = 0.035}
end

--------------------------------------------------------------------------------
-- Galaxie-Ansicht (Stufe 4d)
--------------------------------------------------------------------------------

local gridCache = {}

local function DrawGalaxy(center, radius, labels, flicker, F, R)
    local static = C.static
    if not static or not static.systemsById then return end

    local focusId = GetGlobalString("PD.Naval.HoloFocus", "")
    local here = C.status and C.status.system
    local fsys = static.systemsById[focusId ~= "" and focusId or (here or "")]
    if not fsys then return end

    local rangePc = Naval.HoloGalaxyRanges[GetGlobalInt("PD.Naval.HoloGalaxyZoom", Naval.HoloGalaxyDefaultZoom)] or 800
    local s = radius / rangePc
    local fx, fy = fsys.g.x, fsys.g.y
    local function G(x, y, lift) return center + R * ((x - fx) * s) + F * ((y - fy) * s) + Vector(0, 0, lift or 0) end
    local function Inside(x, y, k) return (x - fx) ^ 2 + (y - fy) ^ 2 <= (rangePc * (k or 1)) ^ 2 end

    local holoCol = Color(COL_HOLO.r, COL_HOLO.g, COL_HOLO.b, 140 * flicker)
    render.SetColorMaterial()
    local last
    for a = 0, 360, 6 do
        local p = center + (R * math.cos(math.rad(a)) + F * math.sin(math.rad(a))) * radius
        if last then render.DrawLine(last, p, Color(holoCol.r, holoCol.g, holoCol.b, 120 * flicker), true) end
        last = p
    end

    -- Gebiete und Frontlinien (Raster fuer diesen Ausschnitt, zwischengespeichert)
    if gridCache.static ~= static then gridCache = {static = static} end
    local key = (focusId ~= "" and focusId or here or "") .. ":" .. rangePc
    if gridCache[key] == nil then
        gridCache[key] = Naval.InfluenceGrid and Naval.InfluenceGrid(fx - rangePc, fy - rangePc, fx + rangePc, fy + rangePc, rangePc / 18) or false
    end
    local grid = gridCache[key]
    if grid then
        for _, st in ipairs(grid.strips) do
            local cx, cy = st.x + st.w / 2, st.y + grid.cell / 2
            if Inside(cx, cy) then
                local col = Naval.TerritoryColor(st.f, 40 * flicker)
                render.DrawQuad(G(st.x, st.y), G(st.x + st.w, st.y), G(st.x + st.w, st.y + grid.cell), G(st.x, st.y + grid.cell), col)
            end
        end
        for _, fr in ipairs(grid.fronts) do
            if Inside(fr[1], fr[2]) and Inside(fr[3], fr[4]) then
                render.DrawLine(G(fr[1], fr[2], 0.1), G(fr[3], fr[4], 0.1), fr[5] and Color(255, 90, 70, 230 * flicker) or Color(200, 220, 255, 60 * flicker), true)
            end
        end
    end

    -- Hyperraumrouten
    for _, route in pairs(static.routes or {}) do
        local col = route.major and Color(110, 160, 240, 170 * flicker) or Color(80, 110, 160, 90 * flicker)
        for _, line in ipairs(route.lines or {}) do
            for i = 2, #line do
                local a, b = line[i - 1], line[i]
                if Inside(a[1], a[2], 1.02) and Inside(b[1], b[2], 1.02) then
                    render.DrawLine(G(a[1], a[2], 0.05), G(b[1], b[2], 0.05), col, true)
                end
            end
        end
    end

    -- Systeme an Routen oder mit Gebiet (hoechstens 400)
    local territory = Naval.TerritoryData and Naval.TerritoryData()
    render.SetMaterial(MAT_GLOW)
    local count = 0
    for _, sys in ipairs(static.systemList or {}) do
        if count >= 400 then break end
        local owner = territory and territory.byId[sys.id]
        if (owner or (sys.routes and #sys.routes > 0)) and Inside(sys.g.x, sys.g.y) then
            count = count + 1
            local col = owner and Naval.TerritoryColor(owner, 220 * flicker) or Color(200, 215, 240, 160 * flicker)
            render.DrawSprite(G(sys.g.x, sys.g.y, 0.2), radius * 0.03, radius * 0.03, col)
        end
    end

    -- Umkaempfte Systeme
    if territory then
        render.SetColorMaterial()
        local pulse = 0.5 + math.sin(CurTime() * 4) * 0.5
        for id in pairs(territory.contested) do
            local sys = static.systemsById[id]
            if sys and Inside(sys.g.x, sys.g.y) then
                local p = G(sys.g.x, sys.g.y, 0.3)
                local lastP
                for a = 0, 360, 30 do
                    local q = p + (R * math.cos(math.rad(a)) + F * math.sin(math.rad(a))) * radius * 0.04
                    if lastP then render.DrawLine(lastP, q, Color(255, 60, 50, (120 + pulse * 135) * flicker), true) end
                    lastP = q
                end
                labels[#labels + 1] = {pos = p, text = sys.name .. " (umkämpft)", col = Color(255, 90, 70)}
            end
        end
    end

    -- Geplanter Sprungweg
    local st = C.status or {}
    local path = C.path and st.pathKey == C.path.key and C.path.points
    if path and #path > 1 then
        render.SetColorMaterial()
        for i = 2, #path do
            local a, b = path[i - 1], path[i]
            render.DrawLine(G(a[1], a[2], 0.4), G(b[1], b[2], 0.4), a[4] and Color(120, 220, 255, 230) or Color(240, 200, 70, 230), true)
        end
    end

    -- Unsere Position, Mittelpunkt, Sprungziel
    local cur = here and static.systemsById[here]
    if cur and Inside(cur.g.x, cur.g.y, 1.05) then
        local size = radius * (0.06 + math.sin(CurTime() * 5) * 0.015)
        render.SetMaterial(MAT_GLOW)
        render.DrawSprite(G(cur.g.x, cur.g.y, 0.5), size, size, Color(120, 255, 160, 255))
        labels[#labels + 1] = {pos = G(cur.g.x, cur.g.y, 1), text = "Hier: " .. cur.name, col = Color(120, 255, 160)}
    end
    if fsys ~= cur then labels[#labels + 1] = {pos = G(fx, fy, 1), text = fsys.name, col = holoCol} end
    local nav = st.nav and static.systemsById[st.nav.target or ""]
    if nav and Inside(nav.g.x, nav.g.y) then labels[#labels + 1] = {pos = G(nav.g.x, nav.g.y, 1), text = "Ziel: " .. nav.name, col = Color(240, 200, 70)} end

    labels[#labels + 1] = {pos = center + R * radius, text = ("%s pc"):format(rangePc), col = holoCol, size = 0.035}
end

--------------------------------------------------------------------------------
-- Hologramm: Lichtkegel, Inhalt (ggf. als Wand gekippt), Beschriftungen
--------------------------------------------------------------------------------

local function DrawHolo()
    local static = C.static
    if not static then return end

    local settings = static.settings or {}
    local radius = settings.holo_radius or 60
    local height = settings.holo_height or 45
    local base = projector:GetPos()
    local wall = GetGlobalBool("PD.Naval.HoloWall", false)
    local galaxy = GetGlobalInt("PD.Naval.HoloMode", 0) == 1
    local flicker = 0.85 + math.sin(CurTime() * 23) * 0.04 + math.sin(CurTime() * 3.1) * 0.05

    -- Als Wand steht die Karte hoeher (Unterkante etwa auf Hoehe der liegenden)
    local center = base + Vector(0, 0, height + (wall and radius or 0))

    -- Achsen des Projektors (waagerecht)
    local F = projector:GetForward()
    F.z = 0
    if F:LengthSqr() < 1e-4 then F = Vector(1, 0, 0) end
    F:Normalize()
    local U = Vector(0, 0, 1)
    local R = F:Cross(U)

    -- Lichtkegel (nicht gekippt)
    render.SetColorMaterial()
    render.DrawLine(base, center, Color(90, 190, 255, 40), true)
    render.SetMaterial(MAT_GLOW)
    render.DrawSprite(base + Vector(0, 0, 2), radius * 0.6, radius * 0.6, Color(60, 150, 255, 60))

    -- Wand: v' = R(v.R) + U(v.F) - F(v.U) um den Mittelpunkt (Norden/Bug nach
    -- oben, Hoehen zum Betrachter auf der Vorderseite)
    local function Tilt(p)
        if not wall then return p end
        local v = p - center
        return center + R * v:Dot(R) + U * v:Dot(F) - F * v:Dot(U)
    end

    if wall then
        local B = Matrix({
            {R.x * R.x + U.x * F.x - F.x * U.x, R.x * R.y + U.x * F.y - F.x * U.y, R.x * R.z + U.x * F.z - F.x * U.z, 0},
            {R.y * R.x + U.y * F.x - F.y * U.x, R.y * R.y + U.y * F.y - F.y * U.y, R.y * R.z + U.y * F.z - F.y * U.z, 0},
            {R.z * R.x + U.z * F.x - F.z * U.x, R.z * R.y + U.z * F.y - F.z * U.y, R.z * R.z + U.z * F.z - F.z * U.z, 0},
            {0, 0, 0, 1},
        })
        local M = Matrix()
        M:Translate(center)
        M = M * B
        M:Translate(-center)
        cam.PushModelMatrix(M, true)
        tilt = {M = M, B = B, Tilt = Tilt}
    end

    local labels = {}
    local ok, err = pcall(function()
        if galaxy then DrawGalaxy(center, radius, labels, flicker, F, R)
        else DrawTactical(center, radius, labels, flicker) end
    end)

    if wall then cam.PopModelMatrix() end
    tilt = nil
    if not ok then error(err, 0) end

    if EyePos():DistToSqr(center) < 900 * 900 then
        for _, l in ipairs(labels) do Label(Tilt(l.pos) + Vector(0, 0, 1.5), l.text, l.col, l.size or 0.03) end
    end
end

hook.Add("PostDrawTranslucentRenderables", "PD.Naval.Holo", function(depth, sky)
    if sky or depth then return end
    if not GetGlobalBool("PD.Naval.HoloOn", false) or not IsValid(projector) then return end
    if not Naval.IsNavalMap() or EyePos():DistToSqr(projector:GetPos()) > DRAW_DIST * DRAW_DIST then return end

    local ok, err = pcall(DrawHolo)
    if not ok then
        render.MaterialOverride()
        render.SetColorModulation(1, 1, 1)
        render.SetBlend(1)
        render.SuppressEngineLighting(false)
        if (Naval.HoloErrorNext or 0) < CurTime() then
            Naval.HoloErrorNext = CurTime() + 10
            ErrorNoHalt("[Naval] Hologramm: " .. tostring(err) .. "\n")
        end
    end
end)

-- Beim Lua-Refresh keine Modelle liegen lassen
for _, m in pairs(Naval.OldHoloModels or {}) do
    if IsValid(m) then m:Remove() end
end
Naval.OldHoloModels = models
