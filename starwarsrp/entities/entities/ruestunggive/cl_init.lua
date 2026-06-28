include("shared.lua")
local imgui = include("library/cl_imgui.lua")

local scan = false

function ENT:Draw()
    self:DrawModel()

    local dist = LocalPlayer():EyePos():Distance(self:GetPos())
    if imgui.Entity3D2D(self, Vector(16, -39, 75), Angle(0, 90, 90), 0.1) then
        -- surface.SetDrawColor(Color(0, 0, 0))
        -- surface.DrawRect(0, 0, 780, 100)

        if dist <= 300 then
            draw.DrawText("Helm ausrüsten", "MLIB.25", 125, 10, Color(0, 0, 0), TEXT_ALIGN_CENTER)
            draw.DrawText("Panzer ausrüsten", "MLIB.25", 385, 10, Color(0, 0, 0), TEXT_ALIGN_CENTER)
            draw.DrawText("Beine ausrüsten", "MLIB.25", 660, 10, Color(0, 0, 0), TEXT_ALIGN_CENTER)
        end

        imgui.End3D2D()
    end

    if imgui.Entity3D2D(self, Vector(16.6, -39, 66.5), Angle(0, 90, 72), 0.1) then
        -- surface.SetDrawColor(Color(0, 0, 0))
        -- surface.DrawRect(0, 0, 780, 210)

        if dist <= 300 then
            
            

            local open = imgui.xTextButton("", "MLIB.12", 10, 10, 220, 190, 2, Color(246, 246, 246), Color(255, 0, 0), Color(0, 255, 0))

            if open then
                net.Start("PD.Armor:GiveArmorEnt")
                    net.WriteInt(3, 8)
                net.SendToServer()
            end

            local open = imgui.xTextButton("", "MLIB.12", 280, 10, 220, 190, 2, Color(246, 246, 246), Color(255, 0, 0), Color(0, 255, 0))

            if open then
                net.Start("PD.Armor:GiveArmorEnt")
                    net.WriteInt(1, 8)
                net.SendToServer()
            end

            local open = imgui.xTextButton("", "MLIB.12", 550, 10, 220, 190, 2, Color(246, 246, 246), Color(255, 0, 0), Color(0, 255, 0))

            if open then
                net.Start("PD.Armor:GiveArmorEnt")
                    net.WriteInt(2, 8)
                net.SendToServer()
            end
                
		
        end

        imgui.End3D2D()
    end

end

