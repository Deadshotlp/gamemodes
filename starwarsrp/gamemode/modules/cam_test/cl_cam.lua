PD.CAM = PD.CAM or {}

PD.CAM.thirdPerson = PD.CAM.thirdPerson or false -- Start in First-Person

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

function ChangeFOVValues()
    if IsValid(Frame) then return end

    Frame = PD.Frame("FOV - Settings", PD.W(300), PD.H(400), true, function(self, w, h) end, true)
    Frame:SetPos(PD.W(10), PD.H(100))

    local pnl, slider = PD.NumSlider("Default FOV", Frame, 60, 120, defaultFOV, function(value)
        defaultFOV = value

        sprintFOV = defaultFOV + drei
        sneakFOV = defaultFOV - drei
    end)
    pnl:Dock(TOP)

    local save = PD.Button("Save", Frame, function(self)
        Frame:Remove()

        file.Write("PD_CameraSettings.json", util.TableToJSON({
            defaultFOV = defaultFOV
        }, true))
    end)
    save:Dock(BOTTOM)
end

hook.Add("EntityFireBullets", "AddCameraRecoil", function(ent, data)
    if ent == LocalPlayer() then
        -- recoilAngle.p = recoilAngle.p - math.Rand(1.0, 2.5) -- Kamera geht leicht nach oben
        -- recoilAngle.y = recoilAngle.y + math.Rand(-0.5, 10.5) -- Leichter seitlicher Rückstoß
        currentFOV = currentFOV - math.Rand(0.5, 2.5) -- FOV wird leicht verringert
    end
end)


hook.Add("CalcView", "ImmersiveCameraEffects", function(ply, pos, angles, fov)
    if not IsValid(ply) or not ply:Alive() then return end

    local velocity = ply:GetVelocity():Length2D()
    local isSprinting = velocity > 200 and ply:KeyDown(IN_SPEED)
    local isSneaking = ply:KeyDown(IN_WALK) or ply:KeyDown(IN_DUCK)
    local eyeAngles = ply:EyeAngles()

    -- FOV-State Handling
    local targetFOV = defaultFOV
    if isSprinting then
        targetFOV = sprintFOV
    elseif isSneaking then
        targetFOV = sneakFOV
    end

    currentFOV = Lerp(FrameTime() * camLerpSpeed, currentFOV, targetFOV)

    -- Headbob
    local bob = 0
    if ply:IsOnGround() and velocity > 10 and not PD.CAM.thirdPerson then
        bob = math.sin(CurTime() * bobSpeed) * (headBobIntensity * math.Clamp(velocity / 300, 0, 1))
    end
    camAngleOffset.p = Lerp(FrameTime() * camLerpSpeed, camAngleOffset.p, bob)

    local view = {}

    if PD.CAM.thirdPerson then
        local offset = Vector(-80, 0, 20)
        local targetPos = pos + eyeAngles:Forward() * offset.x + eyeAngles:Right() * offset.y + eyeAngles:Up() * offset.z

        local tr = util.TraceHull({
            start = pos,
            endpos = targetPos,
            mins = Vector(-4, -4, -4),
            maxs = Vector(4, 4, 4),
            filter = ply
        })

        view.origin = tr.HitPos
        view.angles = angles
        view.fov = currentFOV
        view.drawviewer = true
    else
        view.origin = pos
        view.angles = Angle(eyeAngles.p + camAngleOffset.p, eyeAngles.y, eyeAngles.r)
        view.fov = currentFOV
        view.drawviewer = false

        recoilAngle = LerpAngle(FrameTime() * recoilDecay, recoilAngle, Angle(0, 0, 0))

        -- Kamerawinkel aktualisieren mit Rückstoß
        view.angles = Angle(eyeAngles.p + camAngleOffset.p + recoilAngle.p, eyeAngles.y + recoilAngle.y, eyeAngles.r + recoilAngle.r)
    end

    return view
end)

