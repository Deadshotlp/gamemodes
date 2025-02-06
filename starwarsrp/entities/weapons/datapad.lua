EVO = EVO or {}
if (SERVER) then
    AddCSLuaFile()
    SWEP.HoldType = "slam"
end

if (CLIENT) then
    SWEP.PrintName = "Datapad"
    SWEP.Author = "Progama057"
    SWEP.Contact = ""
    SWEP.Purpose = "Datapad"
    SWEP.Instructions = ""
    SWEP.Slot = 1
    SWEP.SlotPos = 1
    SWEP.DrawAmmo = false
end



SWEP.Category = "PD - Gamemode"
SWEP.Spawnable = true
SWEP.AdminSpawnable = true
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

function SWEP:Initialize()
    self.m_bInitialized = true
    self:SetWeaponHoldType("slam")
end

function SWEP:PrimaryAttack()
end

function SWEP:SecondaryAttack()
	if CLIENT then
		if not IsFirstTimePredicted() then return end

		PD.DataPad:Menu()
	end
end

function SWEP:Reload()
end

function SWEP:Think()
end
