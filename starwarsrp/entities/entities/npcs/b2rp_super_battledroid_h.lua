DEFINE_BASECLASS("seperatist_alliance_npc_base")
AddCSLuaFile()

ENT.ClassToUse = "npc_combine_s"
ENT.Model = "models/cis_npc/hydro/b2rp_battledroid/b2rp_battledroid.mdl"
ENT.WeaponProficiency = WEAPON_PROFICIENCY_AVERAGE
ENT.IdleChatter = "CIS.B2.IdleTalk"
ENT.CombatChatter = "CIS.B2.BattleTalk"
ENT.ReinforceChatter = ""
ENT.NadeThrowCall = ""
ENT.PainChatter = "CIS.B2.Shot"
ENT.GotAKillChatter = "CIS.B2.ConfirmKill"
ENT.PanicChatter = "CIS.B2.AllyDown"
ENT.DeathSound = "CIS.B2_Die"
ENT.Hitpoints = 100
ENT.RocketUser = true
ENT.WeaponOverideIgnore = true
ENT.GrenadeCount = 50
ENT.HasWeaponSwap = false
ENT.MinEngagementRange = 0
ENT.MaxEngagementRange = 0
ENT.CanSpawnReinforcements = false
ENT.HasJetpack = true
ENT.AdvancedDodges = false
ENT.CanDodge = false
ENT.EliteMovement = true

function ENT:Initialize()
	self.DefaultWeaponLoadout = {
		"arccw_b2_blaster"
	}
	self.BaseClass.Initialize(self) 
end
