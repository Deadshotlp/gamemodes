include("shared.lua")

local LABEL_DIST = 300 * 300

function ENT:Draw()
    self:DrawModel()

    local name = self:GetContentName()
    if name == "" then return end
    if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > LABEL_DIST then return end

    -- Beschriftung oben auf der Kiste, zur Kamera gedreht.
    local pos = self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z + 6))
    local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)

    cam.Start3D2D(pos, ang, 0.08)
        draw.SimpleTextOutlined("Transportkiste", "MLIB_ENTS.25", 0, -28, Color(200, 200, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
        draw.SimpleTextOutlined(name, "MLIB_ENTS.40", 0, 4, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
    cam.End3D2D()
end
