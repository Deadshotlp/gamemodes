include("shared.lua")
local imgui = include("library/cl_imgui.lua")

local SpawnPos = {}

net.Receive("PD.VD:Sync", function()
    SpawnPos = net.ReadTable()
end)

net.Start("PD.VD:Sync")
net.SendToServer()

local activePagePanels = {}
local function clearPage()
    for _, panel in pairs(activePagePanels) do
        if IsValid(panel) then
            panel:Remove()
        end
    end
    activePagePanels = {}
end

local function generateRandomCode()
    -- Definiere die möglichen Zeichen
    local characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz123456789"
    local code = ""

    -- Generiere eine 10-stellige Zeichenkette
    for i = 1, 10 do
        local randomIndex = math.random(1, #characters) -- Zufälliger Index innerhalb des Zeichenbereichs
        code = code .. characters:sub(randomIndex, randomIndex) -- Zeichen hinzufügen
    end

    return code
end

local page = 1
local inumber = 1
local noi = 8
local startY = 70
local spacingY = 35
local selectBar = 1
local showInfo = true

local function GetSelectBarPos()
	return startY + spacingY * selectBar - 35
end

PD.ATC.ActiveVehicle = {}
-- PD.ATC.ActiveVehicle[1] = {
-- 	vehicle = "ARC-170",
-- 	pilot = Entity(1):Nick(),
-- 	navycode = generateRandomCode(),
-- 	activecode = "",
-- 	codetime = 0,
-- }

PD.ATC.ActiveVehicle[1] = {
	vehicle = "ARC-170",
	pilot = "Kevin",
	navycode = generateRandomCode(),
	activecode = "",
	codetime = 0,
}

function ENT:Draw()
 	self:DrawModel()

	local dist = LocalPlayer():EyePos():Distance( self:GetPos() )		
	if imgui.Entity3D2D(self, Vector(1, -67, 85), Angle(0, 90, 90), 0.1) then
		draw.RoundedBox(0, 0, 0, 1350, 500, Color(22, 22, 22))

		if dist <= 300 then
			if showInfo then 

				draw.DrawText("Fahrzeug / Pilot", "MLIB.20", 20, 15, Color(255, 255, 255), TEXT_ALIGN_LEFT)
				draw.DrawText("Fahrzeug Code", "MLIB.20", 670, 15, Color(255, 255, 255), TEXT_ALIGN_CENTER)
				draw.DrawText("Pilot", "MLIB.20", 1320, 15, Color(255, 255, 255), TEXT_ALIGN_RIGHT)
				draw.RoundedBox(0, 0, 50, 1350, 3, Color(255, 255, 255))

				draw.RoundedBox(0, 0, GetSelectBarPos(), 1350, 30, Color(55, 55, 55))

				for i = 1, table.Count(PD.ATC.ActiveVehicle) do
					local v = PD.ATC.ActiveVehicle[i]

					if not v then continue end
					if i > noi * page then continue end
					if i <= noi * (page - 1) then continue end

					local relativeIndex = i - noi * (page - 1)
					local buttonY = startY + (relativeIndex - 1) * spacingY

					draw.DrawText(v.vehicle, "MLIB.20", 20, buttonY, Color(255, 255, 255), TEXT_ALIGN_LEFT)
					draw.DrawText(v.navycode, "MLIB.20", 670, buttonY, Color(255, 255, 255), TEXT_ALIGN_CENTER)
					draw.DrawText(v.pilot, "MLIB.20", 1320, buttonY, Color(255, 255, 255), TEXT_ALIGN_RIGHT)
				end
			else
				local v = PD.ATC.ActiveVehicle[selectBar]

				draw.DrawText("Fahrzeug / Pilot", "MLIB.20", 20, 15, Color(255, 255, 255), TEXT_ALIGN_LEFT)
				draw.DrawText("Fahrzeug Code", "MLIB.20", 670, 15, Color(255, 255, 255), TEXT_ALIGN_CENTER)
				draw.DrawText("Pilot", "MLIB.20", 1320, 15, Color(255, 255, 255), TEXT_ALIGN_RIGHT)
				draw.RoundedBox(0, 0, 50, 1350, 3, Color(255, 255, 255))

				draw.RoundedBox(0, 0, GetSelectBarPos(), 1350, 30, Color(55, 55, 55))

				draw.DrawText(v.vehicle, "MLIB.20", 20, 70, Color(255, 255, 255), TEXT_ALIGN_LEFT)
				draw.DrawText(v.navycode, "MLIB.20", 670, 70, Color(255, 255, 255), TEXT_ALIGN_CENTER)
				draw.DrawText(v.pilot, "MLIB.20", 1320, 70, Color(255, 255, 255), TEXT_ALIGN_RIGHT)

				draw.DrawText("Aktiver Code", "MLIB.20", 20, 120, Color(255, 255, 255), TEXT_ALIGN_LEFT)
				draw.DrawText(v.activecode, "MLIB.20", 670, 120, Color(255, 255, 255), TEXT_ALIGN_CENTER)
				draw.DrawText("Code Zeit", "MLIB.20", 1320, 120, Color(255, 255, 255), TEXT_ALIGN_RIGHT)
			end
			
		end

		imgui.End3D2D()
    end

	if imgui.Entity3D2D(self, Vector(6, -8, 32), Angle(0, 90, 55), 0.1) then
		surface.SetDrawColor(Color(22, 22, 22))
        surface.DrawRect(0, 0, 150, 110)

		if dist <= 300 then
			
			local openNext = imgui.xTextButton("Zurück", "MLIB.12", 20, 5, 113, 30, 2, Color(255, 255, 255), Color(255, 0, 0), Color(148, 148, 148))
			if openNext then
				clearPage()  
				page = page + 1
			end

			local openNext = imgui.xTextButton("Bestätigen", "MLIB.12", 20, 40, 113, 30, 2, Color(255, 255, 255), Color(255, 0, 0), Color(148, 148, 148))
			if openNext then
				if showInfo then
					showInfo = false
				else
					showInfo = true
				end
			end

			local openPrev = imgui.xTextButton("▲", "MLIB.12", 20, 75, 55, 30, 2, Color(255, 255, 255), Color(255, 0, 0), Color(148, 148, 148))
			if openPrev then
				if selectBar > 1 then
					selectBar = selectBar - 1
				end
			end

			local openNext = imgui.xTextButton("▼", "MLIB.12", 80, 75, 53, 30, 2, Color(255, 255, 255), Color(255, 0, 0), Color(148, 148, 148))
			if openNext then
				selectBar = selectBar + 1
			end
		end

		imgui.End3D2D()
    end
end

