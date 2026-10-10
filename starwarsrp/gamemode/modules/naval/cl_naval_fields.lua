--[[
    Naval - Asteroidenfelder und Nebel (Client, Stufe 4e): Darstellung im
    Skybox-Pass. Nahe Felsbrocken als Modelle (gleicher Startwert je Zelle,
    bei allen Spielern gleich), ferne Felder als Staubpunkte, Nebel als
    farbige Wolken; im Nebel ein farbiger Schleier.
    Daten: C.system.fields (sv_naval_fields.lua).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C
local V3 = Naval.V3

local MAT_DUST = Material("sprites/light_glow02_add")
local MAT_CLOUD = Material("particle/particle_smokegrenade")

local ROCK_MODELS = {
    "models/props_wasteland/rockgranite02a.mdl",
    "models/props_wasteland/rockgranite03b.mdl",
    "models/props_wasteland/rockcliff01b.mdl",
}

local CELL = 3000      -- m: Zellgroesse fuer nahe Felsbrocken
local NEAR = 12000     -- m: bis hier Modelle
local MAX_ROCKS = 110

local rockEnts = {}
local farPoints = {}   -- Feld-id -> vorberechnete Punkte

local function Fields()
    local sys = C.system
    return sys and sys.fields or {}
end

-- Ganzzahl-Hash einer Zelle -> Zufallsgenerator
local function CellRng(cx, cy, cz, salt)
    local h = bit.bxor(cx * 73856093, cy * 19349663, cz * 83492791, salt)
    local s = math.abs(h) % 2147483646 + 1
    return function()
        s = (s * 16807) % 2147483647
        return s / 2147483647
    end
end

local function RockEnt(i)
    local e = rockEnts[i]
    if IsValid(e) then return e end
    e = ClientsideModel(ROCK_MODELS[i], RENDERGROUP_OPAQUE)
    if not IsValid(e) then return nil end
    e:SetNoDraw(true)
    rockEnts[i] = e
    return e
end

local mtx = Matrix()

-- Felsbrocken einer Zelle (nur die Daten; gleicher Startwert je Zelle)
local function CellRocks(ix, iy, iz, center, f, out)
    local rnd = CellRng(ix, iy, iz, 1013)
    local count = math.floor(rnd() * 2.4 * (f.density or 1))
    for _ = 1, count do
        if #out >= MAX_ROCKS then return end
        out[#out + 1] = {
            p = {x = center.x + (rnd() - 0.5) * CELL, y = center.y + (rnd() - 0.5) * CELL, z = center.z + (rnd() - 0.5) * CELL},
            size = 30 + rnd() ^ 3 * 650, model = math.floor(rnd() * #ROCK_MODELS) + 1,
            spin = (rnd() - 0.5) * 12, a = {rnd() * 360, rnd() * 360, rnd() * 360},
        }
    end
end

-- Liste der nahen Felsbrocken; nur neu, wenn man die Zelle wechselt
local rockCache = {key = nil, list = {}}

-- Nahe Felsbrocken (im beleuchteten Teil des Renderpasses)
function Naval.DrawFieldRocks(view, toRender, scale)
    local fields = Fields()
    if #fields == 0 then return end

    local near = {}
    for _, f in ipairs(fields) do
        if Naval.IsAsteroidField(f) and Naval.FieldDepth(f, view.pos) < NEAR then near[#near + 1] = f end
    end
    if #near == 0 then return end

    local p = view.pos
    local x0, y0, z0 = math.floor((p.x - NEAR) / CELL), math.floor((p.y - NEAR) / CELL), math.floor(((p.z or 0) - NEAR) / CELL)
    local key = x0 .. ":" .. y0 .. ":" .. z0 .. ":" .. tostring(C.system)
    if rockCache.key ~= key then
        rockCache.key = key
        local list = {}
        local n = math.ceil(NEAR * 2 / CELL)
        for ix = x0, x0 + n do
            for iy = y0, y0 + n do
                for iz = z0, z0 + n do
                    local center = {x = (ix + 0.5) * CELL, y = (iy + 0.5) * CELL, z = (iz + 0.5) * CELL}
                    local f = V3.Dist(center, p) <= NEAR + CELL and Naval.FieldAt(near, center) or nil
                    if f then CellRocks(ix, iy, iz, center, f, list) end
                end
            end
        end
        rockCache.list = list
    end

    local now = CurTime()
    render.SetColorModulation(0.62, 0.58, 0.54)
    for _, r in ipairs(rockCache.list) do
        local ent = RockEnt(r.model)
        local pos = ent and toRender(r.p)
        if pos then
            local k = r.size / scale / math.max(ent:GetModelRadius(), 1)
            mtx:SetScale(Vector(k, k, k))
            ent:EnableMatrix("RenderMultiply", mtx)
            ent:SetRenderOrigin(pos)
            ent:SetRenderAngles(Angle(r.a[1], r.a[2] + now * r.spin, r.a[3]))
            ent:SetupBones()
            ent:DrawModel()
        end
    end
    render.SetColorModulation(1, 1, 1)
end

-- Vorberechnete Punkte fuer die Fernansicht eines Feldes
local function FarPoints(f)
    local key = (C.system and C.system.systemId or "") .. ":" .. tostring(f.id)
    if farPoints[key] then return farPoints[key] end

    local rnd = CellRng(#key, string.byte(key, -1) or 0, f.radius and math.floor(f.radius) or 0, 77)
    local pts = {}
    local c = f.pos or {x = 0, y = 0, z = 0}
    if f.kind == "belt" then
        for _ = 1, 500 do
            local a = rnd() * math.pi * 2
            local r = f.radius + (rnd() - 0.5) * f.width
            pts[#pts + 1] = {p = {x = c.x + math.cos(a) * r, y = c.y + math.sin(a) * r, z = (c.z or 0) + (rnd() - 0.5) * f.thickness}, s = 0.6 + rnd()}
        end
    else
        local count = f.kind == "nebula" and 36 or 160
        for _ = 1, count do
            local u, v, w = rnd() * 2 - 1, rnd() * math.pi * 2, rnd() ^ (1 / 3)
            local s = math.sqrt(1 - u * u)
            local r = f.radius * (f.kind == "nebula" and w * 0.75 or w)
            pts[#pts + 1] = {p = {x = c.x + s * math.cos(v) * r, y = c.y + s * math.sin(v) * r, z = (c.z or 0) + u * r}, s = 0.6 + rnd() * 0.8, rot = rnd() * 360}
        end
    end
    farPoints[key] = pts
    return pts
end

-- Staub: ein Mesh mit Quadraten auf der Fernkugel in Universumsrichtung.
-- Neu gebaut, wenn sich das Schiff 5 km bewegt hat oder das System wechselt;
-- gezeichnet mit der Drehung Universum -> Map (wie der Sternenhimmel).
local MAT_DUST_MESH = CreateMaterial("PD_NavalDust", "UnlitGeneric", {
    ["$basetexture"] = "sprites/light_glow02", ["$additive"] = "1", ["$vertexcolor"] = "1", ["$vertexalpha"] = "1", ["$nocull"] = "1",
})
local dust = {mesh = nil, pos = nil, key = nil}
local dustMatrix = Matrix()

local function BuildDust(view, fields, far)
    if dust.mesh then dust.mesh:Destroy() dust.mesh = nil end
    local quads = {}
    for _, f in ipairs(fields) do
        if f.kind ~= "nebula" then
            for _, pt in ipairs(FarPoints(f)) do
                local d = Vector(pt.p.x - view.pos.x, pt.p.y - view.pos.y, (pt.p.z or 0) - (view.pos.z or 0))
                if d:LengthSqr() > 1 then
                    d:Normalize()
                    quads[#quads + 1] = {d, far * 0.002 * pt.s}
                end
            end
        end
    end
    if #quads == 0 then return end
    local m = Mesh()
    mesh.Begin(m, MATERIAL_QUADS, #quads)
    for _, q in ipairs(quads) do
        local dir, size = q[1], q[2]
        local up = math.abs(dir.z) < 0.99 and Vector(0, 0, 1) or Vector(1, 0, 0)
        local u = dir:Cross(up) u:Normalize()
        local v = dir:Cross(u) v:Normalize()
        local c = dir * far
        u, v = u * size, v * size
        mesh.Position(c - u - v) mesh.TexCoord(0, 0, 0) mesh.Color(170, 150, 125, 90) mesh.AdvanceVertex()
        mesh.Position(c + u - v) mesh.TexCoord(0, 1, 0) mesh.Color(170, 150, 125, 90) mesh.AdvanceVertex()
        mesh.Position(c + u + v) mesh.TexCoord(0, 1, 1) mesh.Color(170, 150, 125, 90) mesh.AdvanceVertex()
        mesh.Position(c - u + v) mesh.TexCoord(0, 0, 1) mesh.Color(170, 150, 125, 90) mesh.AdvanceVertex()
    end
    mesh.End()
    dust.mesh = m
end

-- Staub, Nebelwolken und Schleier (nach den Kampfeffekten)
function Naval.DrawFieldClouds(view, toRender, M, camOffset)
    local fields = Fields()
    if #fields == 0 then return end

    -- Staub der Asteroidenfelder
    if M then
        local far = (C.static and C.static.settings and C.static.settings.render_far) or 40000
        local key = tostring(C.system)
        if dust.key ~= key or not dust.pos or V3.Dist(dust.pos, view.pos) > 5000 then
            dust.key, dust.pos = key, V3.Copy(view.pos)
            BuildDust(view, fields, far)
        end
        if dust.mesh then
            dustMatrix:SetAngles(Naval.Q.ToAngle(M))
            dustMatrix:SetTranslation(-(camOffset or Vector(0, 0, 0)))
            render.SetMaterial(MAT_DUST_MESH)
            cam.PushModelMatrix(dustMatrix)
                dust.mesh:Draw()
            cam.PopModelMatrix()
        end
    end

    for _, f in ipairs(fields) do
        local pts = FarPoints(f)
        if f.kind == "nebula" then
            local col = f.color or {150, 90, 255}
            render.SetMaterial(MAT_CLOUD)
            local puff = f.radius * 0.55
            for _, pt in ipairs(pts) do
                local pos = toRender(pt.p)
                if pos then
                    local dist = V3.Dist(pt.p, view.pos)
                    local size = pos:Length() * puff * pt.s / math.max(dist, puff * 0.5)
                    render.DrawQuadEasy(pos, -pos:GetNormalized(), size, size, Color(col[1], col[2], col[3], 38), pt.rot)
                end
            end
        elseif not M then
            render.SetMaterial(MAT_DUST)
            for _, pt in ipairs(pts) do
                local pos = toRender(pt.p)
                if pos then
                    local size = pos:Length() * 0.004 * pt.s
                    render.DrawSprite(pos, size, size, Color(170, 150, 125, 90))
                end
            end
        end
    end

    -- Schleier im Nebel
    local neb, depth = Naval.FieldAt(fields, view.pos, function(f) return f.kind == "nebula" end)
    if neb then
        local center = toRender(V3.Add(view.pos, {x = 2, y = 0, z = 0}))
        if center then
            local col = neb.color or {150, 90, 255}
            local thick = math.Clamp(-depth / (neb.radius * 0.3), 0.25, 1)
            render.SetColorMaterial()
            render.DrawSphere(center, -300, 16, 12, Color(col[1], col[2], col[3], 70 * thick))
        end
    end
end

-- Beim Systemwechsel neu berechnen
hook.Add("PD.Naval.SystemReceived", "PD.Naval.Fields", function() farPoints = {} end)

hook.Add("ShutDown", "PD.Naval.Fields", function()
    if dust.mesh then pcall(dust.mesh.Destroy, dust.mesh) dust.mesh = nil end
    for i, e in pairs(rockEnts) do
        if IsValid(e) then e:Remove() end
        rockEnts[i] = nil
    end
end)

-- Beim Lua-Refresh keine Modelle liegen lassen
for _, e in pairs(Naval.OldFieldRocks or {}) do
    if IsValid(e) then e:Remove() end
end
Naval.OldFieldRocks = rockEnts
