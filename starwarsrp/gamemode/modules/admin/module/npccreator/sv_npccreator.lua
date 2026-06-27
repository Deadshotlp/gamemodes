util.AddNetworkString("PD.NPCCreator.RequestTemplates")
util.AddNetworkString("PD.NPCCreator.Templates")
util.AddNetworkString("PD.NPCCreator.Save")
util.AddNetworkString("PD.NPCCreator.Delete")
util.AddNetworkString("PD.NPCCreator.Spawn")

PD.JSON.Create("npccreator")

PD.NPCCreator = PD.NPCCreator or {}
PD.NPCCreator.Templates = {}

local AllowedAlignments = {
    hostile = true,
    neutral = true,
    friendly = true,
}

local AllowedAttackTypes = {
    melee = true,
    ranged = true,
    thrown = true,
}

local AllowedAimSkills = {
    dumb = true,
    realistic = true,
    better = true,
}

local AllowedSurrenderBehaviors = {
    flee = true,
    surrender = true,
}

local function ClampNumber(value, mn, mx, fallback)
    value = tonumber(value)
    if not value then return fallback end
    return math.Clamp(value, mn, mx)
end

-- "empire, rebels" -> {empire = true, rebels = true}
local function ParseFactionSet(str)
    local set = {}
    for name in tostring(str or ""):gmatch("[^,]+") do
        name = name:Trim()
        if name ~= "" then set[name] = true end
    end
    return set
end

local function FactionSetToString(set)
    local names = {}
    for name in pairs(set or {}) do
        table.insert(names, name)
    end
    table.sort(names)
    return table.concat(names, ", ")
end

local function SanitizeTemplate(tbl)
    tbl = istable(tbl) and tbl or {}

    local name = tostring(tbl.name or ""):sub(1, 48)
    if name == "" then name = "Unbenannt" end

    local model = isstring(tbl.model) and tbl.model or "models/Combine_Soldier.mdl"
    if not util.IsValidModel(model) then model = "models/Combine_Soldier.mdl" end

    local weapon = isstring(tbl.weapon) and tbl.weapon or ""
    if weapon ~= "" and not weapons.GetStored(weapon) then
        weapon = "weapon_pistol"
    end

    local existing = PD.NPCCreator.Templates[name]

    return {
        name = name,
        model = model,
        weapon = weapon,
        health = math.floor(ClampNumber(tbl.health, 1, 2000, 150)),
        alignment = AllowedAlignments[tbl.alignment] and tbl.alignment or "hostile",
        attackType = AllowedAttackTypes[tbl.attackType] and tbl.attackType or "ranged",
        sightRange = math.floor(ClampNumber(tbl.sightRange, 100, 6000, 1800)),
        aimSkill = AllowedAimSkills[tbl.aimSkill] and tbl.aimSkill or "realistic",
        canMove = tbl.canMove ~= false,
        canRotate = tbl.canRotate ~= false,
        seeksCover = tbl.seeksCover ~= false,

        faction = tostring(tbl.faction or ""):sub(1, 32):Trim(),
        hostileFactions = ParseFactionSet(tbl.hostileFactions),

        canSurrender = tbl.canSurrender == true,
        surrenderHealthRatio = ClampNumber(tbl.surrenderHealthRatio, 0.01, 1, 0.25),
        surrenderBehavior = AllowedSurrenderBehaviors[tbl.surrenderBehavior] and tbl.surrenderBehavior or "flee",

        patrolRoute = isstring(tbl.patrolRoute) and tbl.patrolRoute or "",

        spawnsTroop = tbl.spawnsTroop == true,
        troopSize = math.floor(ClampNumber(tbl.troopSize, 1, 9, 9)),
        childTemplate = isstring(tbl.childTemplate) and tbl.childTemplate or "",

        isSquadLeader = tbl.isSquadLeader == true,
        maxSquadSize = math.floor(ClampNumber(tbl.maxSquadSize, 1, 20, 9)),
        commandClaimRadius = math.floor(ClampNumber(tbl.commandClaimRadius, 100, 4000, 1000)),

        -- usage stats survive being overwritten by a save of the same name
        usageCount = existing and existing.usageCount or 0,
        lastUsedBy = existing and existing.lastUsedBy or "",
        lastUsedAt = existing and existing.lastUsedAt or "",
    }
end

local function SaveTemplates()
    PD.JSON.Write("npccreator/templates.json", PD.NPCCreator.Templates)
end

-- Creates and fully configures a deadshot_npc at the given position/angle.
-- Shared by the admin menu spawn button, the Tool Gun stool and squad
-- leaders/troop-spawners creating their own members.
function PD.NPCCreator.CreateNPCFromTemplate(rawData, pos, ang)
    local data = SanitizeTemplate(rawData)

    local npc = ents.Create("deadshot_npc")
    if not IsValid(npc) then return nil end

    -- Every field that Initialize() reads (ModelPath/HealthAmount/WeaponClass/
    -- SpawnsTroop/IsSquadLeader) MUST be set before Spawn() - Initialize() runs
    -- synchronously inside Spawn() and would otherwise still see class defaults.
    npc.ModelPath = data.model
    npc.HealthAmount = data.health
    npc.WeaponClass = data.weapon

    npc.Alignment = data.alignment
    npc.AttackType = data.attackType
    npc.AimSkill = data.aimSkill
    npc.CanMove = data.canMove
    npc.CanRotate = data.canRotate
    npc.SeeksCover = data.seeksCover
    npc.SightRange = data.sightRange

    npc.Faction = data.faction
    npc.HostileFactions = data.hostileFactions

    npc.CanSurrender = data.canSurrender
    npc.SurrenderHealthRatio = data.surrenderHealthRatio
    npc.SurrenderBehavior = data.surrenderBehavior

    npc.PatrolRoute = data.patrolRoute

    npc.SpawnsTroop = data.spawnsTroop
    npc.TroopSize = data.troopSize
    npc.ChildTemplateName = data.childTemplate

    npc.IsSquadLeader = data.isSquadLeader
    npc.MaxSquadSize = data.maxSquadSize
    npc.CommandClaimRadius = data.commandClaimRadius

    npc:SetPos(pos)
    npc:SetAngles(ang)
    npc:Spawn()

    npc:SetMaxHealth(data.health)
    npc:SetHealth(data.health)
    npc:SetNWString("PD_NPCName", data.name)

    return npc
end

local function TrackUsage(ply, name)
    local tpl = PD.NPCCreator.Templates[name]
    if not tpl then return end

    tpl.usageCount = (tpl.usageCount or 0) + 1
    tpl.lastUsedBy = IsValid(ply) and ply:Nick() or "Unbekannt"
    tpl.lastUsedAt = os.date("%d.%m.%Y %H:%M")
    SaveTemplates()
end

function PD.NPCCreator.SpawnFromTemplate(ply, rawData, trace)
    trace = trace or ply:GetEyeTrace()
    local pos = trace.HitPos + trace.HitNormal * 5
    local ang = Angle(0, ply:EyeAngles().y + 180, 0)

    local npc = PD.NPCCreator.CreateNPCFromTemplate(rawData, pos, ang)
    if IsValid(npc) and istable(rawData) and isstring(rawData.name) then
        TrackUsage(ply, rawData.name)
    end

    return npc
end

hook.Add("Initialize", "PD.NPCCreator.Load", function()
    PD.NPCCreator.Templates = PD.JSON.Read("npccreator/templates.json") or {}
end)

net.Receive("PD.NPCCreator.RequestTemplates", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    net.Start("PD.NPCCreator.Templates")
    net.WriteTable(PD.NPCCreator.Templates)
    net.Send(ply)
end)

net.Receive("PD.NPCCreator.Save", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local oldName = net.ReadString()
    local data = SanitizeTemplate(net.ReadTable())

    if oldName ~= "" and oldName ~= data.name then
        PD.NPCCreator.Templates[oldName] = nil
    end

    PD.NPCCreator.Templates[data.name] = data
    SaveTemplates()

    net.Start("PD.NPCCreator.Templates")
    net.WriteTable(PD.NPCCreator.Templates)
    net.Send(ply)
end)

net.Receive("PD.NPCCreator.Delete", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local name = net.ReadString()
    PD.NPCCreator.Templates[name] = nil
    SaveTemplates()

    net.Start("PD.NPCCreator.Templates")
    net.WriteTable(PD.NPCCreator.Templates)
    net.Send(ply)
end)

net.Receive("PD.NPCCreator.Spawn", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    PD.NPCCreator.SpawnFromTemplate(ply, net.ReadTable())
end)
