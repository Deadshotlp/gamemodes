AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self.BaseClass.Initialize(self)
    self.FireGroup = self.FireGroup or 1

    if self.IsSquadLeader then
        self.Squad = {}
        self.SquadState = "hold"
        self.ActiveFireGroup = 1
        self.NextFireGroupSwap = CurTime() + self.FireCycleDuration

        local timerName = "deadshot_npc_squad_" .. self:EntIndex()
        timer.Create(timerName, self.SquadUpdateInterval, 0, function()
            if IsValid(self) then
                self:UpdateSquadState()
            else
                timer.Remove(timerName)
            end
        end)

        -- Deferred so the leader's own SetPos/SetAngles (e.g. from the spawn tool) has settled
        timer.Simple(0, function()
            if IsValid(self) then
                self:SpawnSquad()
            end
        end)
    end
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
-- (only relevant once a Squad Leader has set self.SquadLeader)
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
-- Panic: triggered by this NPC's Squad Leader dying or being removed
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

----------------------------------------------------------------
-- Squad Leader duties: spawning/commanding other deadshot_npc
-- instances. Only active when self.IsSquadLeader == true.
----------------------------------------------------------------

function ENT:SpawnSquad()
    self.Squad = {}

    local childData = nil
    if self.ChildTemplateName ~= "" and PD.NPCCreator then
        childData = PD.NPCCreator.Templates[self.ChildTemplateName]
    end

    for i = 1, self.SquadSize do
        local angle = (360 / self.SquadSize) * i
        local offset = Angle(0, angle, 0):Forward() * self.FormationRadius
        local pos = self:GetPos() + offset

        local member
        if childData then
            local data = table.Copy(childData)
            data.isSquadLeader = false -- never let a squad member command its own squad
            member = PD.NPCCreator.CreateNPCFromTemplate(data, pos, self:GetAngles())
        else
            member = ents.Create("deadshot_npc")
            if IsValid(member) then
                member:SetPos(pos)
                member:SetAngles(self:GetAngles())
                member:Spawn()
            end
        end

        if IsValid(member) then
            member.SquadLeader = self
            member.FormationSlot = {angle = angle, radius = self.FormationRadius}
            member.FireGroup = (i % 2) + 1
            table.insert(self.Squad, member)
        end
    end
end

function ENT:CountAliveTroopers()
    local count = 0
    for _, member in ipairs(self.Squad) do
        if IsValid(member) and member:Health() > 0 then
            count = count + 1
        end
    end
    return count
end

function ENT:GatherVisibleEnemies()
    local seen = {}

    local function scan(npc)
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() and not ply:IsFlagSet(FL_NOTARGET) then
                if npc:GetRangeTo(ply) <= npc.SightRange and npc:Visible(ply) then
                    seen[ply] = true
                end
            end
        end
    end

    scan(self)
    for _, member in ipairs(self.Squad) do
        if IsValid(member) and member:Health() > 0 then
            scan(member)
        end
    end

    local list = {}
    for ply in pairs(seen) do
        table.insert(list, ply)
    end
    return list
end

function ENT:PickPriorityTarget(enemies)
    local nearest, nd = nil, math.huge
    for _, ply in ipairs(enemies) do
        local d = self:GetRangeTo(ply)
        if d < nd then
            nearest, nd = ply, d
        end
    end
    return nearest
end

function ENT:UpdateSquadState()
    local enemies = self:GatherVisibleEnemies()
    local aliveTroopers = self:CountAliveTroopers()
    local squadStrength = aliveTroopers + 1 -- +1 for the leader itself

    local target = self:PickPriorityTarget(enemies)
    self.SquadTargetEnemy = target
    if IsValid(target) then
        self.LastKnownEnemyPos = target:GetPos()
    end

    local casualtyRatio = 1 - (aliveTroopers / math.max(self.SquadSize, 1))

    if casualtyRatio >= self.RetreatLossThreshold then
        self.SquadState = "retreat"
    elseif #enemies == 0 then
        self.SquadState = "hold"
    elseif squadStrength >= #enemies * self.AdvantageRatio then
        self.SquadState = "advance"
    else
        self.SquadState = "hold"
    end

    if CurTime() >= self.NextFireGroupSwap then
        self.ActiveFireGroup = self.ActiveFireGroup == 1 and 2 or 1
        self.NextFireGroupSwap = CurTime() + self.FireCycleDuration
    end
end

----------------------------------------------------------------
-- Death/removal: if this was a Squad Leader, its squad loses
-- coordination and panics. Always defers to the base for the
-- shared ragdoll/weapon cleanup.
----------------------------------------------------------------

function ENT:OnKilled(dmg)
    if self.IsSquadLeader then
        timer.Remove("deadshot_npc_squad_" .. self:EntIndex())

        for _, member in ipairs(self.Squad or {}) do
            if IsValid(member) then
                member:EnterPanic(self:GetPos())
            end
        end
    end

    self.BaseClass.OnKilled(self, dmg)
end

function ENT:OnRemove()
    if self.IsSquadLeader then
        timer.Remove("deadshot_npc_squad_" .. self:EntIndex())

        for _, member in ipairs(self.Squad or {}) do
            if IsValid(member) then
                member:EnterPanic(self:GetPos())
            end
        end
    end

    self.BaseClass.OnRemove(self)
end
