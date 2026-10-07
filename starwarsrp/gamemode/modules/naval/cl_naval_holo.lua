--[[
    Naval - Taktik-Hologramm (Client).

    Erscheint ueber dem Projektor (Station holo_projector), solange es per
    Schalter (holo_power) an ist. Zoom ueber die Schalter holo_zoom_in/out.
    Zustand: GetGlobalBool("PD.Naval.HoloOn"), GetGlobalInt("PD.Naval.HoloZoom").

    Ausgerichtet wie das Schiff: was im Hologramm vorn liegt, liegt auch vor
    dem Bug. Um das eigene Schiff die sechs Schildzonen (blau = voll,
    rot = schwach), das Ziel des Waffenleitstands mit rotem Ring, unbekannte
    Kontakte grau. Mitte = Map-Schiff, Ringe in der Schiffsebene, Kontakte in
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

local function DrawShipModel(key, path, pos, ang, length, col, alpha)
    local m = HoloModel(key, path)
    if not m then return end

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

local function DrawHolo()
    local view = C.View and C.View()
    local static = C.static
    if not view or not view.rot or not static then return end

    local settings = static.settings or {}
    local radius = settings.holo_radius or 60
    local center = projector:GetPos() + Vector(0, 0, settings.holo_height or 45)
    local range = Naval.HoloRanges[GetGlobalInt("PD.Naval.HoloZoom", Naval.HoloDefaultZoom)] or 50000
    local scale = radius / range

    -- Schiffe: echtes Verhaeltnis zueinander, aber mindestens so gross, dass
    -- eine Venator 15 % des Radius lang ist (sonst bei grossem Bereich unsichtbar)
    local shipScale = math.max(scale, radius * 0.15 / 1137)
    local flicker = 0.85 + math.sin(CurTime() * 23) * 0.04 + math.sin(CurTime() * 3.1) * 0.05

    local M, qbm = Naval.UniverseToMap(view.rot)
    local Q = Naval.Q

    local function ToHolo(rel)
        local r = Q.RotateVec(M, rel)
        return center + Vector(r.x, r.y, r.z) * scale
    end

    local holoCol = Color(COL_HOLO.r, COL_HOLO.g, COL_HOLO.b, 140 * flicker)

    -- Ringe und Lichtkegel
    render.SetColorMaterial()
    for i = 1, 4 do Ring(center, radius * i / 4, Color(holoCol.r, holoCol.g, holoCol.b, (i == 4 and 120 or 50) * flicker)) end
    render.DrawLine(center - Vector(0, 0, settings.holo_height or 45), center, Color(90, 190, 255, 40), true)
    render.SetMaterial(MAT_GLOW)
    render.DrawSprite(center - Vector(0, 0, (settings.holo_height or 45) - 2), radius * 0.6, radius * 0.6, Color(60, 150, 255, 60))

    if view.state == "hyperspace" then
        Label(center + Vector(0, 0, 10), "HYPERRAUM", holoCol, 0.08)
        return
    end

    local labels = {}
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

    if EyePos():DistToSqr(center) < 900 * 900 then
        for _, l in ipairs(labels) do Label(l.pos + Vector(0, 0, 1.5), l.text, l.col, 0.03) end
        Label(center + Vector(radius, 0, 0), FormatDist(range), holoCol, 0.035)
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
