include("shared.lua")
local imgui = include("library/cl_imgui.lua")

surface.CreateFont("PD.REAKTOR:Font", {
	font = "Roboto", 
	size = 250,
	weight = 100,
})

local animationTime = 0.5
local t = {
    ["l"] = {
        start = 0,
        oldst = -1,
        newst = -1
    },
    ["r"] = {
        start = 0,
        oldst = -1,
        newst = -1
    }
}

local function InfoBar(type, w1, w2, x, y, w, h, col, rounds, reverse, text)
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local tx = x

    if (t[type].oldst == -1 and t[type].newst == -1) then
        t[type].oldst = w1
        t[type].newst = w1
    end

    local curTime = CurTime()
    local smoothST = Lerp((curTime - t[type].start) / animationTime, t[type].oldst, t[type].newst)

    if t[type].newst ~= w1 then
        if (smoothST ~= w1) then
            t[type].newst = smoothST
        end

        t[type].oldst = t[type].newst
        t[type].start = curTime
        t[type].newst = w1
    end

    local length = math.min(math.max(0, smoothST) / w2 * w, w)

    if !type == "w" then
        draw.RoundedBoxEx(10, x, y, w, h, Color(0,0,0), rounds[1], rounds[2], rounds[3], rounds[4])
    end

    if reverse then
        x = x + w - length
    end

    draw.RoundedBoxEx(10, x, y, length, h, col, rounds[1], rounds[2], rounds[3], rounds[4])

    -- surface.SetDrawColor(0, 0, 0)
    -- surface.DrawOutlinedRect(x, y, w, h, 2)

    if text then
        draw.DrawText(w1, "MLIB.20", tx + w / 2, y, getColor("Text"), TEXT_ALIGN_CENTER)
    end
end

local active = false
local f, c = 0, 0

net.Receive("PD.REAKTOR:Verbrauch", function()
    local a = net.ReadInt(32)
    local b = net.ReadInt(32)

    f = a
    c = b
end)

net.Receive("PD.REAKTOR:Active", function()
    active = !active

    if !active then
        f = 0
        c = 0
    end
end)

function ENT:Draw()
	self:DrawModel()
	local dist = LocalPlayer():EyePos():Distance(self:GetPos())
	local backcol = Color(22,22,22)

	-- Links
	if imgui.Entity3D2D(self, Vector(3, -36.5, 46), Angle(0, 90, 62), 0.1) then
		draw.RoundedBox(20, 0, 0, 120, 110, backcol)

		if dist <= 300 then		
			draw.DrawText("Brennmittel: " .. PD.REAKTOR:GetFuel() .. "L", "MLIB.10", 10, 10, getColor("Text"), TEXT_ALIGN_LEFT)
			InfoBar("l", PD.REAKTOR:GetFuel(), 50000, 10, 30, 100, 10, Color(255,255,255), {false, false, false, false}, false, false)

            draw.DrawText("Verbrauch: " .. f .. "l", "MLIB.10", 10, 50, getColor("Text"), TEXT_ALIGN_LEFT)
		end

		imgui.End3D2D()
    end

	-- Rechts
	if imgui.Entity3D2D(self, Vector(3, 26.5, 46), Angle(0, 90, 62), 0.1) then
		draw.RoundedBox(20, 0, 0, 120, 110, backcol)

		if dist <= 300 then		
			draw.DrawText("Kühlflüssigkeit: " .. PD.REAKTOR:GetCool() .. "L", "MLIB.10", 10, 10, getColor("Text"), TEXT_ALIGN_LEFT)
			InfoBar("r", PD.REAKTOR:GetCool(), 50000, 10, 30, 100, 10, Color(255,255,255), {false, false, false, false}, false, false)

            draw.DrawText("Verbrauch: " .. c .. "l", "MLIB.10", 10, 50, getColor("Text"), TEXT_ALIGN_LEFT)
		end

		imgui.End3D2D()
    end

	-- Links Klein
	if imgui.Entity3D2D(self, Vector(2, 10, 45.3), Angle(0, 90, 62), 0.1) then
		draw.RoundedBox(10, 0, 0, 57, 50, backcol)

		if dist <= 300 then		
			if active then
                draw.DrawText("Online", "MLIB.10", 28.5, 17, Color(0,255,0), TEXT_ALIGN_CENTER)
            else
                draw.DrawText("Offline", "MLIB.10", 28.5, 17, Color(255,0,0), TEXT_ALIGN_CENTER)
            end
		end

		imgui.End3D2D()
    end

	-- Rechts Temperatur
	if imgui.Entity3D2D(self, Vector(2, 17, 45.3), Angle(0, 90, 62), 0.1) then
		draw.RoundedBox(10, 0, 0, 57, 50, backcol)

        local col = Color(0,255,0)

        if PD.REAKTOR:GetHitze() >= 100 then
            col = Color(255,0,0)
        elseif PD.REAKTOR:GetHitze() >= 50 then
            col = Color(255,255,0)
        else
            col = Color(0,255,0)
        end

		if dist <= 300 then		
			draw.DrawText("Temp:", "MLIB.10", 28.5, 12, getColor("Text"), TEXT_ALIGN_CENTER)
            draw.DrawText(PD.REAKTOR:GetHitze() .. "°C", "MLIB.10", 28.5, 27, col, TEXT_ALIGN_CENTER)
		end

		imgui.End3D2D()
    end

    -- Wartung 
	if imgui.Entity3D2D(self, Vector(16, -23, 32), Angle(0, 90, 15), 0.1) then
		-- draw.RoundedBox(10, 0, 0, 57, 50, backcol)

		if dist <= 300 then		
			local open = imgui.xTextButton("Wartung", "MLIB.10", 3, 15, 50, 20, 1, Color(246, 246, 246), Color(255, 0, 0), Color(74, 151, 19, 127))

			if open then
				chat.AddText("Wartung geöffnet")
			end
		end

		imgui.End3D2D()
    end

    -- Start 
	if imgui.Entity3D2D(self, Vector(16, -35.5, 32), Angle(0, 90, 15), 0.1) then
		-- draw.RoundedBox(10, 0, 0, 57, 50, backcol)

        local text = "N/A"

        if active then
            text = "Abschalten"
        else
            text = "Starten"
        end

		if dist <= 300 then		
			local open = imgui.xTextButton(text, "MLIB.10", 3, 15, 55, 20, 1, Color(246, 246, 246), Color(255, 0, 0), Color(74, 151, 19, 127))

			if open then
                net.Start("PD.REAKTOR:Active")
                net.SendToServer()
			end
		end

		imgui.End3D2D()
    end
end
