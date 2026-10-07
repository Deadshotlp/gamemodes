--[[
    Naval - Darstellung im Skybox-Renderpass (Client).

    Alles wird relativ zum Map-Schiff gezeichnet: Universumsrichtungen werden
    mit M = (Schiff -> Map) * (Universum -> Schiff) in Map-Richtungen gedreht,
    die Kamera nutzt die normalen Blickwinkel. Danach render.ClearDepth():
    die Map (Huelle, Fenster) liegt immer davor.

    Ebenen: Sternenhimmel (echte Richtungen der anderen Systeme) ->
    Himmelskoerper (Impostor mit korrekter Winkelgroesse) -> Schiffe
    (Modelle nah, Punkte fern) -> Hyperraum-Tunnel.

    Hook PostDraw2DSkyBox (im Prototyp auf der Venator bestaetigt). Laeuft er
    30 Frames nicht, weil ein anderes Addon ihn verschluckt, uebernimmt
    PreDrawSkyBox.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3, Q = Naval.V3, Naval.Q
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

local STAR_RADIUS = 80000      -- Render-Einheiten (Sternenhimmel)
local ZFAR = 200000
local ZNEAR = 0.5

local materials = {}
local function Mat(path)
    if not path or path == "" then return nil end
    materials[path] = materials[path] or Material(path)
    return materials[path]
end

local MAT_GLOW = Material("sprites/light_glow02_add")
local MAT_STAR = Material("sprites/light_ignorez")
local MAT_DOT = Material("sprites/glow04_noz")

local function Settings()
    return (C.static and C.static.settings) or {}
end

local function Scale() return Settings().render_scale or 50 end
local function Far() return Settings().render_far or 40000 end

-- Universum -> Map (Quaternion), aus Schiffsorientierung und Profil
local function UniverseToMap(shipRot)
    local profile = Naval.GetProfile()
    local a = profile and profile.mapToBody or Angle(0, 0, 0)
    local qbm = Q.FromAngle(a.p, a.y, a.r)

    return Q.Mul(qbm, Q.Conj(shipRot)), qbm
end

Naval.UniverseToMap = UniverseToMap

local function ToMapVector(M, v)
    local r = Q.RotateVec(M, v)
    return Vector(r.x, r.y, r.z)
end

--------------------------------------------------------------------------------
-- Sternenhimmel
--------------------------------------------------------------------------------

local starMeshes = {}
local starMeshSystem

local function AddQuad(dir, size, col)
    -- Quad senkrecht zur Blickrichtung vom Ursprung
    local up = math.abs(dir.z) < 0.99 and Vector(0, 0, 1) or Vector(1, 0, 0)
    local u = dir:Cross(up) u:Normalize()
    local v = dir:Cross(u) v:Normalize()
    local c = dir * STAR_RADIUS
    u = u * size
    v = v * size

    mesh.Position(c - u - v) mesh.TexCoord(0, 0, 0) mesh.Color(col.r, col.g, col.b, col.a) mesh.AdvanceVertex()
    mesh.Position(c + u - v) mesh.TexCoord(0, 1, 0) mesh.Color(col.r, col.g, col.b, col.a) mesh.AdvanceVertex()
    mesh.Position(c + u + v) mesh.TexCoord(0, 1, 1) mesh.Color(col.r, col.g, col.b, col.a) mesh.AdvanceVertex()
    mesh.Position(c - u + v) mesh.TexCoord(0, 0, 1) mesh.Color(col.r, col.g, col.b, col.a) mesh.AdvanceVertex()
end

local function BuildStarfield(systemId)
    for _, m in ipairs(starMeshes) do m:Destroy() end
    starMeshes = {}

    local static = C.static
    if not static then return end

    local here = static.systemsById[systemId]
    local origin = here and here.g or {x = 0, y = 0, z = 0}
    local stars = {}

    -- Andere Systeme in ihrer echten Richtung; nahe heller und groesser
    for _, s in ipairs(static.systemList) do
        if s.id ~= systemId then
            local d = Vector(s.g.x - origin.x, s.g.y - origin.y, s.g.z - origin.z)
            local dist = d:Length()

            if dist > 1 then
                d:Normalize()
                local bright = math.Clamp(1 - dist / 25000, 0.15, 1)
                stars[#stars + 1] = {dir = d, size = 40 + bright * 110, col = Color(255, 245, 230, 120 + bright * 135)}
            end
        end
    end

    -- Hintergrund (deterministisch), leicht ins Blaeuliche
    local seed = 1234
    local function rnd()
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 2147483648
    end

    for _ = 1, 3000 do
        local z = rnd() * 2 - 1
        local a = rnd() * math.pi * 2
        local r = math.sqrt(1 - z * z)
        local tint = rnd()
        stars[#stars + 1] = {dir = Vector(math.cos(a) * r, math.sin(a) * r, z), size = 25 + rnd() * 35,
            col = Color(200 + tint * 55, 210 + tint * 45, 255, 60 + rnd() * 90)}
    end

    -- Meshes zu je hoechstens 8000 Quads
    local PER_MESH = 8000
    for i = 1, #stars, PER_MESH do
        local m = Mesh()
        local count = math.min(PER_MESH, #stars - i + 1)

        mesh.Begin(m, MATERIAL_QUADS, count)
        for j = i, i + count - 1 do
            AddQuad(stars[j].dir, stars[j].size, stars[j].col)
        end
        mesh.End()

        starMeshes[#starMeshes + 1] = m
    end

    starMeshSystem = systemId
end

local function DrawStarfield(M)
    if #starMeshes == 0 then return end

    local mat = Matrix()
    mat:SetAngles(Q.ToAngle(M))

    render.SetMaterial(MAT_STAR)
    cam.PushModelMatrix(mat)
        for _, m in ipairs(starMeshes) do m:Draw() end
    cam.PopModelMatrix()
end

--------------------------------------------------------------------------------
-- Himmelskoerper
--------------------------------------------------------------------------------

local Lighting -- weiter unten

local function DrawBodies(view, M, camOffset, ang, fov)
    local system = C.system
    if not system or system.systemId ~= view.systemId then return nil end

    local scale, far = Scale(), Far()
    local now = Naval.Now()
    local list = {}
    local sunDir

    for _, body in ipairs(system.bodies) do
        local pos = Naval.BodyPos(body, system.bodiesById, now)
        local rel = V3.Sub(pos, view.pos)
        local distM = V3.Len(rel)
        local dir = ToMapVector(M, rel)
        dir:Normalize()

        local dist = distM / scale
        local radius = body.radius / scale

        if dist > far then
            radius = radius * far / dist
            dist = far
        end

        list[#list + 1] = {body = body, pos = dir * dist - camOffset, radius = radius, dist = dist, real = distM}

        if body.type == "star" and not sunDir then sunDir = dir end
    end

    -- Von hinten nach vorn nach echter Entfernung. Jeder Koerper bekommt eine
    -- eigene Kamera, deren Nah-/Fernebene eng um ihn liegt: volle
    -- Tiefengenauigkeit (Wolken flackern nicht in die Oberflaeche), und ferne
    -- Koerper, die alle auf der Projektionskugel liegen, schneiden sich nicht -
    -- der naehere wird danach gezeichnet und deckt ab.
    table.sort(list, function(a, b) return a.real > b.real end)

    -- Eigenes Sonnenlicht setzen: sonst uebernehmen die Planeten die
    -- Beleuchtung dessen, was zuletzt gezeichnet wurde (z. B. die Waffe)
    Lighting(sunDir)

    for _, e in ipairs(list) do
        local body = e.body
        local seg = math.Clamp(math.floor(e.radius / e.dist * 400), 12, 64)
        -- Tiefe entlang der Blickrichtung (Nah-/Fernebene stehen senkrecht dazu)
        local d = e.pos:Dot(ang:Forward())
        local reach = e.radius * (body.type == "star" and 8 or 1.1)

        render.ClearDepth()
        local near = math.max(1, d - reach)
        cam.Start3D(Vector(0, 0, 0), ang, fov, 0, 0, ScrW(), ScrH(), near, math.max(near + 1, d + reach + 1))

        if body.type == "star" then
            local mat = Mat(body.material)
            if mat then
                render.ResetModelLighting(1, 1, 1)
                render.SetMaterial(mat)
                render.DrawSphere(e.pos, e.radius, seg, seg, color_white)
                Lighting(sunDir)
            end
            render.SetMaterial(MAT_GLOW)
            render.DrawSprite(e.pos, e.radius * 7, e.radius * 7, Color(255, 230, 190, 255))
        elseif body.model and body.model ~= "" then
            -- Station mit Modell: spaeter eigener Modell-Pool, vorerst Punkt
            render.SetMaterial(MAT_DOT)
            render.DrawSprite(e.pos, math.max(e.radius * 2, e.dist * 0.004), math.max(e.radius * 2, e.dist * 0.004), Color(200, 220, 255))
        else
            local mat = Mat(body.material)
            if mat then
                render.SetMaterial(mat)
                render.DrawSphere(e.pos, e.radius, seg, seg, color_white)
            end

            local cloud = Mat(body.cloud)
            if cloud then
                render.SetMaterial(cloud)
                render.DrawSphere(e.pos, e.radius * 1.012, seg, seg, Color(255, 255, 255, 190))
            end
        end

        cam.End3D()
    end

    render.SuppressEngineLighting(false)
    return sunDir
end

--------------------------------------------------------------------------------
-- Schiffe
--------------------------------------------------------------------------------

-- Laenge eines Modells in Einheiten. Die im Modell hinterlegten Grenzen
-- stimmen bei manchen Schiffen nicht (Recusant: viel zu klein -> riesig
-- skaliert), daher aus den echten Eckpunkten gemessen und je Modell gemerkt.
-- Laenge und Mitte (Modell-Einheiten) aus den Eckpunkten, je Modell gemerkt
local meshInfo = {}

-- Eckpunkte liegen in der Grundhaltung der Knochen; gezeichnet wird mit der
-- Standardhaltung des Modells. Manche Modelle (z. B. die Venator) haben den
-- Wurzelknochen verschoben - ohne Umrechnung laege die Mitte daneben.
-- Gerechnet werden drei Varianten (roh, Knochen x Bindung, Knochen x
-- invertierte Bindung); genommen wird die, deren Mitte den gezeichneten
-- Grenzen des Modells am naechsten liegt und deren Laenge passt.
local function Bounds(meshes, mats)
    local mins = Vector(math.huge, math.huge, math.huge)
    local maxs = Vector(-math.huge, -math.huge, -math.huge)
    for _, part in ipairs(meshes) do
        for _, v in ipairs(part.triangles or {}) do
            local p = v.pos
            local w = mats and v.weights and v.weights[1]
            if w and mats[w.bone] then p = mats[w.bone] * p end
            if p.x < mins.x then mins.x = p.x end
            if p.y < mins.y then mins.y = p.y end
            if p.z < mins.z then mins.z = p.z end
            if p.x > maxs.x then maxs.x = p.x end
            if p.y > maxs.y then maxs.y = p.y end
            if p.z > maxs.z then maxs.z = p.z end
        end
    end
    if maxs.x <= mins.x then return nil end
    return {length = math.max(maxs.x - mins.x, maxs.y - mins.y), center = (mins + maxs) * 0.5}
end

-- Ergebnisse dauerhaft merken (data/pd_naval_modelinfo.txt): das Einlesen
-- der Meshes erzeugt bei grossen Modellen sehr viel Lua-Speicher - auf dem
-- 32-Bit-Client kann das beim naechsten Map-Laden den Speicher sprengen.
-- So passiert es je Spieler nur einmal pro Modell.
local DISK_FILE, DISK_VERSION = "pd_naval_modelinfo.txt", 2
local disk

local function DiskCache()
    if disk then return disk end
    local data = util.JSONToTable(file.Read(DISK_FILE, "DATA") or "") or {}
    disk = data.v == DISK_VERSION and istable(data.models) and data.models or {}
    return disk
end

function Naval.ModelInfo(path)
    if meshInfo[path] ~= nil then return meshInfo[path] end

    local cached = DiskCache()[path]
    if istable(cached) and tonumber(cached.l) then
        meshInfo[path] = {length = tonumber(cached.l), center = Vector(tonumber(cached.x) or 0, tonumber(cached.y) or 0, tonumber(cached.z) or 0)}
        return meshInfo[path]
    end

    local info = false
    local ok, meshes, bindPose = pcall(util.GetModelMeshes, path, 0)

    if ok and meshes then
        info = Bounds(meshes) or false

        local ent = istable(bindPose) and ClientsideModel(path, RENDERGROUP_OTHER)
        if info and IsValid(ent) then
            ent:SetPos(Vector(0, 0, 0))
            ent:SetAngles(Angle(0, 0, 0))
            ent:SetupBones()
            local rmins, rmaxs = ent:GetRenderBounds()
            local renderCenter = (rmins + rmaxs) * 0.5

            local direct, inverse = {}, {}
            for bone = 0, ent:GetBoneCount() - 1 do
                local boneMat = ent:GetBoneMatrix(bone)
                local bind = bindPose[bone] or bindPose[bone + 1]
                if boneMat and bind and bind.matrix then
                    direct[bone] = boneMat * bind.matrix
                    inverse[bone] = boneMat * bind.matrix:GetInverse()
                end
            end
            ent:Remove()

            local best, bestD = info, info.center:Distance(renderCenter)
            for _, mats in ipairs({direct, inverse}) do
                local cand = next(mats) and Bounds(meshes, mats)
                if cand and math.abs(cand.length - info.length) < info.length * 0.05 then
                    local d = cand.center:Distance(renderCenter)
                    if d < bestD then best, bestD = cand, d end
                end
            end
            info = best
        elseif IsValid(ent) then
            ent:Remove()
        end
    end

    meshInfo[path] = info

    -- Speicher der Meshes sofort freigeben und Ergebnis merken
    meshes, bindPose = nil, nil
    collectgarbage("collect")
    if info then
        DiskCache()[path] = {l = info.length, x = info.center.x, y = info.center.y, z = info.center.z}
        file.Write(DISK_FILE, util.TableToJSON({v = DISK_VERSION, models = disk}) or "")
    end

    return info
end

local function MeshLength(path)
    local info = Naval.ModelInfo(path)
    return info and info.length
end

-- Sichtbare Mitte eines Schiffs (Systemmeter): der Modell-Ursprung liegt oft
-- am Heck oder unten, Schuesse und Einschlaege sollen in die Mitte.
function Naval.ShipCenter(classId, pos, rot)
    local class = C.static and C.static.classes[classId or ""]
    local info = class and class.model and Naval.ModelInfo(class.model)
    if not info or not rot then return pos end

    local k = (class.lengthM or 300) / info.length
    local off = {x = info.center.x * k, y = info.center.y * k, z = info.center.z * k}
    return V3.Add(pos, Q.RotateVec(rot, off))
end

function Naval.ModelLength(m)
    local fromMesh = MeshLength(m:GetModel())
    if fromMesh and fromMesh > 1 then return fromMesh end

    local length = 1
    local mins, maxs = m:GetModelBounds()
    if mins then length = math.max(length, maxs.x - mins.x, maxs.y - mins.y) end

    local rmins, rmaxs = m:GetModelRenderBounds()
    if rmins then length = math.max(length, rmaxs.x - rmins.x, rmaxs.y - rmins.y) end

    return length
end

local shipModels = {}   -- id -> ClientsideModel
Naval.RenderModels = shipModels

local function ShipModel(id, path)
    local m = shipModels[id]

    if IsValid(m) and m:GetModel() == path then return m end
    if IsValid(m) then m:Remove() end

    m = ClientsideModel(path, RENDERGROUP_OPAQUE)
    if not IsValid(m) then return nil end

    m:SetNoDraw(true)
    m.PD_Length = Naval.ModelLength(m)
    shipModels[id] = m

    return m
end

local function FactionColor(factionId)
    local f = C.static and C.static.factions[factionId]
    if f and f.color then return Color(f.color[1], f.color[2], f.color[3]) end
    return Color(200, 200, 200)
end

local function DrawShips(view, M, camOffset)
    local static = C.static
    if not static then return end

    local scale, far = Scale(), Far()
    local nearRange = Settings().near_ship_range or 50000
    local seen = {}

    for id, s in pairs(view.ships) do
        local info = C.info[id]
        local class = info and static.classes[info.classId]

        if class then
            seen[id] = true

            local rel = V3.Sub(s.pos, view.pos)
            local distM = V3.Len(rel)
            local dir = ToMapVector(M, rel)
            dir:Normalize()

            local dist = math.min(distM / scale, far)
            local pos = dir * dist - camOffset

            if distM > nearRange then
                local size = math.max(dist * 0.006, 2)
                render.SetMaterial(MAT_DOT)
                render.DrawSprite(pos, size, size, FactionColor(info.factionId))
            else
                local m = ShipModel(id, class.model)

                if m then
                    local length = (class.lengthM or 300) / scale * (dist / math.max(distM / scale, 0.001))
                    local f = length / m.PD_Length
                    local mat = Matrix()
                    mat:Scale(Vector(f, f, f))

                    m:EnableMatrix("RenderMultiply", mat)
                    m:SetPos(pos)
                    m:SetAngles(Q.ToAngle(Q.Mul(M, s.rot)))
                    m:SetupBones()

                    -- Wrack dunkel, kampfunfaehig gedimmt
                    local dim = s.state == "destroyed" and 0.25 or (s.state == "disabled" and 0.55 or 1)
                    if dim < 1 then render.SetColorModulation(dim, dim * 0.9, dim * 0.85) end
                    m:DrawModel()
                    if dim < 1 then render.SetColorModulation(1, 1, 1) end
                end
            end
        end
    end

    -- Modelle verschwundener Schiffe freigeben
    for id, m in pairs(shipModels) do
        if not seen[id] then
            if IsValid(m) then m:Remove() end
            shipModels[id] = nil
        end
    end
end

--------------------------------------------------------------------------------
-- Hyperraum
--------------------------------------------------------------------------------

local tunnel

local function DrawHyperspace(qbm)
    local profile = Naval.GetProfile()
    local path = profile and profile.hyperspace and profile.hyperspace.tunnel
    if not path then return end

    if not IsValid(tunnel) then
        tunnel = ClientsideModel(path, RENDERGROUP_OPAQUE)
        if not IsValid(tunnel) then return end
        tunnel:SetNoDraw(true)
    end

    -- Tunnel entlang der Schiffsachse (Bug) in Map-Richtung
    tunnel:SetPos(Vector(0, 0, 0))
    tunnel:SetAngles(Q.ToAngle(qbm))
    tunnel:DrawModel()
end

--------------------------------------------------------------------------------
-- Hauptpass
--------------------------------------------------------------------------------

local lastDrawn = 0

Lighting = function(sunDir)
    render.SuppressEngineLighting(true)
    render.ResetModelLighting(0.08, 0.08, 0.1)

    if sunDir then
        -- Richtungslicht naeherungsweise ueber die sechs Achsen
        local s = sunDir
        render.SetModelLighting(BOX_FRONT, math.max(s.x, 0) + 0.08, math.max(s.x, 0) + 0.08, math.max(s.x, 0) + 0.1)
        render.SetModelLighting(BOX_BACK, math.max(-s.x, 0) + 0.08, math.max(-s.x, 0) + 0.08, math.max(-s.x, 0) + 0.1)
        render.SetModelLighting(BOX_LEFT, math.max(s.y, 0) + 0.08, math.max(s.y, 0) + 0.08, math.max(s.y, 0) + 0.1)
        render.SetModelLighting(BOX_RIGHT, math.max(-s.y, 0) + 0.08, math.max(-s.y, 0) + 0.08, math.max(-s.y, 0) + 0.1)
        render.SetModelLighting(BOX_TOP, math.max(s.z, 0) + 0.08, math.max(s.z, 0) + 0.08, math.max(s.z, 0) + 0.1)
        render.SetModelLighting(BOX_BOTTOM, math.max(-s.z, 0) + 0.08, math.max(-s.z, 0) + 0.08, math.max(-s.z, 0) + 0.1)
    end
end

local function CameraOffset()
    local profile = Naval.GetProfile()
    if not profile or not profile.shipOriginMap or not profile.metersPerUnit then return Vector(0, 0, 0) end

    -- Wo im Schiff man steht (Map-Einheiten -> Meter -> Render-Einheiten)
    return (EyePos() - profile.shipOriginMap) * (profile.metersPerUnit / Scale())
end

function Naval.RenderSpace()
    if Naval.ClientShutdown or lastDrawn == FrameNumber() then return end
    lastDrawn = FrameNumber()

    if not Naval.IsNavalMap() then return end

    local view = C.View()
    if not view or not view.rot then return end

    if starMeshSystem ~= view.systemId and C.static then
        BuildStarfield(view.systemId)
    end

    local M, qbm = UniverseToMap(view.rot)
    local setup = render.GetViewSetup and render.GetViewSetup() or nil
    local fov = setup and setup.fov or LocalPlayer():GetFOV()
    local ang = EyeAngles()

    render.FogMode(MATERIAL_FOG_NONE)

    -- Sternenhimmel ohne Parallaxe
    cam.Start3D(Vector(0, 0, 0), ang, fov, 0, 0, ScrW(), ScrH(), ZNEAR, ZFAR)
        local inHyper = view.state == "hyperspace"

        if inHyper then
            DrawHyperspace(qbm)
        else
            DrawStarfield(M)
        end
    cam.End3D()
    render.ClearDepth()

    if view.state ~= "hyperspace" then
        local camOffset = CameraOffset()

        cam.Start3D(Vector(0, 0, 0), ang, fov, 0, 0, ScrW(), ScrH(), ZNEAR, ZFAR)
            local sunDir = DrawBodies(view, M, camOffset, ang, fov)
            render.ClearDepth()

            Lighting(sunDir)
            DrawShips(view, M, camOffset)
            render.SuppressEngineLighting(false)

            -- Kampfeffekte (cl_naval_fx.lua) und Staffeln (cl_naval_hangar.lua)
            local scale, far = Scale(), Far()
            local function toRender(p)
                local rel = V3.Sub(p, view.pos)
                local len = V3.Len(rel)
                if len < 1 then return nil end
                local dir = ToMapVector(M, rel)
                dir:Normalize()
                return dir * math.min(len / scale, far) - camOffset
            end
            if Naval.DrawFX then Naval.DrawFX(view, toRender) end
            if Naval.DrawSquadrons then Naval.DrawSquadrons(view, toRender) end
            if Naval.DrawTractor then Naval.DrawTractor(view, toRender) end
        cam.End3D()
    end

    -- Danach ist die Map immer vorne.
    render.ClearDepth()
end

-- Hook mit Waechter
-- Beide Hooks laufen nur, wenn der Himmel sichtbar ist. Verschluckt ist der
-- Haupthook erst, wenn PreDrawSkyBox laeuft, er selbst aber nicht.
local primaryFrame = 0
local preFrame = 0
local useFallback = false

-- Exklusiver Himmel: der Himmel der Map (2D-Textur und 3D-Skybox mit
-- eigenen Sternen/Planeten) wird nicht gezeichnet. Sonst steht er still,
-- waehrend sich unser Weltraum mit dem Schiff dreht - das sieht aus, als
-- verschiebe sich die Galaxie. pd_naval_sky_exclusive 0 zum Vergleich.
local exclusive = CreateClientConVar("pd_naval_sky_exclusive", "1", true, false, "Naval: nur eigenen Weltraum statt Map-Himmel zeichnen")

local function Exclusive()
    return exclusive:GetBool() and Naval.IsNavalMap() and C.View() ~= nil
end

hook.Add("PostDraw2DSkyBox", "PD.Naval.Render", function()
    primaryFrame = FrameNumber()
    if useFallback and not Exclusive() then return end
    if lastDrawn == FrameNumber() then return end

    -- Map-Himmelstextur ueberdecken
    if Exclusive() then render.Clear(0, 0, 0, 255, false, false) end
    Naval.RenderSpace()
end)

hook.Add("PreDrawSkyBox", "PD.Naval.RenderFallback", function()
    preFrame = FrameNumber()

    if Exclusive() then
        render.Clear(0, 0, 0, 255, true, true)
        Naval.RenderSpace()
        return true   -- Map-Skybox (2D und 3D) auslassen
    end

    if not useFallback then return end
    Naval.RenderSpace()
end)

timer.Create("PD.Naval.RenderGuard", 1, 0, function()
    if not Naval.IsNavalMap() or Exclusive() then return end

    local skyVisible = FrameNumber() - preFrame < 5
    local missing = skyVisible and FrameNumber() - primaryFrame > 30

    if missing and not useFallback then
        useFallback = true
        print("[Naval] PostDraw2DSkyBox laeuft nicht (verschluckt?) - nutze PreDrawSkyBox. pd_naval_hookaudit zeigt die Hooks.")
    end
end)

-- Beim Verlassen der Map (Map-Wechsel, Trennen) alles freigeben, bevor das
-- Grafiksystem herunterfaehrt: selbst erzeugte Meshes, die erst danach vom
-- Garbage Collector entsorgt werden, koennen das Spiel abstuerzen lassen.
hook.Add("ShutDown", "PD.Naval.Render", function()
    Naval.ClientShutdown = true
    for _, m in ipairs(starMeshes) do pcall(m.Destroy, m) end
    starMeshes = {}
    starMeshSystem = nil
    for id, m in pairs(shipModels) do
        if IsValid(m) then m:Remove() end
        shipModels[id] = nil
    end
    if IsValid(tunnel) then tunnel:Remove() end
end)

-- Beim Lua-Refresh keine Modelle liegen lassen
for _, m in pairs(Naval.OldRenderModels or {}) do
    if IsValid(m) then m:Remove() end
end
Naval.OldRenderModels = shipModels
