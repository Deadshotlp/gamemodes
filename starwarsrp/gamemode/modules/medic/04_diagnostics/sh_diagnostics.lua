PD.DM = PD.DM or {}
PD.DM.Diagnostics = PD.DM.Diagnostics or {}

PD.DM.Diagnostics.tbl = {
    [1] = {
        name = LANG.DM_DIAGNOSTIC_CHECK_PULS,
        condition = function(actor, patient, body_part_index)

            if patient.body_part[body_part_index].tourniquet ~= nil and patient.body_part[body_part_index].tourniquet then
                return false
            end

            return true
        end,
        effect = function(actor, patient, body_part_index)
            table.insert(patient.quick_overview_log, {
                time = os.time(),
                str = actor:Nick() .. " Prüfte den Puls : " .. math.Round(patient.puls)
            })
        end,
        time = 5
    },
    [2] = {
        name = LANG.DM_DIAGNOSTIC_CHECK_BREATHING,
        condition = function(actor, patient, body_part_index)

            if body_part_index ~= 1 then
                return false
            end

            return true
        end,
        effect = function(actor, patient, body_part_index)

            local str

            if not patient.respiratory_system.breathing_rate == 0 then
                str = "Keine Atmung erkannt"
            else
                str = "Atmung erkannt"
            end

            table.insert(patient.quick_overview_log, {
                time = os.time(),
                str = actor:Nick() .. " Prüfte die Atmung : " .. str
            })
        end,
        time = 5
    },
    [3] = {
        name = LANG.DM_DIAGNOSTIC_CHECK_BLOOD_PRESSURE,
        condition = function(actor, patient, body_part_index)

            if body_part_index == 1 then
                return false
            end

            if not PD.DM.IsMedic(actor) then
                return false
            end

            return true
        end,
        effect = function(actor, patient, body_part_index)

            table.insert(patient.quick_overview_log, {
                time = os.time(),
                str = actor:Nick() .. " Prüfte den Blutdruck : " .. patient.bp[1] .. "/" .. patient.bp[2]
            })
        end,
        time = 10
    },
    [4] = {
        name = LANG.DM_DIAGNOSTIC_CHECK_SPO2,
        condition = function(actor, patient, body_part_index)

            if body_part_index == 1 then
                return false
            end

            if not PD.DM.IsMedic(actor) then
                return false
            end

            return true
        end,
        effect = function(actor, patient, body_part_index)

            table.insert(patient.quick_overview_log, {
                time = os.time(),
                str = actor:Nick() .. " Prüfte die Sauerstoffsättigung : " .. math.Round(patient.spo2)
            })
        end,
        time = 5
    }
}
