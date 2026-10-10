--[[
    Naval - Render-Prototyp (Stufe 0, P1/P2/P4).

    Prueft, ob die geplante Darstellung im Skybox-Renderpass auf der Map
    funktioniert, bevor das eigentliche System darauf aufbaut. Nur fuer den
    eigenen Client, standardmaessig aus:

      pd_naval_proto 1          Testszene an (Planet, Mond, Schiffe)
      pd_naval_proto_hook 1|2|3 1 = PostDraw2DSkyBox, 2 = PreDrawSkyBox,
                                3 = PostDrawSkyBox
      pd_naval_proto_spin 1     Szene dreht sich (Nicken + Rollen) wie bei
                                einem drehenden Schiff
      pd_naval_bench <n>        n zusaetzliche Schiffe, Zeitmessung in der
                                Konsole (pd_naval_bench 0 = aus)
      pd_naval_hookaudit        listet alle Hooks der Render-/Nebel-Ereignisse
                                mit Herkunftsdatei (wer koennte unsere verschlucken)

    Pruefpunkte (P1): Objekte durch alle Fenster sichtbar, nie vor der
    Schiffshuelle, kein Flackern, auch mit r_3dsky 0.
]]

PD.Naval = PD.Naval or {}

local cvProto = CreateClientConVar("pd_naval_proto", "0", false, false, "Naval: Render-Testszene")
local cvHook = CreateClientConVar("pd_naval_proto_hook", "1", false, false, "Naval: Testszene in 1=PostDraw2DSkyBox 2=PreDrawSkyBox 3=PostDrawSkyBox")
local cvSpin = CreateClientConVar("pd_naval_proto_spin", "0", false, false, "Naval: Testszene drehen")

local PLANET_MAT = "the-coding-ducks/swu/planets/water/terrain_1"
local CLOUD_MAT = "the-coding-ducks/swu/planets/clouds/cloud_1"
local MOON_MAT = "the-coding-ducks/swu/planets/moon/terrain_2"
local SHIP_MODELS = {
    "models/salty/venator-class-cruiser.mdl",
    "models/salty/munificent-class.mdl",
    "models/salty/acclamator-class-ship.mdl",
    "models/salty/recusant-class-destroyer.mdl",
}

local materials = {}
local function Mat(path)
    materials[path] = materials[path] or Material(path)
    return materials[path]
end

local models = {}
local function ShipModel(path)
    if not IsValid(models[path]) then
        local m = ClientsideModel(path, RENDERGROUP_OPAQUE)
        if not IsValid(m) then return nil end

        m:SetNoDraw(true)
        models[path] = m
    end

    return models[path]
end

local bench = {count = 0, ships = {}, total = 0, frames = 0, nextPrint = 0}

-- Testobjekte: Richtung (Grad), Abstand, Radius in Render-Einheiten
local function SceneObjects()
    return {
        {kind = "planet", yaw = 30, pitch = -10, dist = 30000, radius = 9000},
        {kind = "moon", yaw = 60, pitch = -25, dist = 22000, radius = 1500},
        {kind = "ship", model = SHIP_MODELS[1], yaw = -20, pitch = 0, dist = 2500, length = 600, rot = Angle(0, 70, 0)},
        {kind = "ship", model = SHIP_MODELS[2], yaw = -60, pitch = 5, dist = 4000, length = 450, rot = Angle(0, 200, 10)},
        {kind = "ship", model = SHIP_MODELS[3], yaw = 120, pitch = -5, dist = 3000, length = 380, rot = Angle(0, -30, 0)},
    }
end

local function ModelScaleFor(model, length)
    local mins, maxs = model:GetModelBounds()
    local modelLength = math.max(maxs.x - mins.x, maxs.y - mins.y, 1)
    return length / modelLength
end

local function DrawScene()
    local view = render.GetViewSetup and render.GetViewSetup() or nil
    local fov = view and view.fov or LocalPlayer():GetFOV()
    local eyeAng = EyeAngles()

    -- Drehung der ganzen Szene (simuliert ein nickendes und rollendes Schiff)
    local spin = cvSpin:GetBool() and Angle(math.sin(CurTime() * 0.2) * 40, 0, math.sin(CurTime() * 0.13) * 30) or Angle(0, 0, 0)

    local function Place(yaw, pitch, dist)
        local dir = Angle(pitch, yaw, 0):Forward()
        dir:Rotate(spin)
        return dir * dist
    end

    cam.Start3D(Vector(0, 0, 0), eyeAng, fov, 0, 0, ScrW(), ScrH(), 5, 200000)
        render.SuppressEngineLighting(true)
        render.SetModelLighting(0, 1, 1, 1)
        render.SetModelLighting(1, 0.2, 0.2, 0.25)
        render.SetModelLighting(2, 0.6, 0.6, 0.6)
        render.SetModelLighting(3, 0.3, 0.3, 0.35)
        render.SetModelLighting(4, 0.9, 0.9, 0.9)
        render.SetModelLighting(5, 0.15, 0.15, 0.2)

        for _, obj in ipairs(SceneObjects()) do
            local pos = Place(obj.yaw, obj.pitch, obj.dist)

            if obj.kind == "planet" then
                render.SetMaterial(Mat(PLANET_MAT))
                render.DrawSphere(pos, obj.radius, 64, 64, color_white)
                render.SetMaterial(Mat(CLOUD_MAT))
                render.DrawSphere(pos, obj.radius * 1.01, 64, 64, Color(255, 255, 255, 200))
            elseif obj.kind == "moon" then
                render.SetMaterial(Mat(MOON_MAT))
                render.DrawSphere(pos, obj.radius, 32, 32, color_white)
            elseif obj.kind == "ship" then
                local m = ShipModel(obj.model)

                if m then
                    local ang = Angle(obj.rot.p, obj.rot.y, obj.rot.r)
                    ang:RotateAroundAxis(Vector(0, 1, 0), spin.p)
                    ang:RotateAroundAxis(Vector(1, 0, 0), spin.r)

                    local scale = ModelScaleFor(m, obj.length)
                    local mat = Matrix()
                    mat:Scale(Vector(scale, scale, scale))

                    m:EnableMatrix("RenderMultiply", mat)
                    m:SetPos(pos)
                    m:SetAngles(ang)
                    m:SetupBones()
                    m:DrawModel()
                end
            end
        end

        -- Benchmark-Schiffe
        if bench.count > 0 then
            local t0 = SysTime()

            for i = 1, bench.count do
                local data = bench.ships[i]
                local m = ShipModel(data.model)

                if m then
                    local mat = Matrix()
                    mat:Scale(Vector(data.scale, data.scale, data.scale))
                    m:EnableMatrix("RenderMultiply", mat)
                    m:SetPos(Place(data.yaw, data.pitch, data.dist))
                    m:SetAngles(data.ang)
                    m:SetupBones()
                    m:DrawModel()
                end
            end

            bench.total = bench.total + (SysTime() - t0)
            bench.frames = bench.frames + 1

            if CurTime() > bench.nextPrint then
                print(("[Naval] Bench: %d Schiffe, %.2f ms pro Frame"):format(bench.count, bench.total / math.max(bench.frames, 1) * 1000))
                bench.total, bench.frames, bench.nextPrint = 0, 0, CurTime() + 2
            end
        end

        render.SuppressEngineLighting(false)
    cam.End3D()

    -- Danach ist die Map immer vorne: keine Ueberschneidung mit Huelle/Skybox.
    render.ClearDepth()
end

local lastFrame = 0

local function Hooked(variant)
    return function()
        if not cvProto:GetBool() or cvHook:GetInt() ~= variant then return end
        if lastFrame == FrameNumber() then return end

        lastFrame = FrameNumber()
        DrawScene()
    end
end

hook.Add("PostDraw2DSkyBox", "PD.Naval.Proto", Hooked(1))
hook.Add("PreDrawSkyBox", "PD.Naval.Proto", Hooked(2))
hook.Add("PostDrawSkyBox", "PD.Naval.Proto", Hooked(3))

concommand.Add("pd_naval_bench", function(_, _, args)
    local n = math.Clamp(tonumber(args[1]) or 0, 0, 500)
    bench.count = n
    bench.ships = {}

    for i = 1, n do
        local m = ShipModel(SHIP_MODELS[(i % #SHIP_MODELS) + 1])
        local mins, maxs = Vector(-1, -1, -1), Vector(1, 1, 1)
        if m then mins, maxs = m:GetModelBounds() end
        local len = math.max(maxs.x - mins.x, 1)

        bench.ships[i] = {
            model = SHIP_MODELS[(i % #SHIP_MODELS) + 1],
            yaw = math.Rand(-180, 180), pitch = math.Rand(-30, 30), dist = math.Rand(3000, 30000),
            ang = AngleRand(), scale = math.Rand(150, 600) / len,
        }
    end

    print("[Naval] Bench mit " .. n .. " Schiffen (pd_naval_proto muss an sein)")
end)

concommand.Add("pd_naval_hookaudit", function()
    local events = {"PostDraw2DSkyBox", "PreDrawSkyBox", "PostDrawSkyBox", "SetupSkyboxFog", "SetupWorldFog", "Think", "InitPostEntity"}
    local all = hook.GetTable()

    for _, event in ipairs(events) do
        print("[Naval] " .. event .. ":")

        for name, fn in pairs(all[event] or {}) do
            local source = debug.getinfo(fn, "S")
            print(("   %s  (%s:%s)"):format(tostring(name), source and source.short_src or "?", source and source.linedefined or "?"))
        end
    end
end)

-- Beim Lua-Refresh keine Modelle liegen lassen.
for _, m in pairs(PD.Naval.ProtoModels or {}) do
    if IsValid(m) then m:Remove() end
end
PD.Naval.ProtoModels = models
