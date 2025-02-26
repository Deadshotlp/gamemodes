PD.DM = PD.DM or {}
PD.DM.Injury = PD.DM.Injury or {}
PD.DM.Injury.tbl = {
    [1] = {
        name = "Schuss Wunde",
        wo = {1, 2, 3, 4, 5, 6, 7},
        typ = {2},
        needs_desinfication = true,
        bleading_level = 0,
        pain_level = 1,
        treatment = {
            [1] = {
                referenz_id = 1,
                status = false
            }
        }
    },
    [2] = {
        name = "Stich Wunde",
        wo = {1, 2, 3, 4, 5, 6, 7},
        typ = {2},
        needs_desinfication = true,
        bleading_level = 0.1,
        pain_level = 1,
        treatment = {
            [1] = {
                referenz_id = 1, -- Desinfizieren
                status = false
            }
        }
    }

}

-- https://docs.google.com/document/d/1FMGeQtCjmIfhwUJ6MItAneQauIpXqoIUE2xyPdc_8bQ/edit?usp=sharing

hook.Add("EntityTakeDamage", "DM.Injury", function(target, dmg)

    --
    --
    --
    --

    --
    --

    --
    --
    --

    --

    --

    --

    if target:IsPlayer() then -- and not target:LastHitGroup() == 10 then
        dmg:SetDamage(0)
        local hitGroup = 1 -- target:LastHitGroup()
        local dmgType = 2 -- dmg:GetDamageType()

        -- if not dmg:GetAttacker():IsPlayer() and not dmg:GetAttacker():IsNPC() then
        --    hitGroup = math.random(6, 7)
        -- end

        local probabil_injury = {}

        for k, v in pairs(PD.DM.Injury.tbl) do
            if table.HasValue(v.typ, dmgType) and table.HasValue(v.wo, hitGroup) then
                table.insert(probabil_injury, v)
            end
        end

        if probabil_injury[1] ~= nil then

            local rand = math.random(1, #probabil_injury)
            PD.DM:AddInjury(target, probabil_injury[rand], hitGroup)
        end
    end

    return false
end)

function PD.DM:AddInjury(ply, tbl, hitGroup)

    local inj = PD.DM:RequestTable(ply, "injureys")

    local id = {
        name = tbl.name,
        wo = hitGroup,
        needs_desinfication = tbl.needs_desinfication,
        bleading_level = tbl.bleading_level,
        pain_level = tbl.pain_level,
        treatment = tbl.treatment,
        calculated = false
    }

    table.insert(inj, id)

    PD.DM:UpdateTable(ply, "injureys", inj)
end

function PD.DM:CalculateInjuries(tbl)
    if not tbl["injureys"] then
        return
    end

    for k, v in pairs(tbl["injureys"]) do
        if not v.calculated then
            if v.bleading_level > 0 then
                tbl["body_part"][v.wo].bleed = true
                tbl["body_part"][v.wo].bleading_level = tbl["body_part"][v.wo].bleading_level + v.bleading_level
            end

            if v.pain_level > 0 then
                tbl["pain_level"] = tbl["pain_level"] + v.pain_level
            end

            v.calculated = true
        end

        if v.needs_desinfication then
            PD.DM:AddInfactions(tbl)
        end

    end

    for k, v in pairs(tbl["body_part"]) do
        if v.bleading_level > 0 and not v.tourniquet then
            v.blood_amount = v.blood_amount - v.bleading_level
        end
    end
end
