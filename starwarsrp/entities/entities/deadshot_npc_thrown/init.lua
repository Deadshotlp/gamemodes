AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel(self.DefaultModel)
    self:SetMoveType(MOVETYPE_FLYGRAVITY)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionBounds(Vector(-3, -3, -3), Vector(3, 3, 3))
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
end

-- Called by deadshot_npc_base right after Spawn()
function ENT:Launch(attacker, targetPos, speed, damage, radius, model)
    if model and util.IsValidModel(model) then
        self:SetModel(model)
    end

    self.Attacker = attacker
    self.ThrowDamage = damage or self.DefaultDamage
    self.ThrowRadius = radius or self.DefaultRadius

    local dir = (targetPos - self:GetPos()):GetNormalized()
    self:SetVelocity(dir * (speed or 800))

    self.DetonateAt = CurTime() + self.LifeTime
    self:NextThink(CurTime())
end

function ENT:Think()
    if CurTime() >= (self.DetonateAt or 0) then
        self:Detonate()
        return
    end
    self:NextThink(CurTime())
    return true
end

function ENT:Touch(other)
    if other == self.Attacker then return end
    self:Detonate()
end

function ENT:Detonate()
    if self.Detonated or not IsValid(self) then return end
    self.Detonated = true

    local dmgInfo = DamageInfo()
    dmgInfo:SetDamage(self.ThrowDamage)
    dmgInfo:SetAttacker(IsValid(self.Attacker) and self.Attacker or self)
    dmgInfo:SetInflictor(self)
    dmgInfo:SetDamageType(DMG_BLAST)
    util.BlastDamageInfo(dmgInfo, self:GetPos(), self.ThrowRadius)

    local effectData = EffectData()
    effectData:SetOrigin(self:GetPos())
    util.Effect("Explosion", effectData)

    self:Remove()
end
