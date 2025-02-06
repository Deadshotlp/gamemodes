DEFINE_BASECLASS("seperatist_alliance_npc_base")
AddCSLuaFile()

ENT.ClassToUse = "npc_combine_s"
ENT.Model = "models/cis_npc/b1_battledroids/specialist/b1_battledroid_specialist.mdl"
ENT.WeaponProficiency = WEAPON_PROFICIENCY_VERY_GOOD
ENT.IdleChatter = "CIS.IdleTalk"
ENT.CombatChatter = "CIS.BattleTalk"
ENT.ReinforceChatter = ""
ENT.NadeThrowCall = "CIS.NadeThrow"
ENT.PainChatter = "CIS.Shot"
ENT.GotAKillChatter = "CIS.ConfirmKill"
ENT.PanicChatter = "CIS.AllyDown"
ENT.DeathSound = "CIS.Die"
ENT.Hitpoints = 50
ENT.RocketUser = false
ENT.WeaponOverideIgnore = false
ENT.GrenadeCount = 1
ENT.HasWeaponSwap = true
ENT.WeaponSwapMethod = 1
ENT.MinEngagementRange = 500
ENT.MaxEngagementRange = 0
ENT.PrimaryWeapon = ""
ENT.SecondaryWeapon = "npc_sw_weapon_rg4d_edit"
ENT.CanSpawnReinforcements = false
ENT.HasJetpack = false
ENT.AdvancedDodges = false
ENT.CanDodge = false
ENT.Spotter = true

function ENT:Initialize()
	self.DefaultWeaponLoadout = {
		"arccw_e5s"
	}
	self.BaseClass.Initialize(self) 
end
