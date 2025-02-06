PD.REAKTOR = PD.REAKTOR or {}

util.AddNetworkString("PD.REAKTOR:Open")
util.AddNetworkString("PD.REAKTOR:GetInfo")
util.AddNetworkString("PD.REAKTOR:SetInfo")
util.AddNetworkString("PD.REAKTOR:Active")
util.AddNetworkString("PD.REAKTOR:Verbrauch")
util.AddNetworkString("PD.REAKTOR:ExtensiveLights")
util.AddNetworkString("PD.REAKTOR:Pumpe")

local fuel = 50000
local hitze = 0
local cool = 50000
local active = false
local ranNum = 10

local function CheckPlayerJobs(ply)
    if ply then
        local jobID, jobTable = ply:GetJob()
        if PD.REAKTOR.Jobs[jobID] then
            return true
        end
    else
        for k,v in pairs(player.GetAll()) do
            local jobID, jobTable = v:GetJob()
            if PD.REAKTOR.Jobs[jobID] then
                return true
            end
        end
    end
        
    return false
end

local function checkEnt(base, ent)
    if base:GetPos():Distance(ent:GetPos()) <= 50 then
        return true
    end
    return false
end

timer.Create("PD.REAKTOR:Tick",ranNum,0,function()
    if CheckPlayerJobs() and active then
        local f = fuel / 100 * 0.7
        local c = cool / 100 * 0.3

        fuel = fuel - f
        cool = cool - c

        net.Start("PD.REAKTOR:Verbrauch")
            net.WriteInt(f,32)
            net.WriteInt(c,32)
        net.Broadcast()
    end
end)

net.Receive("PD.REAKTOR:GetInfo",function(len,ply)
    net.Start("PD.REAKTOR:GetInfo")
    net.WriteInt(fuel,32)
    net.WriteInt(hitze,32)
    net.WriteInt(cool,32)
    net.Send(ply)
end)    

net.Receive("PD.REAKTOR:SetInfo",function(len,ply)
    local was = net.ReadString()
    local f = net.ReadInt(32)

    if not checkEnt(ents.FindByClass("progama057_befuellung")[1], ents.FindByClass("progama057_" .. was)[1]) then print("Stehen nicht zusammen") return end
    

    if was == "fuel" then
        fuel = f
    elseif was == "hitze" then
        hitze = f
    elseif was == "cool" then
        cool = f
    end
end)

net.Receive("PD.REAKTOR:Active",function(len,ply)
    if not CheckPlayerJobs(ply) then return ply:ChatPrint("Du darfst den Reaktor nicht starten") end

    active = !active

    net.Start("PD.REAKTOR:Active")
    net.WriteBool(active)
    net.Broadcast()
end)

net.Receive("PD.REAKTOR:Pumpe",function(len,ply)
    if not CheckPlayerJobs(ply) then return ply:ChatPrint("Du darfst die Pumpe nicht starten") end

    local typ = net.ReadString()
    local ent = net.ReadEntity()
    local base = net.ReadEntity()

    if not checkEnt(base, ent) then print("Stehen nicht zusammen") return end

    ent:Remove()

    timer.Simple(5, function()
        local e = ents.Create("progama057_" .. typ)
        e:SetPos(base:GetPos() + Vector(0,0,32))
        e:SetAngles(base:GetAngles())
        e:Spawn()
        e:Activate()

        net.Start("PD.REAKTOR:Pumpe")
        net.WriteBool(false)
        net.Broadcast()
    end)

    net.Start("PD.REAKTOR:Pumpe")
    net.WriteBool(true)
    net.Broadcast()
end)

-- Wenn Reaktor zu heiß ist spielen die Türen verrückt
-- Schwerkraft generator kaputt
-- Lichter gehen aus
-- Luft generator kaputt
-- Explosion wenn zu heiß
-- Random kleine Explosionen im Schiff

local entTbl = {
    ["light"] = true,
    ["light_spot"] = true,
    ["light_dynamic"] = true,
    ["point_spotlight"] = true
}

local ddd = false
if ddd then
    local d = false
    timer.Create("PD.REAKTOR:Hitze",3,0,function()
        -- print("Hitze")
        if d then 
            for k, v in pairs(ents.FindByClass("func_door")) do
                local delay = math.random(1, 3)
                v:Fire("Unlock", "", delay)
                v:Fire("Open", "", delay)
            end

            if game.GetMap() == "rp_venator_extensive_v1_4" then
                engine.LightStyle(0, "abcxyz")
                timer.Simple(0, function()
                    net.Start("PD.REAKTOR:ExtensiveLights")
                    net.Broadcast()
                end)
            end

            for k, v in pairs(ents.GetAll()) do
                if entTbl[v:GetClass()] then
                    local delay = math.random(1, 3)
                    v:Fire("TurnOn", "", delay)
                end
            end

            d = false
        else
            for k, v in pairs(ents.FindByClass("func_door")) do
                local delay = math.random(1, 3)
                v:Fire("Lock", "", delay)
                v:Fire("Close", "", delay)
            end

            if game.GetMap() == "rp_venator_extensive_v1_4" then
                engine.LightStyle(0, "abcxyz")
                timer.Simple(0, function()
                    net.Start("PD.REAKTOR:ExtensiveLights")
                    net.Broadcast()
                end)
            end

            for k, v in pairs(ents.GetAll()) do
                if entTbl[v:GetClass()] then
                    local delay = math.random(1, 3)
                    v:Fire("TurnOff", "", delay)
                end
            end

            d = true
        end
        
    end) 
else
    if timer.Exists("PD.REAKTOR:Hitze") then
        timer.Remove("PD.REAKTOR:Hitze")
    end
end

