PD.DM = PD.DM or {}
PD.DM.Treatments = PD.DM.Treatments or {}
PD.DM.Diagnostics = PD.DM.Diagnostics or {}

PD.DM.Treatments.tbl = {
    [1] = {
        name = "Apply Tourniquet",
        requires_medic = false,
        body_part = {4, 5, 6, 7},
        task_time = 15
    },
    [2] = {
        name = "Bandage",
        requires_medic = false,
        body_part = {1, 2, 3, 4, 5, 6, 7},
        task_time = 15
    }
}

PD.DM.Diagnostics.tbl = {
    [1] = {
        name = "Check Puls",
        requires_medic = false,
        body_part = {1, 2, 3, 4, 5, 6, 7},
        task_time = 10
    },
    [2] = {
        name = "Check Breathing",
        requires_medic = false,
        body_part = {1, 2},
        task_time = 10
    },
    [3] = {
        name = "Check Blood Pressure",
        requires_medic = true,
        body_part = {1, 2, 3, 4, 5, 6, 7},
        task_time = 10
    },
    [4] = {
        name = "Check Spo2",
        requires_medic = false,
        body_part = {1, 2, 3, 4, 5, 6, 7},
        task_time = 10
    }
}

