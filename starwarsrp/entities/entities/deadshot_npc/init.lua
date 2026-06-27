AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self.BaseClass.Initialize(self)
    self.FireGroup = self.FireGroup or 1

    if self.SpawnsTroop then
        timer.Simple(0, function()
            if IsValid(self) then
                self:SpawnTroop()
            end
        end)
    end

    if self.IsSquadLeader then
        self.Squad = {}
        self.SquadState = "hold"
        self.ActiveFireGroup = 1
        self.NextFireGroupSwap = CurTime() + self.FireCycleDuration

        local timerName = "deadshot_npc_squad_" .. self:EntIndex()
        timer.Create(timerName, self.SquadUpdateInterval, 0, function()
            if IsValid(self) then
                self:ClaimNearbyTroops()
                self:UpdateSquadState()
            else
                timer.Remove(timerName)
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
        elseif self:ShouldSurrender() then
            self:DoSurrender()
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

    if IsValid(target) and state == "hold" and self.SeeksCover then
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
        Damage = self:GetWeaponDamage() * 0.5,
        Callback = function(_, tr, dmgInfo)
            dmgInfo:SetAttacker(owner)
            dmgInfo:SetInflictor(owner)
        end,
    })

    if self.RangedSound then
        self:EmitSound(self.RangedSound)
    end

    self.NextAttackTime = CurTime() + self:GetWeaponCooldown() * 0.6
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
-- Spawnt Trupp: creates TroopSize child NPCs nearby. Does NOT command
-- them - that's the separate IsSquadLeader capability below. A leader
-- placed close enough will pick up freshly spawned troops on its own.
----------------------------------------------------------------

function ENT:SpawnTroop()
    local childData = nil
    if self.ChildTemplateName ~= "" and PD.NPCCreator then
        childData = PD.NPCCreator.Templates[self.ChildTemplateName]
    end

    for i = 1, self.TroopSize do
        local angle = (360 / self.TroopSize) * i
        local pos = self:GetPos() + Angle(0, angle, 0):Forward() * self.FormationRadius

        local member
        if childData then
            local data = table.Copy(childData)
            data.isSquadLeader = false -- a troop spawner never creates its own commanders
            data.spawnsTroop = false   -- and never recursively spawns further troops
            member = PD.NPCCreator.CreateNPCFromTemplate(data, pos, self:GetAngles())
        else
            member = ents.Create("deadshot_npc")
            if IsValid(member) then
                member:SetPos(pos)
                member:SetAngles(self:GetAngles())
                member:Spawn()
            end
        end
    end
end

----------------------------------------------------------------
-- Squadleader: claims nearby uncommanded, same-faction, same-alignment
-- NPCs (whether it spawned them or not) and coordinates them as a squad.
----------------------------------------------------------------

function ENT:ClaimNearbyTroops()
    self.Squad = self.Squad or {}

    -- drop dead/invalid members so they don't count against MaxSquadSize
    for i = #self.Squad, 1, -1 do
        if not IsValid(self.Squad[i]) or self.Squad[i]:Health() <= 0 then
            table.remove(self.Squad, i)
        end
    end

    if #self.Squad >= self.MaxSquadSize then return end

    for _, npc in ipairs(ents.FindByClass("deadshot_npc")) do
        if #self.Squad >= self.MaxSquadSize then break end
        if npc == self or not IsValid(npc) then continue end
        if npc:Health() <= 0 then continue end
        if IsValid(npc.SquadLeader) then continue end
        if npc.IsSquadLeader then continue end
        if npc.Faction ~= self.Faction then continue end
        if npc.Alignment ~= self.Alignment then continue end
        if self:GetRangeTo(npc) > self.CommandClaimRadius then continue end

        local index = #self.Squad + 1
        local angle = (360 / self.MaxSquadSize) * index

        npc.SquadLeader = self
        npc.FormationSlot = {angle = angle, radius = self.FormationRadius}
        npc.FireGroup = (index % 2) + 1

        table.insert(self.Squad, npc)
    end

    -- highest member count this squad has ever reached - used as the casualty
    -- baseline instead of MaxSquadSize, since a squad may never fill up
    self.PeakSquadSize = math.max(self.PeakSquadSize or 0, #self.Squad)
end

function ENT:CountAliveTroopers()
    local count = 0
    for _, member in ipairs(self.Squad or {}) do
        if IsValid(member) and member:Health() > 0 then
            count = count + 1
        end
    end
    return count
end

function ENT:GatherVisibleEnemies()
    local seen = {}

    local function scan(npc)
        local targetsPlayers = npc.Alignment == "hostile"
            or (npc.Alignment == "neutral" and CurTime() <= npc.ProvokedUntil)

        if targetsPlayers then
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:Alive() and not ply:IsFlagSet(FL_NOTARGET) then
                    if npc:GetRangeTo(ply) <= npc.SightRange and npc:Visible(ply) then
                        seen[ply] = true
                    end
                end
            end
        end

        if next(npc.HostileFactions or {}) then
            for _, other in ipairs(ents.FindByClass("deadshot_npc")) do
                if other ~= npc and IsValid(other) and other:Health() > 0 and npc.HostileFactions[other.Faction] then
                    if npc:GetRangeTo(other) <= npc.SightRange and npc:Visible(other) then
                        seen[other] = true
                    end
                end
            end
        end
    end

    scan(self)
    for _, member in ipairs(self.Squad or {}) do
        if IsValid(member) and member:Health() > 0 then
            scan(member)
        end
    end

    local list = {}
    for ent in pairs(seen) do
        table.insert(list, ent)
    end
    return list
end

function ENT:PickPriorityTarget(enemies)
    local nearest, nd = nil, math.huge
    for _, ent in ipairs(enemies) do
        local d = self:GetRangeTo(ent)
        if d < nd then
            nearest, nd = ent, d
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

    local casualtyRatio = 1 - (aliveTroopers / math.max(self.PeakSquadSize or 0, 1))

    if self.PeakSquadSize and self.PeakSquadSize > 0 and casualtyRatio >= self.RetreatLossThreshold and aliveTroopers > 0 then
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
