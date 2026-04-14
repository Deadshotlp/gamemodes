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

--local bloodTypes = {"A+", "A-", "B+", "B-", "AB+", "AB-", "0+", "0-"}

local blanc_clone = { -- ply:SteamID64()
    puls = 75, -- Puls der person
    spo2 = 95, -- Sauerstoffsättigung der person
    bp = {120, 80}, -- Blutdruck der person
    species = "Mensch", -- Spezies der person
    triage_card = 0, -- Triage einstuffung der person | 0 = non | 1 = delayed | 2 = asap | 3 = Immediately
    blood_type = "0-", -- Blutgruppe der person | A+ | A- | B+ | B- | AB+ | AB- | O+ | O-
    blood_amount = 5.5, -- Blutmenge der person
    blood_to_add = 0.0, -- Blutmenge die noch hinzugefügt werden muss
    pain_level = 0, -- Schmerzlevel der person | 0 = normal | 1 = mild | 2 = moderate | 3 = severe | 4 = critical
    stunning_level = 0, -- 0 - 1 | 0 = nicht betäubt | 1 = betäubt
    recovery_position = false, -- Person in stabile seitenlage
    vital_monitoring = false, -- Vital Monitoring aktiv
    respiratory_system = {
        lungs_functional = true,
        airway_clear = true,
        breathing_rate = 15, -- Atemfrequenz der person
    },
    body_part = { -- Alle Körpergruppen einer Person mit ensprechenden informationen
        [1] = {
            name = "Kopf",
            fractured = false,
            bleading_level = 0,
            has_iv = false
        },
        [2] = {
            name = "Torso",
            fractured = false,
            bleading_level = 0,
            has_iv = false
        },
        [3] = {
            name = "Bauch",
            fractured = false,
            bleading_level = 0,
            has_iv = false  
        },
        [4] = {
            name = "Arm Links",
            tourniquet = false,
            fractured = false,
            bleading_level = 0,
            has_iv = false
        },
        [5] = {
            name = "Arm Rechts",
            tourniquet = false,
            fractured = false,
            bleading_level = 0,
            has_iv = false
        },
        [6] = {
            name = "Bein Links",
            tourniquet = false,
            fractured = false,
            bleading_level = 0,
            has_iv = false
        },
        [7] = {
            name = "Bein Rechts",
            tourniquet = false,
            fractured = false,
            bleading_level = 0,
            has_iv = false
        }
    },
    injuries = { -- Alle Verletzungen welche eine Person momentan hat so wie Hitgroup und behandlungs status
        -- [1] = {wo = 1, name = "Schusswunde", needs_desinfication = true, bleading_level = 0.0, pain_level = 1, treatment = {"bandage"}, puls_influence = 0.0, spo2_influence = 0.0, bp_influence = 0.0, healing_time = 120, calculated = false},
        -- [2] = {wo = 2, name = "Schusswunde", needs_desinfication = true, bleading_level = 0.0, pain_level = 1, treatment = {"bacta_verband", "operativer_eingriff", "bacta_tank"}, puls_influence = 0.0, spo2_influence = 0.0, bp_influence = 0.0, healing_time = 120, calculated = false},
        -- [3] = {wo = 3, name = "Schusswunde", needs_desinfication = true, bleading_level = 0.0, pain_level = 1, treatment = {"bacta_verband", "operativer_eingriff", "bacta_tank"}, puls_influence = 0.0, spo2_influence = 0.0, bp_influence = 0.0, healing_time = 120, calculated = false},
    },
    infactions = { -- Alle Infektionen welche eine Person momentan hat

    },
    medication = { -- Alle Medikamente die sich momnetan im Kreislauf befinden und wann diese verabreicht wurden.
        -- ["antibiotic"] = {administered = 1033},
    },
    activity_log = { -- Alle Behandlungen welche an einer Person vorgenommen wurden
        [1] = {time = 0, str = "Test hat einen Bacta-Verband angelegt!"}
    },
    quick_overview_log = { -- Alle Behandlungen welche an einer Person vorgenommen wurden
        [1] = {time = 0, str = "Test hat einen Bacta-Verband angelegt!"}
    },
    activ_interaktion = {} -- ply:SteamID64()
}

function PD.DM:UpdateTable(ply, key, value)
    PD.DM.Main.tbl[ply:SteamID64()][key] = value
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
        --PrintTable(val1)

        local val2 = {}

        for k, v in ipairs(val1) do
            if v.wo == bone then
                table.insert(val2, v)
            end
        end

        net.Start("PD.DM.RecieveValue")
        net.WriteString("injuries")
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
        return
    end
end)

net.Receive("PD.DM.Interact", function()
    local ply1 = net.ReadEntity()
    local ply2 = net.ReadEntity()
    local task = net.ReadInt(4)
    local index = net.ReadInt(11)
    local body_part_index = net.ReadInt(4)

    if task == "activ_interaktion" then
        PD.DM:UpdateTable(ply1, "activ_interaktion", nil)
    end

    if ply2:Alive() then
        if ply1:GetPos():Distance(ply2:GetPos()) >= 100 then
            return
        end
    else
        local ragdoll = ply2:GetNW2Entity("PD.DM.Ragdoll")
        if not IsValid(ragdoll) or ply1:GetPos():Distance(ragdoll:GetPos()) >= 100 then
            return
        end
    end

    if task == 0 then
        PD.DM.Main.tbl[ply2:SteamID64()].triage_card = index
    elseif task == 1 then
        PD.DM.Diagnostics.tbl[index].effect(ply1, PD.DM.Main.tbl[ply2:SteamID64()], body_part_index, ply2)
    elseif task == 2 then
        PD.DM.Medication.tbl[index].effect(ply1, PD.DM.Main.tbl[ply2:SteamID64()], body_part_index, ply2)
    elseif task == 3 then
        PD.DM.Treatments.tbl[index].effect(ply1, PD.DM.Main.tbl[ply2:SteamID64()], body_part_index, ply2)
    elseif task == 4 then
        PD.DM.Other.tbl[index].effect(ply1, PD.DM.Main.tbl[ply2:SteamID64()], body_part_index, ply2)
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

local function LoadFill(file, tbl)
    if not PD.JSON.Exists(file) then
        PD.JSON.Write(file, tbl)
    end

    return PD.JSON.Read(file)
end

hook.Add("PlayerSpawn", "PD.DM.CreateEntryFromSpawn", function(ply)
    PD.DM.Main.tbl[ply:SteamID64()] = deepcopy(blanc_clone)

    if IsValid(ply:GetNW2Entity("PD.DM.Ragdoll")) then
        ply:GetNW2Entity("PD.DM.Ragdoll"):Remove()
        ply:SetViewEntity(ply)
    end
end)

hook.Add("PlayerDisconnected", "PD.DM.RemoveEntry", function(ply)
    PD.DM.Main.tbl[ply:SteamID64()] = nil

    for _, ply_tbl in pairs(PD.DM.Main.tbl) do
        for k, v in pairs(ply_tbl.activ_interaktion) do
            if v == ply:SteamID64() then
                ply_tbl.activ_interaktion[k] = nil
            end
        end
    end
end)

hook.Add("PostPDLoaded", "PD.DM.CreateEntryFromLoad", function()
    for _, ply in player.Iterator() do
        PD.DM.Main.tbl[ply:SteamID64()] = deepcopy(blanc_clone)
    end

    PD.JSON.Create(dir)

    PD.DM.Injury.tbl = LoadFill(dir .. "/injuries.json", PD.DM.Injury.tbl)
    --PrintTable(PD.DM.Injury.tbl)
    PD.DM.Treatments.tbl = LoadFill(dir .. "/treatments.json", PD.DM.Treatments.tbl)
    PD.DM.Medication.tbl = LoadFill(dir .. "/medication.json", PD.DM.Medication.tbl)
end)

-- function PD.DM.SaveDir(file, tbl) TODO: Spieler verletzungen Speichern
--     if PD.JSON.Exists(file) then
--         PD.JSON.Delete(file)
--     end

--     PD.JSON.Write(file, tbl)
-- end

function PD.DM.AddPlayerEntry(ply)
    if not PD.DM.Main.tbl[ply:SteamID64()] then
        PD.DM.Main.tbl[ply:SteamID64()] = deepcopy(blanc_clone)
    end
end

function PD.DM.Revive(ply, tbl)
    local ragdoll = ply:GetNW2Entity("PD.DM.Ragdoll")
    if IsValid(ragdoll) then
        ply:Spawn()
        ply:SetPos(ragdoll:GetPos())
        ply:SetModel(ragdoll:GetModel())

        for k, v in pairs(ragdoll:GetBodyGroups()) do
            ply:SetBodygroup(k, ragdoll:GetBodygroup(k))
        end

        for k, v in pairs(ragdoll.equip) do
            ply:Give(v)
        end

        for k, v in pairs(ragdoll.ammo) do
            ply:SetAmmo(v, k)
        end

        ragdoll:Remove()

        PD.DM.Main.tbl[ply:SteamID64()] = tbl
    end
end

concommand.Add("pd_dm_prints", function()
    print("===============================Start=======================================")
    PrintTable(PD.DM.Main.tbl)
    print("================================Ende=======================================")
end)

concommand.Add("pd_dm_set_med_value", function(ply, cmd, args)
    local ply_name = args[1]
    local key = args[2]
    local value = args[3]

    for _, v in pairs(player.GetAll()) do
        local str = string.Split(v:Nick(), " ")
        for i = 2, #str do
            if i > 2 then
                ply_name = ply_name .. " " .. str[i]
            else
                ply_name = str[i]
            end
        end
        if string.lower(ply_name) == string.lower(ply_name) then
            PD.DM.Main.tbl[v:SteamID64()][key] = tonumber(value)
            print("Set " .. key .. " to " .. value .. " for " .. ply_name)
            return
        end
    end

    print("Player not found: " .. ply_name)
end)


for _, ply in player.Iterator() do
    PD.DM.Main.tbl[ply:SteamID64()] = deepcopy(blanc_clone)
end
