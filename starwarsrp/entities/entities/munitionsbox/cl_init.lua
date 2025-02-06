include("shared.lua")

surface.CreateFont("Lukas", {
  font = "Star Jedi",
	extended = false,
	size = 70,
	weight = 500,
})


function ENT:Draw()
    self:DrawModel() 
	
	local ply = LocalPlayer()
	if !IsValid(ply) then return end
	
	local plyPos = ply:GetPos()
	local plyAngles = ply:GetAngles()
	local text_color = Color(194, 0, 129, 255)
	local offset = Angle(0,270,90)
		cam.Start3D2D(self:GetPos()+Vector(0,0,40),  Angle(0,plyAngles.y,0) + offset, 0.1)
			draw.SimpleText("Munitionskiste", "Lukas", 0, -40, text_color, TEXT_ALIGN_CENTER, 1)
		surface.SetFont("Lukas")
    local text = "Lager: "..self:GetAmount() .."/100"
    local w, h = surface.GetTextSize( text )
    draw.SimpleText(text, "Lukas", 0, 0, Color(194, 0, 129, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
		cam.End3D2D() 
end