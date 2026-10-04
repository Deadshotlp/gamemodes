include("shared.lua")

-- Kurzanzeige ueber der Konsole; die Bedienung oeffnet sich mit E.
local DIST = 350 * 350

function ENT:Draw()
    local marker = self:StationDef()
    if marker and marker.marker then
        -- Projektor: nur fuer Admins sichtbar, solange das Hologramm aus ist
        if not LocalPlayer():IsAdmin() or GetGlobalBool("PD.Naval.HoloOn", false) then return end
        render.SetColorModulation(0.3, 0.7, 1)
        render.SetBlend(0.5)
        self:DrawModel()
        render.SetBlend(1)
        render.SetColorModulation(1, 1, 1)
    else
        self:DrawModel()
    end

    if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > DIST then return end

    local def = self:StationDef()
    if not def then return end

    local pos = self:LocalToWorld(Vector(0, 0, self:OBBMaxs().z + 12))
    local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)

    cam.Start3D2D(pos, ang, 0.08)
        draw.SimpleTextOutlined(def.name, "MLIB_ENTS.40", 0, 0, Color(120, 190, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))

        local line = self:GetLocked() and "GESPERRT" or (def.noUse and def.desc or "[E] " .. def.desc)
        draw.SimpleTextOutlined(line, "MLIB_ENTS.25", 0, 36, self:GetLocked() and Color(255, 90, 90) or Color(210, 210, 210),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))

        if PD.Naval and PD.Naval.ConsoleSummary then
            local lines = PD.Naval.ConsoleSummary(self:GetStation())
            for i, text in ipairs(lines or {}) do
                draw.SimpleTextOutlined(text, "MLIB_ENTS.25", 0, 36 + i * 30, Color(255, 255, 255),
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
            end
        end
    cam.End3D2D()
end
