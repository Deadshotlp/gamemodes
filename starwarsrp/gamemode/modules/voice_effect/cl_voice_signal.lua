--[[
    Funk-Empfang pro Zuhoerer. Einstellungen in sh_voice_signal.lua.

    Der Funkfilter laeuft auf dem Server, einmal pro Sprecher - alle hoeren
    dieselbe Fassung. ACRE2 rechnet dagegen fuer jeden Zuhoerer einzeln, wie
    gut er den Sprecher empfaengt. GMod bietet clientseitig keinen Zugriff auf
    eingehende Sprache, deshalb die Annaeherung:

        - Stimme leiser (Player:SetVoiceVolumeScale)
        - zusaetzliches Funkrauschen, lokal abgespielt, solange jemand funkt

    Beides haengt an der Entfernung zum Sprecher. Das Rauschen wird einmal
    erzeugt - rosa Rauschen im selben Funkband wie der Serverfilter.

    Wird vor den sh-Dateien geladen: PD.VoiceFX-Funktionen erst zur Laufzeit.
]]

PD.VoiceFX = PD.VoiceFX or {}

local SOUND_NAME = "pd_voicefx_radionoise"
local SOUND_RATE = 22050
local SOUND_LENGTH = 3

local talkers = {}      -- [Spieler] = true, solange Sprache von ihm ankommt
local touched = {}      -- [Spieler] = true, wenn seine Lautstaerke veraendert wurde
local quality = {}      -- [Spieler] = letzte Qualitaet (fuer die Diagnose)
local noisePatch
local soundReady = false
local noiseLevel = 0

local function generateNoise()
    if soundReady then return true end

    local DSP = PD.VoiceFX.DSP

    if not DSP or not sound.Generate then return false end

    local poles = DSP.PinkPoles(SOUND_RATE)
    local A1, A2, A3 = DSP.PinkA[1], DSP.PinkA[2], DSP.PinkA[3]
    local P1, P2, P3 = poles[1], poles[2], poles[3]
    local offset = DSP.PinkOffset
    local lp = DSP.LowPass(SOUND_RATE, DSP.LowPassFreq, DSP.LowPassQ)
    local hp = DSP.HighPass(SOUND_RATE, DSP.HighPassFreq, DSP.HighPassQ)
    local random = math.random

    local s1, s2, s3 = 0.5, 0.5, 0.5
    local lx1, lx2, ly1, ly2 = 0, 0, 0, 0
    local hx1, hx2, hy1, hy2 = 0, 0, 0, 0

    sound.Generate(SOUND_NAME, SOUND_RATE, SOUND_LENGTH, function()
        local r = random()
        s1 = P1 * (s1 - r) + r
        r = random()
        s2 = P2 * (s2 - r) + r
        r = random()
        s3 = P3 * (s3 - r) + r

        local x = (A1 * s1 + A2 * s2 + A3 * s3) * 2 - offset

        -- Gleiches Band wie der Funkfilter: Tiefpass 4000 Hz, Hochpass 750 Hz
        local y = lp[1] * x + lp[2] * lx1 + lp[3] * lx2 - lp[4] * ly1 - lp[5] * ly2
        lx2, lx1, ly2, ly1 = lx1, x, ly1, y

        local z = hp[1] * y + hp[2] * hx1 + hp[3] * hx2 - hp[4] * hy1 - hp[5] * hy2
        hx2, hx1, hy2, hy1 = hx1, y, hy1, z

        return math.Clamp(z * 2, -1, 1)
    end, 0)

    soundReady = true

    return true
end

local function setNoise(level)
    noiseLevel = level

    if level <= 0.001 then
        if noisePatch and noisePatch:IsPlaying() then
            noisePatch:Stop()
        end

        return
    end

    local ply = LocalPlayer()

    if not IsValid(ply) or not generateNoise() then return end

    if not noisePatch then
        noisePatch = CreateSound(ply, SOUND_NAME)
        noisePatch:SetSoundLevel(0)
    end

    -- Laeuft der erzeugte Sound ohne Schleife aus, einfach neu starten.
    if noisePatch:IsPlaying() then
        noisePatch:ChangeVolume(level, 0.1)
    else
        noisePatch:PlayEx(level, 100)
    end
end

local function listenerPos()
    local ply = LocalPlayer()

    if not ply:Alive() then
        local ragdoll = ply:GetNW2Entity("PD.DM.Ragdoll")

        if IsValid(ragdoll) then return ragdoll:GetPos() end
    end

    return ply:GetPos()
end

local function resetVolume(ply)
    if touched[ply] and IsValid(ply) then
        ply:SetVoiceVolumeScale(1)
    end

    touched[ply] = nil
    quality[ply] = nil
end

hook.Add("PlayerStartVoice", "PD.VoiceFX.Signal", function(ply)
    if IsValid(ply) and ply ~= LocalPlayer() then
        talkers[ply] = true
    end
end)

hook.Add("PlayerEndVoice", "PD.VoiceFX.Signal", function(ply)
    talkers[ply] = nil
    resetVolume(ply)
end)

local nextUpdate = 0

hook.Add("Think", "PD.VoiceFX.Signal", function()
    local now = RealTime()

    if now < nextUpdate then return end

    nextUpdate = now + 0.1

    local me = LocalPlayer()
    local cfg = PD.VoiceFX.Signal
    local qualityOf = PD.VoiceFX.SignalQuality

    if not IsValid(me) or not istable(cfg) or not cfg.Enabled or not qualityOf then
        for ply in pairs(touched) do resetVolume(ply) end
        setNoise(0)
        return
    end

    local minQuality = math.Clamp(tonumber(cfg.MinQuality) or 0.2, 0, 0.99)
    local worst = 1
    local active = false
    local pos = listenerPos()

    for ply in pairs(talkers) do
        if not IsValid(ply) then
            talkers[ply] = nil
            touched[ply] = nil
            quality[ply] = nil
        elseif ply:GetNW2String("PD.VoiceFX.Situation", "") == "funk" then
            local q = qualityOf(pos:Distance(ply:GetPos()))
            local t = math.Clamp((q - minQuality) / (1 - minQuality), 0, 1)

            ply:SetVoiceVolumeScale(Lerp(t, tonumber(cfg.VolumeAtWorst) or 0.6, 1))
            touched[ply] = true
            quality[ply] = q

            worst = math.min(worst, q)
            active = true
        else
            -- Spricht nicht (mehr) ueber Funk, etwa am Intercom oder in der Naehe.
            resetVolume(ply)
        end
    end

    local level = 0

    if active then
        level = (tonumber(cfg.NoiseVolume) or 0.35) * math.Clamp((1 - worst) / (1 - minQuality), 0, 1)
    end

    setNoise(level)
end)

concommand.Add("pd_voicefx_signal", function()
    local cfg = PD.VoiceFX.Signal or {}

    print("[Funk-Empfang] aktiv: " .. tostring(cfg.Enabled)
        .. ", voll bis " .. tostring(cfg.FullRange) .. " m, schlechtester Empfang ab " .. tostring(cfg.ZeroRange) .. " m")
    print("[Funk-Empfang] Rauschen erzeugt: " .. tostring(soundReady) .. ", Lautstaerke jetzt " .. math.Round(noiseLevel, 3))

    local any = false

    for ply in pairs(talkers) do
        if IsValid(ply) then
            any = true

            local meters = math.Round(listenerPos():Distance(ply:GetPos()) / 39.37)

            print("  " .. ply:Nick() .. ": " .. ply:GetNW2String("PD.VoiceFX.Situation", "-")
                .. ", " .. meters .. " m, Qualitaet " .. (quality[ply] and math.Round(quality[ply], 2) or "-")
                .. ", Lautstaerke " .. math.Round(ply:GetVoiceVolumeScale(), 2))
        end
    end

    if not any then
        print("  Gerade spricht niemand.")
    end
end)
