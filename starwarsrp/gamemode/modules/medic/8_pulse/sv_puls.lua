PD.DM = PD.DM or {}
PD.DM.Puls = PD.DM.Puls or {}

function PD.DM:CalculatePuls(tbl, m1)
    local modifier = 1 + m1 -- m1 = modifier from medication

    -- pain
    modifier = modifier + (tbl.pain_level / 10)

    -- blood loss
    modifier = modifier + (tbl.blood_amount - 5.5)

    if modifier < 0 then
        modifier = 0
    end

    tbl.puls = tbl.puls * modifier
end
