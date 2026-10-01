--[[
    Funk-Empfang pro Zuhoerer (wie bei ACRE2).

    Bei ACRE hoert jeder Zuhoerer denselben Sprecher anders: je weiter weg,
    desto mehr Rauschen und desto leiser. Der Klangfilter selbst laeuft bei
    uns auf dem Server und ist fuer alle gleich (Preset in sv_voice_config.lua).
    Den Unterschied pro Zuhoerer macht cl_voice_signal.lua: Stimme leiser und
    zusaetzliches Funkrauschen, abhaengig von der Entfernung.

    Gilt nur fuer Funk, nicht fuers Intercom.

    Aenderungen hier wirken nach Lua-Refresh sofort.
    Pruefen im Spiel (Client-Konsole, waehrend jemand funkt): pd_voicefx_signal
]]

PD.VoiceFX = PD.VoiceFX or {}

PD.VoiceFX.Signal = {
    Enabled = true,

    -- Entfernungen in Metern (1 m = 39,37 Units). Eine normale Map ist
    -- hoechstens etwa 800 m breit.
    FullRange = 50,       -- bis hierhin perfekter Empfang
    ZeroRange = 800,      -- ab hier schlechtester Empfang

    MinQuality = 0.2,     -- schlechteste Qualitaet, 0 = nur noch Rauschen
    VolumeAtWorst = 0.6,  -- Lautstaerke der Stimme bei schlechtestem Empfang (1 = normal)
    NoiseVolume = 0.35    -- Lautstaerke des Zusatzrauschens bei schlechtestem Empfang
}

local UNITS_PER_METER = 39.37

-- Signalqualitaet 0..1 aus der Entfernung in Units. Faellt wie beim
-- Freiraum-Modell von ACRE logarithmisch: die ersten Meter nach FullRange
-- kosten mehr als spaeter dieselbe Strecke.
function PD.VoiceFX.SignalQuality(distanceUnits)
    local cfg = PD.VoiceFX.Signal
    local meters = distanceUnits / UNITS_PER_METER
    local full = math.max(tonumber(cfg.FullRange) or 50, 0.1)
    local zero = math.max(tonumber(cfg.ZeroRange) or 800, full + 0.1)
    local minQuality = math.Clamp(tonumber(cfg.MinQuality) or 0.2, 0, 1)

    if meters <= full then return 1 end

    local t = math.Clamp(math.log(meters / full) / math.log(zero / full), 0, 1)

    return 1 - t * (1 - minQuality)
end
