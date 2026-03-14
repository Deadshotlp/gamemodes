PD.DM = PD.DM or {}
PD.DM.Medication = PD.DM.Medication or {}

PD.DM.Medication.tbl = {
    -- [Name] = {
    --     condition = function(actor, patient, body_part_index,)
    --         
    --     end,
    --     time = 10, Sekunden
    --     effect = function(actor, patient, body_part_index)
    --          medicin_tbl = {
    --            name = "Quick Wake", -- Keep name field if needed
    --            time = 1, -- Example: 10 minutes duration
    --            puls = 0, -- Continuous pulse modifier (additive or multiplicative depends on CalculatePuls)
    --            spo2 = 0, -- Continuous SpO2 modifier (additive)
    --            bp = 0, -- Continuous BP modifier (additive or multiplicative depends on CalculateBP)
    --            effect = function(player_tbl, med_data)
    --                if player_tbl.stunning_level then
    --                    player_tbl.stunning_level = 0
    --                end
    --            end,
    --            onExpire = function(player_tbl)
    --                
    --            end
    --        }
    --
    --        PD.DM:AddMedication(patient, medicin_tbl)
    --     end
    -- }
    [1] = {
        name = "Quick Wake Auto Injector",
        condition = function(actor, patient, body_part_index)
            if not PD.DM.IsMedic(actor) then
                return false
            end

            if body_part_index <= 1 then
                return false
            end

            return true
        end,
        effect = function(actor, patient_tbl, body_part_index, patient)
            if patient_tbl.stunning_level then
                patient_tbl.stunning_level = 0
            end
            local medicin_tbl = {
                name = "Quick Wake Auto Injector",
                time = 1,
                puls = 0,
                spo2 = 0,
                bp = 0,
            }

            PD.DM:AddMedication(actor, patient_tbl, medicin_tbl)
        end,
        onExpire = function(player_tbl)

        end,
        time = 5
    },
    [2] = {
        name = "Quick Wake IV",
        condition = function(actor, patient, body_part_index)
            if not PD.DM.IsMedic(actor) then
                return false
            end

            if patient.body_part[body_part_index].has_iv == nil or not patient.body_part[body_part_index].has_iv then
                return false
            end

            return true
        end,
        effect = function(actor, patient_tbl, body_part_index, patient)
            if not patient:Alive() then
                PD.DM.Revive(patient, patient_tbl)
            end
            local medicin_tbl = {
                name = "Quick Wake IV",
                time = 15,
                puls = 1,
                spo2 = 1,
                bp = 1,
            }

            PD.DM:AddMedication(actor, patient_tbl, medicin_tbl)
        end,
        onExpire = function(player_tbl)
        end,
        time = 15
    },
    [3] = {
        name = "Nullicaine Auto Injector",
        condition = function(actor, patient, body_part_index)
            if not PD.DM.IsMedic(actor) then
                return false
            end

            if body_part_index == 1 then
                return false
            end

            return true
        end,
        effect = function(actor, patient_tbl, body_part_index, patient)
            if patient_tbl.pain_level then
                patient_tbl.pain_level = math.max(0, patient_tbl.pain_level - 1)
            end
            local medicin_tbl = {
                name = "Nullicaine Auto Injector",
                time = 10,
                puls = 0.1,
                spo2 = 0,
                bp = 0.2,
            }

            PD.DM:AddMedication(actor, patient_tbl, medicin_tbl)
        end,
        onExpire = function(player_tbl)

        end,
        time = 5
    },
    [4] = {
        name = "Nullicaine IV",
        condition = function(actor, patient, body_part_index)
            if not PD.DM.IsMedic(actor) then
                return false
            end

            if patient.body_part[body_part_index].has_iv == nil or not patient.body_part[body_part_index].has_iv then
                return false
            end

            return true
        end,
        effect = function(actor, patient_tbl, body_part_index, patient)
            if patient_tbl.pain_level then
                patient_tbl.pain_level = math.max(0, patient_tbl.pain_level - 3)
            end
            local medicin_tbl = {
                name = "Nullicaine IV",
                time = 30,
                puls = 0.2,
                spo2 = 0,
                bp = 0.4,
            }

            PD.DM:AddMedication(actor, patient_tbl, medicin_tbl)
        end,
        onExpire = function(player_tbl)

        end,
        time = 15
    },
    [5] = {
        name = "Kouhunin Auto Injector",
        condition = function(actor, patient, body_part_index)
            if not PD.DM.IsMedic(actor) then
                return false
            end

            if body_part_index == 1 then
                return false
            end

            return true
        end,
        effect = function(actor, patient_tbl, body_part_index, patient)
            if patient_tbl.pain_level then
                patient_tbl.pain_level = math.max(0, patient_tbl.pain_level - 3)
            end
            local medicin_tbl = {
                name = "Kouhunin Auto Injector",
                time = 30,
                puls = -0.2,
                spo2 = 0,
                bp = 0.3,
            }

            PD.DM:AddMedication(actor, patient_tbl, medicin_tbl)
        end,
        onExpire = function(player_tbl)

        end,
        time = 5
    },
    [6] = {
        name = "Kouhunin IV",
        condition = function(actor, patient, body_part_index)
            if not PD.DM.IsMedic(actor) then
                return false
            end

            if patient.body_part[body_part_index].has_iv == nil or not patient.body_part[body_part_index].has_iv then
                return false
            end

            return true
        end,
        effect = function(actor, patient_tbl, body_part_index, patient)
            if patient_tbl.pain_level then
                if patient_tbl.pain_level == 0 then
                    local rand = math.random(1, 3)
                    if rand == 1 then
                        patient_tbl.is_breatheing = false
                    end
                else
                    patient_tbl.pain_level = math.max(0, patient_tbl.pain_level - 5)
                end
            end
            local medicin_tbl = {
                name = "Kouhunin IV",
                time = 60,
                puls = -0.5,
                spo2 = 0,
                bp = 0.6,
            }

            PD.DM:AddMedication(actor, patient_tbl, medicin_tbl)
        end,
        onExpire = function(player_tbl)

        end,
        time = 15
    },
    [7] = {
        name = "Adrenalin Auto Injector",
        condition = function(actor, patient, body_part_index)
            if not PD.DM.IsMedic(actor) then
                return false
            end

            if body_part_index == 1 then
                return false
            end

            return true
        end,
        effect = function(actor, patient_tbl, body_part_index, patient)
            local medicin_tbl = {
                name = "Adrenalin Auto Injector",
                time = 10,
                puls = 0.5,
                spo2 = 0.1,
                bp = 0.3,
            }

            PD.DM:AddMedication(actor, patient_tbl, medicin_tbl)
        end,
        onExpire = function(player_tbl)

        end,
        time = 15
    },
    [8] = {
        name = "Adrenalin IV",
        condition = function(actor, patient, body_part_index)
            if not PD.DM.IsMedic(actor) then
                return false
            end

            if patient.body_part[body_part_index].has_iv == nil or not patient.body_part[body_part_index].has_iv then
                return false
            end

            return true
        end,
        effect = function(actor, patient_tbl, body_part_index, patient)
            local medicin_tbl = {
                name = "Adrenalin IV",
                time = 30,
                puls = 1,
                spo2 = 0.2,
                bp = 0.6,
            }

            PD.DM:AddMedication(actor, patient_tbl, medicin_tbl)
        end,
        onExpire = function(player_tbl)

        end,
        time = 15
    },
    [9] = {
        name = "Kryotin IV",
        condition = function(actor, patient, body_part_index)
            if not PD.DM.IsMedic(actor) then
                return false
            end

            if patient.body_part[body_part_index].has_iv == nil or not patient.body_part[body_part_index].has_iv then
                return false
            end

            return true
        end,
        effect = function(actor, patient_tbl, body_part_index, patient)
            if patient_tbl.stunning_level then
                patient_tbl.stunning_level = 1
            end
            local medicin_tbl = {
                name = "Kryotin IV",
                time = 1,
                puls = 0,
                spo2 = 0,
                bp = 0,
            }

            PD.DM:AddMedication(actor, patient_tbl, medicin_tbl)
        end,
        onExpire = function(player_tbl)

        end,
        time = 15
    },
    [10] = {
        name = "250ml Saline IV",
        condition = function(actor, patient, body_part_index)
            if not PD.DM.IsMedic(actor) then
                return false
            end

            if patient.body_part[body_part_index].has_iv == nil or not patient.body_part[body_part_index].has_iv then
                return false
            end

            return true
        end,
        effect = function(actor, patient_tbl, body_part_index, patient)
            patient_tbl.blood_to_add = (patient_tbl.blood_to_add or 0) + 0.25
        end,
        onExpire = function(player_tbl)

        end,
        time = 15
    },
    [11] = {
        name = "500ml Saline IV",
        condition = function(actor, patient, body_part_index)
            if not PD.DM.IsMedic(actor) then
                return false
            end

            if patient.body_part[body_part_index].has_iv == nil or not patient.body_part[body_part_index].has_iv then
                return false
            end

            return true
        end,
        effect = function(actor, patient_tbl, body_part_index, patient)
            patient_tbl.blood_to_add = (patient_tbl.blood_to_add or 0) + 0.5
        end,
        onExpire = function(player_tbl)

        end,
        time = 15
    },
    [12] = {
        name = "1000ml Saline IV",
        condition = function(actor, patient, body_part_index)
            if not PD.DM.IsMedic(actor) then
                return false
            end

            if patient.body_part[body_part_index].has_iv == nil or not patient.body_part[body_part_index].has_iv then
                return false
            end

            return true
        end,
        effect = function(actor, patient_tbl, body_part_index, patient)
            patient_tbl.blood_to_add = (patient_tbl.blood_to_add or 0) + 1
        end,
        onExpire = function(player_tbl)

        end,
        time = 15
    },
}

function PD.DM:AddMedication(actor, ply, medication_template)
    -- Validate input template
    if not medication_template or type(medication_template) ~= "table" or not medication_template.name or
        not medication_template.time then
        PD.LOGS.Add("[MEDIC]", "AddMedication: Invalid medication template provided: " .. medication_template.name,
            Color(255, 255, 255))
        return false
    end

    -- Request the player's current medication list
    if not ply["medication"] then
        PD.LOGS.Add("[MEDIC]", "AddMedication: Player medication table not found for " .. ply:Nick(),
            Color(255, 255, 255))
        ply["medication"] = {}
    end

    -- Create the entry for the player's active list
    local new_med_entry = {
        name = medication_template.name,
        administered = os.time(),
        time = medication_template.time,
        puls = medication_template.puls or 0,
        spo2 = medication_template.spo2 or 0,
        bp = medication_template.bp or 0,
    }

    local activity_log_tbl = {
        time = os.time(),
        str = actor:Nick() .. " verabreichte " .. medication_template.name,
    }

    table.insert(ply.medication, new_med_entry)
    table.insert(ply.activity_log, activity_log_tbl)
    return true
end
