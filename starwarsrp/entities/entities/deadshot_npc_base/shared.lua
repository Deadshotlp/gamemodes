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

-- Movement: "Moving" can walk around / chase targets, "Static" stays at spawn.
-- Rotation only matters for static NPCs (e.g. a turret that turns but never moves).
ENT.CanMove = true
ENT.CanRotate = true
ENT.WalkSpeed = 200
ENT.RunSpeed = 450
ENT.RoamRadius = 400

-- Zugehörigkeit relative to players:
-- "hostile"  -> always attacks players in sight
-- "neutral"  -> ignores players until attacked, then hostile for ProvokedDuration
-- "friendly" -> never attacks players
ENT.Alignment = "hostile"
ENT.ProvokedDuration = 8

-- Attack type: "melee" | "ranged" | "thrown"
ENT.AttackType = "melee"
ENT.DamageAmount = 20
ENT.SightRange = 2500
ENT.AttackCooldown = 1.2

-- Melee
ENT.AttackRange = 70

-- Ranged (hitscan)
ENT.RangedRange = 2000
ENT.BulletDamage = 12
ENT.BulletsPerAttack = 1
ENT.RangedSound = "Weapon_Pistol.Single"

-- Thrown (physical projectile, e.g. grenade)
ENT.ThrowRange = 1200
ENT.ThrowDamage = 60
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
