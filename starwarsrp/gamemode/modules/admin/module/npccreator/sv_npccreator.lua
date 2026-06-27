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

    local weapon = isstring(tbl.weapon) and tbl.weapon or ""
    if weapon ~= "" and not weapons.GetStored(weapon) then
        weapon = "weapon_pistol"
    end

    local childTemplate = isstring(tbl.childTemplate) and tbl.childTemplate or ""

    return {
        name = name,
        model = model,
        weapon = weapon,
        health = math.floor(ClampNumber(tbl.health, 1, 2000, 150)),
        alignment = AllowedAlignments[tbl.alignment] and tbl.alignment or "hostile",
        attackType = AllowedAttackTypes[tbl.attackType] and tbl.attackType or "ranged",
        damage = math.floor(ClampNumber(tbl.damage, 1, 500, 14)),
        sightRange = math.floor(ClampNumber(tbl.sightRange, 100, 6000, 1800)),
        attackCooldown = ClampNumber(tbl.attackCooldown, 0.1, 10, 1.2),
        aimSkill = AllowedAimSkills[tbl.aimSkill] and tbl.aimSkill or "realistic",
        canMove = tbl.canMove ~= false,
        canRotate = tbl.canRotate ~= false,
        isSquadLeader = tbl.isSquadLeader == true,
        childTemplate = childTemplate,
        squadSize = math.floor(ClampNumber(tbl.squadSize, 1, 9, 9)),
    }
end

local function SaveTemplates()
    PD.JSON.Write("npccreator/templates.json", PD.NPCCreator.Templates)
end

-- Creates and fully configures a deadshot_npc at the given position/angle.
-- Shared by the admin menu spawn button, the Tool Gun stool and squad
-- leaders spawning their own members.
function PD.NPCCreator.CreateNPCFromTemplate(rawData, pos, ang)
    local data = SanitizeTemplate(rawData)

    local npc = ents.Create("deadshot_npc")
    if not IsValid(npc) then return nil end

    npc.ModelPath = data.model
    npc.HealthAmount = data.health
    npc.WeaponClass = data.weapon

    npc:SetPos(pos)
    npc:SetAngles(ang)
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

    npc.IsSquadLeader = data.isSquadLeader
    npc.ChildTemplateName = data.childTemplate
    npc.SquadSize = data.squadSize

    npc:SetMaxHealth(data.health)
    npc:SetHealth(data.health)
    npc:SetNWString("PD_NPCName", data.name)

    return npc
end

function PD.NPCCreator.SpawnFromTemplate(ply, rawData, trace)
    trace = trace or ply:GetEyeTrace()
    local pos = trace.HitPos + trace.HitNormal * 5
    local ang = Angle(0, ply:EyeAngles().y + 180, 0)
    return PD.NPCCreator.CreateNPCFromTemplate(rawData, pos, ang)
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
