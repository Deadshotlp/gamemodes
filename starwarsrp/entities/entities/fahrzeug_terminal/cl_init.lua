include("shared.lua")
local imgui = include("library/cl_imgui.lua")

local SpawnPos = {}

net.Receive("PD.VD:Sync", function()
    SpawnPos = net.ReadTable()
end)

timer.Simple(1, function()
	net.Start("PD.VD:Sync")
	net.SendToServer()
end)

local activePagePanels = {}
local function clearPage()
    for _, panel in pairs(activePagePanels) do
        if IsValid(panel) then
            panel:Remove()
        end
    end
    activePagePanels = {}
end

local page = 1
local noi = 8
local startY = 20
local spacingY = 35
local Table = {}

-- net.Receive("PD.VD:Sync", function()
-- 	Table = net.ReadTable()
-- end)

PD.VD.Vehicle = {
    {
        name = "ARC-170 Starfighter",
        vehicle = "lvs_starfighter_arc170",
        check = function(ply)
            return true -- PD.CheckUnitAccess(ply, "Stoßtruppen")
        end,
    },

}


function ENT:Draw()
 	self:DrawModel()

	local dist = LocalPlayer():EyePos():Distance( self:GetPos() )		
	if imgui.Entity3D2D(self, Vector(-2, -9, 52), Angle(0, 90, 81), 0.1) then
		surface.SetDrawColor(Color(22, 22, 22))
        surface.DrawRect(0, 0, 190, 380)

		if dist <= 300 then
			for i = 0, #PD.VD.Vehicle do
				local v = PD.VD.Vehicle[i]
				if not v then continue end

				local jobId, jobTable = LocalPlayer():GetJob()

				if v.check and not v.check(LocalPlayer()) then continue end

				if i > noi * page then continue end
				if i <= noi * (page - 1) then continue end

				local relativeIndex = i - noi * (page - 1)
    			local buttonY = startY + (relativeIndex - 1) * spacingY

				local open = imgui.xTextButton(v.name, "MLIB.12", 10, buttonY, 160, 30, 2, Color(255, 255, 255), Color(255, 0, 0), Color(148, 148, 148))
				table.insert(activePagePanels, open) 

			
				if open then
					if table.Count(SpawnPos) == 0 then chat.AddText("Kein Hangar gefunden!") continue end

					
					local menu = DermaMenu()
					menu:SetPos(ScrW()/2, ScrH()/2)
					menu:Open()
					gui.EnableScreenClicker(true)

					
					for name, pos in pairs(SpawnPos) do
						menu:AddOption(name, function()
							net.Start("PD.VD:SpawnVehicle")
								net.WriteString(name)
								net.WriteString(v.vehicle)
							net.SendToServer()

							menu:Remove()
							gui.EnableScreenClicker(false)
						end)
					end

					menu:AddOption("Schließen", function()
						menu:Remove()
						gui.EnableScreenClicker(false)
					end)
				end
			end

			local openPrev = imgui.xTextButton("<", "MLIB.12", 10, 320, 75, 30, 2, Color(255, 255, 255), Color(255, 0, 0), Color(148, 148, 148))
			if openPrev then
				if page > 1 then
					clearPage()  

					page = page - 1
				end
			end

			local openNext = imgui.xTextButton(">", "MLIB.12", 95, 320, 75, 30, 2, Color(255, 255, 255), Color(255, 0, 0), Color(148, 148, 148))
			if openNext then
				clearPage()  
				page = page + 1
			end
		end

		imgui.End3D2D()
    end
end

