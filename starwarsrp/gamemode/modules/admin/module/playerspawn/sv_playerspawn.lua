--

util.AddNetworkString("PDSyncPlayerSpawns")
util.AddNetworkString("PDPlayerSpawnSet")
util.AddNetworkString("PDDeletePlayerSpawns")

local Spawns = {}


PD.JSON.Create("spawn")

net.Receive("PDPlayerSpawnSet", function(len, ply)
    local tbl = net.ReadTable()

    for k, v in pairs(tbl) do
        Spawns[k] = v
    end

    PD.JSON.Write("spawn/spawns.json", Spawns)
end)

net.Receive("PDDeletePlayerSpawns", function(len, ply)
    Spawns = {}

    PD.JSON.Write("spawn/spawns.json", Spawns)
end)

hook.Add("Initialize", "PlayerSpawnLoad", function()
    Spawns = PD.JSON.Read("spawn/spawns.json")
end)

net.Receive("PDSyncPlayerSpawns", function(len, ply)
    net.Start("PDSyncPlayerSpawns")
    net.WriteTable(Spawns)
    net.Send(ply)
end)

hook.Add("PlayerSpawn", "PlayerSpawnPD", function(ply)
    local Spawns = PD.JSON.Read("spawn/spawns.json")
    local radius = 100
    local attempts = 15

    for k, v in SortedPairs(Spawns) do
        local basePos = v.pos
        local ang = v.ang
        local jobID, jobTbl = ply:GetJob()
        local subUnitId, subUnitTbl = PD.JOBS.GetSubUnit(jobTbl.unit)

        if subUnitTbl.unit == k then
            local finalPos = basePos

            for i = 1, attempts do
                local offset = Vector(math.Rand(-radius, radius), math.Rand(-radius, radius), 0)
                local testPos = basePos + offset

                local tr = util.TraceHull({
                    start = testPos,
                    endpos = testPos,
                    mins = Vector(-16, -16, 0),
                    maxs = Vector(16, 16, 72),
                    filter = ply
                })

                if not tr.Hit then
                    finalPos = testPos
                    break
                end
            end

            ply:SetPos(finalPos)
            ply:SetAngles(ang)
            break
        end
    end
end)
