AddCSLuaFile()
ENT.Base = "base_entity"
ENT.Type = "anim"
ENT.PrintName = "NPC Thrown Projectile"
ENT.Author = "Deadshot"
ENT.Category = "Gamemode - Base"
ENT.Spawnable = false
ENT.AdminOnly = true

-- Used by deadshot_npc_base for the "thrown weapon" attack type.
-- Not meant to be spawned directly, only via ENT:Launch() from an NPC.
ENT.DefaultModel = "models/Items/grenade01.mdl"
ENT.DefaultDamage = 60
ENT.DefaultRadius = 150
ENT.LifeTime = 3
