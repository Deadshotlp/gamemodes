AddCSLuaFile("library/cl_advanceddraw.lua")

include('shared.lua')

local adraw = include("library/cl_advanceddraw.lua")

local color = Color(0, 0, 0, 255)
local start_text_color = Color(255, 255, 255, 255)
local normal_text_color = Color(0, 0, 0, 255)
local hover_text_color = Color(255, 0, 0, 255)
local press_text_color = Color(255, 255, 0, 255)
local titel = "MLIB_ENTS.200"
local sub_titel = "MLIB_ENTS.150"
local content = "MLIB_ENTS.100"
local sub_content = "MLIB_ENTS.50"

local start_up_time = 1
local startet = false
local start_time = 0

ENT.RenderGroup = RENDERGROUP_OPAQUE

function ENT:Initialize()
    self.Scale = 100
    self.ButtonWidth = 120
    self.ButtonHeight = 120
    self.ButtonMarginVertical = 20
    self.ButtonMarginHorizontal = 15
end

function ENT:Draw()
    self:DrawModel()

    local ply = LocalPlayer()

    if ply:GetPos():Distance(self:GetPos()) > 300 then startet = false start_time = 0 return end

    if adraw.Entity3D2D(self, Vector(-1.3, -10.5, 68.2), Angle(0, 90, 80), 1 / self.Scale) then
        local w, h = 2100, 1440
        if self:GetNW2Bool("pd_medical_display_active") then
            surface.SetDrawColor(255, 255, 255, 255)
        else
            surface.SetDrawColor(0, 0, 0, 255)
        end
        surface.DrawRect(0, 0, w, h)

        if self:GetNW2Bool("pd_medical_display_active") then

            if not startet and start_time == 0 then
                start_time = os.time()
            elseif startet then
                draw.DrawText("Puls: " .. self:GetNW2Int("puls", 0) .. " bpm",titel , w * 0.05, h * 0.03, normal_text_color, TEXT_ALIGN_LEFT, TEXT_ALIGN_LEFT, nil, nil, true)
                draw.DrawText("BP: ".. self:GetNW2Int("bp_1", 0) .. " / " .. self:GetNW2Int("bp_2", 0) .. " mmHg",titel , w * 0.05, h * 0.18, normal_text_color, TEXT_ALIGN_LEFT, TEXT_ALIGN_LEFT, nil, nil, true)
                draw.DrawText("Spo2: " .. self:GetNW2Int("spo2", 0) .. " %",titel , w * 0.05, h * 0.33, normal_text_color, TEXT_ALIGN_LEFT, TEXT_ALIGN_LEFT, nil, nil, true)


                if adraw.xTextButton("Scan Stoppen", titel, w * 0.1, h * 0.8, w * 0.8, h * 0.18, 5, normal_text_color, hover_text_color, press_text_color) then
                    startet = false
                    start_time = 0
                    self:SetNW2Bool("pd_medical_display_active", false)
                end
            else
                draw.DrawText("Scanne...",titel , w * 0.5, h * 0.1, normal_text_color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, nil, nil, true)

                local dif = os.time() - start_time
                if dif > start_up_time then
                    startet = true
                end
                
                surface.SetDrawColor(0, 0, 0, 255)
                surface.DrawRect(w * 0.1, h * 0.4, w * 0.8, h * 0.18)
                surface.SetDrawColor(255, 0, 0, 255)
                surface.DrawRect(w * 0.1, h * 0.4, (w * 0.8) / start_up_time * dif, h * 0.18)
            end
        else
            if adraw.xTextButton("Scan Starten", titel, w * 0.1, h * 0.4, w * 0.8, h * 0.18, 5, start_text_color, hover_text_color, press_text_color) then
                self:SetNW2Bool("pd_medical_display_active", true)
            end
        end

        adraw.End3D2D()
    end


end