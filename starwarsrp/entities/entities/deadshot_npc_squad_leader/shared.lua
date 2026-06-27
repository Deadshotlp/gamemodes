AddCSLuaFile()
ENT.Base = "deadshot_npc_base"
ENT.PrintName = "Squad Leader"
ENT.Author = "Deadshot"
ENT.Category = "Gamemode - NPC"
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.ModelPath = "models/Combine_Soldier.mdl"
ENT.HealthAmount = 180
ENT.Alignment = "hostile"
ENT.AttackType = "ranged"
ENT.BulletDamage = 16
ENT.RangedRange = 1800
ENT.AimSkill = "better"

-- Squad composition
ENT.SquadSize = 9
ENT.FormationRadius = 180

-- Squad considers itself superior once it outnumbers visible enemies by this much
ENT.AdvantageRatio = 1.5
-- Squad retreats once it has lost this fraction of its troopers
ENT.RetreatLossThreshold = 0.5

-- How often the active fire group swaps, simulating staggered reloads
ENT.FireCycleDuration = 1.5
-- How often the squad re-evaluates targets/posture
ENT.SquadUpdateInterval = 0.2
