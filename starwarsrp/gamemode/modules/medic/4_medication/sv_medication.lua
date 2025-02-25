PD.DM = PD.DM or {}
PD.DM.Medication = PD.DM.Medication or {}

PD.DM.Medication.tbl = {
    [1] = {
        name = "Aspirin",
        time = 10,
        puls = 0,
        spo2 = 0,
        bp = 0,
        effect = function(tbl) end,
    }
}

function PD.DM:AddMedication(ply, tbl)

    local med = PD.DM:RequestTable(ply, "medication")

    local id = {
        name = tbl.name,
        administered = os.time(),
        time = tbl.time,
        puls = tbl.puls,
        spo2 = tbl.spo2,
        bp = tbl.bp,
        effect = tbl.effect,
        calculated = false
    }

    table.insert(med, id)

    PD.DM:UpdateTable(ply, "medication", med)
end

function PD.DM:CalculateMedication(tbl)
    if not tbl["medication"] then
        return
    end

    local m1, m2, m3 = 0, 0, 0

    for k, v in pairs(tbl["medication"]) do
        if not v.calculated then
            v.effect(v)
            v.calculated = true
        end

        if v.administered + v.time >= os.time() then
            v = nil
            continue
        end

        m1 = m1 + v.puls
        m2 = m2 + v.spo2
        m3 = m3 + v.bp
    end

    return m1, m2, m3
end