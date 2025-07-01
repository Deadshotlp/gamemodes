
if SERVER then
    AddCSLuaFile()
end

SWEP.PrintName = 'Hacking Tool'
SWEP.Author = 'PD - Gamemode'
SWEP.Purpose = ''
SWEP.Spawnable = true
SWEP.Category = 'PD - Gamemode'
SWEP.ViewModel = 'models/weapons/c_medkit.mdl'
SWEP.WorldModel = ''
SWEP.AnimPrefix = 'rpg'
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = 'none'
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = 'none'
SWEP.DrawCrosshair = false

function SWEP:Initialize()
    self:SetHoldType('normal')
    self.range = 100

    self.ownerPos = Vector(0, 0, 0)
    self.ownerAim = Vector(0, 0, 0)
end

function SWEP:Think()
    self.ownerPos = self.Owner:GetShootPos()
    self.ownerAim = self.Owner:GetAimVector()

    if self.dragInfo then
        if not self.Owner:KeyDown(IN_ATTACK) then
            self.dragInfo = nil
        end
    end

end

function SWEP:CanDragEntity(ent)
    return  ( IsValid(ent) ) and
            (not ent:IsPlayer() ) and
            ( not IsValid(ent:GetParent()) ) and
            ( ent:GetMoveType() == MOVETYPE_VPHYSICS ) and
            ( not ent:IsVehicle() )
            --( not MODULE.config.blacklist[ent:GetClass()] )
end

function SWEP:TraceEntity()
    local tr = util.TraceLine({
        start = self.ownerPos,
        endpos = self.ownerPos + self.ownerAim * self.range,
        filter = self.Owner
    })

    return tr
end

local maxVolume = math.pow(10, 5.85)
function SWEP:DragEntity()
    if not self.dragInfo then return end
    if not IsValid(self.dragInfo.ent) then return end

    local physObject = self.dragInfo.ent:GetPhysicsObject()

    if not IsValid(physObject) then return end
    
    if physObject:GetVolume() > maxVolume then return end

    local pos = self.ownerPos + self.ownerAim * self.range * self.dragInfo.fraction
    local offset = self.dragInfo.ent:LocalToWorld( self.dragInfo.offset )

    local applyPos = pos - offset

    local force = (applyPos:GetNormal() * math.min(1, applyPos:Length() / 100) * 500 - physObject:GetVelocity()) * (physObject:GetMass() / 1)

    physObject:ApplyForceOffset(force, offset)
    physObject:AddAngleVelocity( - physObject:GetAngleVelocity() * 0.25)
end

function SWEP:PrimaryAttack()
    if not self.dragInfo then
        local tr = self:TraceEntity()
    
        local ent = tr.Entity

        if not self:CanDragEntity(ent) then return end

        self.dragInfo = {
            ent = ent,
            offset = ent:WorldToLocal(tr.HitPos),
            fraction = tr.Fraction
        }
    end

    if CLIENT then return end

    self:DragEntity()
end

local anima = {
    ["Comlink"] = {
        ['ValveBiped.Bip01_R_UpperArm'] = Angle(32.9448, -103.5211, 2.2273),
        ['ValveBiped.Bip01_R_Forearm'] = Angle(-90.3271, -31.3616, -41.8804),
        ['ValveBiped.Bip01_R_Hand'] = Angle(0,0,-24)
    },
    ["Ergeben"] = {
        ['ValveBiped.Bip01_L_Forearm'] = Angle(25, -65, 25),
        ['ValveBiped.Bip01_R_Forearm'] = Angle(-25, -65, -25),
        ['ValveBiped.Bip01_L_UpperArm'] = Angle(-70, -180, 70),
        ['ValveBiped.Bip01_R_UpperArm'] = Angle(70, -180, -70)
    },
    ["Arme nach Vorne"] = {
        ['ValveBiped.Bip01_R_Forearm'] = Angle(-43, -107, 15),
        ['ValveBiped.Bip01_R_UpperArm'] = Angle(20, -57, -6),
        ['ValveBiped.Bip01_L_UpperArm'] = Angle(-28, -59, 1),
        ['ValveBiped.Bip01_R_Thigh'] = Angle(4, -6, -0),
        ['ValveBiped.Bip01_L_Thigh'] = Angle(-7, -0, 0),
        ['ValveBiped.Bip01_L_Forearm'] = Angle(51, -120, -18),
        ['ValveBiped.Bip01_R_Hand'] = Angle(14, -33, -7),
        ['ValveBiped.Bip01_L_Hand'] = Angle(25, 31, -14)
    },
    ["Arme nach Hinten"] = {
        ['ValveBiped.Bip01_R_UpperArm'] = Angle(3, 15, 2),
        ['ValveBiped.Bip01_R_Forearm'] = Angle(-63, 1 , -84),
        ['ValveBiped.Bip01_L_UpperArm'] = Angle(3, 15, 2.654),
        ['ValveBiped.Bip01_L_Forearm'] = Angle(53, -29, 31),
        ['ValveBiped.Bip01_R_Thigh'] = Angle(4, 0, 0),
        ['ValveBiped.Bip01_L_Thigh'] = Angle(-8, 0, 0)
    },
    ["highfive"] = {
        ['ValveBiped.Bip01_L_Forearm'] = Angle(25,-65,25),
        ['ValveBiped.Bip01_L_UpperArm'] = Angle(-70,-180,70)
    },
    ["hololink"] = {
        ['ValveBiped.Bip01_R_UpperArm'] = Angle(10,-20),
        ['ValveBiped.Bip01_R_Hand'] = Angle(0,1,50),
        ['ValveBiped.Bip01_Head1'] = Angle(0,-30,-20),
        ['ValveBiped.Bip01_R_Forearm'] = Angle(0,-65,39.8863)
    },
    ["Finger"] = {
        ['ValveBiped.Bip01_R_Finger2'] = Angle(4, -52, 0),
        ['ValveBiped.Bip01_R_Finger21'] = Angle(0, -58, 0),
        ['ValveBiped.Bip01_R_Finger3'] = Angle(4, -52, 0),
        ['ValveBiped.Bip01_R_Finger31'] = Angle(0, -58, 0),
        ['ValveBiped.Bip01_R_Finger4'] = Angle(4, -52, 0),
        ['ValveBiped.Bip01_R_Finger41'] = Angle(0, -58, 0),
        ['ValveBiped.Bip01_R_UpperArm'] = Angle(25, -87, -0)
    },
    ["Salutieren"] = {
        ['ValveBiped.Bip01_R_UpperArm'] = Angle(80, -95, -77.5),
        ['ValveBiped.Bip01_R_Forearm'] = Angle(35, -125, -5)
    },
    ["Arme hinter dem Kopf"] = {
        ['ValveBiped.Bip01_L_Forearm'] = Angle(25,-115,15),
        ['ValveBiped.Bip01_R_Forearm'] = Angle(-32,-115,-15),
        ['ValveBiped.Bip01_L_UpperArm'] = Angle(-50,-210,80),
        ['ValveBiped.Bip01_R_UpperArm'] = Angle(50,-210,-80)
    },
    ["armsonbelt"] = {
        ['ValveBiped.Bip01_L_Forearm'] = Angle(50,-90,5),
        ['ValveBiped.Bip01_R_Forearm'] = Angle(-50,-90,5),
        ['ValveBiped.Bip01_L_UpperArm'] = Angle(-40,30,-20),
        ['ValveBiped.Bip01_R_UpperArm'] = Angle(40,30,20)
    },
    ["Nachdenken"] = {
        ['ValveBiped.Bip01_R_Forearm'] = Angle(-14.4,-106.18412780762,76.318969154358),
        ['ValveBiped.Bip01_R_UpperArm'] = Angle(23.656689071655, -58.723915100098, -5.3269416809082),
        ['ValveBiped.Bip01_L_UpperArm'] = Angle(-28.913911819458, -59.408206939697, 1.0253102779388),
        ['ValveBiped.Bip01_R_Thigh'] = Angle(4.7250719070435, -6.0294013023376, -0.46876749396324),
        ['ValveBiped.Bip01_L_Thigh'] = Angle(-7.6583762168884, -0.21996378898621, 0.4060270190239),
        ['ValveBiped.Bip01_L_Forearm'] = Angle(51.038677215576, -120.44165039063, -18.86986541748),
        ['ValveBiped.Bip01_R_Hand'] = Angle(-6.224224853516, -7.906204223633, 10.8624106407166),
        ['ValveBiped.Bip01_L_Hand'] = Angle(25.959447860718, 31.564517974854, -14.979378700256)
    },
    ["typing"] = {
        ['ValveBiped.Bip01_L_Forearm'] = Angle(0,0,0),
        ['ValveBiped.Bip01_R_Forearm'] = Angle(0,0,0),
        ['ValveBiped.Bip01_L_UpperArm'] = Angle(-28,-65,50),
        ['ValveBiped.Bip01_R_UpperArm'] = Angle(20,-65,-50),
    },
    ["test"] = {
        ['ValveBiped.Bip01_R_UpperArm'] = Angle(35, -140, 0),
        ['ValveBiped.Bip01_R_Forearm'] = Angle(-10, 0, 0),
        ['ValveBiped.Bip01_R_Hand'] = Angle(0,0,-90),
    }
}

local function ResetPlayerModel(ply)
    local model = ply:GetModel()

    if IsValid(ply) and ply:IsPlayer() then
        local boneCount = ply:GetBoneCount()

        if boneCount then
            for bone = 0, boneCount - 1 do
                ply:ManipulateBonePosition(bone, vector_origin)
                ply:ManipulateBoneAngles(bone, angle_zero)
            end
        end
    end
end

local function AnimationEvent(ply, val, id)
    local tbl = anima[id]

    if not tbl then return end

    animaangle = Lerp(FrameTime() * 5, animaangle or 0, val)

    for bone, angle in pairs(tbl) do
        local boneID = ply:LookupBone(bone)

        if boneID then
            local currentAngle = ply:GetManipulateBoneAngles(boneID)
            local newAngle = Lerp(FrameTime() * 5, currentAngle, angle * animaangle)

            ply:ManipulateBoneAngles(boneID, newAngle)
        end
    end
end

local function HandsMenuMario(ply)
    if IsValid(base) then return end

    base = PD.Frame("Animations Menu", PD.W(400), PD.H(700), true)

    local scrl = PD.Scroll(base)

    for k, v in SortedPairs(anima) do
        local aniBTN = PD.Button(k, scrl, function()
            -- if IsValid(ply) then
            --     local model = ply:GetModel()

            --     -- for bone, angle in pairs(v.ang) do
            --     --     -- Smooth the bone movement
            --     --     local currentAngle = ply:GetManipulateBoneAngles(ply:LookupBone(bone))
            --     --     local newAngle = Lerp(FrameTime() * (5), currentAngle, angle)

            --     --     ply:ManipulateBoneAngles(ply:LookupBone(bone), newAngle)

                    
            --     -- end
            -- end

            ply.isanimation = k
            base:Remove()
        end)
        aniBTN:Dock(TOP)
    end
end

function SWEP:SecondaryAttack()
    if not self.Owner.isanimation then 
        HandsMenuMario(self.Owner)
    end
end

if CLIENT then
    hook.Add("PlayerButtonDown","ResetAnimationMario",function(ply,key)
        if (key == KEY_R) then
            if ply.isanimation and ply:HasWeapon("mhands") then 
                ResetPlayerModel(ply)
                ply.isanimation = false
            else
                return
            end
        elseif (key == MOUSE_LEFT) then
            if ply.isanimation and ply:HasWeapon("mhands") then 
                ResetPlayerModel(ply)
                ply.isanimation = false
            else
                return
            end
        end
    end)
end

hook.Add("Think", "PlayerAnimationStarthands", function()
    for _, ply in pairs(player.GetAll()) do
        if ply.isanimation then
            AnimationEvent(ply, 1, ply.isanimation)
        else
            AnimationEvent(ply, 0, ply.isanimation)
        end
    end
end)

if SERVER then
    return 
end

local w, h = ScrW, ScrH
local clrWhite = Color(255, 255, 255)

function SWEP:DrawHUD()
    if IsValid(self.Owner:GetVehicle()) then return end

    local tr = self:TraceEntity()
    local showIndicator = (IsValid(tr.Entity) and self:CanDragEntity(tr.Entity)) or self.dragInfo
    local showIndicatorHint = (IsValid(tr.Entity) and self:CanDragEntity(tr.Entity)) and not self.dragInfo

    self.alphaMult = Lerp(FrameTime() * 10, self.alphaMult or 0, showIndicator and 1 or 0)
    self.alphaMultHint = Lerp(FrameTime() * 10, self.alphaMultHint or 0, showIndicatorHint and 1 or 0)

    
    surface.SetAlphaMultiplier(self.alphaMultHint)

    draw.RoundedBox(100, w() / 2 - 2.5, h() / 2 - 2.5, 5, 5, clrWhite)
    draw.SimpleText("Objekt mit Links-click bewegen", "MLIB.25", w() / 2, h() - PG.H(120), clrWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    surface.SetAlphaMultiplier(1)

    local pulsateSpeed = (math.cos(CurTime() * 0.5) + 0.5)

    local hintsPos = h() - 150
    -- if MODULE.camera.isActive and mvp.config.Get('freelook') then
    --     local x, y = draw.SimpleText(mvp.language.Get('ph#RLook'), 'perfecthands.hint', w() * .5, hintsPos, Color(255,255,255, 255 * pulsateSpeed), TEXT_ALIGN_CENTER)
    --     hintsPos = hintsPos + y
    -- end


    if self.Owner.isanimation then
        local x, y = draw.SimpleText("R - Zum beenden", "MLIB.25", w() * .5, hintsPos, Color(255,255,255, 255 * pulsateSpeed), TEXT_ALIGN_CENTER)
        hintsPos = hintsPos + y
    else
        draw.SimpleText("Recht-click zum Öffnen", "MLIB.25", w() * .5, hintsPos, Color(255,255,255, 255 * pulsateSpeed), TEXT_ALIGN_CENTER)
    end

    if not self.dragInfo then
        return 
    end

    if not IsValid(self.dragInfo.ent) then
        return 
    end

    local offset = self.dragInfo.ent:LocalToWorld( self.dragInfo.offset ):ToScreen()
    surface.SetDrawColor( clrWhite )
    surface.DrawLine( offset.x, offset.y, w() * .5, h() * .5, clrWhite )
end

function SWEP:PreDrawViewModel()
    return true
end