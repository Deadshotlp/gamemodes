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
ENT.RangedRange = 1800
ENT.AimSkill = "realistic"

-- How long this NPC flees blindly after its Squad Leader dies
ENT.PanicDuration = 6

-- Spawnt Trupp: spawns TroopSize child NPCs next to itself on spawn.
-- Independent of IsSquadLeader - a leader doesn't have to spawn its own
-- troop, and a troop-spawner doesn't have to command what it spawns.
ENT.SpawnsTroop = false
ENT.TroopSize = 9
-- Name of a saved NPC Creator template used for spawned troop members.
-- Empty = spawn plain default deadshot_npc instances.
ENT.ChildTemplateName = ""
ENT.FormationRadius = 180

-- Squadleader: periodically claims nearby uncommanded, same-faction NPCs
-- (including ones it didn't spawn itself) and commands them as a squad.
ENT.IsSquadLeader = false
ENT.MaxSquadSize = 9
ENT.CommandClaimRadius = 1000

-- Squad considers itself superior once it outnumbers visible enemies by this much
ENT.AdvantageRatio = 1.5
-- Squad retreats once it has lost this fraction of its members
ENT.RetreatLossThreshold = 0.5

-- How often the active fire group swaps, simulating staggered reloads
ENT.FireCycleDuration = 1.5
-- How often a Squad Leader re-evaluates targets/posture/claims troops
ENT.SquadUpdateInterval = 0.2
