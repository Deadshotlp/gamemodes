AddCSLuaFile()

ENT.Type = "nextbot"
ENT.Base = "base_nextbot"
ENT.PrintName = "Mein NPC"
ENT.Author = "Du"
ENT.Category = "Deadshots Zeug"
ENT.Spawnable = true

function ENT:Initialize()
    self:SetModel("models/player/gman_high.mdl")
end

function ENT:SpawnFunction(ply, tr, ClassName)
    if not tr.Hit then
        return
    end
    local spawnPos = tr.HitPos + tr.HitNormal * 16
    local npc = ents.Create(ClassName)
    npc:SetPos(spawnPos)
    npc:Spawn()
    npc:Activate()
    return npc
end

list.Set("NPC", "test_npc", {
    Name = "Mein NPC",
    Class = "test_npc",
    Category = "Deadshots Zeug"
})
