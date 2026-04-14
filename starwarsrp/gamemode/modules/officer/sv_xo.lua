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
    co = {"Infanterie", "Death Trooper", "Piloten Corps"}, -- Alle Einheiten, die als CO in Frage kommen
    eo = {"Infanterie", "Death Trooper", "Piloten Corps"},  -- Alle Einheiten, die als EO in Frage kommen
    mo = {"Medical Trooper"}, -- Medics
    no = {"Flottencrew"}, -- Navy
    so = {"Security Forces"}, -- Security
    to = {"Combat Engineers"} -- Techniker
}

-- Add Kommand zum Manuellen Spieler zuweisen
hook.Add("PlayerSay", "PD.Officer.ManualAssign", function(ply, text)
    if string.sub(text, 1, 9) == "!officer " then
        local args = string.Split(string.sub(text, 10), " ")
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

-- Ermittelt den übergeordneten Unit-Namen für eine Subunit
local function getParentUnitName(subunitName)
    for _, unitData in pairs(PD.JOBS.Jobs) do
        if unitData.subunits then
            for _, subunitData in pairs(unitData.subunits) do
                if subunitData.name == subunitName then
                    return unitData.name
                end
            end
        end
    end
    return nil
end

-- Prüft ob ein Spieler-Job zu den gesuchten Unit/Subunit-Namen passt
local function matchesRole(jobTable, searchNames)
    if not jobTable or not jobTable.unit then return false end

    local subunitName = jobTable.unit
    local parentUnitName = getParentUnitName(subunitName)

    for _, searchName in ipairs(searchNames) do
        if subunitName == searchName or parentUnitName == searchName then
            return true
        end
    end

    return false
end

-- Sammelt alle Spieler für eine Rolle, sortiert nach Position (niedrigste Position = höchster Rang)
local function getPlayersForRole(roleKey)
    local roleData = PD.Officer.JobMap[roleKey]
    if not roleData then return {} end

    local players = {}

    for _, ply in ipairs(player.GetAll()) do
        local jobID, jobTable = ply:GetJob()
        if jobTable and matchesRole(jobTable, roleData) then
            local position = jobTable.position or 999
            table.insert(players, {ply = ply, position = position})
        end
    end

    table.sort(players, function(a, b) return a.position < b.position end)
    return players
end

local function recompute()
    for k, _ in pairs(PD.Officer.Table) do
        PD.Officer.Table[k] = "Nicht im Dienst"
    end

    local assignedPlayers = {}

    -- CO bekommt den höchsten Spieler, EO den zweithöchsten
    local coPlayers = getPlayersForRole("co")
    for _, data in ipairs(coPlayers) do
        if not assignedPlayers[data.ply] then
            PD.Officer.Table.co = data.ply:Nick()
            assignedPlayers[data.ply] = true
            break
        end
    end

    local eoPlayers = getPlayersForRole("eo")
    for _, data in ipairs(eoPlayers) do
        if not assignedPlayers[data.ply] then
            PD.Officer.Table.eo = data.ply:Nick()
            assignedPlayers[data.ply] = true
            break
        end
    end

    -- Restliche Rollen: jeweils höchster verfügbarer Spieler
    for _, roleKey in ipairs({"mo", "no", "so", "to"}) do
        local rolePlayers = getPlayersForRole(roleKey)
        for _, data in ipairs(rolePlayers) do
            if not assignedPlayers[data.ply] then
                PD.Officer.Table[roleKey] = data.ply:Nick()
                assignedPlayers[data.ply] = true
                break
            end
        end
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


