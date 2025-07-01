AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )

ENT.entTable = {}
ENT.entTable["Level"] = 1
ENT.entTable["Doors"] = {}

function ENT:Initialize()
    self:SetModel("models/kingpommes/starwars/misc/misc_panel_1.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType( SIMPLE_USE )

    local phys = self:GetPhysicsObject()

    if phys:IsValid() then
        phys:Wake()
    end
end

function ENT:Use(activator)
    if not activator:HasWeapon("idcard") then
        activator:ChatPrint("Du hast keine ID-Card!")
        return
    end

    activator:ChatPrint("ID-Card benutzen...")
    
    
end

util.AddNetworkString("DoorLinker")

function ENT:SaveDoors()
    local doorsData = {}

    if file.Exists("doorlinker.json", "DATA") then
        local file = file.Read("doorlinker.json", "DATA")
        doorsData = util.JSONToTable(file)
    end

    if not doorsData[game.GetMap()] then
        doorsData[game.GetMap()] = {}
    end

    if not doorsData[game.GetMap()][self:EntIndex()] then
        doorsData[game.GetMap()][self:EntIndex()] = {}

        doorsData[game.GetMap()][self:EntIndex()]["Level"] = self.entTable["Level"]
        doorsData[game.GetMap()][self:EntIndex()]["Doors"] = {}
        for _, door in pairs(self.entTable["Doors"]) do
            if IsValid(door) then
                table.insert(doorsData[game.GetMap()][self:EntIndex()]["Doors"], door:EntIndex())
            end
        end
    else
        doorsData[game.GetMap()][self:EntIndex()]["Level"] = self.entTable["Level"]
        doorsData[game.GetMap()][self:EntIndex()]["Doors"] = {}

        for _, door in pairs(self.entTable["Doors"]) do
            if IsValid(door) then
                table.insert(doorsData[game.GetMap()][self:EntIndex()]["Doors"], door:EntIndex())
            end
        end
    end

    file.Write("doorlinker.json", util.TableToJSON(doorsData, true))
end

function ENT:LoadDoors()
    local doorsData = {}

    if file.Exists("doorlinker.json", "DATA") then
        local file = file.Read("doorlinker.json", "DATA")
        doorsData = util.JSONToTable(file)
    end

    if doorsData[game.GetMap()] and doorsData[game.GetMap()][self:EntIndex()] then
        self.entTable["Level"] = doorsData[game.GetMap()][self:EntIndex()]["Level"]
        self.entTable["Doors"] = {}

        for _, doorIndex in pairs(doorsData[game.GetMap()][self:EntIndex()]["Doors"]) do
            local door = Entity(doorIndex)
            if IsValid(door) then
                table.insert(self.entTable["Doors"], door)
            end
        end
    end
end

function ENT:OnRestore()
    self:LoadDoors()
end

function ENT:LockDoors()
    for _, door in pairs(self.entTable["Doors"]) do
        if IsValid(door) then
            door:Fire("Lock", "", 0)
            door:Fire("Close", "", 0)
        end
    end
end

function ENT:UnlockDoors()
    for _, door in pairs(self.entTable["Doors"]) do
        if IsValid(door) then
            door:Fire("Unlock", "", 0)
            door:Fire("Open", "", 0)
        end
    end
end

function ENT:AddDoors(doors, level)
    if not doors or not level then return end

    self.entTable["Level"] = level
    self.entTable["Doors"] = doors

    self:LockDoors()

    net.Start("DoorLinker")
        net.WriteTable(doors)
        net.WriteInt(level, 8)
    net.Send(self:GetOwner())

    self:SaveDoors()
end

