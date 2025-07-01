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
        -- local w, h = 12 * self.Scale, 10 * self.Scale
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

        adraw.End3D2D()

    end
end

-- if true then

--     if adraw.Entity3D2D(self, Vector(0, 0, 0), Angle(0, 90, 90), 1 / self.Scale) then
--         local w, h = 12 * self.Scale, 10 * self.Scale

--         draw.DrawText("Bitte Loggen sie sich ein!", "MLIB_ENTS.150", w * 1.1395, h * 0.1, color, TEXT_ALIGN_CENTER,
--             TEXT_ALIGN_CENTER)

--         adraw.End3D2D()
--     end
-- else
--     if adraw.Entity3D2D(self, Vector(-15.9, -0.26, 59.26), Angle(0, 90, 90), 1 / self.Scale) then
--         local w, h = 12 * self.Scale, 10 * self.Scale

--         for _, i in ipairs(buttons) do
--             if adraw.xSymbolButton(i.icon, w * (0.04 + _ * 0.2 - 0.2), h * 0.05, 200, 200, 0, i.normalcolor,
--                 i.hovercolor) then
--                 net.Start("PD.RefreshData")
--                 net.WriteEntity(self)
--                 net.WriteString("selectetdApp")
--                 net.WriteString("int")
--                 net.WriteInt(i.id, 32)
--                 net.SendToServer()
--             end
--         end

--         if adraw.xSymbolButton(Material("images/logout.png"), w * 0.04, h * 1.175, 200, 200, 0,
--             Color(255, 255, 255, 200), Color(255, 255, 255, 255)) then
--             net.Start("PD.RefreshData")
--             net.WriteEntity(self)
--             net.WriteString("LoggdIn")
--             net.WriteString("bool")
--             net.WriteBool(false)
--             net.SendToServer()
--         end

--         adraw.End3D2D()
--     end

--     if self:GetNWInt("selectetdApp", 0) ~= nil and self:GetNWInt("selectetdApp", 0) <= #buttons and
--         self:GetNWInt("selectetdApp", 0) >= 0 then
--         buttons[self:GetNWInt("selectetdApp")].func()
--     end
-- end

-- if adraw.Entity3D2D(self, Vector(-15.9, -0.26, 59.26), Angle(0, 90, 90), 1 / self.Scale) then
--     local w, h = 12 * self.Scale, 10 * self.Scale

--     draw.DrawText("Deadshot OS", "MLIB_ENTS.100", w * 1.8, h * 1.25, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

--     adraw.End3D2D()
-- end
