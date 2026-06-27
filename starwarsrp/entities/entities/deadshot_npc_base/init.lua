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
-- Held weapon - visual hold + the source of truth for combat damage
-- and fire rate (falls back to FallbackDamage/FallbackCooldown when
-- no weapon is equipped or it defines no Primary.Damage/Delay)
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

function ENT:GetWeaponDamage()
    if IsValid(self.HeldWeapon) and istable(self.HeldWeapon.Primary) and self.HeldWeapon.Primary.Damage then
        return self.HeldWeapon.Primary.Damage
    end
    return self.FallbackDamage
end

function ENT:GetWeaponCooldown()
    if IsValid(self.HeldWeapon) and istable(self.HeldWeapon.Primary) and self.HeldWeapon.Primary.Delay then
        return self.HeldWeapon.Primary.Delay
    end
    return self.FallbackCooldown
end

function ENT:OnRemove()
    if IsValid(self.HeldWeapon) then
        self.HeldWeapon:Remove()
    end
end

----------------------------------------------------------------
-- Targeting / Zugehörigkeit / Fraktionen
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
                nearest, nd = ply, d
            end
        end
    end

    if next(self.HostileFactions or {}) then
        for _, npc in ipairs(ents.FindByClass("deadshot_npc")) do
            if npc ~= self and IsValid(npc) and npc:Health() > 0 and self.HostileFactions[npc.Faction] then
                local d = self:GetRangeTo(npc)
                if d < nd and self:Visible(npc) then
                    nearest, nd = npc, d
                end
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
-- Surrender / Flee at low health (independent of squad retreat logic)
----------------------------------------------------------------

function ENT:ShouldSurrender()
    if not self.CanSurrender then return false end
    return self:Health() / math.max(self:GetMaxHealth(), 1) <= self.SurrenderHealthRatio
end

function ENT:DoSurrender()
    if self.SurrenderBehavior == "surrender" then
        self:StartActivity(ACT_IDLE)
        return
    end

    local target = self:SelectTarget()
    local awayDir

    if IsValid(target) then
        awayDir = (self:GetPos() - target:GetPos()):GetNormalized()
    else
        awayDir = VectorRand()
    end

    local fleeTo = self:GetPos() + awayDir * 500

    self.loco:SetDesiredSpeed(self.RunSpeed)
    self:StartActivity(ACT_RUN)
    self:MoveToPos(fleeTo, {maxage = 0.5, repath = 0.4, tolerance = 40})
end

----------------------------------------------------------------
-- Movement / Rotation / Deckung
----------------------------------------------------------------

function ENT:RunBehaviour()
    while true do
        if self:ShouldSurrender() then
            self:DoSurrender()
        else
            local target = self:SelectTarget()

            if IsValid(target) then
                self:HandleCombat(target)
            elseif self.CanMove then
                self:Roam()
            else
                coroutine.wait(0.5)
            end
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

-- Probes points around self for a spot whose line of sight to the threat is
-- blocked - a cheap stand-in for a real cover system, since nextbots have
-- no built-in cover-node integration.
function ENT:FindCoverPosition(threatPos)
    local myPos = self:GetPos()

    for i = 1, 8 do
        local ang = (360 / 8) * i
        local testPos = myPos + Angle(0, ang, 0):Forward() * self.CoverSearchRadius

        local tr = util.TraceLine({
            start = testPos + Vector(0, 0, 40),
            endpos = threatPos,
            filter = self,
        })

        if tr.Hit and tr.HitPos:Distance(threatPos) > 40 then
            return testPos
        end
    end

    return nil
end

function ENT:GetCoverPosition(threatPos)
    if self.NextCoverRecalc and CurTime() < self.NextCoverRecalc then
        return self.CachedCoverPos
    end

    self.CachedCoverPos = self:FindCoverPosition(threatPos)
    self.NextCoverRecalc = CurTime() + self.CoverRecalcInterval
    return self.CachedCoverPos
end

function ENT:HandleCombat(target)
    local engageRange = self:GetEngageRange()

    if self.CanMove then
        self:StartActivity(ACT_RUN)
        self.loco:SetDesiredSpeed(self.RunSpeed)
    end

    while IsValid(target) do
        self:FaceTarget(target)

        if self.CanMove and self.SeeksCover and not self:Visible(target) then
            local cover = self:GetCoverPosition(target:GetPos())
            if cover then
                self:MoveToPos(cover, {maxage = 0.6, repath = 0.3, tolerance = 30})
            end
        elseif self.CanMove and self:GetRangeTo(target) > engageRange then
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
    if self.PatrolRoute ~= "" and PD.PatrolRoutes then
        local route = PD.PatrolRoutes.Routes[self.PatrolRoute]
        if route and #route > 0 then
            self:WalkPatrolRoute(route)
            return
        end
    end

    self:StartActivity(ACT_WALK)
    self.loco:SetDesiredSpeed(self.WalkSpeed)
    local roam = self:GetPos() + VectorRand() * self.RoamRadius
    roam.z = self:GetPos().z
    self:MoveToPos(roam, {maxage = 2.0})
    self:StartActivity(ACT_IDLE)
    coroutine.wait(0.5)
end

function ENT:WalkPatrolRoute(route)
    self.PatrolIndex = self.PatrolIndex or 1
    if self.PatrolIndex > #route then
        self.PatrolIndex = 1
    end

    local point = route[self.PatrolIndex]

    if self:GetRangeTo(point.pos) <= 40 then
        self.PatrolIndex = self.PatrolIndex + 1
        self:StartActivity(ACT_IDLE)
        coroutine.wait(1)
    else
        self:StartActivity(ACT_WALK)
        self.loco:SetDesiredSpeed(self.WalkSpeed)
        self:MoveToPos(point.pos, {maxage = 1.0, repath = 0.4, tolerance = 30})
    end
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
    dmg:SetDamage(self:GetWeaponDamage())
    dmg:SetAttacker(self)
    dmg:SetInflictor(self)
    dmg:SetDamageType(DMG_CLUB)
    target:TakeDamageInfo(dmg)

    self.NextAttackTime = CurTime() + self:GetWeaponCooldown()
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
        Damage = self:GetWeaponDamage(),
        Callback = function(_, tr, dmgInfo)
            dmgInfo:SetAttacker(owner)
            dmgInfo:SetInflictor(owner)
        end,
    })

    if self.RangedSound then
        self:EmitSound(self.RangedSound)
    end

    self.NextAttackTime = CurTime() + self:GetWeaponCooldown()
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
    proj:Launch(self, targetPos, self.ThrowSpeed, self:GetWeaponDamage(), self.ThrowRadius, self.ThrownModel)

    self.NextAttackTime = CurTime() + self:GetWeaponCooldown()
end
