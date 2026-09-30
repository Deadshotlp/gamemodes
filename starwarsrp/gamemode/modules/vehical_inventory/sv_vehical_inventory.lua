PD.VehicalInventory = PD.VehicalInventory or {}
PD.VehicalInventory.vehicals = {}
-- [vehicle] = {
--     cargo_slots = 4,
--     cargo_space = {
--         [1] = {
--             ent = Entity,
--             class = "prop_physics",
--             name = "Kiste",
--             is_ragdoll = false,
--         },
--     },
--     players_looking = { [steamid64] = true },
-- }

-- Wie viele Cargo Slots ein Fahrzeug je nach Klasse hat. Fehlt ein Eintrag wird DEFAULT_CARGO_SLOTS genutzt.
PD.VehicalInventory.VehicleConfig = {
    ["lvs_sw_transport"] = {cargo_slots = 6},
    ["lvs_fakehover_iftx"] = {cargo_slots = 5},
}

PD.VehicalInventory.ValidCargo = {
    "munitionsbox",
    "prop_physics",
    "prop_physics_multiplayer",
    --"prop_ragdoll",
}

local DEFAULT_CARGO_SLOTS = 4
local INTERACT_RANGE = 1000 -- Maximaler Abstand Spieler <-> Fahrzeug für jede Interaktion
local SCAN_RADIUS = 250 -- ~2 Meter (1m =~ 39.37 units)

util.AddNetworkString("PD.VehicalInventory.StartRequestItems")
util.AddNetworkString("PD.VehicalInventory.EndRequestItems")
util.AddNetworkString("PD.VehicalInventory.UpdateRequestItems")
util.AddNetworkString("PD.VehicalInventory.LoadEntity")
util.AddNetworkString("PD.VehicalInventory.UnloadEntity")
util.AddNetworkString("PD.VehicalInventory.ForceClose")

local function GetCargoSlots(vehicle)
    local cfg = PD.VehicalInventory.VehicleConfig[vehicle:GetClass()]
    return cfg and cfg.cargo_slots or DEFAULT_CARGO_SLOTS
end

local function GetCargoData(vehicle)
    local data = PD.VehicalInventory.vehicals[vehicle]

    if not data then
        data = {
            cargo_slots = GetCargoSlots(vehicle),
            cargo_space = {},
            players_looking = {}
        }
        PD.VehicalInventory.vehicals[vehicle] = data
    end

    return data
end

local function GetDisplayName(ent)
    if ent:IsRagdoll() then
        local owner = ent:GetNW2Entity("PD.DM.RagdollOwner")
        if IsValid(owner) and owner:IsPlayer() then
            return "Leiche von " .. owner:Nick()
        end

        return "Unbekannte Leiche"
    end

    local fileName = string.StripExtension(string.GetFileFromFilename(ent:GetModel() or ""))
    if fileName and fileName ~= "" then
        return fileName
    end

    return ent:GetClass()
end

local function IsCargoableEntity(ent)
    if not IsValid(ent) then return false end
    if ent:IsRagdoll() then return true end

    local class = ent:GetClass()

    for _, validClass in ipairs(PD.VehicalInventory.ValidCargo) do
        if class == validClass then
            return true
        end
    end

    return false
end

local function IsEntityFrozen(ent)
    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then return false end

    return not phys:IsMotionEnabled()
end

local function IsEntityStored(ent)
    for _, data in pairs(PD.VehicalInventory.vehicals) do
        for _, slot in pairs(data.cargo_space) do
            if slot.ent == ent then
                return true
            end
        end
    end

    return false
end

local function FindFreeSlot(data)
    for i = 1, data.cargo_slots do
        if not data.cargo_space[i] then
            return i
        end
    end

    return nil
end

local function GetNearbyEntities(vehicle)
    local nearby = {}

    for _, ent in ipairs(ents.FindInSphere(vehicle:GetPos(), SCAN_RADIUS)) do
        if ent == vehicle then continue end
        if not IsCargoableEntity(ent) then continue end
        if IsEntityStored(ent) then continue end

        table.insert(nearby, {
            entindex = ent:EntIndex(),
            class = ent:GetClass(),
            name = GetDisplayName(ent),
            is_ragdoll = ent:IsRagdoll(),
            frozen = IsEntityFrozen(ent)
        })
    end

    return nearby
end

local function BuildClientState(vehicle)
    local data = GetCargoData(vehicle)

    local cargo = {}
    for i = 1, data.cargo_slots do
        local slot = data.cargo_space[i]
        if slot and IsValid(slot.ent) then
            cargo[i] = {
                class = slot.class,
                name = slot.name,
                is_ragdoll = slot.is_ragdoll
            }
        end
    end

    return {
        cargo_slots = data.cargo_slots,
        cargo_space = cargo,
        nearby = GetNearbyEntities(vehicle)
    }
end

local function CanInteract(ply, vehicle)
    return IsValid(ply) and IsValid(vehicle) and ply:GetPos():Distance(vehicle:GetPos()) <= INTERACT_RANGE
end

local function SendStateTo(vehicle, ply)
    local state = BuildClientState(vehicle)

    net.Start("PD.VehicalInventory.UpdateRequestItems")
    net.WriteEntity(vehicle)
    net.WriteTable(state)
    net.Send(ply)
end

local function BroadcastState(vehicle)
    local data = PD.VehicalInventory.vehicals[vehicle]
    if not data then return end

    for steamid in pairs(data.players_looking) do
        local ply = player.GetBySteamID64(steamid)

        if not CanInteract(ply, vehicle) then
            data.players_looking[steamid] = nil
            continue
        end

        SendStateTo(vehicle, ply)
    end
end

-- Nicht-Ragdolls: normales Teleportieren ueber den Entity-Ursprung.
local function MoveEntity(ent, pos, ang)
    ent:SetPos(pos)
    ent:SetAngles(ang)
end

-- Pose eines Ragdolls sichern: alle Bones relativ zu Bone 0 (Wurzel).
-- Bewusst NICHT relativ zu ent:GetPos(): der Entity-Ursprung folgt nach dem
-- SetParent dem Fahrzeug, die eingefrorenen Bone-PhysObjs bleiben dagegen an
-- ihrer Weltposition vom Einladen stehen. Beide Werte liegen damit in
-- unterschiedlichen Bezugssystemen, und genau diese Differenz war der Versatz
-- beim Ausladen.
local function CaptureRagdollPose(ent)
    local root = ent:GetPhysicsObjectNum(0)
    if not IsValid(root) then return nil end

    local refPos, refAng = root:GetPos(), root:GetAngles()
    local bones = {}

    for i = 0, ent:GetPhysicsObjectCount() - 1 do
        local phys = ent:GetPhysicsObjectNum(i)
        if IsValid(phys) then
            local localPos, localAng = WorldToLocal(phys:GetPos(), phys:GetAngles(), refPos, refAng)
            bones[i] = {pos = localPos, ang = localAng}
        end
    end

    return {bones = bones, ang = refAng}
end

-- Setzt die gesicherte Pose an einer neuen Position wieder zusammen.
local function ApplyRagdollPose(ent, pose, pos, ang)
    for i = 0, ent:GetPhysicsObjectCount() - 1 do
        local phys = ent:GetPhysicsObjectNum(i)
        local bone = pose.bones[i]

        if IsValid(phys) and bone then
            local worldPos, worldAng = LocalToWorld(bone.pos, bone.ang, pos, ang)

            -- EnableMotion(true) muss vor SetPos kommen: auf einem eingefrorenen
            -- PhysObj wird eine neue Position nicht uebernommen.
            phys:EnableMotion(true)
            phys:SetPos(worldPos)
            phys:SetAngles(worldAng)
            phys:SetVelocity(vector_origin)
            phys:AddAngleVelocity(phys:GetAngleVelocity() * -1)
            phys:Wake()
        end
    end
end

local DROP_CLEARANCE = 60 -- Abstand zwischen Fahrzeughülle und Ablageort
local MIN_DROP_DISTANCE = 200 -- Untergrenze, falls die Bounding Box zu klein ausfällt

-- Richtung vom Fahrzeug zu dem Spieler, der auslädt - so landet die Fracht immer
-- auf der Seite, auf der derjenige steht. Ohne Spieler (Cleanup beim Entfernen des
-- Fahrzeugs) bleibt es bei der rechten Seite wie bisher.
local function GetDropDir(vehicle, ply)
    local dir

    if IsValid(ply) then
        dir = ply:GetPos() - vehicle:GetPos()
        dir.z = 0
    end

    -- Spieler steht exakt auf der Fahrzeugachse (oder fehlt): Fallback rechts.
    if not dir or dir:LengthSqr() < 1 then
        dir = vehicle:GetRight()
        dir.z = 0
    end

    dir:Normalize()

    return dir
end

-- Fahrzeug, Fracht und alles was am Fahrzeug hängt aus den Traces heraushalten:
-- LVS-Fahrzeuge bestehen aus mehreren Entities (Rumpf, Räder, Sitze). Filtert man
-- nur das Fahrzeug selbst, schlägt die Trace sofort auf einem Kindobjekt an.
local function BuildDropFilter(ent, vehicle)
    local filter = {ent, vehicle}

    for _, child in ipairs(vehicle:GetChildren()) do
        table.insert(filter, child)
    end

    local root = vehicle:GetParent()
    if IsValid(root) then
        table.insert(filter, root)

        for _, child in ipairs(root:GetChildren()) do
            table.insert(filter, child)
        end
    end

    return filter
end

-- Abstand vom Fahrzeugursprung bis zum Rand der Bounding Box in Richtung dir.
-- Ein fester Wert läge bei langen Fahrzeugen je nach Seite noch im Modell.
local function GetHullDistance(vehicle, dir)
    local localDir = vehicle:WorldToLocal(vehicle:GetPos() + dir)
    local mins, maxs = vehicle:OBBMins(), vehicle:OBBMaxs()

    local dist = math.huge

    for _, axis in ipairs({"x", "y"}) do
        local d = localDir[axis]

        if math.abs(d) > 0.001 then
            local bound = d > 0 and maxs[axis] or mins[axis]
            dist = math.min(dist, bound / d)
        end
    end

    if dist == math.huge then return 0 end

    return math.abs(dist)
end

local function GetDropPos(ent, vehicle, ply)
    local dir = GetDropDir(vehicle, ply)
    local origin = vehicle:GetPos() + Vector(0, 0, 40)
    local filter = BuildDropFilter(ent, vehicle)

    local distance = math.max(GetHullDistance(vehicle, dir) + DROP_CLEARANCE, MIN_DROP_DISTANCE)
    local dropPos = origin + dir * distance

    -- Steht eine Wand zwischen Fahrzeug und Ablageort, kurz davor ablegen statt die
    -- Fracht durch die Geometrie zu schieben.
    local side = util.TraceLine({
        start = origin,
        endpos = dropPos,
        filter = filter,
        mask = MASK_SOLID
    })

    -- StartSolid wird bewusst ignoriert: beginnt die Trace in Resten der
    -- Fahrzeugkollision, liefert sie HitPos == start und die Fracht landete
    -- dadurch unter dem Fahrzeug.
    if side.Hit and not side.StartSolid then
        local blocked = side.HitPos - dir * 16

        -- Nur zurückziehen, wenn davor überhaupt noch Platz neben dem Fahrzeug ist.
        if (blocked - origin):Dot(dir) >= MIN_DROP_DISTANCE * 0.5 then
            dropPos = blocked
        end
    end

    -- Strikt entlang der Weltachse nach unten suchen: vehicle:GetUp() zeigt bei
    -- schräg stehendem Fahrzeug in die falsche Richtung.
    local tr = util.TraceLine({
        start = dropPos,
        endpos = dropPos - Vector(0, 0, 300),
        filter = filter,
        mask = MASK_SOLID
    })

    if tr.Hit and not tr.StartSolid then
        return tr.HitPos + Vector(0, 0, 5)
    end

    return dropPos
end

local function RestoreEntity(slot, vehicle, ply)
    local ent = slot.ent
    local restorePos = GetDropPos(ent, vehicle, ply)

    -- Erst unparenten und bewegen, WÄHREND die Entity noch NotSolid ist. Würde man
    -- SetNotSolid(false) vorher setzen, hält die Physik-Engine das Reinteleportieren
    -- in überlappende Geometrie (Fahrzeug/Boden) für eine Kollision und löst
    -- Crush-Damage (TakeDamage) aus.
    ent:SetParent(nil)

    if ent:IsRagdoll() and slot.pose then
        -- Drehung des Fahrzeugs seit dem Einladen mitnehmen, damit die Leiche
        -- relativ zum Fahrzeug so herauskommt, wie sie hineingelegt wurde.
        local yawDelta = vehicle:GetAngles().y - (slot.vehicle_yaw or vehicle:GetAngles().y)
        local restoreAng = Angle(slot.pose.ang.p, slot.pose.ang.y + yawDelta, slot.pose.ang.r)

        ApplyRagdollPose(ent, slot.pose, restorePos, restoreAng)
    else
        MoveEntity(ent, restorePos, vehicle:GetAngles())

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(true)
            phys:Wake()
        end
    end

    ent:SetNoDraw(false)
    ent:SetNotSolid(false)

    -- Kamera des Ragdoll-Besitzers heftet sich wieder an das (jetzt sichtbare) Ragdoll.
    if ent:IsRagdoll() then
        local owner = ent:GetNW2Entity("PD.DM.RagdollOwner")
        if IsValid(owner) and owner:IsPlayer() then
            owner:SetViewEntity(ent)
            owner:SetPos(restorePos)
        end
    end
end

net.Receive("PD.VehicalInventory.StartRequestItems", function(len, ply)
    local vehicle = net.ReadEntity()

    if not CanInteract(ply, vehicle) then return end

    local data = GetCargoData(vehicle)
    data.players_looking[ply:SteamID64()] = true

    SendStateTo(vehicle, ply)
end)

net.Receive("PD.VehicalInventory.EndRequestItems", function(len, ply)
    local vehicle = net.ReadEntity()

    local data = PD.VehicalInventory.vehicals[vehicle]
    if data then
        data.players_looking[ply:SteamID64()] = nil
    end
end)

net.Receive("PD.VehicalInventory.LoadEntity", function(len, ply)
    local vehicle = net.ReadEntity()
    local target = net.ReadEntity()

    if not CanInteract(ply, vehicle) then return end
    if not IsCargoableEntity(target) then return end
    if IsEntityFrozen(target) then return end
    if IsEntityStored(target) then return end
    if target:GetPos():Distance(vehicle:GetPos()) > SCAN_RADIUS then return end

    local data = GetCargoData(vehicle)
    local slotIndex = FindFreeSlot(data)
    if not slotIndex then return end

    -- Pose sichern, BEVOR geparented und eingefroren wird - danach sind die
    -- Bone-Weltpositionen nicht mehr mit dem Entity-Ursprung deckungsgleich.
    local pose = target:IsRagdoll() and CaptureRagdollPose(target) or nil

    data.cargo_space[slotIndex] = {
        ent = target,
        class = target:GetClass(),
        name = GetDisplayName(target),
        is_ragdoll = target:IsRagdoll(),
        pose = pose,
        vehicle_yaw = vehicle:GetAngles().y
    }

    -- Entity bleibt vollständig bestehen (nur versteckt/eingefroren/geparented), damit
    -- z.B. die NW2Entity Verknüpfung Ragdoll <-> Spieler aus dem Medic Modul erhalten bleibt.
    target:SetParent(vehicle)
    target:SetNoDraw(true)
    target:SetNotSolid(true)

    -- Bei Ragdolls müssen ALLE Bone-Physics-Objekte eingefroren werden, nicht nur das
    -- Hauptobjekt - sonst fallen die übrigen Bones (Schwerkraft, NotSolid) während der
    -- Lagerung unkontrolliert weiter und driften vom Entity-Ursprung weg.
    for i = 0, target:GetPhysicsObjectCount() - 1 do
        local phys = target:GetPhysicsObjectNum(i)
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:Sleep()
        end
    end

    -- Kamera des Ragdoll-Besitzers folgt jetzt dem Fahrzeug statt dem (versteckten) Ragdoll.
    if target:IsRagdoll() then
        local owner = target:GetNW2Entity("PD.DM.RagdollOwner")
        if IsValid(owner) and owner:IsPlayer() then
            owner:SetViewEntity(vehicle)
        end
    end

    BroadcastState(vehicle)
end)

net.Receive("PD.VehicalInventory.UnloadEntity", function(len, ply)
    local vehicle = net.ReadEntity()
    local slotIndex = net.ReadUInt(8)

    if not CanInteract(ply, vehicle) then return end

    local data = PD.VehicalInventory.vehicals[vehicle]
    if not data then return end

    local slot = data.cargo_space[slotIndex]
    if not slot or not IsValid(slot.ent) then return end

    RestoreEntity(slot, vehicle, ply)
    data.cargo_space[slotIndex] = nil

    BroadcastState(vehicle)
end)

hook.Add("EntityRemoved", "PD.VehicalInventory.Cleanup", function(ent)
    local vehicleData = PD.VehicalInventory.vehicals[ent]

    if vehicleData then
        for _, slot in pairs(vehicleData.cargo_space) do
            if IsValid(slot.ent) then
                RestoreEntity(slot, ent)
            end
        end

        for steamid in pairs(vehicleData.players_looking) do
            local ply = player.GetBySteamID64(steamid)
            if IsValid(ply) then
                net.Start("PD.VehicalInventory.ForceClose")
                net.WriteEntity(ent)
                net.Send(ply)
            end
        end

        PD.VehicalInventory.vehicals[ent] = nil
        return
    end

    for vehicle, data in pairs(PD.VehicalInventory.vehicals) do
        for index, slot in pairs(data.cargo_space) do
            if slot.ent == ent then
                data.cargo_space[index] = nil
                BroadcastState(vehicle)
            end
        end
    end
end)

hook.Add("PlayerDisconnected", "PD.VehicalInventory.RemovePlayerLooking", function(ply)
    local steamid = ply:SteamID64()

    for _, data in pairs(PD.VehicalInventory.vehicals) do
        data.players_looking[steamid] = nil
    end
end)

timer.Create("PD.VehicalInventory.Refresh", 1, 0, function()
    for vehicle, data in pairs(PD.VehicalInventory.vehicals) do
        if not IsValid(vehicle) then
            PD.VehicalInventory.vehicals[vehicle] = nil
            continue
        end

        if next(data.players_looking) then
            BroadcastState(vehicle)
        end
    end
end)
