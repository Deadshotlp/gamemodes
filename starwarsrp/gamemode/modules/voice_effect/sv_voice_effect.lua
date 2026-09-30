PD.VoiceFX = PD.VoiceFX or {}

--[[
    Funk-/Radio-Effekt fuer Comlink und Intercom.

    Die Klaenge (Presets) und welche Situation welches Preset nutzt, stehen in
    sv_voice_config.lua. Jeder Sprecher filtert mit seinem eigenen Preset -
    Funk und Intercom klingen deshalb unterschiedlich, und eine Situation wie
    ein Stoersender laesst sich per pd_funk_situation serverweit einschalten.

    Zwei Filterketten:
        type = "acre"  Nachbau des Funkklangs von ACRE2 (Bausteine in
                       sh_voice_dsp.lua). Der Empfang pro Zuhoerer kommt in
                       cl_voice_signal.lua dazu.
        sonst          Der fruehere eigene Filter mit Einzelreglern.

    Benoetigt das Binary-Modul gm_8bit (https://github.com/Deadshotlp/gm_8bit).
    Das Modul ist SERVERSEITIG - die DLL gehoert nach garrysmod/lua/bin/ und heisst
    je nach Branch gmsv_eightbit_win32.dll / gmsv_eightbit_linux.dll (32 Bit) bzw.
    gmsv_eightbit_win64.dll / gmsv_eightbit_linux64.dll (x86-64 Branch).

    API des Forks:
        eightbit.EnableEffects(userid, 1/0)
        eightbit.SetSampleRate(number)
        hook "ApplyVoiceEffect"(userId, samples, count)
]]

local BIN_SUFFIX = (system.IsWindows() and "win" or "linux") .. (jit.arch == "x64" and "64" or (system.IsWindows() and "32" or ""))
local BIN_NAME = "gmsv_eightbit_" .. BIN_SUFFIX .. ".dll"

local loaded, loadErr = pcall(require, "eightbit")
local hasEightbit = loaded and istable(eightbit) and isfunction(eightbit.EnableEffects)

PD.VoiceFX.Available = hasEightbit
PD.VoiceFX.BinaryName = BIN_NAME

if not hasEightbit then
    local reason
    if loaded then
        reason = "geladen, aber eightbit.EnableEffects fehlt - veralteter/falscher Build"
    elseif file.Exists("bin/" .. BIN_NAME, "LUA") then
        reason = "lua/bin/" .. BIN_NAME .. " existiert, laesst sich aber nicht laden (falsche Architektur oder fehlende Abhaengigkeiten): " .. tostring(loadErr)
    else
        reason = "lua/bin/" .. BIN_NAME .. " nicht gefunden (Server ist " .. jit.arch .. ", " .. jit.os .. ")"
    end

    ErrorNoHalt("[PD.VoiceFX] gmsv_eightbit fehlt - Funk laeuft ohne Sprachfilter.\n[PD.VoiceFX] Grund: " .. reason .. "\n")
end

-- Presets ----------------------------------------------------------------------
-- Der Encoder von gm_8bit laeuft fest auf 24000 Hz.
local SAMPLE_RATE = 24000

-- Neutrale Werte fuer den frueheren Filter: ergibt keinen Effekt.
PD.VoiceFX.Defaults = {
    lowCut = 20,
    highCut = 11000,
    gain = 1,
    clip = 32767,
    bits = 16,
    noise = 0,
    reverb = 0,
    reverbDecay = 0.5,
    reverbDamping = 0.5,
    mix = 1
}

-- Werte fuer ACRE-Presets, wenn das Preset sie nicht angibt.
PD.VoiceFX.AcreDefaults = {
    quality = 1,
    loudspeaker = false,
    noiseScale = 1,
    reverb = 0,
    reverbDecay = 0.5,
    reverbDamping = 0.5,
    mix = 1
}

-- Hall: drei parallele Kammfilter mit teilerfremden Laengen, danach ein Allpass.
-- Laengen in Samples bei 24000 Hz, entspricht ca. 42-54 ms bzw. 14 ms.
local COMB_LEN = { 1013, 1187, 1289 }
local ALLPASS_LEN = 331
local NOISE_COUNT = 1024

-- [Presetname] = Werte samt vorberechneter Filterkoeffizienten
local built = {}
local warnedMissing = {}

local function ReverbValues(p)
    p.mixWet = math.Clamp(p.mix, 0, 1)
    p.mixDry = 1 - p.mixWet
    p.decay = math.Clamp(p.reverbDecay, 0, 0.9)
    p.damp = 1 - math.Clamp(p.reverbDamping, 0, 0.95)
end

local function BuildClassicPreset(raw)
    local p = {}

    for key, default in pairs(PD.VoiceFX.Defaults) do
        local value = tonumber(raw[key])
        p[key] = value ~= nil and value or default
    end

    p.aLow = 1 - math.exp(-2 * math.pi * p.lowCut / SAMPLE_RATE)
    p.aHigh = 1 - math.exp(-2 * math.pi * p.highCut / SAMPLE_RATE)

    p.crushStep = 2 ^ (16 - math.Clamp(p.bits, 1, 16))
    p.invCrush = 1 / p.crushStep

    ReverbValues(p)

    p.noiseTbl = {}

    for i = 1, NOISE_COUNT do
        p.noiseTbl[i] = (math.random() * 2 - 1) * p.noise
    end

    return p
end

local function BuildAcrePreset(raw)
    local DSP = PD.VoiceFX.DSP

    if not DSP then
        ErrorNoHalt("[PD.VoiceFX] sh_voice_dsp.lua fehlt - ACRE-Presets ohne Filter.\n")
        return nil
    end

    local p = {acre = true}

    for key, default in pairs(PD.VoiceFX.AcreDefaults) do
        local value = raw[key]

        if isbool(default) then
            if value == nil then
                p[key] = default
            else
                p[key] = value == true or value == 1
            end
        else
            p[key] = tonumber(value) or default
        end
    end

    local q = math.Clamp(p.quality, 0, 1)
    local noiseScale = math.max(p.noiseScale, 0)

    p.quality = q
    p.pinkAmp = DSP.PinkAmount(q) * noiseScale
    p.whiteAmp = DSP.WhiteAmount(q) * noiseScale
    p.ringAmt = DSP.RingAmount(q)
    p.ringStep = DSP.RingFreq / SAMPLE_RATE
    p.holdLen = DSP.HoldLength(q, SAMPLE_RATE)
    p.poles = DSP.PinkPoles(SAMPLE_RATE)
    p.lp = DSP.LowPass(SAMPLE_RATE, DSP.LowPassFreq, DSP.LowPassQ)
    p.hp = DSP.HighPass(SAMPLE_RATE, DSP.HighPassFreq, DSP.HighPassQ)
    p.shelf = p.loudspeaker and DSP.LowShelf(SAMPLE_RATE, DSP.ShelfFreq, DSP.ShelfGain, DSP.ShelfSlope) or nil

    ReverbValues(p)

    return p
end

local function BuildPreset(raw)
    if raw.type == "acre" then
        return BuildAcrePreset(raw)
    end

    return BuildClassicPreset(raw)
end

-- Aktive Sprecher + deren Filterzustand (muss ueber Pakete hinweg erhalten bleiben)
local states = {}

local floor, random, sin = math.floor, math.random, math.sin
local HALF_PI = math.pi * 0.5

local function NewBuffer(len)
    local buf = {}
    for i = 1, len do buf[i] = 0 end

    return buf
end

--[[
    ACRE-Kette pro Paket. Reihenfolge wie bei ACRE2: Verstaerkung, rosa und
    weisses Rauschen, Ringmodulation, Sample-and-Hold, Tiefpass, Hochpass,
    Lautsprecher-Bass, Begrenzen. Danach optional Hall und Mischung.
]]
local function ProcessAcre(st, p, samples, count)
    if p.quality <= 0 then
        for i = 1, count do samples[i] = 0 end
        return
    end

    local DSP = PD.VoiceFX.DSP
    local gain = DSP.InputGain / 32768

    local pinkAmp, whiteAmp = p.pinkAmp, p.whiteAmp
    local useNoise = pinkAmp > 0 or whiteAmp > 0
    local A1, A2, A3 = DSP.PinkA[1], DSP.PinkA[2], DSP.PinkA[3]
    local pinkOffset = DSP.PinkOffset
    local P1, P2, P3 = p.poles[1], p.poles[2], p.poles[3]
    local ps1, ps2, ps3 = st.ps1, st.ps2, st.ps3

    local ringAmt, ringStep, ringPhase = p.ringAmt, p.ringStep, st.ringPhase
    local holdLen, holdLeft, holdValue = p.holdLen, st.holdLeft, st.holdValue

    local lp, hp, shelf = p.lp, p.hp, p.shelf
    local lb0, lb1, lb2, la1, la2 = lp[1], lp[2], lp[3], lp[4], lp[5]
    local hb0, hb1, hb2, ha1, ha2 = hp[1], hp[2], hp[3], hp[4], hp[5]
    local lx1, lx2, ly1, ly2 = st.lx1, st.lx2, st.ly1, st.ly2
    local hx1, hx2, hy1, hy2 = st.hx1, st.hx2, st.hy1, st.hy2

    local sb0, sb1, sb2, sa1, sa2 = 0, 0, 0, 0, 0
    local sx1, sx2, sy1, sy2 = st.sx1, st.sx2, st.sy1, st.sy2

    if shelf then
        sb0, sb1, sb2, sa1, sa2 = shelf[1], shelf[2], shelf[3], shelf[4], shelf[5]
    end

    local mix, dry = p.mixWet, p.mixDry
    local revAmt, decay, damp = p.reverb, p.decay, p.damp
    local c1, c2, c3, ap = st.c1, st.c2, st.c3, st.ap
    local p1, p2, p3, pa = st.p1, st.p2, st.p3, st.pa
    local d1, d2, d3 = st.d1, st.d2, st.d3
    local l1, l2, l3, la = COMB_LEN[1], COMB_LEN[2], COMB_LEN[3], ALLPASS_LEN

    for i = 1, count do
        local x = samples[i]
        local s = x * gain

        -- Rauschen: rosa gemischt wie bei ACRE, dazu ein Hauch weisses
        if useNoise then
            local r = random()
            ps1 = P1 * (ps1 - r) + r
            r = random()
            ps2 = P2 * (ps2 - r) + r
            r = random()
            ps3 = P3 * (ps3 - r) + r

            local n = ((A1 * ps1 + A2 * ps2 + A3 * ps3) * 2 - pinkOffset) * pinkAmp
            s = (s + n) - (n * s)
            s = s + (random() * 2 - 1) * whiteAmp
        end

        -- Ringmodulation mit 90 Hz: metallisches Brummen bei schlechtem Signal
        if ringAmt > 0 then
            local m = s * sin(ringPhase * HALF_PI)
            ringPhase = ringPhase + ringStep
            if ringPhase > 1 then ringPhase = 0 end
            s = s * (1 - ringAmt) + m * ringAmt
        end

        -- Sample-and-Hold: haelt jeden Wert einige Samples lang, das Knirschen
        holdLeft = holdLeft - 1
        if holdLeft <= 0 then
            holdValue = s
            holdLeft = holdLeft + holdLen
        end
        s = holdValue

        -- Tiefpass 4000 Hz
        local y = lb0 * s + lb1 * lx1 + lb2 * lx2 - la1 * ly1 - la2 * ly2
        lx2, lx1, ly2, ly1 = lx1, s, ly1, y
        s = y

        -- Hochpass 750 Hz
        y = hb0 * s + hb1 * hx1 + hb2 * hx2 - ha1 * hy1 - ha2 * hy2
        hx2, hx1, hy2, hy1 = hx1, s, hy1, y
        s = y

        -- Lautsprecher: Bass weg
        if shelf then
            y = sb0 * s + sb1 * sx1 + sb2 * sx2 - sa1 * sy1 - sa2 * sy2
            sx2, sx1, sy2, sy1 = sx1, s, sy1, y
            s = y
        end

        if s > 1 then
            s = 1
        elseif s < -1 then
            s = -1
        end

        s = floor(s * 32767)

        -- Hall wie beim frueheren Filter
        if revAmt > 0 then
            local v1 = c1[p1]
            d1 = d1 + damp * (v1 - d1)
            c1[p1] = s + d1 * decay
            p1 = p1 + 1
            if p1 > l1 then p1 = 1 end

            local v2 = c2[p2]
            d2 = d2 + damp * (v2 - d2)
            c2[p2] = s + d2 * decay
            p2 = p2 + 1
            if p2 > l2 then p2 = 1 end

            local v3 = c3[p3]
            d3 = d3 + damp * (v3 - d3)
            c3[p3] = s + d3 * decay
            p3 = p3 + 1
            if p3 > l3 then p3 = 1 end

            local wet = (v1 + v2 + v3) * 0.3333333

            local va = ap[pa]
            ap[pa] = wet + va * 0.5
            pa = pa + 1
            if pa > la then pa = 1 end

            s = s + (va - wet * 0.5) * revAmt
        end

        local out = x * dry + s * mix

        if out > 32767 then
            out = 32767
        elseif out < -32767 then
            out = -32767
        end

        samples[i] = out
    end

    st.ps1, st.ps2, st.ps3 = ps1, ps2, ps3
    st.ringPhase, st.holdLeft, st.holdValue = ringPhase, holdLeft, holdValue
    st.lx1, st.lx2, st.ly1, st.ly2 = lx1, lx2, ly1, ly2
    st.hx1, st.hx2, st.hy1, st.hy2 = hx1, hx2, hy1, hy2
    st.sx1, st.sx2, st.sy1, st.sy2 = sx1, sx2, sy1, sy2
    st.p1, st.p2, st.p3, st.pa = p1, p2, p3, pa
    st.d1, st.d2, st.d3 = d1, d2, d3
end

-- Frueherer Filter: Bandpass -> Uebersteuerung -> Bitcrush -> Rauschen -> Hall -> Mischung
local function ProcessClassic(st, p, samples, count)
    local lp1, lp2, ni = st.lp1, st.lp2, st.ni
    local aLow, aHigh = p.aLow, p.aHigh
    local gain, clip = p.gain, p.clip
    local crushStep, invCrush = p.crushStep, p.invCrush
    local useCrush = crushStep > 1
    local noiseTbl = p.noiseTbl
    local useNoise = p.noise > 0

    local mix, dry = p.mixWet, p.mixDry

    local revAmt, decay, damp = p.reverb, p.decay, p.damp
    local c1, c2, c3, ap = st.c1, st.c2, st.c3, st.ap
    local p1, p2, p3, pa = st.p1, st.p2, st.p3, st.pa
    local d1, d2, d3 = st.d1, st.d2, st.d3
    local l1, l2, l3, la = COMB_LEN[1], COMB_LEN[2], COMB_LEN[3], ALLPASS_LEN

    for i = 1, count do
        local x = samples[i]

        -- Hochpass: Tiefanteil ermitteln und abziehen
        lp1 = lp1 + aLow * (x - lp1)
        local s = x - lp1

        -- Tiefpass: Hoehen weg -> schmales Funkband
        lp2 = lp2 + aHigh * (s - lp2)
        s = lp2

        -- Uebersteuern und hart begrenzen
        s = s * gain
        if s > clip then
            s = clip
        elseif s < -clip then
            s = -clip
        end

        -- Bitcrush
        if useCrush then
            s = floor(s * invCrush + 0.5) * crushStep
        end

        -- Rauschteppich aus der Tabelle (billiger als math.random pro Sample)
        if useNoise then
            ni = ni + 1
            if ni > NOISE_COUNT then ni = 1 end
            s = s + noiseTbl[ni]
        end

        -- Hall: Kammfilter mit gedaempfter Rueckkopplung, danach Allpass zum
        -- Aufloesen des Flatterechos
        if revAmt > 0 then
            local v1 = c1[p1]
            d1 = d1 + damp * (v1 - d1)
            c1[p1] = s + d1 * decay
            p1 = p1 + 1
            if p1 > l1 then p1 = 1 end

            local v2 = c2[p2]
            d2 = d2 + damp * (v2 - d2)
            c2[p2] = s + d2 * decay
            p2 = p2 + 1
            if p2 > l2 then p2 = 1 end

            local v3 = c3[p3]
            d3 = d3 + damp * (v3 - d3)
            c3[p3] = s + d3 * decay
            p3 = p3 + 1
            if p3 > l3 then p3 = 1 end

            local wet = (v1 + v2 + v3) * 0.3333333

            local va = ap[pa]
            ap[pa] = wet + va * 0.5
            pa = pa + 1
            if pa > la then pa = 1 end

            s = s + (va - wet * 0.5) * revAmt
        end

        -- Originalstimme beimischen
        samples[i] = x * dry + s * mix
    end

    st.lp1, st.lp2, st.ni = lp1, lp2, ni
    st.p1, st.p2, st.p3, st.pa = p1, p2, p3, pa
    st.d1, st.d2, st.d3 = d1, d2, d3
end

hook.Add("ApplyVoiceEffect", "PD.VoiceFX", function(userId, samples, count)
    local st = states[userId]
    if not st then return end

    local p = built[st.preset]
    if not p then return end

    if p.acre then
        ProcessAcre(st, p, samples, count)
    else
        ProcessClassic(st, p, samples, count)
    end

    return samples
end)

-- Steuerung ------------------------------------------------------------------

-- Filter fuer einen Spieler mit einem Preset einschalten, auf ein anderes
-- Preset umstellen (Filterzustand bleibt, kein Knacken) oder mit nil aus.
function PD.VoiceFX.SetPreset(ply, preset)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local id = ply:UserID()
    local st = states[id]

    if preset then
        if not st then
            states[id] = {
                preset = preset,

                -- frueherer Filter
                lp1 = 0, lp2 = 0, ni = random(NOISE_COUNT),

                -- ACRE-Kette
                ps1 = 0.5, ps2 = 0.5, ps3 = 0.5,
                ringPhase = 0, holdLeft = 0, holdValue = 0,
                lx1 = 0, lx2 = 0, ly1 = 0, ly2 = 0,
                hx1 = 0, hx2 = 0, hy1 = 0, hy2 = 0,
                sx1 = 0, sx2 = 0, sy1 = 0, sy2 = 0,

                -- Hall
                c1 = NewBuffer(COMB_LEN[1]), p1 = 1, d1 = 0,
                c2 = NewBuffer(COMB_LEN[2]), p2 = 1, d2 = 0,
                c3 = NewBuffer(COMB_LEN[3]), p3 = 1, d3 = 0,
                ap = NewBuffer(ALLPASS_LEN), pa = 1,
            }

            if hasEightbit then eightbit.EnableEffects(id, 1) end
        else
            st.preset = preset
        end
    elseif st then
        states[id] = nil
        if hasEightbit then eightbit.EnableEffects(id, 0) end
    end
end

-- In welcher Situation spricht der Spieler? "intercom", "funk" oder nil.
function PD.VoiceFX.GetSituation(ply)
    if not IsValid(ply) then return nil end
    if ply.UsingIntercom then return "intercom" end
    if PD.Comlink and PD.Comlink.IsTransmitting and PD.Comlink.IsTransmitting(ply) then return "funk" end

    return nil
end

-- Spricht der Spieler gerade ueber Funk oder Intercom?
function PD.VoiceFX.ShouldUseRadio(ply)
    return PD.VoiceFX.GetSituation(ply) ~= nil
end

-- Welches Preset gilt fuer den Spieler gerade? nil = kein Filter.
function PD.VoiceFX.PresetFor(ply)
    local situation = PD.VoiceFX.GetSituation(ply)
    if not situation then return nil end

    local name = (PD.VoiceFX.Assign or {})[situation]
    local override = PD.VoiceFX.Situation

    if override and (situation == "funk" or PD.VoiceFX.SituationAffectsIntercom) then
        name = override
    end

    if not name then return nil end

    if not built[name] then
        if not warnedMissing[name] then
            warnedMissing[name] = true
            ErrorNoHalt("[PD.VoiceFX] Preset '" .. tostring(name) .. "' fuer " .. situation .. " existiert nicht (sv_voice_config.lua) - ohne Filter.\n")
        end

        return nil
    end

    return name
end

-- Kompatibel zu bisherigen Aufrufen.
function PD.VoiceFX.SetEnabled(ply, enabled)
    PD.VoiceFX.SetPreset(ply, enabled and PD.VoiceFX.PresetFor(ply) or nil)
end

-- Zustand neu bewerten - beim Kanalwechsel und beim Ein-/Ausschalten des Intercoms.
--
-- Der Effekt haengt bewusst am Funk-Status und nicht am Sprechen: PlayerStartVoice
-- und PlayerEndVoice feuern serverseitig nicht zuverlaessig synchron zum ersten bzw.
-- letzten Sprachpaket. Wurde der Effekt erst dort eingeschaltet, ging der Anfang einer
-- Uebertragung ungefiltert durch oder blieb ganz unbearbeitet. Solange jemand auf Funk
-- ist, bleibt der Effekt aktiv - der Hook laeuft ohnehin nur, wenn Pakete kommen.
--
-- Die NW2-Werte werden hier ebenfalls gesetzt, damit die Clients den Funkstatus
-- kennen, bevor das erste Sprachpaket ankommt. Die Situation braucht
-- cl_voice_signal.lua: Empfang nach Entfernung gilt nur fuer Funk.
function PD.VoiceFX.Refresh(ply)
    if not IsValid(ply) then return end

    ply:SetNW2Bool("PD.VoiceFX.Radio", PD.VoiceFX.ShouldUseRadio(ply))
    ply:SetNW2String("PD.VoiceFX.Situation", PD.VoiceFX.GetSituation(ply) or "")
    PD.VoiceFX.SetPreset(ply, PD.VoiceFX.PresetFor(ply))
end

-- Presets aus sv_voice_config.lua neu berechnen und laufende Sprecher umstellen.
function PD.VoiceFX.Rebuild()
    local fresh = {}

    for name, raw in pairs(PD.VoiceFX.Presets or {}) do
        if istable(raw) then
            fresh[name] = BuildPreset(raw)
        end
    end

    built = fresh
    warnedMissing = {}

    for _, ply in ipairs(player.GetAll()) do
        PD.VoiceFX.Refresh(ply)
    end
end

PD.VoiceFX.Rebuild()

-- Sicherheitsnetz, falls ein Refresh verpasst wurde
hook.Add("PlayerStartVoice", "PD.VoiceFX", function(ply)
    PD.VoiceFX.SetPreset(ply, PD.VoiceFX.PresetFor(ply))
end)

hook.Add("PlayerDisconnected", "PD.VoiceFX", function(ply)
    if not IsValid(ply) then return end
    states[ply:UserID()] = nil
end)

-- Regelmaessiger Abgleich: haelt Modulzustand und Funkstatus zusammen, auch wenn ein
-- Ereignis verloren geht (Spieler stirbt am Intercom, Kanal wird ohne Netmessage frei).
timer.Create("PD.VoiceFX.Reconcile", 5, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        local st = states[ply:UserID()]
        local current = st and st.preset or nil

        if PD.VoiceFX.PresetFor(ply) ~= current
            or PD.VoiceFX.ShouldUseRadio(ply) ~= ply:GetNW2Bool("PD.VoiceFX.Radio")
            or (PD.VoiceFX.GetSituation(ply) or "") ~= ply:GetNW2String("PD.VoiceFX.Situation", "") then
            PD.VoiceFX.Refresh(ply)
        end
    end
end)

-- Befehle ----------------------------------------------------------------------
local function Sayer(ply)
    return function(msg)
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
    end
end

local function PresetList()
    local names = {}

    for name in SortedPairs(built) do
        names[#names + 1] = name
    end

    return table.concat(names, ", ")
end

-- Serverweite Situation: pd_funk_situation <preset> | aus
concommand.Add("pd_funk_situation", function(ply, _, args)
    if IsValid(ply) and not ply:IsAdmin() then return end

    local say = Sayer(ply)
    local name = args[1]

    if not name then
        say("[Funk] Situation: " .. (PD.VoiceFX.Situation or "aus"))
        say("[Funk] Presets: " .. PresetList())
        say("[Funk] Nutzung: pd_funk_situation <preset> | aus")
        return
    end

    local wanted = string.lower(name)
    local match

    for key in pairs(built) do
        if string.lower(key) == wanted then match = key end
    end

    if wanted == "aus" or wanted == "off" then
        PD.VoiceFX.Situation = nil
    elseif match then
        PD.VoiceFX.Situation = match
    else
        say("[Funk] Unbekanntes Preset '" .. name .. "'. Vorhanden: " .. PresetList())
        return
    end

    for _, target in ipairs(player.GetAll()) do
        PD.VoiceFX.Refresh(target)
    end

    local state = PD.VoiceFX.Situation or "aus"
    local who = IsValid(ply) and ply:Nick() or "Konsole"

    say("[Funk] Situation: " .. state)

    if IsValid(ply) and PD.Notify then
        PD.Notify("Funk-Situation: " .. state, Color(255, 170, 60), false, ply)
    end

    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("[Funk]", who .. " hat die Funk-Situation auf '" .. state .. "' gesetzt.", Color(255, 170, 60))
    end
end)

concommand.Add("pd_voicefx_status", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    local say = Sayer(ply)

    say("[PD.VoiceFX] Modul geladen: " .. tostring(hasEightbit))
    say("[PD.VoiceFX] Erwartete Datei: lua/bin/" .. BIN_NAME .. " (vorhanden: " .. tostring(file.Exists("bin/" .. BIN_NAME, "LUA")) .. ")")
    say("[PD.VoiceFX] Server: " .. jit.os .. " " .. jit.arch)
    if not hasEightbit then
        say("[PD.VoiceFX] require-Fehler: " .. tostring(loadErr))
    end

    local found = false
    for _, name in ipairs({ "gmsv_eightbit_win32.dll", "gmsv_eightbit_win64.dll", "gmsv_eightbit_linux.dll", "gmsv_eightbit_linux64.dll" }) do
        if file.Exists("bin/" .. name, "LUA") then
            say("[PD.VoiceFX] Gefunden in lua/bin/: " .. name)
            found = true
        end
    end
    if not found then
        say("[PD.VoiceFX] In lua/bin/ liegt keine gmsv_eightbit_*.dll")
    end

    say("[PD.VoiceFX] Signalbausteine (sh_voice_dsp.lua): " .. tostring(PD.VoiceFX.DSP ~= nil))

    for situation, name in SortedPairs(PD.VoiceFX.Assign or {}) do
        say("[PD.VoiceFX] Zuweisung " .. situation .. " -> " .. tostring(name)
            .. (built[name] and "" or "  (FEHLT!)"))
    end

    say("[PD.VoiceFX] Situation: " .. (PD.VoiceFX.Situation or "aus")
        .. " (gilt fuer Intercom: " .. tostring(PD.VoiceFX.SituationAffectsIntercom == true) .. ")")

    for name, raw in SortedPairs(PD.VoiceFX.Presets or {}) do
        if istable(raw) then
            local parts = {}

            for key, value in SortedPairs(raw) do
                parts[#parts + 1] = key .. "=" .. tostring(value)
            end

            say("[PD.VoiceFX] Preset " .. name .. (built[name] and "" or " (nicht gebaut!)") .. ": " .. table.concat(parts, " "))
        end
    end

    for id, st in pairs(states) do
        local p = Player(id)
        say("[PD.VoiceFX] Aktiv: " .. (IsValid(p) and p:Nick() or ("UserID " .. id)) .. " mit " .. tostring(st.preset))
    end
end)

-- Klang im laufenden Betrieb ausprobieren: pd_voicefx_set <preset> <regler> <wert>
-- Gilt bis zum naechsten Lua-Refresh von sv_voice_config.lua - dauerhaft dort eintragen.
concommand.Add("pd_voicefx_set", function(ply, _, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    local say = Sayer(ply)
    local preset, key, value = args[1], args[2], tonumber(args[3])
    local raw = preset and (PD.VoiceFX.Presets or {})[preset]
    local isAcre = istable(raw) and raw.type == "acre"
    local allowed = isAcre and PD.VoiceFX.AcreDefaults or PD.VoiceFX.Defaults

    if not istable(raw) or not key or allowed[key] == nil or not value then
        say("[PD.VoiceFX] Nutzung: pd_voicefx_set <preset> <regler> <wert>")
        say("[PD.VoiceFX] Presets: " .. PresetList())

        local acreKeys, classicKeys = {}, {}
        for k in SortedPairs(PD.VoiceFX.AcreDefaults) do acreKeys[#acreKeys + 1] = k end
        for k in SortedPairs(PD.VoiceFX.Defaults) do classicKeys[#classicKeys + 1] = k end
        say("[PD.VoiceFX] Regler ACRE-Presets: " .. table.concat(acreKeys, ", ") .. " (loudspeaker: 1/0)")
        say("[PD.VoiceFX] Regler andere Presets: " .. table.concat(classicKeys, ", "))
        return
    end

    if isbool(allowed[key]) then
        raw[key] = value == 1
    else
        raw[key] = value
    end

    PD.VoiceFX.Rebuild()

    say("[PD.VoiceFX] " .. preset .. "." .. key .. " = " .. tostring(raw[key]))
end)
