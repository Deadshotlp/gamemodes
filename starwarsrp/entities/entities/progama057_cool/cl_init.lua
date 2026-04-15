include("shared.lua")

function ENT:Draw()
	self:DrawModel()
	local dist = LocalPlayer():EyePos():Distance(self:GetPos())
	local backcol = Color(22,22,22)
	
	cam.Start3D2D(self:GetPos() + Vector(0, 0, 45), Angle(0, Angle(0, (LocalPlayer():GetPos() - self:GetPos()):Angle().y + 90, 90).y, 90), 0.1)

		if dist <= 300 then		
			draw.DrawText("Kühlflüssigkeit: \n" .. self:GetCool() .. "L", "MLIB.40", 10, 10, getColor("Text"), TEXT_ALIGN_CENTER)
		end

	cam.End3D2D()
end
