include("shared.lua")

surface.CreateFont("PD.NavalNachschub.3D2D", {font = "Roboto", size = 52, weight = 700, extended = true})

local DRAW_DIST = 400 * 400

function ENT:Draw()
    self:DrawModel()

    local ply = LocalPlayer()
    if not IsValid(ply) or ply:GetPos():DistToSqr(self:GetPos()) > DRAW_DIST then return end

    local def = self:KindDef()
    if not def then return end

    local ang = Angle(0, ply:EyeAngles().y - 90, 90)
    cam.Start3D2D(self:GetPos() + Vector(0, 0, 40), ang, 0.1)
        draw.SimpleText(def.name, "PD.NavalNachschub.3D2D", 0, -40, def.color or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("zur Nachschub-Annahme bringen", "PD.NavalNachschub.3D2D", 0, 20, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
