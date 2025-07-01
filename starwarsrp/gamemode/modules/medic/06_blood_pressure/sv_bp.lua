PD.DM = PD.DM or {}
PD.DM.BP = PD.DM.BP or {}

-- Konstanten für die Blutdruckberechnung
local BASE_SYSTOLIC = 120 -- Normaler systolischer Ruhewert
local BASE_DIASTOLIC = 80 -- Normaler diastolischer Ruhewert

local NORMAL_BLOOD_VOLUME = 5.5 -- Normales Blutvolumen (aus sv_main.lua)
local BLOOD_LOSS_SYSTOLIC_IMPACT = 10 -- Wie stark der systolische Druck pro verlorener Bluteinheit sinkt
local BLOOD_LOSS_DIASTOLIC_IMPACT = 5 -- Wie stark der diastolische Druck pro verlorener Bluteinheit sinkt

local PAIN_SYSTOLIC_IMPACT = 2 -- Wie stark der systolische Druck pro Schmerzlevel steigt
local PAIN_DIASTOLIC_IMPACT = 1 -- Wie stark der diastolische Druck pro Schmerzlevel steigt

local MIN_SYSTOLIC = 40 -- Minimaler realistischer systolischer Druck
local MAX_SYSTOLIC = 220 -- Maximaler realistischer systolischer Druck
local MIN_DIASTOLIC = 20 -- Minimaler realistischer diastolischer Druck
local MAX_DIASTOLIC = 140 -- Maximaler realistischer diastolischer Druck

local BP_ADJUSTMENT_RATE = 0.08 -- Wie schnell sich der Blutdruck an den Zielwert anpasst (0 bis 1)

--[[
Berechnet den Blutdruck (systolisch/diastolisch) des Spielers basierend auf
Blutmenge, Schmerz und Medikamenten.

@param tbl table Die medizinische Datentabelle des Spielers. Erwartete Felder:
    - bp (table): {systolisch, diastolisch} - Der aktuelle Blutdruck (wird modifiziert).
    - blood_amount (number): Das aktuelle Blutvolumen.
    - pain_level (number): Das aktuelle Schmerzlevel.
@param medication_modifier table Ein Table {systolic = mod, diastolic = mod} oder ein einzelner Wert,
                                 der den *additiven* BP-Modifikator aus aktiven Medikamenten darstellt.
                                 (z.B. +5 für +5 mmHg)
]]
function PD.DM:CalculateBP(tbl, medication_modifier)
    -- Stelle sicher, dass tbl.bp existiert und ein Table mit zwei Zahlen ist. Initialisiere ggf.
    if not tbl.bp or type(tbl.bp) ~= "table" or #tbl.bp ~= 2 or type(tbl.bp[1]) ~= "number" or type(tbl.bp[2]) ~=
        "number" then
        tbl.bp = {BASE_SYSTOLIC, BASE_DIASTOLIC}
    end

    -- Standardwerte für fehlende Daten setzen
    local blood = (tbl.blood_amount and type(tbl.blood_amount) == "number") and tbl.blood_amount or NORMAL_BLOOD_VOLUME
    local pain = (tbl.pain_level and type(tbl.pain_level) == "number") and tbl.pain_level or 0

    -- Verarbeite den Medikamenten-Modifikator
    local med_mod_systolic = 0
    local med_mod_diastolic = 0
    if type(medication_modifier) == "table" then
        med_mod_systolic = medication_modifier.systolic or 0
        med_mod_diastolic = medication_modifier.diastolic or 0
    elseif type(medication_modifier) == "number" then
        -- Wenn nur eine Zahl übergeben wird, wende sie auf beide an (oder entscheide anders)
        med_mod_systolic = medication_modifier
        med_mod_diastolic = medication_modifier
    end

    -- 1. Berechne den Ziel-Blutdruck
    local target_systolic = BASE_SYSTOLIC
    local target_diastolic = BASE_DIASTOLIC

    -- Effekt von Blutverlust (senkt den Blutdruck)
    local blood_loss = math.max(0, NORMAL_BLOOD_VOLUME - blood)
    target_systolic = target_systolic - (blood_loss * BLOOD_LOSS_SYSTOLIC_IMPACT)
    target_diastolic = target_diastolic - (blood_loss * BLOOD_LOSS_DIASTOLIC_IMPACT)

    -- Effekt von Schmerz (erhöht den Blutdruck)
    target_systolic = target_systolic + (pain * PAIN_SYSTOLIC_IMPACT)
    target_diastolic = target_diastolic + (pain * PAIN_DIASTOLIC_IMPACT)

    -- Effekt von Medikamenten (additiv)
    target_systolic = target_systolic + med_mod_systolic
    target_diastolic = target_diastolic + med_mod_diastolic

    -- 2. Passe den aktuellen Blutdruck schrittweise an den Zielwert an
    local current_systolic = tbl.bp[1]
    local current_diastolic = tbl.bp[2]

    local diff_systolic = target_systolic - current_systolic
    local diff_diastolic = target_diastolic - current_diastolic

    tbl.bp[1] = current_systolic + (diff_systolic * BP_ADJUSTMENT_RATE)
    tbl.bp[2] = current_diastolic + (diff_diastolic * BP_ADJUSTMENT_RATE)

    -- 3. Begrenze den Blutdruck auf realistische Werte
    tbl.bp[1] = math.Clamp(tbl.bp[1], MIN_SYSTOLIC, MAX_SYSTOLIC)
    tbl.bp[2] = math.Clamp(tbl.bp[2], MIN_DIASTOLIC, MAX_DIASTOLIC)

    -- Stelle sicher, dass der systolische Wert nicht unter den diastolischen fällt
    if tbl.bp[1] < tbl.bp[2] then
        tbl.bp[1] = tbl.bp[2] + 1 -- Halte einen minimalen Abstand
    end

    -- Optional: Runde die Werte für eine sauberere Anzeige
    -- tbl.bp[1] = math.Round(tbl.bp[1])
    -- tbl.bp[2] = math.Round(tbl.bp[2])
end
