AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self.BaseClass.Initialize(self)
    self.FireGroup = self.FireGroup or 1
end

----------------------------------------------------------------
-- Main loop: solo (base AI) unless attached to a Squad Leader
----------------------------------------------------------------

function ENT:RunBehaviour()
    while true do
        if self.PanicUntil and CurTime() < self.PanicUntil then
            self:DoPanic()
        elseif IsValid(self.SquadLeader) then
            self:DoSquadDuty()
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

----------------------------------------------------------------
-- Squad duty: formation, perimeter security, cover, suppression
----------------------------------------------------------------

function ENT:GetFormationPos(sl)
    local slot = self.FormationSlot or {angle = 0, radius = 150}
    return sl:GetPos() + Angle(0, slot.angle, 0):Forward() * slot.radius
end

function ENT:MoveToFormation(pos, running)
    if self:GetRangeTo(pos) <= 40 then
        self:StartActivity(ACT_IDLE)
        return true
    end

    self.loco:SetDesiredSpeed(running and self.RunSpeed or self.WalkSpeed)
    self:StartActivity(running and ACT_RUN or ACT_WALK)
    self:MoveToPos(pos, {maxage = 0.6, repath = 0.3, tolerance = 30})
    return false
end

-- Probes points around threatPos's opposite side for a spot whose line of
-- sight to the threat is blocked - a cheap stand-in for a real cover system,
-- since nextbots have no built-in cover-node integration.
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

function ENT:DoSquadDuty()
    local sl = self.SquadLeader
    if not IsValid(sl) then return end

    local state = sl.SquadState or "hold"
    local target = sl.SquadTargetEnemy

    if state == "retreat" then
        self:DoRetreat(sl)
        return
    end

    local desiredPos = self:GetFormationPos(sl)

    if IsValid(target) and state == "hold" then
        desiredPos = self:GetCoverPosition(target:GetPos()) or desiredPos
    end

    local arrived = self:MoveToFormation(desiredPos, IsValid(target) and state == "advance")

    if IsValid(target) then
        self:EngageAsSquad(target, state)
    elseif arrived then
        local slot = self.FormationSlot
        if slot then
            local outward = self:GetPos() + Angle(0, slot.angle, 0):Forward() * 100
            self.loco:FaceTowards(outward)
        end
    end
end

function ENT:IsMyFireTurn()
    local sl = self.SquadLeader
    if not IsValid(sl) then return true end
    return self.FireGroup == (sl.ActiveFireGroup or 1)
end

function ENT:EngageAsSquad(target, state)
    self.loco:FaceTowards(target:GetPos())

    if self:Visible(target) then
        if self:IsMyFireTurn() then
            self:RangedAttack(target)
        end
    elseif state ~= "advance" then
        self:SuppressPosition(self.SquadLeader.LastKnownEnemyPos or target:GetPos())
    end
end

-- Blind fire at a remembered position - doesn't need a hit, just keeps the enemy pinned
function ENT:SuppressPosition(pos)
    if not pos then return end
    if CurTime() < self.NextAttackTime then return end

    local aim = self:GetAimSettings()
    local startPos = self:GetPos() + Vector(0, 0, 60)
    local dir = self:ApplySpread((pos - startPos):GetNormalized(), aim.spread * 3)
    local owner = self

    self:FireBullets({
        Num = 1,
        Src = startPos,
        Dir = dir,
        Spread = Vector(0, 0, 0),
        Tracer = 1,
        Force = 5,
        Damage = self.BulletDamage * 0.5,
        Callback = function(_, tr, dmgInfo)
            dmgInfo:SetAttacker(owner)
            dmgInfo:SetInflictor(owner)
        end,
    })

    if self.RangedSound then
        self:EmitSound(self.RangedSound)
    end

    self.NextAttackTime = CurTime() + self.AttackCooldown * 0.6
end

function ENT:DoRetreat(sl)
    local threat = sl.SquadTargetEnemy
    local awayDir

    if IsValid(threat) then
        awayDir = (self:GetPos() - threat:GetPos()):GetNormalized()
    else
        awayDir = (self:GetPos() - sl:GetPos()):GetNormalized()
    end

    local fallback = self:GetPos() + awayDir * 300

    self.loco:SetDesiredSpeed(self.RunSpeed)
    self:StartActivity(ACT_RUN)
    self:MoveToPos(fallback, {maxage = 0.6, repath = 0.3, tolerance = 40})

    if IsValid(threat) and self:Visible(threat) and self:IsMyFireTurn() then
        self.loco:FaceTowards(threat:GetPos())
        self:RangedAttack(threat)
    end
end

----------------------------------------------------------------
-- Panic: triggered by the Squad Leader dying or being removed
----------------------------------------------------------------

function ENT:EnterPanic(source)
    self.PanicUntil = CurTime() + self.PanicDuration
    self.PanicSource = source
    self.SquadLeader = NULL
end

function ENT:DoPanic()
    local fleeFrom = self.PanicSource or self:GetPos()
    local awayDir = (self:GetPos() - fleeFrom):GetNormalized()

    if awayDir:LengthSqr() < 0.01 then
        awayDir = VectorRand()
    end

    local fleeTo = self:GetPos() + awayDir * 500 + VectorRand() * 150

    self.loco:SetDesiredSpeed(self.RunSpeed)
    self:StartActivity(ACT_RUN)
    self:MoveToPos(fleeTo, {maxage = 0.5, repath = 0.4, tolerance = 40})
end
