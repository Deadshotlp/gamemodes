-- HUD 

local webTbl = {}
local wh = 0
local weaponsTbl = {
    ["weapon_physgun"] = true,
    ["gmod_tool"] = true,
    ["gmod_camera"] = true,
    ["datapad"] = true,
    ["mhands"] = true,
    ["hackingtool"] = true,
    ["idcard"] = true,
    ["repairstool"] = true,
}


PD.HUD = PD.HUD or {}
PD.HUD.x = PD.W(10)
PD.HUD.y = ScrH() - PD.H(60)

local elements = {}

function AddSmoothElement(baseX, baseY, sizeW, sizeH, drawFunc)
    table.insert(elements, {
        baseX = baseX,
        baseY = baseY,
        sizeW = sizeW,
        sizeH = sizeH,
        targetX = baseX,
        targetY = baseY,
        smoothX = baseX,
        smoothY = baseY,
        sensitivity = 1,
        followSpeed = 5,
        drawFunc = drawFunc
    })
end

local lastEyeAngles = Angle(0, 0, 0)

-- Base HUD - Star Wars Andor Imperial Style (Zentral über PD.Theme)
AddSmoothElement(PD.W(20), ScrH() - PD.H(125), PD.W(350), PD.H(105), function(smoothX, smoothY)
    if PD.FOV.thirdPerson then return end
    
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    -- Charakterdaten holen
    local rpName = ply:GetNWString("rpname", ply:Nick())
    local jobID, jobTbl = ply:GetJob()
    local jobName = jobTbl and jobTbl.name or "Unbekannt"
    local unitName = jobTbl and jobTbl.unit or ""

    -- Id Entfernen, wenn showid true ist
    if jobTbl and jobTbl.showid then
        -- es werden die ersten 7 zeichen entfernt 00-0000
        local name = string.sub(rpName, 8)
        rpName = name
    end

    -- Text-Breiten berechnen
    surface.SetFont("MLIB.28")
    local nameW, nameH = surface.GetTextSize(rpName)
    surface.SetFont("MLIB.18")
    local jobW, jobH = surface.GetTextSize(jobName)
    surface.SetFont("MLIB.14")
    local unitW, unitH = surface.GetTextSize(unitName)

    local panelW = math.max(nameW, jobW, unitW) + PD.W(50)
    local panelH = PD.H(105)

    -- Panel mit zentralem Theme zeichnen
    PD.DrawPanel(smoothX, smoothY, panelW, panelH, {
        background = PD.Theme.Colors.BackgroundLight,
        accent = PD.Theme.Colors.AccentRed,
        accentTop = false,
        accentBottom = false,
        corners = false,
        borders = false
    })

    -- Linke Akzentlinie (Imperial Red)
    surface.SetDrawColor(PD.Theme.Colors.AccentRed)
    surface.DrawRect(smoothX, smoothY, PD.W(4), panelH)

    -- Obere horizontale Akzentlinie
    surface.SetDrawColor(PD.Theme.Colors.AccentGray)
    surface.DrawRect(smoothX + PD.W(4), smoothY, panelW - PD.W(4), 1)

    -- Untere horizontale Akzentlinie
    surface.DrawRect(smoothX + PD.W(4), smoothY + panelH - 1, panelW - PD.W(4), 1)

    -- Trennlinie unter dem Namen
    PD.DrawDivider(smoothX + PD.W(15), smoothY + PD.H(38), panelW - PD.W(30))

    if jobTbl.showid then
        local nameWords = string.Split(rpName, " ")
        rpName = ""

        for i = 2, #nameWords do
            rpName = rpName .. " " .. nameWords[i]
        end
    end

    -- Charaktername
    draw.DrawText(rpName, "MLIB.28", smoothX + PD.W(15), smoothY + PD.H(8), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)

    -- Job/Rang
    draw.DrawText(jobName, "MLIB.18", smoothX + PD.W(15), smoothY + PD.H(45), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)

    -- Einheit (wenn vorhanden)
    if unitName and unitName ~= "" then
        draw.DrawText(unitName, "MLIB.14", smoothX + PD.W(15), smoothY + PD.H(70), PD.Theme.Colors.AccentGray, TEXT_ALIGN_LEFT)
    end

    -- Imperial Ecken-Dekor (oben rechts)
    local cornerSize = PD.W(8)
    surface.SetDrawColor(PD.Theme.Colors.AccentGray)
    surface.DrawLine(smoothX + panelW - cornerSize, smoothY, smoothX + panelW, smoothY)
    surface.DrawLine(smoothX + panelW - 1, smoothY, smoothX + panelW - 1, smoothY + cornerSize)

    -- Imperial Ecken-Dekor (unten rechts)
    surface.DrawLine(smoothX + panelW - cornerSize, smoothY + panelH - 1, smoothX + panelW, smoothY + panelH - 1)
    surface.DrawLine(smoothX + panelW - 1, smoothY + panelH - cornerSize, smoothX + panelW - 1, smoothY + panelH)

    -- Status-Indikator Punkt
    PD.DrawStatusIndicator(smoothX + panelW - PD.W(18), smoothY + PD.H(12), PD.W(8), PD.Theme.Colors.AccentRed, false)
end)

-- EyeTrace Player HUD - Star Wars Andor Imperial Style (Zentral über PD.Theme)
AddSmoothElement(PD.W(20), ScrH() - PD.H(200), PD.W(280), PD.H(55), function(smoothX, smoothY)
    if PD.FOV.thirdPerson then return end

    local ply = LocalPlayer()
    local trace = ply:GetEyeTrace()
    local ent = trace.Entity
    if not IsValid(ent) or ent == ply then return end
    if not ent:IsPlayer() then return end
    
    local name = PD.HUD.GetKnownPlayers(ent:SteamID64())
    
    -- Target Job holen (wenn bekannt)
    local targetJobID, targetJobTbl = ent:GetJob()
    local targetJob = targetJobTbl and targetJobTbl.name or ""

    surface.SetFont("MLIB.20")
    local nameW, nameH = surface.GetTextSize(name)
    surface.SetFont("MLIB.14")
    local jobW, jobH = surface.GetTextSize(targetJob)

    local panelW = math.max(nameW, jobW) + PD.W(40)
    local panelH = PD.H(50)

    -- Hintergrund
    draw.RoundedBox(0, smoothX, smoothY, panelW, panelH, PD.Theme.Colors.BackgroundLight)

    -- Linke Akzentlinie (Imperial Blue für Target)
    surface.SetDrawColor(PD.Theme.Colors.AccentBlue)
    surface.DrawRect(smoothX, smoothY, PD.W(3), panelH)

    -- Obere Linie
    surface.SetDrawColor(PD.Theme.Colors.AccentGray)
    surface.DrawRect(smoothX + PD.W(3), smoothY, panelW - PD.W(3), 1)

    -- Untere Linie  
    surface.DrawRect(smoothX + PD.W(3), smoothY + panelH - 1, panelW - PD.W(3), 1)

    -- Target Icon (kleines Fadenkreuz)
    local iconX = smoothX + PD.W(12)
    local iconY = smoothY + panelH / 2
    local iconSize = PD.W(4)
    surface.SetDrawColor(PD.Theme.Colors.AccentBlue)
    surface.DrawLine(iconX - iconSize, iconY, iconX + iconSize, iconY)
    surface.DrawLine(iconX, iconY - iconSize, iconX, iconY + iconSize)

    -- Name
    draw.DrawText(name, "MLIB.20", smoothX + PD.W(22), smoothY + PD.H(6), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)

    -- Job (wenn bekannt und nicht "Unbekannt")
    if targetJob ~= "" then
        draw.DrawText(targetJob, "MLIB.14", smoothX + PD.W(22), smoothY + PD.H(28), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
    end
end)

-- Kompass HUD
AddSmoothElement(ScrW() / 2 - PD.W(250), ScrH() - PD.H(110), PD.W(500), PD.H(90), function(smoothX, smoothY)
    if PD.FOV.thirdPerson then return end

    local ply = LocalPlayer()
    local yaw = math.NormalizeAngle(ply:EyeAngles().y)
    local compassWidth = PD.W(475)
    local compassX = smoothX
    local compassY = smoothY + PD.H(20)
    local curveDepth = PD.H(25)
    local scale = 5
    local directions = {"N","NE","E","SE","S","SW","W","NW"}

    for i = -180, 180, 5 do
        local rel = math.AngleDifference(i, yaw)
        local x = compassX + compassWidth / 2 - rel * scale
        if x > compassX and x < compassX + compassWidth then
            local normalized = (x - (compassX + compassWidth / 2)) / (compassWidth / 2)
            local offsetY = (normalized ^ 2) * curveDepth
            local alpha = math.Clamp(255 - math.abs(rel * 2), 0, 255)
            local isMajor = i % 45 == 0

            surface.SetDrawColor(255, 255, 255, alpha)
            surface.DrawRect(x, compassY + PD.H(25) + offsetY, PD.W(1), isMajor and PD.H(15) or PD.H(8))

            if isMajor then
                local ang = math.NormalizeAngle(i - 90)
                local idx = math.floor((ang + 180) / 45) + 1
                local dir = directions[idx]
                if dir then
                    draw.SimpleText(dir, "MLIB.20", x, compassY + offsetY, Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
        end
    end

    surface.SetDrawColor(DEFCON:GetColor())
    surface.DrawLine(compassX + compassWidth / 2, compassY + PD.H(10), compassX + compassWidth / 2, compassY + PD.H(60))
end)

-- Waffen HUD - Star Wars Andor Imperial Style (Zentral über PD.Theme)
AddSmoothElement(ScrW() - PD.W(20), ScrH() - PD.H(95), PD.W(0), PD.H(75), function(smoothX, smoothY)
    if PD.FOV.thirdPerson then return end

    local ply = LocalPlayer()
    local wep = ply:GetActiveWeapon()

    if IsValid(wep) then
        local clip = wep:Clip1()
        local ammo = ply:GetAmmoCount(wep:GetPrimaryAmmoType())

        if not wep:GetMaxClip1() or wep:GetMaxClip1() <= 0 then
            return
        end

        if clip == -1 then
            clip = 0
        end

        surface.SetFont("MLIB.55")
        local clipW, clipH = surface.GetTextSize(clip)
        surface.SetFont("MLIB.25")
        local ammoW, ammoH = surface.GetTextSize("/" .. ammo)

        local totalW = clipW + ammoW + PD.W(35)
        local panelH = PD.H(75)
        smoothX = smoothX - totalW

        -- Hintergrund
        draw.RoundedBox(0, smoothX, smoothY, totalW, panelH, PD.Theme.Colors.BackgroundLight)

        -- Rechte Akzentlinie (Imperial Red)
        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
        surface.DrawRect(smoothX + totalW - PD.W(4), smoothY, PD.W(4), panelH)

        -- Obere Linie
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(smoothX, smoothY, totalW - PD.W(4), 1)

        -- Untere Linie
        surface.DrawRect(smoothX, smoothY + panelH - 1, totalW - PD.W(4), 1)

        -- Linke Eck-Dekor
        local cornerSize = PD.W(8)
        surface.DrawLine(smoothX, smoothY, smoothX + cornerSize, smoothY)
        surface.DrawLine(smoothX, smoothY, smoothX, smoothY + cornerSize)
        surface.DrawLine(smoothX, smoothY + panelH - 1, smoothX + cornerSize, smoothY + panelH - 1)
        surface.DrawLine(smoothX, smoothY + panelH - cornerSize, smoothX, smoothY + panelH - 1)

        -- Magazin-Farbe basierend auf Munition
        local clipColor = PD.Theme.Colors.Text
        if clip <= 5 and clip > 0 then
            clipColor = PD.Theme.Colors.StatusWarning
        elseif clip == 0 then
            clipColor = PD.Theme.Colors.StatusCritical
        end

        -- Clip Anzeige (große Zahl)
        draw.DrawText(clip, "MLIB.55", smoothX + PD.W(12), smoothY + PD.H(8), clipColor, TEXT_ALIGN_LEFT)

        -- Reserve Munition (kleinere Zahl mit Trennstrich)
        draw.DrawText("/" .. ammo, "MLIB.25", smoothX + PD.W(12) + clipW + PD.W(5), smoothY + PD.H(30), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)

        local firemode = ""

        if wep and wep.GetFireMode then
            firemode = wep:GetFireMode()
        end

        local firetext = ""

        if firemode == 1 then
            firetext = "DAUERFEUER"
        elseif firemode == 2 then
            firetext = "BURSTFEUER"
        elseif firemode == 3 then
            firetext = "EINZELFEUER"
        elseif firemode == 4 then
            firetext = "GESICHERT"
        end

        -- "AMMO" Label
        PD.DrawLabel(firetext, "MLIB.12", smoothX + PD.W(12), smoothY + panelH - PD.H(18))
    end
end)

PD.HUD.ShowPoint = PD.HUD.ShowPoint or true
hook.Add("HUDPaint", "PD.GamemodeHUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if not ply:Alive() then return end

    local eyeAngles = ply:EyeAngles()
    local deltaYaw = math.AngleDifference(eyeAngles.y, lastEyeAngles.y)
    local deltaPitch = math.AngleDifference(eyeAngles.p, lastEyeAngles.p)

    -- Trace nach vorne prüfen
    local tr = util.TraceLine({
        start = ply:EyePos(),
        endpos = ply:EyePos() + ply:EyeAngles():Forward() * 100, -- 100 Units (1 Meter)
        filter = ply
    })

    -- Wenn das Ziel näher als 100 Units ist -> Keine HUD-Bewegung
    if tr.Hit and tr.Fraction < 1 then
        deltaYaw = 0
        deltaPitch = 0
    end

    for _, e in ipairs(elements) do
        if not e.sizeW or not e.sizeH then
            continue
        end

        e.targetX = e.targetX + deltaYaw * e.sensitivity
        e.targetY = e.targetY - deltaPitch * e.sensitivity
        e.targetX = Lerp(FrameTime() * e.followSpeed, e.targetX, e.baseX)
        e.targetY = Lerp(FrameTime() * e.followSpeed, e.targetY, e.baseY)
        e.smoothX = Lerp(FrameTime() * e.followSpeed, e.smoothX, e.targetX)
        e.smoothY = Lerp(FrameTime() * e.followSpeed, e.smoothY, e.targetY)

        e.smoothX = math.Clamp(e.smoothX, PD.W(0), ScrW() - e.sizeW)
        e.smoothY = math.Clamp(e.smoothY, PD.H(0), ScrH() - e.sizeH)

        if e.drawFunc then
            e.drawFunc(e.smoothX, e.smoothY)
        end
    end

    -- Mittelpunkt
    -- if PD.HUD.ShowPoint then
    --     draw.RoundedBox(100, ScrW() / 2 - PD.W(1), ScrH() / 2 - PD.H(1), PD.W(2), PD.H(2), Color(255, 255, 255))
    -- end
    -- Letzte EyeAngles merken
    lastEyeAngles = eyeAngles
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

hook.Add("HUDDrawTargetID", "RemoveTargetID", function()
    return false
end)
