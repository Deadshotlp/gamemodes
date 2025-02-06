include("shared.lua")
local imgui = include("library/cl_imgui.lua")

surface.CreateFont("Waffenkiste", {
    font = "Roboto",
    size = 250,
    weight = 100
})

function ENT:Draw()
    self:DrawModel()

    local dist = LocalPlayer():EyePos():Distance(self:GetPos())
    if imgui.Entity3D2D(self, Vector(4, -40, 70), Angle(0, 90, 70), 0.1) then
        surface.SetDrawColor(Color(0, 0, 0))
        surface.DrawRect(0, 0, 100, 150)

        if dist <= 300 then
            if GetGlobal2Bool("WaffenkisteKaputt") then
                draw.DrawText("Kaputt", "MLIB.15", 50, 80, Color(255, 0, 0), TEXT_ALIGN_CENTER)

                if LocalPlayer():GetActiveWeapon():GetClass() == "progama057_cutter" then
                    draw.DrawText(self:Health() .. "/" .. self:GetMaxHealth(), "MLIB.20", 50, 110, Color(255, 255, 255),
                        TEXT_ALIGN_CENTER)
                end
            else
                local open = imgui.xTextButton("Öffnen", "MLIB.10", 20, 75, 60, 30, 2, Color(246, 246, 246),
                    Color(0, 255, 0), Color(0, 0, 255))

                if open then
                    PD.WB:Menu()
                end
            end
        end

        imgui.End3D2D()
    end

end

