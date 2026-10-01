--[[
    Signalbausteine fuer den ACRE-artigen Funkklang.

    Nachgebaut nach dem Verfahren von ACRE2 (IDI-Systems, FilterRadio und
    AcreDsp) - nicht kopiert. Die Kette dort, pro Stimme:

        Verstaerkung x3 -> rosa Rauschen -> Ringmodulation (90 Hz)
        -> Sample-and-Hold (dort "foldback") -> Tiefpass 4000 Hz
        -> Hochpass 750 Hz -> [Lautsprecher: Bass -10 dB] -> Begrenzen

    ACRE rechnet mit 48000 Hz, gm_8bit mit 24000 Hz. Alles, was an der
    Abtastrate haengt (Rauschpole, Haltedauer, Modulationsschritt, Filter),
    wird deshalb umgerechnet, damit es gleich klingt.

    Genutzt vom Server (sv_voice_effect.lua) und vom Client
    (cl_voice_signal.lua, Rauschen pro Zuhoerer).
]]

PD.VoiceFX = PD.VoiceFX or {}

local DSP = {}
PD.VoiceFX.DSP = DSP

DSP.ReferenceRate = 48000

DSP.InputGain = 3
DSP.RingFreq = 90
DSP.LowPassFreq, DSP.LowPassQ = 4000, 2.0
DSP.HighPassFreq, DSP.HighPassQ = 750, 0.97
DSP.ShelfFreq, DSP.ShelfGain, DSP.ShelfSlope = 1000, -10, 1

-- Biquad-Koeffizienten nach dem RBJ-Kochbuch, auf a0 normiert:
-- {b0, b1, b2, a1, a2}
local function normalize(b0, b1, b2, a0, a1, a2)
    return {b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0}
end

function DSP.LowPass(rate, freq, q)
    local w0 = 2 * math.pi * freq / rate
    local cs, sn = math.cos(w0), math.sin(w0)
    local alpha = sn / (2 * q)

    return normalize((1 - cs) / 2, 1 - cs, (1 - cs) / 2, 1 + alpha, -2 * cs, 1 - alpha)
end

function DSP.HighPass(rate, freq, q)
    local w0 = 2 * math.pi * freq / rate
    local cs, sn = math.cos(w0), math.sin(w0)
    local alpha = sn / (2 * q)

    return normalize((1 + cs) / 2, -(1 + cs), (1 + cs) / 2, 1 + alpha, -2 * cs, 1 - alpha)
end

function DSP.LowShelf(rate, freq, gainDb, slope)
    local A = 10 ^ (gainDb / 40)
    local w0 = 2 * math.pi * freq / rate
    local cs, sn = math.cos(w0), math.sin(w0)
    local alpha = sn / 2 * math.sqrt((A + 1 / A) * (1 / slope - 1) + 2)
    local sq = 2 * math.sqrt(A) * alpha

    return normalize(
        A * ((A + 1) - (A - 1) * cs + sq),
        2 * A * ((A - 1) - (A + 1) * cs),
        A * ((A + 1) - (A - 1) * cs - sq),
        (A + 1) + (A - 1) * cs + sq,
        -2 * ((A - 1) + (A + 1) * cs),
        (A + 1) + (A - 1) * cs - sq
    )
end

-- Rosa Rauschen: drei gedaempfte Zufallsstufen. Die Pole gelten fuer
-- 48000 Hz und werden auf die Zielrate umgerechnet (gleiche Zeitkonstante).
DSP.PinkA = {0.02109238, 0.07113478, 0.68873558}
DSP.PinkOffset = DSP.PinkA[1] + DSP.PinkA[2] + DSP.PinkA[3]

function DSP.PinkPoles(rate)
    local exponent = DSP.ReferenceRate / rate

    return {0.3190 ^ exponent, 0.7756 ^ exponent, 0.9613 ^ exponent}
end

-- Wie stark das Rauschen bei einer Signalqualitaet 0..1 ist.
function DSP.PinkAmount(quality)
    return 0.35 * (1.25 - quality)
end

function DSP.WhiteAmount(quality)
    return 0.001 * (1.25 - quality)
end

-- Anteil der Ringmodulation (metallisches Brummen), 0 bei perfektem Signal.
function DSP.RingAmount(quality)
    return (1 - quality) * 0.2
end

-- Haltedauer des Sample-and-Hold in Samples bei der Zielrate. Bei gutem
-- Signal 5 Samples bei 48000 Hz (knirschig), bei sehr schlechtem bis 40.
function DSP.HoldLength(quality, rate)
    local q = quality
    local divisor = math.floor(256 * q ^ 4 - 693.33 * q ^ 3 + 648 * q ^ 2 - 250.67 * q + 40)

    if divisor < 5 then divisor = 5 end

    return divisor * rate / DSP.ReferenceRate
end
