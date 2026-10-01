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

--[[
    Fahrzeuge und erlaubte Fracht kommen aus der Datenbank und sind im
    Web-Panel (Seite "Fahrzeuge") pflegbar:

      pd_vehinv_vehicles  class, name, cargo_slots, bones, position
      pd_vehinv_cargo     class

    bones: kommagetrennte Bone-Namen, an denen im Interaktionsmenue der Punkt
    "Fahrzeug Inventar" erscheint (Bones eines Fahrzeugs listet List_bones in
    der Konsole, waehrend man es ansieht).

    Beim ersten Start werden die Tabellen mit den bisherigen festen Werten
    befuellt. Neu laden: pd_reload fahrzeuge.
]]
local TBL_VEHICLES = "pd_vehinv_vehicles"
local TBL_CARGO = "pd_vehinv_cargo"

-- Startwerte = die bisher fest eingetragenen Fahrzeuge.
local SEED_VEHICLES = {
    {class = "lvs_sw_transport", name = "Transporter", cargo_slots = 6, bones = "static_prop"},
    {class = "lvs_fakehover_iftx", name = "TX-130", cargo_slots = 5, bones = "root"},
    {class = "lvs_mixy_atte_rep", name = "AT-TE Front", cargo_slots = 4, bones = "root_front"},
    {class = "lvs_mixy_atte_rear_rep", name = "AT-TE Back", cargo_slots = 4, bones = "root_rear"},
}

local SEED_CARGO = {"munitionsbox", "prop_physics", "prop_physics_multiplayer"}

-- class -> {name, cargo_slots, bones = {...}}
PD.VehicalInventory.VehicleConfig = PD.VehicalInventory.VehicleConfig or {}
-- class -> true. Fester Grundstock, bis die Datenbank geantwortet hat.
PD.VehicalInventory.ValidCargo = PD.VehicalInventory.ValidCargo or {
    munitionsbox = true,
    prop_physics = true,
    prop_physics_multiplayer = true,
}

-- Klassen, die andere Module immer als Fracht anmelden (z. B. Transportkisten).
PD.VehicalInventory.ExtraCargo = PD.VehicalInventory.ExtraCargo or {}

local DEFAULT_CARGO_SLOTS = 4
local MAX_CARGO_SLOTS = 32
local INTERACT_RANGE = 1000 -- Maximaler Abstand Spieler <-> Fahrzeug für jede Interaktion
local SCAN_RADIUS = 250 -- ~2 Meter (1m =~ 39.37 units)

util.AddNetworkString("PD.VehicalInventory.StartRequestItems")
util.AddNetworkString("PD.VehicalInventory.EndRequestItems")
util.AddNetworkString("PD.VehicalInventory.UpdateRequestItems")
util.AddNetworkString("PD.VehicalInventory.LoadEntity")
util.AddNetworkString("PD.VehicalInventory.UnloadEntity")
util.AddNetworkString("PD.VehicalInventory.ForceClose")
util.AddNetworkString("PD.VehicalInventory.Config")

local function SplitBones(text)
    local bones = {}

    for _, part in ipairs(string.Explode(",", tostring(text or ""))) do
        local bone = string.Trim(part)
        if bone ~= "" then bones[#bones + 1] = bone end
    end

    return bones
end

-- Name und Interaktions-Bones an Clients; die Slotzahl braucht nur der Server.
function PD.VehicalInventory.SendConfig(target)
    local vehicles = {}

    for class, cfg in pairs(PD.VehicalInventory.VehicleConfig) do
        vehicles[class] = {name = cfg.name, bones = cfg.bones}
    end

    net.Start("PD.VehicalInventory.Config")
    net.WriteTable(vehicles)

    if target then net.Send(target) else net.Broadcast() end
end

local function EnsureTables(callback)
    local createVehicles = "CREATE TABLE IF NOT EXISTS `" .. TBL_VEHICLES .. "` ("
        .. "`class` VARCHAR(128) NOT NULL,"
        .. "`name` VARCHAR(64) NOT NULL DEFAULT '',"
        .. "`cargo_slots` INT NOT NULL DEFAULT 4,"
        .. "`bones` VARCHAR(255) NOT NULL DEFAULT '',"
        .. "`position` INT NOT NULL DEFAULT 0,"
        .. "PRIMARY KEY (`class`)"
        .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

    local createCargo = "CREATE TABLE IF NOT EXISTS `" .. TBL_CARGO .. "` ("
        .. "`class` VARCHAR(128) NOT NULL,"
        .. "PRIMARY KEY (`class`)"
        .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

    PD.SQL.Query(createVehicles, function()
        PD.SQL.Query(createCargo, function()
            callback()
        end)
    end)
end

-- Leere Tabellen einmalig mit den Startwerten fuellen.
local function SeedIfEmpty(callback)
    PD.SQL.FetchOne("SELECT (SELECT COUNT(*) FROM `" .. TBL_VEHICLES .. "`) AS v, (SELECT COUNT(*) FROM `" .. TBL_CARGO .. "`) AS c", function(row)
        local pending = 0
        local function finish()
            pending = pending - 1
            if pending <= 0 then callback() end
        end

        pending = 1

        if row and tonumber(row.v) == 0 then
            for index, v in ipairs(SEED_VEHICLES) do
                pending = pending + 1
                PD.SQL.Query("INSERT IGNORE INTO `" .. TBL_VEHICLES .. "` (`class`, `name`, `cargo_slots`, `bones`, `position`) VALUES ("
                    .. PD.SQL.EscapeString(v.class) .. ", " .. PD.SQL.EscapeString(v.name) .. ", "
                    .. v.cargo_slots .. ", " .. PD.SQL.EscapeString(v.bones) .. ", " .. index .. ")", finish)
            end
        end

        if row and tonumber(row.c) == 0 then
            for _, class in ipairs(SEED_CARGO) do
                pending = pending + 1
                PD.SQL.Query("INSERT IGNORE INTO `" .. TBL_CARGO .. "` (`class`) VALUES (" .. PD.SQL.EscapeString(class) .. ")", finish)
            end
        end

        finish()
    end)
end

function PD.VehicalInventory.LoadConfig(callback)
    EnsureTables(function()
        SeedIfEmpty(function()
            PD.SQL.FetchAll("SELECT * FROM `" .. TBL_VEHICLES .. "` ORDER BY `position`, `class`", function(vehicles)
                PD.SQL.FetchAll("SELECT * FROM `" .. TBL_CARGO .. "`", function(cargo)
                    local config = {}

                    for _, row in ipairs(vehicles or {}) do
                        config[row.class] = {
                            name = row.name ~= "" and row.name or row.class,
                            cargo_slots = math.Clamp(tonumber(row.cargo_slots) or DEFAULT_CARGO_SLOTS, 1, MAX_CARGO_SLOTS),
                            bones = SplitBones(row.bones),
                        }
                    end

                    local valid = {}
                    for _, row in ipairs(cargo or {}) do
                        valid[row.class] = true
                    end

                    PD.VehicalInventory.VehicleConfig = config
                    PD.VehicalInventory.ValidCargo = valid

                    -- Slotzahl bestehender Inventare anpassen. Belegte Slots
                    -- ueber der neuen Grenze bleiben bestehen, bis sie entladen
                    -- werden - sonst verschwaende Fracht.
                    for vehicle, data in pairs(PD.VehicalInventory.vehicals) do
                        if IsValid(vehicle) then
                            local slots = config[vehicle:GetClass()] and config[vehicle:GetClass()].cargo_slots or DEFAULT_CARGO_SLOTS
                            local highest = 0

                            for index in pairs(data.cargo_space) do
                                highest = math.max(highest, index)
                            end

                            data.cargo_slots = math.max(slots, highest)
                        end
                    end

                    PD.VehicalInventory.SendConfig()

                    if callback then callback(true, table.Count(config), table.Count(valid)) end
                end)
            end)
        end)
    end)
end

hook.Add("PlayerInitialSpawn", "PD.VehicalInventory.Config", function(ply)
    timer.Simple(5, function()
        if IsValid(ply) then PD.VehicalInventory.SendConfig(ply) end
    end)
end)

timer.Simple(3, function()
    PD.VehicalInventory.LoadConfig(function(ok, vehicles, cargo)
        print("[Fahrzeuginventar] " .. tostring(vehicles) .. " Fahrzeuge, " .. tostring(cargo) .. " Frachtklassen geladen")
    end)
end)

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

    -- Transportkiste: Inhalt statt Kistenmodell anzeigen.
    if ent.GetContentName and ent:GetContentName() ~= "" then
        return "Transportkiste: " .. ent:GetContentName()
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

    return PD.VehicalInventory.ValidCargo[class] == true or PD.VehicalInventory.ExtraCargo[class] == true
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

-- Nur eingetragene Fahrzeuge haben ein Inventar. Vorher liess sich per
-- Netzwerknachricht jedes beliebige Entity als "Fahrzeug" benutzen.
-- Ein schon bestehendes Inventar bleibt erreichbar, auch wenn das Fahrzeug
-- im Panel entfernt wurde - sonst saesse die Fracht fest.
local function CanInteract(ply, vehicle)
    return IsValid(ply) and IsValid(vehicle)
        and (PD.VehicalInventory.VehicleConfig[vehicle:GetClass()] ~= nil or PD.VehicalInventory.vehicals[vehicle] ~= nil)
        and ply:GetPos():Distance(vehicle:GetPos()) <= INTERACT_RANGE
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
