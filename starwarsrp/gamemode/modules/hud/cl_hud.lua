-- HUD 

surface.CreateFont("estaurebesh", {
    font = "aurebesh",
    size = PD.H(15),
    weight = 500,
    antialias = true,
    shadow = false
})

surface.CreateFont("estaurebesh15", {
    font = "aurebesh",
    size = PD.H(7),
    weight = 500,
    antialias = true,
    shadow = false
})

local animationTime = 0.5
local t = {
    ["h"] = {
        start = 0,
        oldst = -1,
        newst = -1
    },
    ["a"] = {
        start = 0,
        oldst = -1,
        newst = -1
    },
    ["w"] = {
        start = 0,
        oldst = -1,
        newst = -1
    }  
}

local function Vital(type, r, x, y, w, h, w1, w2, col, rounds, reverse, text)
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

    -- if !type == "w" then
        draw.RoundedBoxEx(r, x, y, w, h, Color(0,0,0), rounds[1], rounds[2], rounds[3], rounds[4])
    -- end

    if reverse then
        x = x + w - length
    end

    draw.RoundedBoxEx(r, x, y, length, h, col, rounds[1], rounds[2], rounds[3], rounds[4])

    -- surface.SetDrawColor(0, 0, 0)
    -- surface.DrawOutlinedRect(x, y, w, h, 2)

    if text then
        draw.DrawText(w1, "MLIB.20", tx + w + PD.W(10), y + h / 2 - PD.H(10) , Color(255,255,255), TEXT_ALIGN_CENTER)
    end
end

local webTbl = {}
local weaponsTbl = {
    ["weapon_physgun"] = true,
    ["gmod_tool"] = true,
    ["gmod_camera"] = true,
    ["datapad"] = true,
    ["mhands"] = true,
}

local SteamIDs = {
    ["76561198418087933"] = true,
    ["76561198839912587"] = true
}

PD.HUD = PD.HUD or {}
PD.HUD.x = 0
PD.HUD.y = 0
hook.Add("HUDPaint", "PD.GamemodeHUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if not ply:Alive() then return end
    local name = string.Split(ply:Nick(), " ")

    surface.SetFont("MLIB.20")
    local tw, th = surface.GetTextSize(name[1])

    draw.DrawText(name[1], "estaurebesh", PD.W(10), ScrH() - PD.H(60), Color(255, 255, 255), TEXT_ALIGN_LEFT)
    draw.DrawText(name[2], "MLIB.20", PD.W(30) + tw, ScrH() - PD.H(60), Color(255, 255, 255), TEXT_ALIGN_LEFT)

    local jobID, job = ply:GetJob()

    if jobID then
        draw.SimpleText("JobID: " .. jobID, "MLIB.20", ScrW() - PD.W(10), ScrH() / 2 - PD.H(10), Color(255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
        draw.SimpleText("Unit: " .. job.unit, "MLIB.20", ScrW() - PD.W(10), ScrH() / 2 - PD.H(40), Color(255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
    end
    
    if PD.Developer then
        draw.DrawText("Developer Informationen", "MLIB.20", ScrW() / 2, PD.H(10), Color(255, 255, 255), TEXT_ALIGN_CENTER)
       
        local x, y = gui.MousePos()
        draw.DrawText("Maus Pos: X: " .. x .. " Y: " .. y, "MLIB.20", ScrW() / 2 - PD.W(5), PD.H(30), Color(255, 255, 255), TEXT_ALIGN_RIGHT)
        draw.DrawText("Button Pos: X: " .. PD.HUD.x .. " Y: " .. PD.HUD.y, "MLIB.20", ScrW() / 2 - PD.W(5), PD.H(50), Color(255, 255, 255), TEXT_ALIGN_RIGHT)

        local ang = ply:EyeAngles()
        draw.DrawText("Winkel: " .. math.Round(ang.p) .. " | " .. math.Round(ang.y) .. " | " .. math.Round(ang.r), "MLIB.20", ScrW() / 2 + PD.W(5), PD.H(30), Color(255, 255, 255), TEXT_ALIGN_LEFT)

        local pos = ply:GetPos()
        draw.DrawText("Pos: X: " .. math.Round(pos.x) .. " Y: " .. math.Round(pos.y) .. " Z: " .. math.Round(pos.z), "MLIB.20", ScrW() / 2 + PD.W(5), PD.H(50), Color(255, 255, 255), TEXT_ALIGN_LEFT)
    
        if SteamIDs[ply:SteamID64()] then
            for _, otherPlayer in ipairs(player.GetAll()) do
                -- Überspringe den lokalen Spieler
                if otherPlayer == ply then continue end

                -- Stelle sicher, dass der Spieler gültig und am Leben ist
                if not IsValid(otherPlayer) or not otherPlayer:Alive() then continue end

                -- Hole die Sichtposition und -winkel des anderen Spielers
                local viewOrigin = otherPlayer:EyePos()
                local viewAngles = otherPlayer:EyeAngles()

                -- Render eine kleine Ansicht im HUD
                cam.Start2D()
                    -- Beispiel: Fenster für die Ansicht
                    local x, y = PD.W(10), PD.H(100) + 120 * (_ - 1) -- Position basierend auf Spielerindex
                    local width, height = 200, 120

                    -- Hintergrund
                    draw.RoundedBox(6, x, y, width, height, Color(0, 0, 0, 200))
                    draw.SimpleText(otherPlayer:Nick(), "Trebuchet24", x + 10, y + 10, color_white)

                    -- Kamera-Ansicht des anderen Spielers rendern
                    render.RenderView({
                        origin = viewOrigin + Vector(0, 0, 30),
                        angles = viewAngles,
                        x = x + 5,
                        y = y + 35,
                        w = width - 10,
                        h = height - 40,
                        drawhud = false,
                        drawviewmodel = false,
                    })
                cam.End2D()
            end
        end

    end

    local noi = 13
    local ComPos = ScrH() - PD.H(30)
    local size = ScrW() * 0.5

    if IsValid(ply) then
        local dir = EyeAngles().y

        for i = 0, 360 / 7.5 - 1 do
            local ang = i * 7.5
            local dif = math.AngleDifference(ang, dir)
            local numofinst = noi
            local offang = (numofinst * 12) / 2.7

            if math.abs(dif) < offang then
                local alpha = math.Clamp(0.7 - (math.abs(dif) / offang), 0, 1) * 255
                local dif2 = size / noi
                local pos = dif / 17 * dif2
                local color = Color(255, 255, 255, alpha)
                local y_offset = ComPos + math.abs(dif) * 2

                if i % 2 == 0 then
                    local text = tostring(360 - ang)
                    local direction = ""

                    if ang == 0 then
                        direction = "N"
                    elseif ang == 180 then
                        direction = "S"
                    elseif ang == 90 then
                        direction = "W"
                    elseif ang == 270 then
                        direction = "O"
                    elseif ang == 45 then
                        direction = "NW"
                    elseif ang == 135 then
                        direction = "SW"
                    elseif ang == 225 then
                        direction = "SO"
                    elseif ang == 315 then
                        direction = "NO"
                    end

                    draw.RoundedBox(0, ScrW() / 2 - pos, y_offset - PD.H(10), PD.W(2), PD.H(10), color)
                    draw.DrawText(text, "estaurebesh15", ScrW() / 2 - pos, y_offset, color, TEXT_ALIGN_CENTER)
                    draw.DrawText(direction, "estaurebesh", ScrW() / 2 - pos, y_offset - PD.H(30), color, TEXT_ALIGN_CENTER)
                else
                    draw.RoundedBox(0, ScrW() / 2 - pos, y_offset - PD.H(5), PD.W(2), PD.H(5), color)
                end
            end
        end

        local ang = (LocalPlayer():GetEyeTrace().HitPos - LocalPlayer():GetPos()):Angle()
        draw.DrawText("▼", "MLIB.15", ScrW() / 2, ComPos - PD.H(40), color, TEXT_ALIGN_CENTER)
        draw.DrawText(math.Round(360 - ang.y), "estaurebesh", ScrW() / 2, ComPos - PD.H(55), color, TEXT_ALIGN_CENTER)
    end

    -- Waffen HUD 
    local wep = ply:GetActiveWeapon()
    if IsValid(wep) then
        local wepName = wep:GetClass()
        if weaponsTbl[wepName] then
            webTbl = {
                mode = "N/A",
                heat_enabled = false,
                heat_level = 0,
                heat_maxlevel = 0
            }
        else
            webTbl = wep:GetHUDData()
        end

        local clip = wep:Clip1()
        local maxclip = wep:GetMaxClip1()
        local ammo = ply:GetAmmoCount(wep:GetPrimaryAmmoType())
        local name = wep:GetPrintName()
        name = name .. " | " .. clip .. " / " .. ammo .. " | " .. webTbl.mode

        Vital("w", 0, ScrW() - PD.W(210), ScrH() - PD.H(30), PD.W(200), PD.H(20), clip, maxclip, Color(255, 255, 255), {10, 10, 0, 0}, true, false)
        draw.DrawText(name, "MLIB.20", ScrW() - PD.W(10), ScrH() - PD.H(55), Color(255, 255, 255), TEXT_ALIGN_RIGHT)

        if webTbl.heat_enabled then
            local txt = "Heat: " .. math.Round(webTbl.heat_level) .. " / " .. webTbl.heat_maxlevel
            draw.DrawText(txt, "MLIB.20", ScrW() - PD.W(10), ScrH() - PD.H(75), Color(255, 255, 255), TEXT_ALIGN_RIGHT)
        end
    end
end)

local dis = {
    ["CHudHealth"]              = true,
    ["CHudBattery"]             = true,
    ["CHudAmmo"]                = true,
    ["CHudSecondaryAmmo"]       = true
}

local function Disabled(r)
    if dis[r] then
        return false
    end
end
hook.Add("HUDShouldDraw","DisableHUD",Disabled)

