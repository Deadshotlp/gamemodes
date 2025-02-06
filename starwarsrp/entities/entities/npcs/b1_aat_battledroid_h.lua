DEFINE_BASECLASS("seperatist_alliance_npc_base")
AddCSLuaFile()

ENT.ClassToUse = "npc_combine_s"
ENT.Model = "models/cis_npc/hydro/b1_battledroids/aat/b1_battledroid_aat.mdl"
ENT.WeaponProficiency = WEAPON_PROFICIENCY_AVERAGE
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
		"arccw_e5"
	}
	self.BaseClass.Initialize(self) 
end
