include("shared.lua")
local imgui = include("library/cl_imgui.lua")


function ENT:Draw()
 	self:DrawModel()

	local dist = LocalPlayer():EyePos():Distance( self:GetPos() )		
	if imgui.Entity3D2D(self, Vector(-2, -9, 52), Angle(0, 90, 81), 0.1) then
		surface.SetDrawColor(Color(22, 22, 22))
        surface.DrawRect(0, 0, 190, 380)

		if dist <= 300 then
			
		end

		imgui.End3D2D()
    end
end

