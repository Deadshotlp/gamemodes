AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    local model = util.IsValidModel(self.ModelPath) and self.ModelPath or "models/Combine_Soldier.mdl"
    self:SetModel(model)
    self:SetHealth(self.HealthAmount)
    self.loco:SetAcceleration(900)
    self.loco:SetDeceleration(900)
    self.loco:SetStepHeight(30)
    self.loco:SetJumpHeight(0)
    self.loco:SetDeathDropHeight(200)
    self.NextAttackTime = 0
    self.ProvokedUntil = 0
    self:SetCollisionGroup(COLLISION_GROUP_NPC)
    self:EquipWeapon(self.WeaponClass)
end

----------------------------------------------------------------
-- Held weapon (visual only - combat damage is resolved separately
-- per attack type, see MeleeAttack/RangedAttack/ThrownAttack below)
----------------------------------------------------------------

function ENT:EquipWeapon(class)
    if not isstring(class) or class == "" then return end

    local attIndex = self:LookupAttachment(self.WeaponAttachment)
    local att = attIndex > 0 and self:GetAttachment(attIndex) or nil

    local wep = ents.Create(class)
    if not IsValid(wep) then return end

    wep:SetPos(att and att.Pos or self:GetPos())
    wep:SetAngles(att and att.Ang or self:GetAngles())
    wep:Spawn()
    wep:SetOwner(self)
    wep:SetSolid(SOLID_NONE)
    wep:SetMoveType(MOVETYPE_NONE)
    wep:SetParent(self)

    if attIndex > 0 then
        wep:Fire("SetParentAttachment", self.WeaponAttachment, 0)
    end

    self.HeldWeapon = wep
end

function ENT:OnRemove()
    if IsValid(self.HeldWeapon) then
        self.HeldWeapon:Remove()
    end
end

----------------------------------------------------------------
-- Targeting / Zugehörigkeit
----------------------------------------------------------------

-- Override to customize target priority
function ENT:SelectTarget()
    if self.Alignment == "friendly" then return nil end
    if self.Alignment == "neutral" and CurTime() > self.ProvokedUntil then return nil end

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

function ENT:OnInjured(dmg)
    local attacker = dmg:GetAttacker()

    if self.Alignment == "neutral" and IsValid(attacker) and attacker:IsPlayer() then
        self.ProvokedUntil = CurTime() + self.ProvokedDuration
    end

    if self.CanRotate then
        self.loco:FaceTowards(IsValid(attacker) and attacker:GetPos() or self:GetPos())
    end
end

function ENT:OnKilled(dmg)
    self:BecomeRagdoll(dmg)
end

----------------------------------------------------------------
-- Movement / Rotation
----------------------------------------------------------------

function ENT:RunBehaviour()
    while true do
        local target = self:SelectTarget()

        if IsValid(target) then
            self:HandleCombat(target)
        elseif self.CanMove then
            self:Roam()
        else
            coroutine.wait(0.5)
        end

        coroutine.yield()
    end
end

function ENT:GetEngageRange()
    if self.AttackType == "ranged" then return self.RangedRange end
    if self.AttackType == "thrown" then return self.ThrowRange end
    return self.AttackRange
end

function ENT:FaceTarget(target)
    if not IsValid(target) then return end

    if self.CanMove then
        self.loco:FaceTowards(target:GetPos())
    elseif self.CanRotate then
        local dir = (target:GetPos() - self:GetPos()):GetNormalized()
        self:SetAngles(Angle(0, dir:Angle().y, 0))
    end
end

function ENT:HandleCombat(target)
    local engageRange = self:GetEngageRange()

    if self.CanMove then
        self:StartActivity(ACT_RUN)
        self.loco:SetDesiredSpeed(self.RunSpeed)
    end

    while IsValid(target) do
        self:FaceTarget(target)

        if self.CanMove and self:GetRangeTo(target) > engageRange then
            self:MoveToPos(target:GetPos(), {maxage = 0.8, repath = 0.25, tolerance = 20})
        end

        self:AttackTarget(target)

        if not self:Visible(target) or not target:Alive() or self:GetRangeTo(target) > self.SightRange * 1.2 then
            break
        end

        coroutine.yield()
    end

    self:StartActivity(ACT_IDLE)
end

function ENT:Roam()
    self:StartActivity(ACT_WALK)
    self.loco:SetDesiredSpeed(self.WalkSpeed)
    local roam = self:GetPos() + VectorRand() * self.RoamRadius
    roam.z = self:GetPos().z
    self:MoveToPos(roam, {maxage = 2.0})
    self:StartActivity(ACT_IDLE)
    coroutine.wait(0.5)
end

----------------------------------------------------------------
-- Combat: Nahkampf / Fernkampf / Wurfwaffen
----------------------------------------------------------------

function ENT:AttackTarget(target)
    if CurTime() < self.NextAttackTime then return end
    if not IsValid(target) then return end

    if self.AttackType == "ranged" then
        self:RangedAttack(target)
    elseif self.AttackType == "thrown" then
        self:ThrownAttack(target)
    else
        self:MeleeAttack(target)
    end
end

function ENT:GetAimSettings()
    return self.AimSkillSettings[self.AimSkill] or self.AimSkillSettings.realistic
end

-- Spreads a direction by up to spreadDegrees on pitch/yaw, scaled by aim skill
function ENT:ApplySpread(dir, spreadDegrees)
    if spreadDegrees <= 0 then return dir end

    local ang = dir:Angle()
    ang.p = ang.p + math.Rand(-spreadDegrees, spreadDegrees)
    ang.y = ang.y + math.Rand(-spreadDegrees, spreadDegrees)
    return ang:Forward()
end

function ENT:MeleeAttack(target)
    if self:GetRangeTo(target) > self.AttackRange then return end

    local dmg = DamageInfo()
    dmg:SetDamage(self.DamageAmount)
    dmg:SetAttacker(self)
    dmg:SetInflictor(self)
    dmg:SetDamageType(DMG_CLUB)
    target:TakeDamageInfo(dmg)

    self.NextAttackTime = CurTime() + self.AttackCooldown
end

function ENT:RangedAttack(target)
    if self:GetRangeTo(target) > self.RangedRange then return end
    if not self:Visible(target) then return end

    local aim = self:GetAimSettings()
    local startPos = self:GetPos() + Vector(0, 0, 60)

    local targetPos = target:GetPos() + Vector(0, 0, 40)
    if aim.lead > 0 and target.GetVelocity then
        targetPos = targetPos + target:GetVelocity() * aim.lead * 0.2
    end

    local dir = self:ApplySpread((targetPos - startPos):GetNormalized(), aim.spread)
    local owner = self

    self:FireBullets({
        Num = self.BulletsPerAttack,
        Src = startPos,
        Dir = dir,
        Spread = Vector(0, 0, 0),
        Tracer = 1,
        Force = 5,
        Damage = self.BulletDamage,
        Callback = function(_, tr, dmgInfo)
            dmgInfo:SetAttacker(owner)
            dmgInfo:SetInflictor(owner)
        end,
    })

    if self.RangedSound then
        self:EmitSound(self.RangedSound)
    end

    self.NextAttackTime = CurTime() + self.AttackCooldown
end

function ENT:ThrownAttack(target)
    if self:GetRangeTo(target) > self.ThrowRange then return end
    if not self:Visible(target) then return end

    local aim = self:GetAimSettings()
    local startPos = self:GetPos() + Vector(0, 0, 60)

    local targetPos = target:GetPos()
    if aim.lead > 0 and target.GetVelocity then
        targetPos = targetPos + target:GetVelocity() * aim.lead * 0.5
    end
    targetPos = targetPos + VectorRand() * (aim.spread * 4)

    local proj = ents.Create("deadshot_npc_thrown")
    if not IsValid(proj) then return end

    proj:SetPos(startPos)
    proj:Spawn()
    proj:Launch(self, targetPos, self.ThrowSpeed, self.ThrowDamage, self.ThrowRadius, self.ThrownModel)

    self.NextAttackTime = CurTime() + self.AttackCooldown
end
