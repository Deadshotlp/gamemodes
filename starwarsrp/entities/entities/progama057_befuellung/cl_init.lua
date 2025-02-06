include("shared.lua")
local imgui = include("library/cl_imgui.lua")

surface.CreateFont("PD.REAKTOR:SmallFont", {
    font = "Roboto", 
    size = 10,
    weight = 0
})

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
	if imgui.Entity3D2D(self, Vector(2, -13.5, 45.3), Angle(0, 90, 62), 0.1) then
		draw.RoundedBox(10, 0, 0, 57, 50, backcol)

		if dist <= 300 then		
			if IsNearEntity(self, "progama057_cool", 50) then
                draw.DrawText("Kühlflüssigkeit\ngefunden!", "PD.REAKTOR:SmallFont", 28, 17, CONFIG:GetConfig("textcolor"), TEXT_ALIGN_CENTER)
            else
                draw.DrawText("Kühlflüssigkeit\nnicht\ngefunden!", "PD.REAKTOR:SmallFont", 28, 12, CONFIG:GetConfig("textcolor"), TEXT_ALIGN_CENTER)
            end
		end

		imgui.End3D2D()
    end

	-- Rechts
	if imgui.Entity3D2D(self, Vector(2, -6.5, 45.3), Angle(0, 90, 62), 0.1) then
		draw.RoundedBox(10, 0, 0, 57, 50, backcol)

		if dist <= 300 then		
			if IsNearEntity(self, "progama057_fuel", 50) then
                draw.DrawText("Brennmittel\ngefunden!", "PD.REAKTOR:SmallFont", 28, 17, CONFIG:GetConfig("textcolor"), TEXT_ALIGN_CENTER)
            else
                draw.DrawText("Brennmittel\nnicht\ngefunden!", "PD.REAKTOR:SmallFont", 28, 12, CONFIG:GetConfig("textcolor"), TEXT_ALIGN_CENTER)
            end
		end

		imgui.End3D2D()
    end

	-- Rechts Groß
	if imgui.Entity3D2D(self, Vector(3, 3, 46), Angle(0, 90, 62), 0.1) then
		draw.RoundedBox(20, 0, 0, 120, 105, backcol)

		if dist <= 300 then		
	
		end

		imgui.End3D2D()
    end

    -- Befüllung starten
    if imgui.Entity3D2D(self, Vector(16, 0.5, 32), Angle(0, 90, 15), 0.1) then
        --draw.RoundedBox(10, 0, 0, 120, 120, backcol)

		if dist <= 300 then		
            local open = imgui.xTextButton("Starten", "MLIB.10", 3, 15, 50, 20, 1, Color(246, 246, 246), Color(255, 0, 0), Color(74, 151, 19, 127))

			if open then
                local s, ent = IsNearEntity(self, {"progama057_cool", "progama057_fuel"}, 50)

				if s then
                    chat.AddText(ent:GetPName() .. " wurde gefunden")

                    
                else
                    chat.AddText("Nicht alle benötigten Materialien wurden gefunden!")
                end
			end
		end

		imgui.End3D2D()
    end
end
