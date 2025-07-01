PD.DM = PD.DM or {}
PD.DM.Treatments = PD.DM.Treatments or {}
PD.DM.Diagnostics = PD.DM.Diagnostics or {}

PD.DM.Treatments.tbl = {
    [1] = {
        name = "Apply Tourniquet"
    },
    [2] = {
        name = "Bandage"
    }
}

PD.DM.Diagnostics.tbl = {
    [1] = {
        name = "Check Puls",
        func = function(ply1, ply2)
            local activity_log = PD.DM:RequestTable(ply2, "activity_log")

            if activity_log then
                table.insert(activity_log, {
                    time = os.time(),
                    str = ply1:Nick() .. " Checked Puls : " .. math.Round(PD.DM:RequestTable(ply2, "puls"))
                })

                PD.DM:UpdateTable(ply2, "activity_log", activity_log)
            end
        end
    },
    [2] = {
        name = "Check Breathing",
        func = function(ply1, ply2)
            local activity_log = PD.DM:RequestTable(ply2, "activity_log")
            local breathing = PD.DM:RequestTable(ply2, "is_breatheing")
            local str

            if not breathing then
                str = "No Breathing Detected"
            else
                str = "Breathing Detected"
            end

            if activity_log then
                table.insert(activity_log, {
                    time = os.time(),
                    str = ply1:Nick() .. " Checked Breathing : " .. str
                })

                PD.DM:UpdateTable(ply2, "activity_log", activity_log)
            end
        end
    },
    [3] = {
        name = "Check Blood Pressure",
        func = function(ply1, ply2)
            local activity_log = PD.DM:RequestTable(ply2, "activity_log")
            local bp = PD.DM:RequestTable(ply2, "bp")

            if activity_log then
                table.insert(activity_log, {
                    time = os.time(),
                    str = ply1:Nick() .. " Checked Blood Pressure : " .. bp[1] .. "/" .. bp[2]
                })

                PD.DM:UpdateTable(ply2, "activity_log", activity_log)
            end
        end
    },
    [4] = {
        name = "Check Spo2",
        func = function(ply1, ply2)
            local activity_log = PD.DM:RequestTable(ply2, "activity_log")

            if activity_log then
                table.insert(activity_log, {
                    time = os.time(),
                    str = ply1:Nick() .. " Checked Spo2 : " .. math.Round(PD.DM:RequestTable(ply2, "spo2"))
                })

                PD.DM:UpdateTable(ply2, "activity_log", activity_log)
            end
        end
    }
}

