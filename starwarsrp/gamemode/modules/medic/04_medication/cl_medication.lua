PD.DM = PD.DM or {}
PD.DM.Medication = PD.DM.Medication or {}

PD.DM.Medication.tbl = {
    [1] = { -- Use name as key
        name = "Aspirin", -- Keep name field if needed
        requires_medic = false, -- Example: Only medics can administer this
        body_part = {1},
        task_time = 5 -- Time needed to administer the medication (in Secounds)
    },
    [2] = {
        name = "Adrenaline",
        requires_medic = true, -- Example: Only medics can administer this
        body_part = {4, 5, 6, 7},
        task_time = 10 -- Time needed to administer the medication (in Secounds)
    }
    -- Add more medications here...
}
