AddCSLuaFile("library/advanceddraw.lua")
local adraw = include("library/advanceddraw.lua")

if ( SERVER ) then
	AddCSLuaFile( "sw_datapad.lua" )
	SWEP.HoldType = "slam"
end

if ( CLIENT ) then
	SWEP.PrintName = "Datapad (edit by Deadshot)"
	SWEP.Author = "Goldermor (edit by Deadshot)"
	SWEP.Contact = ""
	SWEP.Purpose = "Datapad"
	SWEP.Instructions = "Datapad"
	SWEP.Slot = 1
	SWEP.SlotPos = 1
	SWEP.DrawAmmo = false					 

end

SWEP.Category = "PD - Gamemode"

SWEP.Spawnable= true
SWEP.AdminSpawnable= true
SWEP.AdminOnly = false

SWEP.ViewModelFOV = 50
SWEP.ViewModel = "models/swcw_items/sw_datapad_v.mdl" 
SWEP.WorldModel = "models/swcw_items/sw_datapad.mdl"
SWEP.ViewModelFlip = false

SWEP.AutoSwitchTo = true
SWEP.AutoSwitchFrom = false

SWEP.UseHands = true

SWEP.HoldType = "slam" 

SWEP.FiresUnderwater = true

SWEP.DrawCrosshair = true

SWEP.DrawAmmo = false

SWEP.Base = "weapon_base"

SWEP.Primary.Damage = 0
SWEP.Primary.ClipSize = -1 
SWEP.Primary.Delay = 0
SWEP.Primary.DefaultClip = -1 
SWEP.Primary.Automatic = false 
SWEP.Primary.Ammo = "none" 

SWEP.Secondary.ClipSize = -1 
SWEP.Secondary.DefaultClip = -1 
SWEP.Secondary.Damage = 0 
SWEP.Secondary.Automatic = false 	 
SWEP.Secondary.Ammo = "none" 

-- Default position offset
SWEP.OffsetPos = Vector(0, 0, 0)
SWEP.OffsetAng = Angle(0, 0, 0)
SWEP.SetNextPrimaryFire = CurTime()

function SWEP:Initialize() 
    self:SetWeaponHoldType( "slam" )

    self.Scale = 100
end 

function SWEP:PrimaryAttack()
    self.OffsetPos = Vector(-8, -0.2, -0.5)
    self.OffsetAng = Angle(15, 17, -2)
end

function SWEP:GetViewModelPosition(pos, ang)
    pos = pos + ang:Forward() * self.OffsetPos.x + ang:Right() * self.OffsetPos.y + ang:Up() * self.OffsetPos.z
    ang:RotateAroundAxis(ang:Right(), self.OffsetAng.p)
    ang:RotateAroundAxis(ang:Up(), self.OffsetAng.y)
    ang:RotateAroundAxis(ang:Forward(), self.OffsetAng.r)
    return pos, ang
end
	
function SWEP:SecondaryAttack()
end

function SWEP:Reload() 
end

function SWEP:ResetWeaponPos()
	self.OffsetPos = Vector(0, 0, 0)
    self.OffsetAng = Angle(0, 0, 0)
end

-- draw screen

function SWEP:PostDrawViewModel(ent, weapon, ply )
    if adraw.Entity3D2D(ent, Vector(0, 0, 0), Angle(0, 90, 90), 1 / self.Scale) then
        local w, h = 12 * self.Scale, 10 * self.Scale

        draw.RoundedBox(0, 0, 0, 100, 100, Color(255, 255, 255, 255))
    end
end