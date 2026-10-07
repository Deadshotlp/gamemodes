--[[
    Nachschubkiste des Naval-Systems: wird am Logistik-Leitstand angefordert,
    erscheint an der Anlieferung und wird an der Nachschub-Annahme verbucht
    (gamemode/modules/naval/sv_naval_supply.lua). Passt ins Fahrzeuginventar.
]]

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Nachschubkiste"
ENT.Author = "PD"
ENT.Category = "PD - Gamemode"
ENT.Spawnable = false

ENT.Model = "models/reizer_props/srsp/sci_fi/crate_01/crate_01.mdl"

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "Kind")
end

function ENT:KindDef()
    local Naval = PD and PD.Naval
    return Naval and Naval.SupplyKinds and Naval.SupplyKinds[self:GetKind()]
end

-- Name im Fahrzeuginventar
function ENT:GetContentName()
    local def = self:KindDef()
    return def and def.name or "Nachschubkiste"
end
