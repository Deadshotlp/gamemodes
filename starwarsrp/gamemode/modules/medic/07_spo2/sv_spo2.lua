PD.DM = PD.DM or {}
PD.DM.SPO2 = PD.DM.SPO2 or {}

-- Konstanten für die SpO2-Berechnung
local NORMAL_SPO2 = 98 -- Zielwert für die Sauerstoffsättigung unter normalen Bedingungen
local MIN_SPO2 = 0 -- Minimal möglicher SpO2-Wert
local MAX_SPO2 = 100 -- Maximal möglicher SpO2-Wert
local NORMAL_BLOOD_VOLUME = 5.5 -- Normales Blutvolumen (aus sv_main.lua)
local BLOOD_LOSS_SPO2_IMPACT = 2.5 -- Wie stark SpO2 pro verlorener Bluteinheit sinkt
local NOT_BREATHING_SPO2_DROP = 5 -- Wie viel SpO2 pro Update sinkt, wenn nicht geatmet wird
local SPO2_RECOVERY_RATE = 0.5 -- Wie schnell sich SpO2 pro Update erholt (wenn Bedingungen gut sind)
local SPO2_DECAY_RATE = 0.2 -- Wie schnell SpO2 pro Update sinkt, wenn über NORMAL_SPO2 (z.B. durch Medikation)

--[[
Berechnet die Sauerstoffsättigung (SpO2) des Spielers basierend auf Atmung,
Blutmenge und Medikamenten.

@param tbl table Die medizinische Datentabelle des Spielers. Erwartete Felder:
    - spo2 (number): Der aktuelle SpO2-Wert (wird modifiziert).
    - is_breatheing (boolean): Ob die Person atmet.
    - blood_amount (number): Das aktuelle Blutvolumen.
@param medication_modifier number Der kombinierte *additive* SpO2-Modifikator aus aktiven Medikamenten.
                                  (z.B. +1 für +1% SpO2 pro Update)
]]
function PD.DM:CalculateSPO2(tbl, medication_modifier)
    -- Stelle sicher, dass tbl.spo2 existiert und eine Zahl ist. Initialisiere ggf. mit dem Normalwert.
    if not tbl.spo2 or type(tbl.spo2) ~= "number" then
        tbl.spo2 = NORMAL_SPO2
    end

    -- Standardwerte für fehlende Daten setzen
    local is_breathing = (tbl.is_breatheing ~= nil) and tbl.is_breatheing or true -- Annahme: Atmet standardmäßig
    local blood = (tbl.blood_amount and type(tbl.blood_amount) == "number") and tbl.blood_amount or NORMAL_BLOOD_VOLUME
    local med_mod = (medication_modifier and type(medication_modifier) == "number") and medication_modifier or 0

    -- Berechne die Änderung des SpO2-Wertes für dieses Update
    local spo2_change = 0

    -- 1. Effekt der Atmung
    if not is_breathing then
        spo2_change = spo2_change - NOT_BREATHING_SPO2_DROP
    else
        -- 2. Erholung/Normalisierung (nur wenn geatmet wird)
        if tbl.spo2 < NORMAL_SPO2 then
            -- Erhöhe SpO2 in Richtung Normalwert, aber nicht schneller als die Recovery Rate
            spo2_change = spo2_change + math.min(SPO2_RECOVERY_RATE, NORMAL_SPO2 - tbl.spo2)
        elseif tbl.spo2 > NORMAL_SPO2 then
            -- Senke SpO2 langsam Richtung Normalwert (falls künstlich erhöht)
            spo2_change = spo2_change - math.min(SPO2_DECAY_RATE, tbl.spo2 - NORMAL_SPO2)
        end

        -- 3. Effekt von Blutverlust (nur wenn geatmet wird)
        local blood_loss = math.max(0, NORMAL_BLOOD_VOLUME - blood)
        if blood_loss > 0 then
            -- Reduziere SpO2 basierend auf dem Blutverlust
            spo2_change = spo2_change - (blood_loss * BLOOD_LOSS_SPO2_IMPACT)
        end
    end

    -- 4. Effekt von Medikamenten (wirkt immer)
    spo2_change = spo2_change + med_mod

    -- Wende die berechnete Änderung an
    tbl.spo2 = tbl.spo2 + spo2_change

    -- Begrenze den SpO2-Wert auf den gültigen Bereich
    tbl.spo2 = math.Clamp(tbl.spo2, MIN_SPO2, MAX_SPO2)

    -- Optional: Runde das Ergebnis für eine sauberere Anzeige
    -- tbl.spo2 = math.Round(tbl.spo2)
end
