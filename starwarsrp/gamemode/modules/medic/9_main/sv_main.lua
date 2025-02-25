-- Test
PD.DM = PD.DM or {}
PD.DM.Main = PD.DM.Main or {}

PD.DM.Main.tbl = {}

util.AddNetworkString("TESTTESTTESTTEST")

local dir = "deadshot/dm"

local blanc_clone = { -- ply:SteamID64()
    puls = 60, -- Puls der person
    spo2 = 90, -- Sauerstoffsättigung der person
    bp = {120, 80}, -- Blutdruck der person
    species = "Mensch", -- Spezies der person
    triage_card = 0, -- Triage einstuffung der person | 0 = nnon | 1 = delayed | 2 = asap | 3 = Immediately
    blood_type = "0-", -- Blutgruppe der person | A+ | A- | B+ | B- | AB+ | AB- | O+ | O-
    blood_amount = 5.5, -- Blutmenge der person
    pain_level = 0, -- Schmerzlevel der person | 0 = normal | 1 = mild | 2 = moderate | 3 = severe | 4 = critical
    body_part = { -- Alle Körpergruppen einer Person mit ensprechenden relevanten informationen
        [1] = {
            name = "Kopf",
            tourniquet = false,
            bleading_level = 0
        },
        [2] = {
            name = "Torso",
            tourniquet = false,
            bleading_level = 0
        },
        [3] = {
            name = "Bauch",
            tourniquet = false,
            bleading_level = 0
        },
        [4] = {
            name = "Arm Links",
            tourniquet = false,
            bleading_level = 0
        },
        [5] = {
            name = "Arm Rechts",
            tourniquet = false,
            bleading_level = 0
        },
        [6] = {
            name = "Bein Links",
            tourniquet = false,
            bleading_level = 0
        },
        [7] = {
            name = "Bein Rechts",
            tourniquet = false,
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
    activity_directory = { -- Alle Behandlungen welche an einer Person vorgenommen wurden
        -- [1] = {time = "00:00", str = "Test hat einen Bacta-Verband angelegt!"}
    }
}

function PD.DM:UpdateTable(ply, key, value)
    PD.DM.Main.tbl[ply:SteamID64()][key] = value

    if istable(PD.DM.Main.tbl[ply:SteamID64()][key]) then
        net.Start("TESTTESTTESTTEST")
        net.WriteTable(PD.DM.Main.tbl[ply:SteamID64()])
        net.Send(ply)
    else
        print(PD.DM.Main.tbl[ply:SteamID64()][key])
    end
end

function PD.DM:RequestTable(ply, key)
    return PD.DM.Main.tbl[ply:SteamID64()][key]
end

-- TODO: Char status save in json, Char status change on char change

hook.Add("PlayerSpawn", "PD.DM.CreateEntryFromSpawn", function(ply, trans)
    PD.DM.Main.tbl[ply:SteamID64()] = blanc_clone
end)

hook.Add("PlayerDisconnected", "PD.DM.RemoveEntry", function(ply)
    if not PD.DM.Main.tbl[ply:SteamID64()] then
        return
    end
    PD.DM.Main.tbl[ply:SteamID64()] = nil
end)

hook.Add("PostPDLoaded", "PD.DM.CreateEntryFromLoad", function()
    for _, ply in player.Iterator() do
        PD.DM.Main.tbl[ply:SteamID64()] = blanc_clone
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
    PD.DM.Main.tbl[ply:SteamID64()] = blanc_clone
end

concommand.Add("pd_dm_prints", function()
    print("===============================Start=======================================")
    PrintTable(PD.DM.Main.tbl)
    print("================================Ende=======================================")
end)
