--
local function BlockSuicide(ply)
    ply:ChatPrint("Versuch es erst garnicht...")
    return false
end
hook.Add("CanPlayerSuicide", "BlockSuicide", BlockSuicide)

util.AddNetworkString("PD.Notify")
util.AddNetworkString("PD.OpenYoutube")

hook.Add("PlayerInitialSpawn", "PD.Notify", function(ply)
    ply:GetNWString("rpname", "Unknown")
end)

function PD.CheckSubUnitAccess(ply, subunit)
    local jobID, jobTable = ply:GetJob()
    if jobTable.unit == subunit then
        return true
    end
    return false
end

function PD.CheckJobAccess(ply, jobID)
    local jobID, jobTable = ply:GetJob()
    if jobID == jobID then
        return true
    end
    return false
end

function PD.CheckUnitAccess(ply, unit)
    local jobID, jobTable = ply:GetJob()
    local subunitID, subunitTable = PD.JOBS.GetSubUnit(unit)
    if subunitTable.unit == unit then
        return true
    end
    return false
end

function PD.LinearInterpolation(x, tbl)
    -- Sortiere die Punkte nach x-Werten in aufsteigender Reihenfolge
    table.sort(tbl, function(a, b)
        return a.x < b.x
    end)

    -- Finde die beiden benachbarten Punkte für das gegebene x
    for i = 1, #tbl - 1 do
        local p1 = tbl[i]
        local p2 = tbl[i + 1]
        if x >= p1.x and x <= p2.x then
            -- Berechne den interpolierten y-Wert
            local t = (x - p1.x) / (p2.x - p1.x)
            return p1.y + t * (p2.y - p1.y)
        end
    end

    -- Falls x außerhalb des Bereichs liegt, gebe nil zurück
    return 0
end

