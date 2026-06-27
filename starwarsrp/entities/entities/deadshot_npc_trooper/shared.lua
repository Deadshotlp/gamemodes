AddCSLuaFile()
ENT.Base = "deadshot_npc_base"
ENT.PrintName = "Trooper"
ENT.Author = "Deadshot"
ENT.Category = "Gamemode - NPC"
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.ModelPath = "models/Combine_Soldier.mdl"
ENT.HealthAmount = 120
ENT.Alignment = "hostile"
ENT.AttackType = "ranged"
ENT.BulletDamage = 14
ENT.RangedRange = 1800
ENT.AimSkill = "realistic"

-- How long a trooper flees blindly after its Squad Leader dies
ENT.PanicDuration = 6
-- Radius used when probing for nearby cover
ENT.CoverSearchRadius = 150
-- Minimum time between cover re-evaluations (each one costs 8 traces)
ENT.CoverRecalcInterval = 1
