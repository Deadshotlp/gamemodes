
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    local m = self.ModelPath
    if util.IsValidModel(self.ModelPath) then
        m = self.ModelPath
    else
        m = "models/Combine_Soldier.mdl"
    end
    self:SetModel(m)
    self:SetHealth(self.HealthAmount)
    self.loco:SetAcceleration(900)
    self.loco:SetDeceleration(900)
    self.loco:SetStepHeight(30)
    self.loco:SetJumpHeight(0)
    self.loco:SetDeathDropHeight(200)
    self.NextAttackTime = 0
    self:SetCollisionGroup(COLLISION_GROUP_NPC)
end

function ENT:SelectTarget()
    local nearest, nd = nil, self.SightRange
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply:Alive() and not ply:IsFlagSet(FL_NOTARGET) then
            local d = self:GetRangeTo(ply)
            if d < nd and self:Visible(ply) then
                nearest = ply
                nd = d
            end
        end
    end
    return nearest
end

function ENT:AttackTarget(t)
    if CurTime() < self.NextAttackTime then return end
    if not IsValid(t) then return end
    if self:GetRangeTo(t) > self.AttackRange then return end
    self:EmitSound("npc/metropolice/knock2.wav", 70, 100)
    local dmg = DamageInfo()
    dmg:SetDamage(self.DamageAmount)
    dmg:SetAttacker(self)
    dmg:SetInflictor(self)
    dmg:SetDamageType(DMG_CLUB)
    t:TakeDamageInfo(dmg)
    self.NextAttackTime = CurTime() + self.AttackCooldown
end

function ENT:MoveToTarget(t)
    if not IsValid(t) then return end
    self:StartActivity(ACT_RUN)
    self.loco:FaceTowards(t:GetPos())
    self:MoveToPos(t:GetPos(), {maxage = 1, repath = 0.3, tolerance = 20})
    self:StartActivity(ACT_IDLE)
end

function ENT:RunBehaviour()
    while true do
        local target = self:SelectTarget()
        if IsValid(target) then
            self:StartActivity(ACT_RUN)
            while IsValid(target) do
                self.loco:FaceTowards(target:GetPos())
                if self:GetRangeTo(target) > self.AttackRange then
                    self:MoveToPos(target:GetPos(), {maxage = 0.8, repath = 0.25, tolerance = 20})
                end
                self:AttackTarget(target)
                if not self:Visible(target) or not target:Alive() or self:GetRangeTo(target) > self.SightRange * 1.2 then
                    break
                end
                coroutine.wait(0)
            end
            self:StartActivity(ACT_IDLE)
        else
            self:StartActivity(ACT_WALK)
            local roam = self:GetPos() + VectorRand() * 400
            roam.z = self:GetPos().z
            self:MoveToPos(roam, {maxage = 2.0})
            self:StartActivity(ACT_IDLE)
            coroutine.wait(0.5)
        end
        coroutine.yield()
    end
end

function ENT:OnInjured(dmg)
    self.loco:FaceTowards(dmg:GetAttacker() and dmg:GetAttacker():GetPos() or self:GetPos())
end

function ENT:OnKilled(dmg)
    self:BecomeRagdoll(dmg)
end
