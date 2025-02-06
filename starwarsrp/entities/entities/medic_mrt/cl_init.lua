AddCSLuaFile("library/advanceddraw.lua")

include('shared.lua')
local adraw = include("library/advanceddraw.lua")

local color = Color(255, 255, 255, 50)

ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:Initialize()
    self.Scale = 100
    self.ButtonWidth = 120
    self.ButtonHeight = 120
    self.ButtonMarginVertical = 20
    self.ButtonMarginHorizontal = 15

    self:SetPredictable(true)
end

function ENT:Draw()
    self:DrawModel()
end
