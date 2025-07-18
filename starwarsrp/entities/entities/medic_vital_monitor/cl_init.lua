AddCSLuaFile("library/advanceddraw.lua")

include('shared.lua')
local adraw = include("library/advanceddraw.lua")

local color = Color(255, 255, 255, 125)
local titel = "MLIB_ENTS.300"
local sub_titel = "MLIB_ENTS.250"
local content = "MLIB_ENTS.200"
local sub_content = "MLIB_ENTS.150"

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

    if self:GetNW2Bool("active", false) and adraw.Entity3D2D(self, Vector(2, 0, 0), Angle(0, 90, 90), 1 / self.Scale) then
        --vitals
        local l_screen_w, r_screen_w, screen_h = -4500, 600, -2200

        draw.DrawText("Vitals:", titel, l_screen_w * 1, screen_h * 1, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

        if self:GetNW2Int("puls") >= 0 then
            draw.DrawText("Puls: " .. self:GetNW2Int("puls"), content, l_screen_w * 0.99, screen_h * 0.85, color,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
        else
            draw.DrawText("Puls: -", content, l_screen_w * 0.99, screen_h * 0.85, color, TEXT_ALIGN_LEFT,
                TEXT_ALIGN_BOTTOM)
        end

        if self:GetNW2Int("spo2") >= 0 then
            draw.DrawText("Spo2: " .. self:GetNW2Int("spo2") .. "%", content, l_screen_w * 0.99, screen_h * 0.75, color,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
        else
            draw.DrawText("Spo2: -%", content, l_screen_w * 0.99, screen_h * 0.75, color, TEXT_ALIGN_LEFT,
                TEXT_ALIGN_BOTTOM)
        end

        if self:GetNW2Int("bp_1") >= 0 then
            draw.DrawText("BP: " .. self:GetNW2Int("bp_1") .. "/" .. self:GetNW2Int("bp_2"), content, l_screen_w * 0.99,
                screen_h * 0.65, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
        else
            draw.DrawText("BP: -/-", content, l_screen_w * 0.99, screen_h * 0.65, color, TEXT_ALIGN_LEFT,
                TEXT_ALIGN_BOTTOM)
        end

        -- Body TODO:	

        adraw.End3D2D()

    end
end