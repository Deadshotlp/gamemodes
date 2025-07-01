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

-- Base HUD
AddSmoothElement(PD.W(20), ScrH() - PD.H(90), PD.W(200), PD.H(0), function(smoothX, smoothY)
    local ply = LocalPlayer()

    surface.SetFont("MLIB.20")
    local NameW, NameH = surface.GetTextSize(ply:Nick())

    draw.RoundedBox(0, smoothX, smoothY, NameW + PD.W(20), PD.H(40), PD.UI.Colors["Background"])

    surface.SetDrawColor(DEFCON:GetColor())
    surface.DrawOutlinedRect(smoothX, smoothY, NameW + PD.W(20), PD.H(40), 2)

    draw.DrawText(ply:Nick(), "MLIB.20", smoothX + PD.W(10), smoothY + PD.H(10), Color(255, 255, 255), TEXT_ALIGN_LEFT)
end)

local knownPlayers = {}
local dataFile = "known_players.json"

local function LoadKnown()
    if file.Exists(dataFile, "DATA") then
        local json = file.Read(dataFile, "DATA")
        knownPlayers = util.JSONToTable(json) or {}
    end
end

local function SaveKnown()
    file.Write(dataFile, util.TableToJSON(knownPlayers, true))
end

function PD.HUD.GetKnownPlayers(plyID)
    if plyID == LocalPlayer():SteamID64() then
        return LocalPlayer():Nick()
    end

    return knownPlayers[plyID] or "Unbekannt"
end

function PD.HUD.GetKnownPlayersAll()
    return knownPlayers
end

hook.Add("InitPostEntity", "LoadKnownPlayers", function()
    LoadKnown()
end)

hook.Add("KeyPress", "HandleMeetKeyPress_Client", function(ply, key)
    
end)

local function KnownMenu(name)
    if IsValid(knownMenuFrame) then return end
    if not name or name == "" then
        name = "Unbekannt"
    end

    knownMenuFrame = PD.Frame("Wasn das?", PD.W(300), PD.H(150), true, nil, true)
    knownMenuFrame:SetPos(PD.W(200), PD.H(20))

    local lbl = PD.Label(name .. " möchte deinen\nNamen wissen", knownMenuFrame)

    local bottomPanel = PD.Panel("", knownMenuFrame)
    bottomPanel:Dock(BOTTOM)
    bottomPanel:SetTall(PD.H(50))

    local accept = PD.Button("Akzeptieren", bottomPanel, function()
        knownMenuFrame:Remove()
    end)
    accept:Dock(LEFT)
    accept:SetWide(bottomPanel:GetWide() / 2 - PD.W(10))
    accept:SetHoverColor(PD.UI.Colors["Green"])

    local decline = PD.Button("Ablehnen", bottomPanel, function()
        knownMenuFrame:Remove()
    end)
    decline:Dock(RIGHT)
    decline:SetWide(bottomPanel:GetWide() / 2 - PD.W(10))
    decline:SetHoverColor(PD.UI.Colors["SithRed"])
end

-- if knownMenuFrame then knownMenuFrame:Remove() end

-- KnownMenu()

net.Receive("StartMeetRequest", function()
    local sender = net.ReadEntity()
    
end)

net.Receive("ConfirmMeet", function()
    local p1 = net.ReadEntity()
    local p2 = net.ReadEntity()

    if p1 == LocalPlayer() then
        knownPlayers[p2:SteamID64()] = p2:Nick()
    elseif p2 == LocalPlayer() then
        knownPlayers[p1:SteamID64()] = p1:Nick()
    end
    SaveKnown()
    chat.AddText(Color(0, 255, 255), "Du hast jemanden kennengelernt!")
end)

-- EyeTrace Player HUD
AddSmoothElement(PD.W(20), ScrH() - PD.H(135), PD.W(200), PD.H(40), function(smoothX, smoothY)
    local ply = LocalPlayer()
    local trace = ply:GetEyeTrace()
    local ent = trace.Entity
    if not IsValid(ent) or ent == ply then return end
    if not ent:IsPlayer() then return end
    local name = PD.HUD.GetKnownPlayers(ent:SteamID64())

    surface.SetFont("MLIB.20")
    local nameW, nameH = surface.GetTextSize(name)
    
    draw.RoundedBox(0, smoothX, smoothY, nameW + PD.W(20), PD.H(40), PD.UI.Colors["Background"])

    surface.SetDrawColor(DEFCON:GetColor())
    surface.DrawOutlinedRect(smoothX, smoothY, nameW + PD.W(20), PD.H(40), 2)

    draw.DrawText(name, "MLIB.20", smoothX + PD.W(10), smoothY + PD.H(10), Color(255, 255, 255), TEXT_ALIGN_LEFT)
    -- draw.DrawText(name[2], "MLIB.20", smoothX + PD.W(10), smoothY + PD.H(20), Color(255, 255, 255), TEXT_ALIGN_LEFT)
end)

-- Radar / Kompass HUD
AddSmoothElement(PD.W(20), PD.H(20), PD.W(150), PD.H(150), function(smoothX, smoothY)
    local ply = LocalPlayer()
    
    local mapX, mapY = smoothX, smoothY
    local mapSize = PD.H(150)
    local centerX, centerY = mapX + mapSize / 2, mapY + mapSize / 2
    local radarRange = 1000

    surface.SetDrawColor(DEFCON:GetColor())
    surface.DrawOutlinedRect(smoothX, smoothY, PD.W(150), PD.H(150), 2)
    
    surface.SetDrawColor(30, 30, 30, 200)
    surface.DrawRect(mapX, mapY, mapSize, mapSize)

    surface.SetDrawColor(70, 70, 70, 100)
    for i = 0, 10 do
        local offset = i * (mapSize / 10)
        
        surface.DrawLine(mapX + offset, mapY, mapX + offset, mapY + mapSize)
        surface.DrawLine(mapX, mapY + offset, mapX + mapSize, mapY + offset)
    end

    draw.DrawText("Radar\nBald verfügbar!", "MLIB.20", centerX, mapY + PD.H(55), Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

    -- local eyeAngles = ply:EyeAngles() 

    -- surface.SetDrawColor(100, 100, 255, 150)
    -- surface.DrawPoly({
    --     {x = centerX, y = centerY},
    --     {x = centerX - 50, y = centerY - 50},
    --     {x = centerX + 50, y = centerY - 50},
    -- })

    -- for _, ent in ipairs(ents.GetAll()) do
    --     if not IsValid(ent) or ent == ply then continue end

    --     local isPlayer = ent:IsPlayer()
    --     local isNPC = ent:IsNPC()
    --     local isBot = isPlayer and ent:IsBot()
    --     local posDiff = ent:GetPos() - ply:GetPos()
    --     local distance = posDiff:Length()

    --     if distance <= radarRange then
    --         local radarX = (posDiff.y / radarRange) * (mapSize / 2)
    --         local radarY = (posDiff.x / radarRange) * (mapSize / 2)
    --         local angleRad = math.rad(eyeAngles.y)
    --         local rotatedX = radarX * math.cos(angleRad) + radarY * math.sin(angleRad)
    --         local rotatedY = radarY * math.cos(angleRad) + radarX * math.sin(angleRad)
    --         local drawX = centerX + rotatedX
    --         local drawY = centerY - rotatedY

    --         if isPlayer and isBot then
    --             surface.SetDrawColor(255, 255, 0, 255) -- 🟡 Bots
    --         elseif isPlayer then
    --             surface.SetDrawColor(0, 255, 0) -- 🔵 Spieler
    --         elseif isNPC then
    --             surface.SetDrawColor(255, 0, 0, 255) -- 🔴 NPCs
    --         else
    --             continue
    --         end

    --         surface.DrawRect(drawX - 2, drawY - 2, 4, 4)
    --     end
    -- end

    -- surface.SetDrawColor(0, 255, 0, 255)
    -- surface.DrawRect(centerX - 3, centerY - 3, 6, 6)

    -- Kompass unten
    local directions = {"N", "NE", "E", "SE", "S", "SW", "W", "NW"}
    local yaw = math.NormalizeAngle(ply:EyeAngles().y)
    local compassWidth = PD.H(150)
    local compassX = smoothX
    local compassY = smoothY + mapSize + PD.H(12)

    surface.SetDrawColor(30, 30, 30, 200)
    surface.DrawRect(compassX, compassY - PD.H(7), compassWidth, 20)

    surface.SetDrawColor(DEFCON:GetColor())
    surface.DrawOutlinedRect(compassX, compassY - PD.H(7), compassWidth, 20, 2)

    for i, dir in ipairs(directions) do
        local angleOffset = (i - 1) * 45
        local diff = math.AngleDifference(yaw, angleOffset)
        local x = compassX + compassWidth / 2 + (diff * 3)

        if x > compassX and x < compassX + compassWidth then
            draw.SimpleText(dir, "MLIB.15", x, compassY, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
end)

-- Waffen HUD
AddSmoothElement(ScrW() - PD.W(200), ScrH() - PD.H(87), PD.W(180), PD.H(67), function(smoothX, smoothY)
    local ply = LocalPlayer()
    local wep = ply:GetActiveWeapon()

    draw.RoundedBox(0, smoothX, smoothY, PD.W(180), PD.H(67), PD.UI.Colors["Background"])

    surface.SetDrawColor(DEFCON:GetColor())
    surface.DrawOutlinedRect(smoothX, smoothY, PD.W(180), PD.H(67), 2)

    if IsValid(wep) then
        local clip = wep:Clip1()
        local ammo = ply:GetAmmoCount(wep:GetPrimaryAmmoType())

        if clip == -1 then
            clip = 0
        end

        draw.DrawText("000", "MLIB.70", smoothX + PD.W(10), smoothY, PD.UI.Colors["Grey3"], TEXT_ALIGN_LEFT)
        draw.DrawText(clip, "MLIB.70", smoothX + PD.W(10), smoothY, Color(255, 255, 255), TEXT_ALIGN_LEFT)

        draw.DrawText("000", "MLIB.35", smoothX + PD.W(120), smoothY + PD.H(27), PD.UI.Colors["Grey3"], TEXT_ALIGN_LEFT)
        draw.DrawText(ammo, "MLIB.35", smoothX + PD.W(120), smoothY + PD.H(27), Color(255, 255, 255), TEXT_ALIGN_LEFT)
    end
end)

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
    draw.RoundedBox(100, ScrW() / 2 - PD.W(1), ScrH() / 2 - PD.H(1), PD.W(2), PD.H(2), Color(255, 255, 255))

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