DEFINE_BASECLASS("seperatist_alliance_npc_base")
AddCSLuaFile()

ENT.ClassToUse = "npc_combine_s"
ENT.Model = "models/cis_npc/b1_battledroids/heavy/b1_battledroid_heavy.mdl"
ENT.WeaponProficiency = WEAPON_PROFICIENCY_GOOD
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
ENT.HasWeaponSwap = false
ENT.MinEngagementRange = 0
ENT.MaxEngagementRange = 0
ENT.CanSpawnReinforcements = false
ENT.HasJetpack = false
ENT.AdvancedDodges = false
ENT.CanDodge = false

function ENT:Initialize()
	self.DefaultWeaponLoadout = {
		"arccw_e5c",
		"arccw_e5c",
		"arccw_e5c",
		"arccw_sg6",
		"arccw_sg6",
		"arccw_sg6",
		"arccw_e5",
		"arccw_e5",
		"arccw_e5"
	}
	self.BaseClass.Initialize(self) 
end
