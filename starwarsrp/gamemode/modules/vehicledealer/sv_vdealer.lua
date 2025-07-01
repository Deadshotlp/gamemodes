PD.VD = PD.VD or {}

util.AddNetworkString("PD.VD:SpawnVehicle")
util.AddNetworkString("PD.VD:RemoveVehicle")
util.AddNetworkString("PD.VD:Sync")
util.AddNetworkString("PD.VD:SyncTable")

local VehicleTable = {}
local activeVahicle = {}
timer.Simple(1, function()
    PD.JSON.Create("vehicledealer")
end)

hook.Add("PlayerSay", "PD.VD:AddSpawnPos", function(ply, text)
    local args = string.Explode(" ", text)
    local txt = string.sub(text, #args[1] + 1)

    if args[1] == "!addspawn" then
        if not ply:IsAdmin() then return "" end
        if VehicleTable[txt] then return "Spawn already exists" end
        if not VehicleTable[txt] then VehicleTable[txt] = {} end

        local pos = ply:GetPos() + Vector(0, 0, 50)

        VehicleTable[txt].pos = pos
        VehicleTable[txt].ang = ply:GetAngles()

        net.Start("PD.VD:Sync")
            net.WriteTable(VehicleTable)
        net.Broadcast()

        PD.JSON.Write("vehicledealer/spawns.json", VehicleTable)

        return "Spawn added"
    end

    if args[1] == "!removespawn" then
        if not ply:IsAdmin() then return "" end
        if not VehicleTable[txt] then return "Spawn doesn't exists" end

        VehicleTable[txt] = nil

        net.Start("PD.VD:Sync")
            net.WriteTable(VehicleTable)
        net.Broadcast()

        PD.JSON.Write("vehicledealer/spawns.json", VehicleTable)

        return "Spawn removed"
    end
end)

net.Receive("PD.VD:SpawnVehicle", function(len, ply)
    local name = net.ReadString()
    local vehicle = net.ReadString()

    if not VehicleTable[name] then return end

    local pos = VehicleTable[name].pos
    local ang = VehicleTable[name].ang

    local car
    if simfphys and list.Get("simfphys_vehicles")[vehicle] then
        car = simfphys.SpawnVehicleSimple(vehicle, pos, ang)
    elseif list.Get("Vehicles")[vehicle] then
        local D = list.Get("Vehicles")[vehicle]

        --if !D.Class or !D.Model then return end

        car = ents.Create(D.Class)
        car:SetModel(D.Model)
        car:SetPos(pos)

        car:SetKeyValue("vehiclescript",list.Get( "Vehicles" )[ vehicle ].KeyValues.vehiclescript) 
        car:SetAngles(ang)

        car:Spawn()
        car:Activate()
    else
        car = ents.Create(vehicle)
        car:SetPos(pos)
        car:SetAngles(ang)
        car:Spawn()
    end

    activeVahicle[ply:SteamID64()] = car
end)

net.Receive("PD.VD:Sync", function(len, ply)
    net.Start("PD.VD:Sync")
        net.WriteTable(VehicleTable)
    net.Send(ply)
end)

hook.Add("PlayerDisconnected", "PD.VD:RemoveVehicle", function(ply)
    if not activeVahicle[ply:SteamID64()] then return end

    activeVahicle[ply:SteamID64()]:Remove()
    activeVahicle[ply:SteamID64()] = nil
end)

hook.Add("PlayerInitialSpawn", "PD.VD:Sync", function(ply)
    VehicleTable = PD.JSON.Read("vehicledealer/spawns.json")

    net.Start("PD.VD:Sync")
        net.WriteTable(VehicleTable)
    net.Send(ply)
end)