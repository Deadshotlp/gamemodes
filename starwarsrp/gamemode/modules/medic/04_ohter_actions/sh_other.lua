PD.DM = PD.DM or {}
PD.DM.Other = PD.DM.Other or {}

PD.DM.Other.tbl = {
    -- [1] = {
    --     name = "",
    --     condition = function(actor, patient, body_part_index,)
    --         
    --     end,
    --     time = 10, Sekunden
    --     effect = function(actor, patient, body_part_index)
    --
    --     end
    -- }
    [1] = {
        name = "In die Stabieleseitenlage bringen",
        condition = function(actor, patient, body_part_index, ply)
            if patient.recovery_position then
                return false
            end

            if ply:Alive() then
                return false
            end

            if body_part_index ~= 2 then
                return false
            end

            return true
        end,
        effect = function(actor, patient, body_part_index)
            patient.recovery_position = true
        end,
        time = 10
    },
    [2] = {
        name = "Athemwege freimachen",
        condition = function(actor, patient, body_part_index, ply)
            if patient.respiratory_system.airway_clear then
                return false
            end

            if body_part_index ~= 1 then
                return false
            end

            return true
        end,
        effect = function(actor, patient, body_part_index)
            patient.respiratory_system.airway_clear = true
        end,
        time = 5
    },
    [3] = {
        name = "Vital Monitoring aktivieren",
        condition = function(actor, patient, body_part_index, ply)
            if patient.vital_monitoring then
                return false
            end

            return true
        end,
        effect = function(actor, patient, body_part_index)
            patient.vital_monitoring = true
        end,
        time = 10
    },
    [4] = {
        name = "Vital Monitoring Deaktivieren",
        condition = function(actor, patient, body_part_index, ply)
            if not patient.vital_monitoring then
                return false
            end

            return true
        end,
        effect = function(actor, patient, body_part_index)
            patient.vital_monitoring = false
        end,
        time = 10
    },
    [5] = {
        name = "Tourniquet Anlegen",
        condition = function(actor, patient, body_part_index)

            if patient.body_part[body_part_index].tourniquet == nil or patient.body_part[body_part_index].tourniquet then
                return false
            end

            return true
        end,
        effect = function(actor, patient, body_part_index)
            patient.body_part[body_part_index].tourniquet = true
        end,
        time = 5
    },
    [6] = {
        name = "Tourniquet Entfernen",
        condition = function(actor, patient, body_part_index)
            if patient.body_part[body_part_index].tourniquet == nil or not patient.body_part[body_part_index].tourniquet then
                return false
            end

            return true
        end,
        effect = function(actor, patient, body_part_index)
            patient.body_part[body_part_index].tourniquet = false
        end,
        time = 5
    },
    [7] = {
        name = "Zugang legen",
        condition = function(actor, patient, body_part_index)
            if not PD.DM.IsMedic(actor) then return false end

            if patient.body_part[body_part_index].has_iv == nil or patient.body_part[body_part_index].has_iv then
                return false
            end

            return true
        end,
        effect = function(actor, patient, body_part_index)
            patient.body_part[body_part_index].has_iv = true
        end,
        time = 15
    },
    [8] = {
        name = "Zugang entfernen",
        condition = function(actor, patient, body_part_index)
            if not PD.DM.IsMedic(actor) then return false end

            if patient.body_part[body_part_index].has_iv == nil or not patient.body_part[body_part_index].has_iv then
                return false
            end

            return true
        end,
        effect = function(actor, patient, body_part_index)
            patient.body_part[body_part_index].has_iv = false
        end,
        time = 10
    },
    [9] = {
        name = "Herzlungen Wiederbelebung durchführen",
        condition = function(actor, patient, body_part_index)
            if body_part_index ~= 2 then
                return false
            end

            return true
        end,
        effect = function(actor, patient, body_part_index)
            if patient.recovery_position then
                patient.recovery_position = false
            end

            patient.puls = 30
        end,
        time = 30
    },
}