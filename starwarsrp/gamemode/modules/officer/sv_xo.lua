PD.Officer = PD.Officer or {}

PD = PD or {}
PD.Officer = PD.Officer or {}
PD.Officer.Table = {
    co = "Nicht im Dienst",
    eo = "Nicht im Dienst",
    mo = "Nicht im Dienst",
    no = "Nicht im Dienst",
    so = "Nicht im Dienst",
    to = "Nicht im Dienst"
}
PD.Officer.JobMap = {
    co = {"Infanterie", "Death trooper", "Piloten Corps"}, -- Einheiten die durchsucht werden
    eo = {"Infanterie", "Death trooper", "Piloten Corps"},
    mo = {"Medical Trooper"},
    no = {"Flottencrew"},
    so = {"Security Forces"},
    to = {"Combat Engineers"}
}

-- Add Kommand zum Manuellen Spieler zuweisen
hook.Add("PlayerSay", "PD.Officer.ManualAssign", function(ply, text)
    if string.sub(text, 1, 11) == "!officer " then
        local args = string.Split(string.sub(text, 12), " ")
        local roleKey = args[1]
        local targetName = ply:Nick() -- Standardmäßig auf den Spieler selbst setzen

        if PD.Officer.JobMap[roleKey] then
            PD.Officer.Table[roleKey] = targetName

            net.Start("PD.Officer:Sync")
                net.WriteTable(PD.Officer.Table)
            net.Broadcast()

            return ""
        else
            return "Ungültige Rolle. Verfügbare Rollen: co, eo, mo, no, so, to."
        end
    end
end)

util.AddNetworkString("PD.Officer:Sync")
util.AddNetworkString("PD.Officer:Request")

local function findHighestRankInUnit(unit)
    local highestRank = 0
    local highestPlayer = nil

    local allSubUnits = {}
    for k, v in SortedPairs(PD.JOBS.GetSubUnit(false, true)) do
        if v.unit == unit then
            table.insert(allSubUnits, k)
        end
    end

    for _, ply in ipairs(player.GetAll()) do
        local jobID, jobTable = ply:GetJob()
        if jobTable and jobTable.unit == unit or table.HasValue(allSubUnits, jobTable.unit) then
            local rank = PD.List.JobRanks[jobID] or 0
            if rank > highestRank then
                highestRank = rank
                highestPlayer = ply
            end
        end
    end

    return highestPlayer
end

local function matches(roleKey)
    local roleData = PD.Officer.JobMap[roleKey]
    for _, ply in ipairs(player.GetAll()) do
        local jobID, jobTable = ply:GetJob()
        if jobTable.unit and table.HasValue(roleData, jobTable.unit) then
            local highestRankPlayer = findHighestRankInUnit(jobTable.unit)
            if highestRankPlayer and highestRankPlayer == ply then
                PD.Officer.Table[roleKey] = ply:Nick()

                return
            end
        end
    end
end

local function recompute()
    PD.Officer.Table.co = "Nicht im Dienst"
    PD.Officer.Table.eo = "Nicht im Dienst"
    PD.Officer.Table.mo = "Nicht im Dienst"
    PD.Officer.Table.no = "Nicht im Dienst"
    PD.Officer.Table.so = "Nicht im Dienst"
    PD.Officer.Table.to = "Nicht im Dienst"
    for officer, _ in SortedPairs(PD.Officer.Table) do
        matches(officer)
    end
end

local function syncAll()
    net.Start("PD.Officer:Sync")
    net.WriteTable(PD.Officer.Table)
    net.Broadcast()
end

local function updateAndSync()
    recompute()
    syncAll()
end

timer.Simple(1, updateAndSync)

hook.Add("Initialize","PD.Officer.AutoInit", function()
    timer.Simple(1, updateAndSync)
end)

hook.Add("PlayerInitialSpawn","PD.Officer.Join", function()
    timer.Simple(2, updateAndSync)
end)

hook.Add("PlayerDisconnected","PD.Officer.Leave", function()
    timer.Simple(1, updateAndSync)
end)

hook.Add("PlayerSpawn","PD.Officer.Spawn", function()
    timer.Simple(1, updateAndSync)
end)

hook.Add("PlayerChangedChar","PD.Officer.TeamChange", function()
    timer.Simple(1, updateAndSync)
end)

hook.Add("PD_Faction_Change", "PD.Officer.FactionChange", function()
    timer.Simple(1, updateAndSync)
end)

net.Receive("PD.Officer:Request", function(len, ply)
    net.Start("PD.Officer:Sync")
    net.WriteTable(PD.Officer.Table)
    net.Send(ply)
end)


