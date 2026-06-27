AddCSLuaFile()
ENT.Base = "deadshot_npc_base"
ENT.PrintName = "NPC"
ENT.Author = "Deadshot"
ENT.Category = "Gamemode - NPC"
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.ModelPath = "models/Combine_Soldier.mdl"
ENT.HealthAmount = 150
ENT.Alignment = "hostile"
ENT.AttackType = "ranged"
ENT.BulletDamage = 14
ENT.RangedRange = 1800
ENT.AimSkill = "realistic"

-- How long this NPC flees blindly after its Squad Leader dies
ENT.PanicDuration = 6
-- Radius used when probing for nearby cover
ENT.CoverSearchRadius = 150
-- Minimum time between cover re-evaluations (each one costs 8 traces)
ENT.CoverRecalcInterval = 1

-- Set IsSquadLeader = true to make this NPC spawn and command its own
-- squad on top of its normal solo behaviour (see deadshot_npc_base).
ENT.IsSquadLeader = false
-- Name of a saved NPC Creator template used for spawned squad members.
-- Empty = spawn plain default deadshot_npc instances.
ENT.ChildTemplateName = ""
ENT.SquadSize = 9
ENT.FormationRadius = 180

-- Squad considers itself superior once it outnumbers visible enemies by this much
ENT.AdvantageRatio = 1.5
-- Squad retreats once it has lost this fraction of its members
ENT.RetreatLossThreshold = 0.5

-- How often the active fire group swaps, simulating staggered reloads
ENT.FireCycleDuration = 1.5
-- How often a Squad Leader re-evaluates targets/posture
ENT.SquadUpdateInterval = 0.2
