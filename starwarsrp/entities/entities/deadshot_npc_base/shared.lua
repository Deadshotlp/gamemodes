AddCSLuaFile()
ENT.Base = "base_nextbot"
ENT.Type = "nextbot"
ENT.PrintName = "NPC Base"
ENT.Author = "Deadshot"
ENT.Category = "Gamemode - Base"
ENT.Spawnable = false
ENT.AdminOnly = true

-- Override these in entities that inherit from this base

-- Model / Health
ENT.ModelPath = "models/Combine_Soldier.mdl"
ENT.HealthAmount = 200

-- Visually held weapon. Also drives combat damage/fire rate (see
-- GetWeaponDamage/GetWeaponCooldown below) and fixes T-posing on models
-- like Combine_Soldier that expect a weapon hold-type for their
-- animations. "" = no weapon.
ENT.WeaponClass = "weapon_pistol"
ENT.WeaponAttachment = "anim_attachment_RH"
-- Used only when no weapon is equipped, or the weapon defines no Primary.Damage/Delay
ENT.FallbackDamage = 14
ENT.FallbackCooldown = 1.2

-- Movement: "Moving" can walk around / chase targets, "Static" stays at spawn.
-- Rotation only matters for static NPCs (e.g. a turret that turns but never moves).
ENT.CanMove = true
ENT.CanRotate = true
ENT.WalkSpeed = 200
ENT.RunSpeed = 450
ENT.RoamRadius = 400
-- Name of a saved patrol route (see PD.PatrolRoutes) to walk instead of
-- random wandering. "" = wander randomly.
ENT.PatrolRoute = ""

-- Zugehörigkeit relative to players:
-- "hostile"  -> always attacks players in sight
-- "neutral"  -> ignores players until attacked, then hostile for ProvokedDuration
-- "friendly" -> never attacks players
ENT.Alignment = "hostile"
ENT.ProvokedDuration = 8

-- Faction-based NPC-vs-NPC hostility. Faction is this NPC's own faction
-- ("" = none). HostileFactions is a set ({factionName = true, ...}) of
-- other factions this NPC will also target, in addition to players.
ENT.Faction = ""
ENT.HostileFactions = {}

-- Seeks cover when it can't see its target instead of standing still.
-- Cheap heuristic (see FindCoverPosition) - not a real nav-mesh cover system.
ENT.SeeksCover = true
ENT.CoverSearchRadius = 150
ENT.CoverRecalcInterval = 1

-- Flees (or stands down) once health drops to/below this ratio of max health.
ENT.CanSurrender = false
ENT.SurrenderHealthRatio = 0.25
ENT.SurrenderBehavior = "flee" -- "flee" | "surrender"

-- Attack type: "melee" | "ranged" | "thrown"
ENT.AttackType = "melee"
ENT.SightRange = 2500

-- Melee
ENT.AttackRange = 70

-- Ranged (hitscan)
ENT.RangedRange = 2000
ENT.BulletsPerAttack = 1
ENT.RangedSound = "Weapon_Pistol.Single"

-- Thrown (physical projectile, e.g. grenade)
ENT.ThrowRange = 1200
ENT.ThrowRadius = 150
ENT.ThrowSpeed = 800
ENT.ThrownModel = "models/Items/grenade01.mdl"

-- Aim skill: "dumb" | "realistic" | "better" - controls spread/reaction/target leading
ENT.AimSkill = "realistic"
ENT.AimSkillSettings = {
    dumb       = {spread = 12,  reaction = 0.6,  lead = 0},
    realistic  = {spread = 4,   reaction = 0.25, lead = 0.5},
    better     = {spread = 0.5, reaction = 0.05, lead = 1},
}
