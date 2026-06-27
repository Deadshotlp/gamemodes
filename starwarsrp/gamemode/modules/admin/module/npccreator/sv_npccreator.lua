util.AddNetworkString("PD.NPCCreator.RequestTemplates")
util.AddNetworkString("PD.NPCCreator.Templates")
util.AddNetworkString("PD.NPCCreator.Save")
util.AddNetworkString("PD.NPCCreator.Delete")
util.AddNetworkString("PD.NPCCreator.Spawn")

PD.JSON.Create("npccreator")

local Templates = {}

local AllowedBases = {
    deadshot_npc_trooper = true,
    deadshot_npc_squad_leader = true,
}

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

local function ClampNumber(value, mn, mx, fallback)
    value = tonumber(value)
    if not value then return fallback end
    return math.Clamp(value, mn, mx)
end

local function SanitizeTemplate(tbl)
    tbl = istable(tbl) and tbl or {}

    local name = tostring(tbl.name or ""):sub(1, 48)
    if name == "" then name = "Unbenannt" end

    local model = isstring(tbl.model) and tbl.model or "models/Combine_Soldier.mdl"
    if not util.IsValidModel(model) then model = "models/Combine_Soldier.mdl" end

    return {
        name = name,
        base = AllowedBases[tbl.base] and tbl.base or "deadshot_npc_trooper",
        model = model,
        health = math.floor(ClampNumber(tbl.health, 1, 2000, 150)),
        alignment = AllowedAlignments[tbl.alignment] and tbl.alignment or "hostile",
        attackType = AllowedAttackTypes[tbl.attackType] and tbl.attackType or "ranged",
        damage = math.floor(ClampNumber(tbl.damage, 1, 500, 14)),
        sightRange = math.floor(ClampNumber(tbl.sightRange, 100, 6000, 1800)),
        attackCooldown = ClampNumber(tbl.attackCooldown, 0.1, 10, 1.2),
        aimSkill = AllowedAimSkills[tbl.aimSkill] and tbl.aimSkill or "realistic",
        canMove = tbl.canMove ~= false,
        canRotate = tbl.canRotate ~= false,
        squadSize = math.floor(ClampNumber(tbl.squadSize, 1, 9, 9)),
    }
end

local function SaveTemplates()
    PD.JSON.Write("npccreator/templates.json", Templates)
end

local function SpawnFromTemplate(ply, data)
    local npc = ents.Create(data.base)
    if not IsValid(npc) then return end

    npc.ModelPath = data.model
    npc.HealthAmount = data.health

    local tr = ply:GetEyeTrace()
    npc:SetPos(tr.HitPos + tr.HitNormal * 5)
    npc:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
    npc:Spawn()

    npc.Alignment = data.alignment
    npc.AttackType = data.attackType
    npc.AimSkill = data.aimSkill
    npc.CanMove = data.canMove
    npc.CanRotate = data.canRotate
    npc.SightRange = data.sightRange
    npc.AttackCooldown = data.attackCooldown

    if data.attackType == "melee" then
        npc.DamageAmount = data.damage
    elseif data.attackType == "ranged" then
        npc.BulletDamage = data.damage
    elseif data.attackType == "thrown" then
        npc.ThrowDamage = data.damage
    end

    if data.base == "deadshot_npc_squad_leader" then
        npc.SquadSize = data.squadSize
    end

    npc:SetMaxHealth(data.health)
    npc:SetHealth(data.health)
    npc:SetNWString("PD_NPCName", data.name)
end

hook.Add("Initialize", "PD.NPCCreator.Load", function()
    Templates = PD.JSON.Read("npccreator/templates.json") or {}
end)

net.Receive("PD.NPCCreator.RequestTemplates", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    net.Start("PD.NPCCreator.Templates")
    net.WriteTable(Templates)
    net.Send(ply)
end)

net.Receive("PD.NPCCreator.Save", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local oldName = net.ReadString()
    local data = SanitizeTemplate(net.ReadTable())

    if oldName ~= "" and oldName ~= data.name then
        Templates[oldName] = nil
    end

    Templates[data.name] = data
    SaveTemplates()

    net.Start("PD.NPCCreator.Templates")
    net.WriteTable(Templates)
    net.Send(ply)
end)

net.Receive("PD.NPCCreator.Delete", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local name = net.ReadString()
    Templates[name] = nil
    SaveTemplates()

    net.Start("PD.NPCCreator.Templates")
    net.WriteTable(Templates)
    net.Send(ply)
end)

net.Receive("PD.NPCCreator.Spawn", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local data = SanitizeTemplate(net.ReadTable())
    SpawnFromTemplate(ply, data)
end)
