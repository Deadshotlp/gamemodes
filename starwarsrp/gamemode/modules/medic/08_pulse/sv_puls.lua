PD.DM = PD.DM or {}
PD.DM.Puls = PD.DM.Puls or {}

-- Konstanten für die Pulsberechnung
local BASE_PULSE = 75 -- Der Ruhepuls, zu dem der Wert tendiert
local PAIN_BPM_PER_LEVEL = 1.75 -- Zusätzliche Schläge pro Minute pro Schmerzlevel
local NORMAL_BLOOD_VOLUME = 5.5 -- Normales Blutvolumen
local BLOOD_LOSS_BPM_PER_UNIT = 10.5 -- Zusätzliche Schläge pro Minute pro verlorener Bluteinheit
local RANDOM_FLUCTUATION = 10 -- Maximale zufällige Abweichung (+/-) pro Update
local MIN_PULSE = 0 -- Minimaler realistischer Puls
local MAX_PULSE = 250 -- Maximaler realistischer Puls
local PULSE_ADJUSTMENT_RATE = 0.1 -- Wie schnell sich der Puls an den Zielwert anpasst (0 bis 1)

--[[
Berechnet den Puls des Spielers basierend auf verschiedenen Faktoren und lässt ihn
zu einem Basiswert tendieren, wenn keine Modifikatoren aktiv sind. Fügt leichte
zufällige Schwankungen hinzu.

@param tbl table Die medizinische Datentabelle des Spielers. Erwartete Felder:
    - puls (number): Der aktuelle Puls (wird modifiziert).
    - pain_level (number): Das aktuelle Schmerzlevel (Standard: 0).
    - blood_amount (number): Das aktuelle Blutvolumen (Standard: NORMAL_BLOOD_VOLUME).
@param medication_modifier number Der kombinierte *multiplikative* Puls-Modifikator aus aktiven Medikamenten (z.B. 0.1 für +10%).
]]
function PD.DM:CalculatePuls(tbl, medication_modifier)
    -- Stelle sicher, dass tbl.puls existiert und eine Zahl ist. Initialisiere ggf. mit dem Basiswert.
    if tbl.puls == 0 then
        return
    end

    if not tbl.puls or type(tbl.puls) ~= "number" or tbl.puls <= 0 then
        tbl.puls = BASE_PULSE
    end

    -- Standardwerte für fehlende Daten setzen
    local pain = (tbl.pain_level and type(tbl.pain_level) == "number") and tbl.pain_level or 0
    local blood = (tbl.blood_amount and type(tbl.blood_amount) == "number") and tbl.blood_amount or NORMAL_BLOOD_VOLUME
    local med_mod = (medication_modifier and type(medication_modifier) == "number") and medication_modifier or 0

    -- 1. Berechne den Zielpuls basierend auf den aktuellen Bedingungen
    local target_pulse = BASE_PULSE

    -- Wende den Medikamenten-Modifikator an (multiplikativ auf den Basiswert)
    target_pulse = target_pulse * (1 + med_mod)

    -- Füge den Effekt von Schmerz hinzu (additiv)
    target_pulse = target_pulse + (pain * PAIN_BPM_PER_LEVEL)

    -- Füge den Effekt von Blutverlust hinzu (additiv)
    -- Nur wenn Blut unter dem Normalwert ist. math.max stellt sicher, dass wir keinen negativen Wert bekommen.
    local blood_loss = math.max(0, NORMAL_BLOOD_VOLUME - blood)
    target_pulse = target_pulse + (blood_loss * BLOOD_LOSS_BPM_PER_UNIT)

    -- Füge eine leichte zufällige Schwankung zum Zielpuls hinzu
    target_pulse = target_pulse + math.random(-RANDOM_FLUCTUATION, RANDOM_FLUCTUATION)

    -- 2. Passe den aktuellen Puls schrittweise an den Zielpuls an
    -- Dies sorgt für eine glattere Veränderung statt sprunghafter Wechsel.
    local difference = target_pulse - tbl.puls

    tbl.puls = tbl.puls + (difference * PULSE_ADJUSTMENT_RATE)

    if tbl.puls > 250 then tbl.puls = 0 end

    -- 3. Begrenze den Puls auf realistische Werte
    tbl.puls = math.Round(math.Clamp(tbl.puls, MIN_PULSE, MAX_PULSE))
end
