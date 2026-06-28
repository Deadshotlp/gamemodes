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
}

local DEFAULT_CARGO_SLOTS = 4
local INTERACT_RANGE = 150 -- Maximaler Abstand Spieler <-> Fahrzeug für jede Interaktion
local SCAN_RADIUS = 80 -- ~2 Meter (1m =~ 39.37 units)

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

    local fileName = string.StripExtension(string.GetFileName(ent:GetModel() or ""))
    if fileName and fileName ~= "" then
        return fileName
    end

    return ent:GetClass()
end

local function IsCargoableEntity(ent)
    if not IsValid(ent) then return false end
    if ent:IsRagdoll() then return true end

    local class = ent:GetClass()
    return class == "prop_physics" or class == "prop_physics_multiplayer"
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
    net.Start("PD.VehicalInventory.UpdateRequestItems")
    net.WriteEntity(vehicle)
    net.WriteTable(BuildClientState(vehicle))
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

local function RestoreEntity(ent, vehicle)
    ent:SetParent(nil)
    ent:SetNoDraw(false)
    ent:SetNotSolid(false)

    local dropPos = vehicle:GetPos() + vehicle:GetForward() * 60 + vehicle:GetUp() * 20
    local tr = util.TraceLine({
        start = dropPos,
        endpos = dropPos - vehicle:GetUp() * 200,
        filter = vehicle
    })

    ent:SetPos(tr.HitPos or dropPos)
    ent:SetAngles(vehicle:GetAngles())

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(true)
        phys:Wake()
    end

    -- Kamera des Ragdoll-Besitzers heftet sich wieder an das (jetzt sichtbare) Ragdoll.
    if ent:IsRagdoll() then
        local owner = ent:GetNW2Entity("PD.DM.RagdollOwner")
        if IsValid(owner) and owner:IsPlayer() then
            owner:SetViewEntity(ent)
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

    data.cargo_space[slotIndex] = {
        ent = target,
        class = target:GetClass(),
        name = GetDisplayName(target),
        is_ragdoll = target:IsRagdoll()
    }

    -- Entity bleibt vollständig bestehen (nur versteckt/eingefroren/geparented), damit
    -- z.B. die NW2Entity Verknüpfung Ragdoll <-> Spieler aus dem Medic Modul erhalten bleibt.
    target:SetParent(vehicle)
    target:SetNoDraw(true)
    target:SetNotSolid(true)

    local phys = target:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
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

    RestoreEntity(slot.ent, vehicle)
    data.cargo_space[slotIndex] = nil

    BroadcastState(vehicle)
end)

hook.Add("EntityRemoved", "PD.VehicalInventory.Cleanup", function(ent)
    local vehicleData = PD.VehicalInventory.vehicals[ent]

    if vehicleData then
        for _, slot in pairs(vehicleData.cargo_space) do
            if IsValid(slot.ent) then
                RestoreEntity(slot.ent, ent)
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
