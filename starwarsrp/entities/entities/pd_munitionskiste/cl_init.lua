include("shared.lua")

surface.CreateFont("PD.Munitionskiste.3D2D", {
    font = "Roboto",
    size = 56,
    weight = 700,
    extended = true,
})

local DRAW_DIST = 400 * 400

function ENT:Draw()
    self:DrawModel()

    local ply = LocalPlayer()
    if not IsValid(ply) or ply:GetPos():DistToSqr(self:GetPos()) > DRAW_DIST then return end

    local kind = self:GetKind()
    if not kind then return end

    local stock = self:GetStock()
    local line

    if stock > 0 then
        line = "Lager: " .. stock .. "/" .. kind.stock
    else
        line = "Leer - voll in " .. math.max(0, math.ceil(self:GetRefillAt() - CurTime())) .. " s"
    end

    local ang = Angle(0, ply:EyeAngles().y - 90, 90)

    cam.Start3D2D(self:GetPos() + Vector(0, 0, 40), ang, 0.1)
        draw.SimpleText(kind.name, "PD.Munitionskiste.3D2D", 0, -40, kind.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(line, "PD.Munitionskiste.3D2D", 0, 20, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
