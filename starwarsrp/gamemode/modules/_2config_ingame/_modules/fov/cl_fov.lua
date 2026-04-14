PD.FOV = PD.FOV or {}

PD.FOV.thirdPerson = PD.FOV.thirdPerson or false
PD.FOV.AFKPerson = PD.FOV.AFKPerson or false

local lastthirdPersonToggle = false
net.Receive("PD_UpdateAFKStatus", function()
    local isAFK = net.ReadBool()
    PD.FOV.AFKPerson = isAFK

    if isAFK and not PD.FOV.thirdPerson then
        lastthirdPersonToggle = PD.FOV.thirdPerson
        PD.FOV.thirdPerson = true
    end

    if not isAFK and lastthirdPersonToggle ~= PD.FOV.thirdPerson then
        PD.FOV.thirdPerson = lastthirdPersonToggle
    end
end)

local headBobIntensity = 1.5
local check_FOV_Value = 17 -- Angabe in Prozent
local defaultFOV = 80
local drei = defaultFOV / 100 * check_FOV_Value
local sprintFOV = defaultFOV + drei
local sneakFOV = defaultFOV - drei
local camLerpSpeed = 8
local bobSpeed = 6
local recoilAngle = Angle(0, 0, 0)
local recoilDecay = 10 -- Wie schnell sich der Rückstoß wieder zurücksetzt

timer.Simple(0.1, function()
    if file.Exists("PD_CameraSettings.json", "DATA") then
        local data = util.JSONToTable(file.Read("PD_CameraSettings.json", "DATA"))
        if data and data.defaultFOV then
            defaultFOV = data.defaultFOV

            sprintFOV = defaultFOV + drei
            sneakFOV = defaultFOV - drei
        end
    end
end)

local currentFOV = defaultFOV
local camAngleOffset = Angle(0, 0, 0)

function PD.FOV:Menu(base)
    -- base = PD.Frame("FOV - Settings", PD.W(300), PD.H(400), true, function(self, w, h) end, true)
    -- base:SetPos(PD.W(10), PD.H(100))

    local pnl, slider = PD.NumSlider(LANG.ESC_CONFIG_FOV_CURRENT, base, 60, 120, defaultFOV, function(value)
        defaultFOV = value
        PD.Config.tbl.fov.CurrentFOV = defaultFOV

        sprintFOV = defaultFOV + drei
        sneakFOV = defaultFOV - drei
    end)
    pnl:Dock(TOP)

    -- local save = PD.Button("Save", base, function(self)
    --     base:Remove()

    --     file.Write("PD_CameraSettings.json", util.TableToJSON({
    --         defaultFOV = defaultFOV
    --     }, true))
    -- end)
    -- save:Dock(BOTTOM)
end

function PD.FOV:Load()
    defaultFOV = PD.Config.tbl.fov.CurrentFOV or PD.Config.tbl.fov.defaultFOV
end

hook.Add("EntityFireBullets", "AddCameraRecoil", function(ent, data)
    if ent == LocalPlayer() then
        -- recoilAngle.p = recoilAngle.p - math.Rand(1.0, 2.5) -- Kamera geht leicht nach oben
        -- recoilAngle.y = recoilAngle.y + math.Rand(-0.5, 10.5) -- Leichter seitlicher Rückstoß
        -- currentFOV = currentFOV + math.Rand(0.5, 1) -- FOV wird leicht verringert
    end
end)

local smoothOffsetX = 0
local afkOrbitSpeed = 0.08
local afkOrbitRadius = 40
local afkOrbitHeight = 45

local afkBlend = 0
local afkCamPos = Vector(0, 0, 0)
local afkCamAng = Angle(0, 0, 0)

hook.Add("ShouldDrawLocalPlayer", "SimpleTP.ShouldDraw", function(ply)
    if PD.FOV.thirdPerson then
        return true
    end
end)

hook.Add("CalcView", "ImmersiveCameraEffects", function(ply, pos, angles, fov)
    if not IsValid(ply) or not ply:Alive() then return end
    -- if true then return end -- Deaktiviert für jetzt

    local velocity = ply:GetVelocity():Length2D()
    local isSprinting = velocity > 200 and ply:KeyDown(IN_SPEED)
    local isSneaking = ply:KeyDown(IN_WALK) or ply:KeyDown(IN_DUCK)
    local eyeAngles = ply:EyeAngles()

    local targetFOV = defaultFOV
    if isSprinting and not PD.FOV.thirdPerson then
        targetFOV = sprintFOV
    elseif isSneaking and not PD.FOV.thirdPerson then
        targetFOV = sneakFOV
    end

    currentFOV = Lerp(FrameTime() * camLerpSpeed, currentFOV, targetFOV)

    local bob = 0
    if ply:IsOnGround() and velocity > 10 and not PD.FOV.thirdPerson then
        bob = math.sin(CurTime() * bobSpeed) * (headBobIntensity * math.Clamp(velocity / 300, 0, 1))
    end
    camAngleOffset.p = Lerp(FrameTime() * camLerpSpeed, camAngleOffset.p, bob)

    smoothOffsetX = Lerp(FrameTime() * 8, smoothOffsetX, PD.FOV.thirdPerson and -80 or 0)

    afkBlend = Lerp(FrameTime() * 2, afkBlend, PD.FOV.AFKPerson and 1 or 0)

    local useThirdPerson = PD.FOV.thirdPerson or math.abs(smoothOffsetX) > 1 or afkBlend > 0.01
    local view = {}

    if useThirdPerson then
        local basePos, baseAng

        do
            local offset = Vector(smoothOffsetX, 0, 0)
            local tpPos = pos
                + eyeAngles:Forward() * offset.x
                + eyeAngles:Right() * offset.y
                + eyeAngles:Up() * offset.z

            local tr = util.TraceHull({
                start = pos,
                endpos = tpPos,
                mins = Vector(-4, -4, -4),
                maxs = Vector(4, 4, 4),
                filter = ply
            })

            basePos = tr.HitPos
            baseAng = angles
        end

        local focus = ply:GetPos() + Vector(0, 0, afkOrbitHeight)
        local a = CurTime() * afkOrbitSpeed
        local orbitPos = focus + Vector(math.cos(a) * afkOrbitRadius, math.sin(a) * afkOrbitRadius, afkOrbitHeight)

        local tr = util.TraceHull({
            start = focus,
            endpos = orbitPos,
            mins = Vector(-4, -4, -4),
            maxs = Vector(4, 4, 4),
            filter = ply
        })

        afkCamPos = tr.HitPos
        afkCamAng = (focus - afkCamPos):Angle()

        view.origin = LerpVector(afkBlend, basePos, afkCamPos)
        view.angles = LerpAngle(afkBlend, baseAng, afkCamAng)
        view.fov = currentFOV
        view.drawviewer = true
    else
        recoilAngle = LerpAngle(FrameTime() * recoilDecay, recoilAngle, Angle(0, 0, 0))

        view.origin = pos
        view.angles = Angle(
            eyeAngles.p + camAngleOffset.p + recoilAngle.p,
            eyeAngles.y + recoilAngle.y,
            eyeAngles.r + recoilAngle.r
        )
        view.fov = currentFOV
        view.drawviewer = false
    end


    return view
end)



hook.Add("PD.Config.LoadModule", "PD.FOV", function()
    if not PD.Config.tbl.fov or not istable(PD.Config.tbl.fov) then
        PD.Config.tbl.fov = {}
        PD.Config.tbl.fov.defaultFOV = 80
        PD.Config.tbl.fov.CurrentFOV = 80
    end

    PD.FOV:Load()

    PD.Config:AddModule(LANG.ESC_CONFIG_FOV, function(base)
        PD.FOV:Menu(base)
    end)
end)