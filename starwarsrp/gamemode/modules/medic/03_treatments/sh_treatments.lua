PD.DM = PD.DM or {}
PD.DM.Treatments = PD.DM.Treatments or {}

PD.DM.Treatments.tbl = {
    -- [1] = {
    --     name = "",
    --     condition = function(actor, patient_tbl, body_part_index, ply)
    --         
    --     end,
    --     time = 10, Sekunden
    --     effect = function(actor, patient, body_part_index)
    --
    --     end
    -- }
    [1] = {
        name = "Bactaverband Anlegen",
        condition = function(actor, patient_tbl, body_part_index, ply)
            return PD.DM.FindTreatmentValid(actor, patient_tbl, body_part_index, ply, "bacta_verband")
        end,
        effect = function(actor, patient, body_part_index)
            PD.DM.ApplyTreatment(actor, patient, body_part_index, "bacta_verband")
        end,
        time = 5
    },
    [2] = {
        name = "Operativer Eingriff",
        condition = function(actor, patient_tbl, body_part_index, ply)
            -- if not PD.DM.IsMedic(actor) then return false end

            return PD.DM.FindTreatmentValid(actor, patient_tbl, body_part_index, ply, "operativer_eingriff")
        end,
        effect = function(actor, patient, body_part_index)
            PD.DM.ApplyTreatment(actor, patient, body_part_index, "operativer_eingriff")
        end,
        time = 15
    },
    [3] = {
        name = "Bacta Tank (Arbeitstitel)",
        condition = function(actor, patient_tbl, body_part_index, ply)
            -- if not PD.DM.IsMedic(actor) then return false end

            return PD.DM.FindTreatmentValid(actor, patient_tbl, body_part_index, ply, "bacta_tank")
        end,
        effect = function(actor, patient, body_part_index)
            PD.DM.ApplyTreatment(actor, patient, body_part_index, "bacta_tank")
        end,
        time = 15
    },
    [4] = {
        name = "Synth Fleisch Einbringen",
        condition = function(actor, patient_tbl, body_part_index, ply)
            return PD.DM.FindTreatmentValid(actor, patient_tbl, body_part_index, ply, "synth_fleisch")
        end,
        effect = function(actor, patient, body_part_index)
            PD.DM.ApplyTreatment(actor, patient, body_part_index, "synth_fleisch")
        end,
        time = 10
    },
    [5] = {
        name = "Oberflächige Splitter Entfernen",
        condition = function(actor, patient_tbl, body_part_index, ply)
            -- if not PD.DM.IsMedic(actor) then return false end

            return PD.DM.FindTreatmentValid(actor, patient_tbl, body_part_index, ply, "oberflaechige_splitter_entfernen")
        end,
        effect = function(actor, patient, body_part_index)
            PD.DM.ApplyTreatment(actor, patient, body_part_index, "oberflaechige_splitter_entfernen")
        end,
        time = 15
    },
    [6] = {
        name = "Eine Schiene Anlegen",
        condition = function(actor, patient_tbl, body_part_index, ply)
            return PD.DM.FindTreatmentValid(actor, patient_tbl, body_part_index, ply, "schienung")
        end,
        effect = function(actor, patient, body_part_index)
            PD.DM.ApplyTreatment(actor, patient, body_part_index, "schienung")
        end,
        time = 10
    },
    [7] = {
        name = "Gasbinder verabreichen",
        condition = function(actor, patient_tbl, body_part_index, ply)
            -- if not PD.DM.IsMedic(actor) then return false end

            return PD.DM.FindTreatmentValid(actor, patient_tbl, body_part_index, ply, "gasbinder")
        end,
        effect = function(actor, patient, body_part_index)
            PD.DM.ApplyTreatment(actor, patient, body_part_index, "gasbinder")
        end,
        time = 5
    },
    [8] = {
        name = "Enkephalin verabreichen",
        condition = function(actor, patient_tbl, body_part_index, ply)
            -- if not PD.DM.IsMedic(actor) then return false end

            return PD.DM.FindTreatmentValid(actor, patient_tbl, body_part_index, ply, "enkephalin")
        end,
        effect = function(actor, patient, body_part_index)
            PD.DM.ApplyTreatment(actor, patient, body_part_index, "enkephalin")
        end,
        time = 5
    },
    [9] = {
        name = "Dermasel auftragen",
        condition = function(actor, patient_tbl, body_part_index, ply)
            -- if not PD.DM.IsMedic(actor) then return false end

            return PD.DM.FindTreatmentValid(actor, patient_tbl, body_part_index, ply, "dermasel")
        end,
        effect = function(actor, patient, body_part_index)
            PD.DM.ApplyTreatment(actor, patient, body_part_index, "dermasel")
        end,
        time = 5
    },
    [10] = {
        name = "Bonemer verabreichen",
        condition = function(actor, patient_tbl, body_part_index, ply)
            -- if not PD.DM.IsMedic(actor) then return false end

            return PD.DM.FindTreatmentValid(actor, patient_tbl, body_part_index, ply, "bonemer")
        end,
        effect = function(actor, patient, body_part_index)
            PD.DM.ApplyTreatment(actor, patient, body_part_index, "bonemer")
        end,
        time = 15
    },
    [11] = {
        name = "Prothese anbauen",
        condition = function(actor, patient_tbl, body_part_index, ply)
            -- if not PD.DM.IsMedic(actor) then return false end

            return PD.DM.FindTreatmentValid(actor, patient_tbl, body_part_index, ply, "prothese_anbauen")
        end,
        effect = function(actor, patient, body_part_index)
            PD.DM.ApplyTreatment(actor, patient, body_part_index, "prothese_anbauen")
        end,
        time = 30
    },
}

function PD.DM.FindTreatmentValid(actor, patient_tbl, body_part_index, ply, key)
    if table.IsEmpty(patient_tbl.injuries) then return false end

    for _, injury in pairs(patient_tbl.injuries) do
        if injury.wo == body_part_index and table.HasValue(injury.treatment, key) then
            return true
        end
        if body_part_index == 2 then
            body_part_index = 3
            if injury.wo == body_part_index and table.HasValue(injury.treatment, key) then
                return true 
            end
            body_part_index = 2
        end
    end

    return false
end

function PD.DM.ApplyTreatment(actor, patient, body_part_index, key)
    if body_part_index == 2 then
        body_part_index = 3
    end

    for _, injury in pairs(patient.injuries) do
        if injury.wo == body_part_index and table.HasValue(injury.treatment, key) then
            injury.healing_time = injury.healing_time - (injury.healing_time / #injury.treatment)

            for i, treatment_key in pairs(injury.treatment) do
                if treatment_key == key then
                    table.remove(injury.treatment, i)
                    break
                end
            end

            return
        end
    end
end