include("shared.lua")
local imgui = include("library/cl_imgui.lua")

local scan = false

function ENT:Draw()
    self:DrawModel()

    local dist = LocalPlayer():EyePos():Distance(self:GetPos())
    if imgui.Entity3D2D(self, Vector(-1.3, -10.5, 68.5), Angle(0, 90, 80), 0.1) then
        surface.SetDrawColor(Color(0, 0, 0))
        surface.DrawRect(0, 0, 210, 150)

        if dist <= 300 then
            if scan then
                local PlayerArmorTable = LocalPlayer():PDGetArmor()
                if not PlayerArmorTable then return end

                draw.DrawText("Helm: " .. PlayerArmorTable.helm .. "%", "MLIB.15", 105, 10, Color(255, 255, 255), TEXT_ALIGN_CENTER)
                draw.DrawText("Panzer: " .. PlayerArmorTable.panzer .. "%", "MLIB.15", 105, 30, Color(255, 255, 255), TEXT_ALIGN_CENTER)
                draw.DrawText("Beine: " .. PlayerArmorTable.beine .. "%", "MLIB.15", 105, 50, Color(255, 255, 255), TEXT_ALIGN_CENTER)

                -- Wenn nicht Voll dann Button anzeigen

                if PlayerArmorTable.helm < 100 or PlayerArmorTable.panzer < 100 or PlayerArmorTable.beine < 100 then
                    local open = imgui.xTextButton("Aufladen", "MLIB.12", 55, 80, 100, 30, 2, Color(246, 246, 246), Color(255, 0, 0), Color(0, 255, 0))

                    if open then
                        net.Start("PD.Armor:PlayerArmor")
                            net.WriteInt(4, 8)
                        net.SendToServer()

                        scan = false

                        chat.AddText(Color(255, 255, 255), "Du hast deine Rüstung aufgeladen!")
                    end
                end
				
			else
				draw.DrawText("Scan nicht vorhanden\n bitte Scan durchführen!", "MLIB.15", 105, 10, Color(255, 255, 255), TEXT_ALIGN_CENTER)

				local open = imgui.xTextButton("Scan starten", "MLIB.12", 55, 80, 100, 30, 2, Color(246, 246, 246), Color(255, 0, 0), Color(0, 255, 0))

                if open then
                    scan = true
                end
			end
        end

        imgui.End3D2D()
    end

end

