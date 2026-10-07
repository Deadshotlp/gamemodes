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

-- Felsbrocken einer Zelle; gibt die neue Anzahl gezeichneter zurueck
local function DrawCell(ix, iy, iz, center, f, toRender, scale, drawn)
    local rnd = CellRng(ix, iy, iz, 1013)
    local count = math.floor(rnd() * 2.4 * (f.density or 1))
    local now = CurTime()
    for _ = 1, count do
        if drawn >= MAX_ROCKS then return drawn end
        local rp = {x = center.x + (rnd() - 0.5) * CELL, y = center.y + (rnd() - 0.5) * CELL, z = center.z + (rnd() - 0.5) * CELL}
        local size = 30 + rnd() ^ 3 * 650
        local ent = RockEnt(math.floor(rnd() * #ROCK_MODELS) + 1)
        local spin = (rnd() - 0.5) * 12
        local ang = Angle(rnd() * 360, rnd() * 360 + now * spin, rnd() * 360)
        local pos = toRender(rp)
        if ent and pos then
            local k = size / scale / math.max(ent:GetModelRadius(), 1)
            mtx:SetScale(Vector(k, k, k))
            ent:EnableMatrix("RenderMultiply", mtx)
            ent:SetRenderOrigin(pos)
            ent:SetRenderAngles(ang)
            ent:SetupBones()
            ent:DrawModel()
            drawn = drawn + 1
        end
    end
    return drawn
end

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
    local n = math.ceil(NEAR * 2 / CELL)
    local drawn = 0
    render.SetColorModulation(0.62, 0.58, 0.54)

    for ix = x0, x0 + n do
        for iy = y0, y0 + n do
            for iz = z0, z0 + n do
                local center = {x = (ix + 0.5) * CELL, y = (iy + 0.5) * CELL, z = (iz + 0.5) * CELL}
                local f = V3.Dist(center, p) <= NEAR and Naval.FieldAt(near, center) or nil
                if f then drawn = DrawCell(ix, iy, iz, center, f, toRender, scale, drawn) end
                if drawn >= MAX_ROCKS then break end
            end
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

-- Staub, Nebelwolken und Schleier (nach den Kampfeffekten)
function Naval.DrawFieldClouds(view, toRender)
    local fields = Fields()
    if #fields == 0 then return end

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
        else
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
