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
        bleading_level = 0.001,
        pain_level = 1,
        treatment = {
            [1] = {
                referenz_id = 1, -- Desinfizieren
                status = false
            }
        }
    }

}

local punkte = {{
    x = 100,
    y = 3
}, {
    x = 75,
    y = 17
}, {
    x = 50,
    y = 37
}, {
    x = 25,
    y = 69
}, {
    x = 0,
    y = 99
}}

-- https://docs.google.com/document/d/1FMGeQtCjmIfhwUJ6MItAneQauIpXqoIUE2xyPdc_8bQ/edit?usp=sharing

hook.Add("EntityTakeDamage", "DM.Injury", function(target, dmg)

    if not target:IsPlayer() then
        return
    end

    local hitGroup = target:LastHitGroup()
    local dmgType = dmg:GetDamageType()

    if not dmg:GetAttacker():IsPlayer() and not dmg:GetAttacker():IsNPC() then
        hitGroup = math.random(6, 7)
    end

    if hitGroup == 0 then
        hitGroup = math.random(1, 7)
    end

    local armor = PD.DM:CheckForArmor(target, dmg, hitGroup)

    if isnumber(armor) then
        local threshold = PD.LinearInterpolation(armor, punkte)
        local rand = math.random(0, 100)

        if rand < threshold then
            print("Test")
            PD.DM:GetPossibleInjuries(target, hitGroup, dmgType)
        end
    else
        PD.DM:GetPossibleInjuries(target, hitGroup, dmgType)
    end

    dmg:SetDamage(0)

    return false
end)

function PD.DM:CheckForArmor(ply, dmg, hitGroup)
    if hitGroup == 1 and ply:PDGetArmor().helm then
        print("Kopftreffer!")
        PD.Armor:CalculateArmor(ply, dmg, "helm")
        return ply:PDGetArmor().helm
    elseif (hitGroup >= 2 and hitGroup) <= 5 and ply:PDGetArmor().panzer then
        print("Brusttreffer!")
        PD.Armor:CalculateArmor(ply, dmg, "panzer")
        return ply:PDGetArmor().panzer
    elseif (hitGroup == 6 or hitGroup == 7) and ply:PDGetArmor().beine then
        print("Beintreffer!")
        PD.Armor:CalculateArmor(ply, dmg, "beine")
        return ply:PDGetArmor().beine
    else
        return nil
    end
end

function PD.DM:GetPossibleInjuries(ply, hitGroup, dmgType)
    local probabil_injury = {}

    for k, v in pairs(PD.DM.Injury.tbl) do
        if table.HasValue(v.typ, dmgType) and table.HasValue(v.wo, hitGroup) then
            table.insert(probabil_injury, v)
        end
    end

    if probabil_injury[1] ~= nil then

        local rand = math.random(1, #probabil_injury)
        PD.DM:AddInjury(ply, probabil_injury[rand], hitGroup)
    end
end

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

    -- PrintTable(id)

    table.insert(inj, id)

    PD.DM:UpdateTable(ply, "injureys", inj)

    -- PrintTable(PD.DM:RequestTable(ply, "injureys"))
end

function PD.DM:CalculateInjuries(tbl)
    -- Stelle sicher, dass die notwendigen Tabellen existieren
    if not tbl or not tbl.injureys or not tbl.body_part then
        -- print("[PD.DM Error] CalculateInjuries: Fehlende Spielerdaten.")
        return
    end

    -- Initialisiere numerische Werte, falls sie fehlen
    tbl.pain_level = (type(tbl.pain_level) == "number") and tbl.pain_level or 0
    tbl.blood_amount = (type(tbl.blood_amount) == "number") and tbl.blood_amount or 5.5 -- Standard-Blutmenge

    local injuries = tbl.injureys
    local body_parts = tbl.body_part
    local total_bleeding_this_update = 0

    -- --- Erste Schleife: Einmalige Effekte neuer Verletzungen anwenden ---
    for k, injury in pairs(injuries) do
        -- Stelle sicher, dass die Verletzung einen gültigen Körperteil referenziert
        local body_part_index = injury.wo
        local target_body_part = body_parts[body_part_index]

        if not target_body_part then
            -- print(string.format("[PD.DM Warning] Verletzung '%s' referenziert ungültigen Körperteil-Index %d. Übersprungen.", injury.name, body_part_index))
            continue
        end

        -- Wende initiale Effekte nur an, wenn die Verletzung noch nicht berechnet wurde
        if not injury.calculated then
            -- Füge die Blutungsrate der Verletzung zur Blutungsrate des Körperteils hinzu
            if injury.bleading_level and injury.bleading_level > 0 then
                -- Initialisiere die Blutungsrate des Körperteils, falls sie nicht existiert
                target_body_part.bleading_level = (type(target_body_part.bleading_level) == "number") and target_body_part.bleading_level or 0
                target_body_part.bleading_level = target_body_part.bleading_level + injury.bleading_level
                -- target_body_part.bleed = true -- Nicht wirklich nötig, da bleading_level > 0 dies impliziert
            end

            -- Füge den Schmerz der Verletzung zum Gesamtschmerz des Spielers hinzu
            if injury.pain_level and injury.pain_level > 0 then
                tbl.pain_level = tbl.pain_level + injury.pain_level
            end

            -- Markiere die Verletzung als berechnet, damit diese Effekte nicht erneut angewendet werden
            injury.calculated = true
        end

        -- --- Kontinuierliche Effekte (bei jedem Update prüfen) ---

        -- Prüfe auf Infektionsrisiko (dies geschieht bei jedem Update für relevante Verletzungen)
        if injury.needs_desinfication then
            -- TODO: Überprüfen, ob AddInfactions korrekt mit wiederholten Aufrufen umgeht
            -- oder ob hier eine Wahrscheinlichkeitsprüfung/einmalige Auslösung besser wäre.
            PD.DM:AddInfactions(tbl, injury) -- Übergibt optional Verletzungsdaten
        end
    end

    -- --- Zweite Schleife: Kontinuierlichen Blutverlust berechnen ---
    -- Iteriere durch alle Körperteile, um den Gesamtblutverlust zu ermitteln
    for i = 1, #body_parts do
        local part = body_parts[i]
        -- Prüfe, ob der Körperteil existiert, blutet und kein Tourniquet angelegt ist
        if part and part.bleading_level and part.bleading_level > 0 and not part.tourniquet then
            total_bleeding_this_update = total_bleeding_this_update + part.bleading_level
        end
    end

    -- Wende den berechneten Gesamtblutverlust auf das Blutvolumen des Spielers an
    if total_bleeding_this_update > 0 then
        tbl.blood_amount = tbl.blood_amount - total_bleeding_this_update
        -- Stelle sicher, dass die Blutmenge nicht unter 0 fällt
        if tbl.blood_amount < 0 then
            tbl.blood_amount = 0
        end
    end

    -- Optional: Schmerzlevel begrenzen, falls Maximalwert existiert
    -- tbl.pain_level = math.Clamp(tbl.pain_level, 0, MAX_PAIN_LEVEL)
end