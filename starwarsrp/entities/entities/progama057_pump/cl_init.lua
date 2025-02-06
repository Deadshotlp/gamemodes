
include("shared.lua")
local imgui = include("library/cl_imgui.lua")

surface.CreateFont("PD.REAKTOR:SmallFont", {
    font = "Roboto", 
    size = 10,
    weight = 0
})

local pump = false
net.Receive("PD.REAKTOR:Pumpe", function()
    pump = net.ReadBool()
end)

-- Eine Funktion die prüft ob was neben dem Entity ein anderes bestimmtes Entity steht
local function IsNearEntity(ent, class, dist)
    local ents = ents.FindInSphere(ent:GetPos(), dist)
    if istable(class) then
        for k, v in pairs(ents) do
            for _, c in pairs(class) do
                if v:GetClass() == c then
                    return true, v
                end
            end
        end
    else
        for k, v in pairs(ents) do
            if v:GetClass() == class then
                return true, v
            end
        end
    end
    return false
end

function ENT:Draw()
	self:DrawModel()
	local dist = LocalPlayer():EyePos():Distance(self:GetPos())
	local backcol = Color(22,22,22)

	-- Links
	if imgui.Entity3D2D(self, Vector(3, -13, 46), Angle(0, 90, 62), 0.1) then
		draw.RoundedBox(20, 0, 0, 120, 105, backcol)

		if dist <= 300 then
            if pump then
                draw.DrawText("Befüllung gestartet", "PD.REAKTOR:SmallFont", 60, 10, Color(255, 255, 255), TEXT_ALIGN_CENTER)
                draw.DrawText("Bitte warten...", "PD.REAKTOR:SmallFont", 60, 30, Color(255, 255, 255), TEXT_ALIGN_CENTER)
            else
                if IsNearEntity(self, "progama057_empty", 50) then
                    draw.DrawText("Behälter gefunden", "PD.REAKTOR:SmallFont", 60, 10, Color(255, 255, 255), TEXT_ALIGN_CENTER)
                else
                    draw.DrawText("Kein Behälter in der Nähe", "PD.REAKTOR:SmallFont", 60, 10, Color(255, 255, 255), TEXT_ALIGN_CENTER)
                end
            end
		end

		imgui.End3D2D()
    end

    -- Befüllung starten fuel
    if imgui.Entity3D2D(self, Vector(16, 0, 32), Angle(0, 90, 15), 0.1) then
        --draw.RoundedBox(10, 0, 0, 120, 120, backcol)

		if dist <= 300 then		
            local open = imgui.xTextButton("Brennmittel", "MLIB.10", 3, 15, 60, 20, 1, Color(246, 246, 246), Color(255, 0, 0), Color(74, 151, 19, 127))

			if open then
                local s, ent = IsNearEntity(self, "progama057_empty", 50)

				if s then
                    chat.AddText(ent:GetPName() .. " wurde gefunden")

                    net.Start("PD.REAKTOR:Pumpe")
                    net.WriteString("fuel")
                    net.WriteEntity(ent)
                    net.WriteEntity(self)
                    net.SendToServer()
                else
                    chat.AddText("Nicht alle benötigten Materialien wurden gefunden!")
                end
			end
		end

		imgui.End3D2D()
    end

    -- Befüllung starten cool
    if imgui.Entity3D2D(self, Vector(16, -13.5, 32), Angle(0, 90, 15), 0.1) then
        --draw.RoundedBox(10, 0, 0, 120, 120, backcol)

		if dist <= 300 then		
            local open = imgui.xTextButton("Kühlflüssigkeit", "MLIB.10", 3, 15, 70, 20, 1, Color(246, 246, 246), Color(255, 0, 0), Color(74, 151, 19, 127))

			if open then
                local s, ent = IsNearEntity(self, "progama057_empty", 100)

				if s then
                    chat.AddText(ent:GetPName() .. " wurde gefunden")

                    net.Start("PD.REAKTOR:Pumpe")
                    net.WriteString("cool")
                    net.WriteEntity(ent)
                    net.WriteEntity(self)
                    net.SendToServer()
                else
                    chat.AddText("Nicht alle benötigten Materialien wurden gefunden!")
                end
			end
		end

		imgui.End3D2D()
    end

end
