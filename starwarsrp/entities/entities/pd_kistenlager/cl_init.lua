include("shared.lua")

local LABEL_DIST = 400 * 400

function ENT:Draw()
    self:DrawModel()

    if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > LABEL_DIST then return end

    local pos = self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z + 10))
    local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)

    cam.Start3D2D(pos, ang, 0.1)
        draw.SimpleTextOutlined("Kistenlager", "MLIB_ENTS.40", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
        draw.SimpleTextOutlined("[E] Ausrüstung holen", "MLIB_ENTS.25", 0, 34, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
    cam.End3D2D()
end
