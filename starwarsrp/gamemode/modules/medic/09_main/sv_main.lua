-- Test
PD.DM = PD.DM or {}
PD.DM.Main = PD.DM.Main or {}

PD.DM.Main.tbl = {}

util.AddNetworkString("PD.DM.RequestValue")
util.AddNetworkString("PD.DM.ChangeValue")
util.AddNetworkString("PD.DM.RecieveValue")
util.AddNetworkString("PD.DM.ChangeTourniquetStatus")
util.AddNetworkString("PD.DM.Interact")

local dir = "deadshot/dm"

local blanc_clone = { -- ply:SteamID64()
    puls = 60, -- Puls der person
    spo2 = 90, -- Sauerstoffsättigung der person
    bp = {120, 80}, -- Blutdruck der person
    species = "Mensch", -- Spezies der person
    triage_card = 0, -- Triage einstuffung der person | 0 = non | 1 = delayed | 2 = asap | 3 = Immediately
    blood_type = "0-", -- Blutgruppe der person | A+ | A- | B+ | B- | AB+ | AB- | O+ | O-
    blood_amount = 5.5, -- Blutmenge der person
    pain_level = 0, -- Schmerzlevel der person | 0 = normal | 1 = mild | 2 = moderate | 3 = severe | 4 = critical
    is_breatheing = true, -- Person Atmet
    body_part = { -- Alle Körpergruppen einer Person mit ensprechenden relevanten informationen
        [1] = {
            name = "Kopf",
            fractured = false,
            bleading_level = 0
        },
        [2] = {
            name = "Torso",
            fractured = false,
            bleading_level = 0
        },
        [3] = {
            name = "Bauch",
            fractured = false,
            bleading_level = 0
        },
        [4] = {
            name = "Arm Links",
            tourniquet = false,
            fractured = false,
            bleading_level = 0
        },
        [5] = {
            name = "Arm Rechts",
            tourniquet = false,
            fractured = false,
            bleading_level = 0
        },
        [6] = {
            name = "Bein Links",
            tourniquet = false,
            fractured = false,
            bleading_level = 0
        },
        [7] = {
            name = "Bein Rechts",
            tourniquet = false,
            fractured = false,
            bleading_level = 0
        }
    },
    injureys = { -- Alle Verletzungen welche eine Person momentan hat so wie Hitgroup und behandlungs status
        -- [1] = {wo = 1, name = "Schusswunde", treatment = { [1] = { name = "Desinfizieren", time = 60, status = false} }},
    },
    infactions = { -- Alle Infektionen welche eine Person momentan hat
        -- ["gunshot_wound"] = {name = "Fieber", treatment = { [1] = { name = "Desinfizieren", time = 60, status = false} }},
    },
    medication = { -- Alle Medikamente die sich momnetan im Kreislauf befinden und wann diese verabreicht wurden.
        -- ["antibiotic"] = {administered = 1033},
    },
    activity_log = { -- Alle Behandlungen welche an einer Person vorgenommen wurden
        -- [1] = {time = "00:00", str = "Test hat einen Bacta-Verband angelegt!"}
    },
    activ_interaktion = nil -- ply:SteamID64()
}

function PD.DM:UpdateTable(ply, key, value)
    PD.DM.Main.tbl[ply:SteamID64()][key] = value
    PD.DM.UI.UpdateLiveInteraktion(ply)
end

function PD.DM:RequestTable(ply, key)
    return PD.DM.Main.tbl[ply:SteamID64()][key]
end

net.Receive("PD.DM.RequestValue", function()
    local ply1 = net.ReadEntity()
    local ply2 = net.ReadEntity()
    local bone = net.ReadInt(16)

    local task = net.ReadString()

    if task == "inspect" then
        local val1 = PD.DM:RequestTable(ply2, task)
        PrintTable(val1)

        local val2 = {}

        for k, v in ipairs(val1) do
            if v.wo == bone then
                table.insert(val2, v)
            end
        end

        net.Start("PD.DM.RecieveValue")
        net.WriteString("injureys")
        net.WriteTable(val2)
        net.Send(ply1)
    elseif task == "puls" then
        local val = PD.DM:RequestTable(ply2, task)

        net.Start("PD.DM.RecieveValue")
        net.WriteString("puls")
        net.WriteInt(val, 16)
        net.Send(ply1)
    elseif task == "bp" then
        local val = PD.DM:RequestTable(ply2, task)

        net.Start("PD.DM.RecieveValue")
        net.WriteString("bp")
        net.WriteTable(val)
        net.Send(ply1)
    end
end)

net.Receive("PD.DM.ChangeValue", function()
    local ply1 = net.ReadEntity()
    local ply2 = net.ReadEntity()

    local tbl = net.ReadTable()

    if ply1:GetPos():Distance(ply2:GetPos()) >= 100 then
        return
    end

    PD.DM:UpdateTable(ply2, tbl[1], tbl[2])
end)

net.Receive("PD.DM.ChangeTourniquetStatus", function()
    local ply1 = net.ReadEntity()
    local ply2 = net.ReadEntity()
    local bone = net.ReceiveInt(16)

    if bone >= 4 then

    end
end)

net.Receive("PD.DM.Interact", function()
    local ply1 = net.ReadEntity()
    local ply2 = net.ReadEntity()
    local task = net.ReadString()
    local tbl = net.ReadTable()

    print(ply1)
    print(ply2)
    print(task)
    PrintTable(tbl)

    if task == "activ_interaktion" then
        PD.DM:UpdateTable(ply1, "activ_interaktion", nil)
    end

    if ply1:GetPos():Distance(ply2:GetPos()) >= 100 then
        return
    end

    if task == "Diagnostics" then
        for _, v in ipairs(PD.DM.Diagnostics.tbl) do
            if v.name == tbl.name then
                v.func(ply1, ply2)
                return
            end
        end
        print("PD.DM: Diagnostics task not found: " .. tbl.name)
    else

    end
end)

-- TODO: Char status save in json, Char status change on char change

local function deepcopy(orig)
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        copy = {}
        for orig_key, orig_value in pairs(orig) do
            copy[deepcopy(orig_key)] = deepcopy(orig_value) -- Rekursiv für verschachtelte Tabellen
        end
    else -- number, string, boolean, nil, function etc.
        copy = orig
    end
    return copy
end

hook.Add("PlayerSpawn", "PD.DM.CreateEntryFromSpawn", function(ply)
    PD.DM.Main.tbl[ply:SteamID64()] = deepcopy(blanc_clone)
end)

hook.Add("PlayerDisconnected", "PD.DM.RemoveEntry", function(ply)
    if not PD.DM.Main.tbl[ply:SteamID64()] then
        return
    end
    PD.DM.Main.tbl[ply:SteamID64()] = nil
end)

hook.Add("PostPDLoaded", "PD.DM.CreateEntryFromLoad", function()
    for _, ply in player.Iterator() do
        PD.DM.Main.tbl[ply:SteamID64()] = deepcopy(blanc_clone)
    end

    PD.DM.LoadDir(dir)

    PD.DM.Injury.tbl = PD.DM.LoadFill(dir .. "/injuries.json", PD.DM.Injury.tbl)
    PD.DM.Treatments.tbl = PD.DM.LoadFill(dir .. "/treatments.json", PD.DM.Treatments.tbl)
    PD.DM.Medication.tbl = PD.DM.LoadFill(dir .. "/medication.json", PD.DM.Medication.tbl)
end)

function PD.DM.LoadDir(dir)
    if not PD.JSON.Exists(dir) then
        PD.JSON.Create(dir)
    end
end

function PD.DM.LoadFill(file, tbl)
    if not PD.JSON.Exists(file) then
        PD.JSON.Write(file, tbl)
    end

    return PD.JSON.Read(file)
end

-- function PD.DM.SaveDir(file, tbl) TODO: Spieler verletzungen Speichern
--     if PD.JSON.Exists(file) then
--         PD.JSON.Delete(file)
--     end

--     PD.JSON.Write(file, tbl)
-- end

function PD.DM.AddPlayerEntry(ply)
    PD.DM.Main.tbl[ply:SteamID64()] = deepcopy(blanc_clone)
end

concommand.Add("pd_dm_prints", function()
    print("===============================Start=======================================")
    PrintTable(PD.DM.Main.tbl)
    print("================================Ende=======================================")
end)
