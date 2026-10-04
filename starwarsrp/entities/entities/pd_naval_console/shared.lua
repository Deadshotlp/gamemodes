--[[
    Naval - Konsole. Eine Klasse fuer alle Stationen (siehe
    gamemode/modules/naval/_core/sh_naval_stations.lua). Platziert und
    gespeichert werden Konsolen ueber pd_naval_consoles (sv_naval_consoles.lua).
]]

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Naval-Konsole"
ENT.Author = "PD"
ENT.Category = "PD - Gamemode"
ENT.Spawnable = false

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "Station")
    self:NetworkVar("Bool", 0, "Locked")
    self:NetworkVar("Int", 0, "ConsoleId")
end

function ENT:StationDef()
    return PD.Naval and PD.Naval.Stations and PD.Naval.Stations[self:GetStation()]
end
