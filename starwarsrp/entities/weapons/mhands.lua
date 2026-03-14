
if SERVER then
    AddCSLuaFile()
end

SWEP.PrintName = 'Hands and Drag'
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
    ["Komlink"] = {
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
    ["Arme verschränken"] = {
        ['ValveBiped.Bip01_R_Forearm'] = Angle(-43, -107, 15),
        ['ValveBiped.Bip01_R_UpperArm'] = Angle(20, -57, -6),
        ['ValveBiped.Bip01_L_UpperArm'] = Angle(-28, -59, 1),
        ['ValveBiped.Bip01_R_Thigh'] = Angle(4, -6, -0),
        ['ValveBiped.Bip01_L_Thigh'] = Angle(-7, -0, 0),
        ['ValveBiped.Bip01_L_Forearm'] = Angle(51, -120, -18),
        ['ValveBiped.Bip01_R_Hand'] = Angle(14, -33, -7),
        ['ValveBiped.Bip01_L_Hand'] = Angle(25, 31, -14)
    },
    ["Haltung annehmen"] = {
        ['ValveBiped.Bip01_R_UpperArm'] = Angle(3, 15, 2),
        ['ValveBiped.Bip01_R_Forearm'] = Angle(-63, 1 , -84),
        ['ValveBiped.Bip01_L_UpperArm'] = Angle(3, 15, 2.654),
        ['ValveBiped.Bip01_L_Forearm'] = Angle(53, -29, 31),
        ['ValveBiped.Bip01_R_Thigh'] = Angle(4, 0, 0),
        ['ValveBiped.Bip01_L_Thigh'] = Angle(-8, 0, 0)
    },
    ["Gib mir fünf"] = {
        ['ValveBiped.Bip01_L_Forearm'] = Angle(25,-65,25),
        ['ValveBiped.Bip01_L_UpperArm'] = Angle(-70,-180,70)
    },
    ["Holoübertragung"] = {
        ['ValveBiped.Bip01_R_UpperArm'] = Angle(10,-20),
        ['ValveBiped.Bip01_R_Hand'] = Angle(0,1,50),
        ['ValveBiped.Bip01_Head1'] = Angle(0,-30,-20),
        ['ValveBiped.Bip01_R_Forearm'] = Angle(0,-65,39.8863)
    },
    ["Zeigen"] = {
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
    ["Arme hinter Kopf"] = {
        ['ValveBiped.Bip01_L_Forearm'] = Angle(25,-115,15),
        ['ValveBiped.Bip01_R_Forearm'] = Angle(-32,-115,-15),
        ['ValveBiped.Bip01_L_UpperArm'] = Angle(-50,-210,80),
        ['ValveBiped.Bip01_R_UpperArm'] = Angle(50,-210,-80)
    },
    ["Arme am Gürtel"] = {
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
    ["Tippen"] = {
        ['ValveBiped.Bip01_L_Forearm'] = Angle(0,0,0),
        ['ValveBiped.Bip01_R_Forearm'] = Angle(0,0,0),
        ['ValveBiped.Bip01_L_UpperArm'] = Angle(-28,-65,50),
        ['ValveBiped.Bip01_R_UpperArm'] = Angle(20,-65,-50),
    },
    -- ["test"] = {
    --     ['ValveBiped.Bip01_R_UpperArm'] = Angle(35, -140, 0),
    --     ['ValveBiped.Bip01_R_Forearm'] = Angle(-10, 0, 0),
    --     ['ValveBiped.Bip01_R_Hand'] = Angle(0,0,-90),
    -- }
}

local isAnimating = false
if SERVER then
    util.AddNetworkString("SetPlayerAnimation")
    util.AddNetworkString("ResetPlayerAnimation")

    net.Receive("SetPlayerAnimation", function(len, ply)
        local id = net.ReadString()

        if anima[id] then
            ply:SetNWString("mhands_anim", id)
        else
            ply:SetNWString("mhands_anim", "")
        end
    end)

    net.Receive("ResetPlayerAnimation", function(len, ply)
        ply:SetNWString("mhands_anim", "")
    end)
elseif CLIENT then
    function SendAnimationToServer(anim)
        net.Start("SetPlayerAnimation")
        net.WriteString(anim)
        net.SendToServer()
    end

    function ResetAnimationOnServer()
        net.Start("ResetPlayerAnimation")
        net.SendToServer()
    end

    local function CopyAngle(a)
        return Angle(a.p, a.y, a.r)
    end

    local function AddAngles(a, b)
        return Angle(a.p + b.p, a.y + b.y, a.r + b.r)
    end

    local function RestoreMHandsBones(ply)
        if not ply.mhandsBaseAngles then return end

        for boneID, baseAng in pairs(ply.mhandsBaseAngles) do
            ply:ManipulateBoneAngles(boneID, baseAng)
        end

        ply.mhandsBaseAngles = nil
    end

    hook.Add("PostPlayerDraw", "mhands_anim_draw", function(ply)
        local id = ply:GetNWString("mhands_anim", "")
        if id == "" then return end

        local tbl = anima[id]
        if not tbl then return end

        if ply.mhandsLastAnim ~= id then
            -- Restore previous mhands offsets before changing to a new hand animation.
            RestoreMHandsBones(ply)
            ply.mhandsBaseAngles = {}

            for bone, _ in pairs(tbl) do
                local boneID = ply:LookupBone(bone)
                if boneID then
                    local cur = ply:GetManipulateBoneAngles(boneID) or angle_zero
                    ply.mhandsBaseAngles[boneID] = CopyAngle(cur)
                end
            end

            ply.mhandsLerp = 0
            ply.mhandsLastAnim = id
        end

        ply.mhandsLerp = ply.mhandsLerp or 0
        ply.mhandsLerp = Lerp(FrameTime() * 8, ply.mhandsLerp, 1)

        for bone, ang in pairs(tbl) do
            local boneID = ply:LookupBone(bone)
            if boneID then
                local baseAng = (ply.mhandsBaseAngles and ply.mhandsBaseAngles[boneID]) or angle_zero
                local targetAng = AddAngles(baseAng, ang * ply.mhandsLerp)
                local cur = ply:GetManipulateBoneAngles(boneID) or angle_zero
                local newAng = LerpAngle(FrameTime() * 8, cur, targetAng)
                ply:ManipulateBoneAngles(boneID, newAng)
            end
        end
    end)

    hook.Add("Think", "mhands_reset_anim", function()
        for _, ply in ipairs(player.GetAll()) do
            local id = ply:GetNWString("mhands_anim", "")

            if id == "" and ply.mhandsWasAnimating then
                RestoreMHandsBones(ply)
                ply.mhandsWasAnimating = false
                ply.mhandsLerp = 0
                ply.mhandsLastAnim = nil
            elseif id ~= "" then
                ply.mhandsWasAnimating = true
            end
        end
    end)



    hook.Add("PlayerButtonDown", "ResetAnimationKeys", function(ply, key)
        if not ply:HasWeapon("mhands") then return end
        if not isAnimating then return end
    
        if key == KEY_R or key == KEY_W or key == KEY_A or key == KEY_S or key == KEY_D or key == KEY_SPACE or key == KEY_LSHIFT or key == KEY_LCONTROL then
            ResetAnimationOnServer()
            -- ResetPlayerModel(ply)
            isAnimating = false

            print("Animation abgebrochen")
        end
    end) 

    function HandsMenuRadial(ply)
        if IsValid(base) then return end

        base = vgui.Create("DFrame")
        base:SetSize(ScrW(), ScrH())
        base:SetTitle("")
        base:SetDraggable(false)
        base:ShowCloseButton(false)
        base:MakePopup()
        base:SetBackgroundBlur(true)
        base.Paint = function() end

        local radius = PD.W(350)
        local centerX, centerY = ScrW() / 2, ScrH() / 2
        local buttonSize = PD.W(125)
        local count = table.Count(anima)
        local angleStep = 360 / count
        local i = 0

        for name, _ in SortedPairs(anima) do
            local angle = math.rad(i * angleStep - 90)
            local x = centerX + math.cos(angle) * radius - buttonSize / 2
            local y = centerY + math.sin(angle) * radius - buttonSize / 2

            -- local btn = vgui.Create("DButton", base)
            -- btn:SetText(name)
            -- btn:SetSize(buttonSize, buttonSize)
            -- btn:SetPos(x, y)
            -- btn:SetFont("MLIB.15")
            -- btn:SetTextColor(Color(255, 255, 255))
            -- btn.Paint = function(s, w, h)
            --     draw.RoundedBox(20, 0, 0, w, h, Color(50, 50, 50, 200))
            --     -- draw.SimpleText(name, "DermaLarge", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            -- end
            -- btn.DoClick = function()
            --     SendAnimationToServer(name)
            --     base:Remove()

            --     isAnimating = true
            -- end

            local model_panel = PD.Panel(base, {}, function(self, w, h)
                --surface.SetDrawColor(50, 50, 50, 200)
                --surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.RoundedBox( 15, 0, 0, w, h, PD.Theme.Colors.BackgroundTransparent )
            end)
            model_panel:Dock(NODOCK)
            model_panel:SetSize(buttonSize, buttonSize)
            model_panel:SetPos(x, y)

            local model = PD.Model(model_panel, LocalPlayer():GetModel(), 0, 0, buttonSize, buttonSize, {canRotate = false, canZoom = false})
            model:SetFOV( 50 )

            function model:OnMousePressed( k )
                if k == MOUSE_LEFT then
                    SendAnimationToServer(name)
                    base:Remove()

                    isAnimating = true
                end
            end

            for bone, ang in pairs(_) do
                local boneID = model:GetEntity():LookupBone(bone)
                if boneID then
                    model:GetEntity():ManipulateBoneAngles(boneID, ang)
                end
            end

            i = i + 1
        end

        base.OnMousePressed = function(_, code)
            if code == MOUSE_RIGHT then
                base:Remove()
            end
        end
    end
end

function SWEP:SecondaryAttack()
    if not CLIENT then return end

    if not isAnimating then 
        HandsMenuRadial(self.Owner)
    else
        ResetAnimationOnServer()
        isAnimating = false
    end
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
    draw.SimpleText("Objekt mit Links-click bewegen", "MLIB.25", w() / 2, h() - PD.H(200), clrWhite, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    surface.SetAlphaMultiplier(1)

    local pulsateSpeed = (math.cos(CurTime() * 0.5) + 0.5)

    local hintsPos = h() - 200
    -- if MODULE.camera.isActive and mvp.config.Get('freelook') then
    --     local x, y = draw.SimpleText(mvp.language.Get('ph#RLook'), 'perfecthands.hint', w() * .5, hintsPos, Color(255,255,255, 255 * pulsateSpeed), TEXT_ALIGN_CENTER)
    --     hintsPos = hintsPos + y
    -- end


    if self.Owner:GetNWString("mhands_anim", "") ~= "" then
        local x, y = draw.SimpleText("R - Zum beenden", "MLIB.25", w() * .5, hintsPos, Color(255,255,255, 255 * pulsateSpeed), TEXT_ALIGN_CENTER)
        hintsPos = hintsPos + y
    else
        draw.SimpleText("Rechts-click zum Öffnen", "MLIB.25", w() * .5, hintsPos, Color(255,255,255, 255 * pulsateSpeed), TEXT_ALIGN_CENTER)
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