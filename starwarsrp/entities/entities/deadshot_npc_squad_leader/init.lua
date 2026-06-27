AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self.BaseClass.Initialize(self)

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

function ENT:SpawnSquad()
    self.Squad = {}

    for i = 1, self.SquadSize do
        local trooper = ents.Create("deadshot_npc_trooper")
        if not IsValid(trooper) then continue end

        local angle = (360 / self.SquadSize) * i
        local offset = Angle(0, angle, 0):Forward() * self.FormationRadius

        trooper:SetPos(self:GetPos() + offset)
        trooper:SetAngles(self:GetAngles())
        trooper:Spawn()

        trooper.SquadLeader = self
        trooper.FormationSlot = {angle = angle, radius = self.FormationRadius}
        trooper.FireGroup = (i % 2) + 1

        table.insert(self.Squad, trooper)
    end
end

----------------------------------------------------------------
-- Squad-wide situational awareness, run on a timer independent
-- of the leader's own RunBehaviour coroutine
----------------------------------------------------------------

function ENT:CountAliveTroopers()
    local count = 0
    for _, trooper in ipairs(self.Squad) do
        if IsValid(trooper) and trooper:Health() > 0 then
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
    for _, trooper in ipairs(self.Squad) do
        if IsValid(trooper) and trooper:Health() > 0 then
            scan(trooper)
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
-- Leader death/removal: squad loses coordination and panics
----------------------------------------------------------------

function ENT:OnKilled(dmg)
    timer.Remove("deadshot_npc_squad_" .. self:EntIndex())

    for _, trooper in ipairs(self.Squad) do
        if IsValid(trooper) then
            trooper:EnterPanic(self:GetPos())
        end
    end

    self.BaseClass.OnKilled(self, dmg)
end

function ENT:OnRemove()
    timer.Remove("deadshot_npc_squad_" .. self:EntIndex())

    for _, trooper in ipairs(self.Squad) do
        if IsValid(trooper) then
            trooper:EnterPanic(self:GetPos())
        end
    end
end
