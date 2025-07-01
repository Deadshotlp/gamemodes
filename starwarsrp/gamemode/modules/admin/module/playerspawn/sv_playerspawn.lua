--

util.AddNetworkString("PDPlayerSpanwMenuOpen")
util.AddNetworkString("PDPlayerSpawnSet")
util.AddNetworkString("PDDeltePlayerSPawns")

local Spawns = {}

hook.Add("PlayerSay", "PlayerSpawnCreatorPD", function(ply, text)
    if string.lower(text) == "!spawns" then
        net.Start("PDPlayerSpanwMenuOpen")
        net.WriteTable(Spawns)
        net.Send(ply)

        return ""
    end
end)

PD.JSON.Create("spawn")

net.Receive("PDPlayerSpawnSet", function(len, ply)
    local tbl = net.ReadTable()

    for k, v in pairs(tbl) do
        Spawns[k] = v
    end

    PD.JSON.Write("spawn/spawns.json", Spawns)
end)

net.Receive("PDDeltePlayerSpawns", function(len, ply)
    Spawns = {}

    PD.JSON.Write("spawn/spawns.json", Spawns)
end)

hook.Add("Initialize", "PlayerSpawnLoad", function()
    Spawns = PD.JSON.Read("spawn/spawns.json")
end)

hook.Add("PlayerSpawn", "PlayerSpawnPD", function(ply)
    if not Spawns then return end

    for k, v in pairs(Spawns) do
        local pos = v.pos
        local ang = v.ang

        local jobID, jobTbl = ply:GetJob()
        local subUnitId, subUnitTbl = PD.JOBS.GetSubUnit(jobTbl.unit)

        if subUnitTbl.unit == k then
            local tr = util.TraceLine({
                start = pos,
                endpos = pos,
                filter = ply
            })

            if tr.Hit then
                pos = tr.HitPos + Vector(0, 0, 10)
            end

            ply:SetPos(pos)
            ply:SetAngles(ang)
        end
    end
end)