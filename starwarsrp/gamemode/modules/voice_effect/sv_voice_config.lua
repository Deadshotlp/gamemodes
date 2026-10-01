--[[
    Funk-Presets fuer den Sprachfilter (sv_voice_effect.lua).

    Hier werden Klaenge angelegt und den Situationen zugewiesen. Nach dem
    Speichern wirkt die Aenderung per Lua-Refresh sofort, auch bei Spielern,
    die gerade funken.

    Zwei Arten von Presets:

    type = "acre"  Klang wie ACRE2 (Arma 3). Wird ueber die Signalqualitaet
                   gesteuert statt ueber Einzelregler:
        quality        1 = perfekter Empfang (leichtes Rauschen, knirschig),
                       0.5 = deutlich verrauscht, 0.1 = kaum verstaendlich,
                       0 = stumm
        loudspeaker    true = Lautsprecher (weniger Bass), etwa fuers Intercom
        noiseScale     Rauschen im Verhaeltnis zu ACRE, 1 = wie ACRE,
                       0.5 = halb so laut, 0 = kein Rauschen
        reverb, reverbDecay, reverbDamping, mix   wie unten

    ohne type      Der fruehere eigene Filter mit Einzelreglern. Was fehlt,
                   nimmt den neutralen Wert, also "kein Effekt":
        lowCut, highCut  Hz, Sprachband
        gain             Verstaerkung vor dem Begrenzen, 1 = unveraendert
        clip             Begrenzung, 32767 = aus
        bits             Bitcrush, 16 = aus
        noise            Rauschen, 0 = aus
        reverb           Hallanteil, 0 = aus
        reverbDecay      Nachhall 0 bis 0.9
        reverbDamping    0 = heller Hall, 1 = dumpfer Hall
        mix              1 = nur Effekt, 0 = nur Originalstimme

    Wie weit Funk reicht und wie schnell der Empfang mit der Entfernung
    schlechter wird, steht in sh_voice_signal.lua.

    Befehle (Serverkonsole oder Spielerkonsole):
        pd_funk_situation                zeigt aktuelle Situation und Presets
        pd_funk_situation <preset>       Admins: aller Funk nutzt dieses Preset
        pd_funk_situation aus            zurueck zur Zuweisung unten
        pd_voicefx_set <preset> <regler> <wert>
                                         Superadmins: ausprobieren, gilt bis
                                         zum naechsten Refresh dieser Datei
        pd_voicefx_status                Superadmins: Zustand und Werte
]]

PD.VoiceFX = PD.VoiceFX or {}

PD.VoiceFX.Presets = {
    -- Normaler Funk wie bei ACRE mit gutem Empfang. Die Verschlechterung mit
    -- der Entfernung kommt pro Zuhoerer dazu (sh_voice_signal.lua).
    funk = {
        type = "acre",
        quality = 1
    },

    -- Durchsage ueber das Intercom: ACRE-Lautsprecher mit Raumhall.
    intercom = {
        type = "acre",
        quality = 1,
        loudspeaker = true,
        reverb = 0.7,
        reverbDecay = 0.9,
        reverbDamping = 0.2
    },

    -- Schwaches Signal / grosse Entfernung.
    fernfunk = {
        type = "acre",
        quality = 0.45
    },

    -- Stoersender: kaum noch verstaendlich.
    stoersender = {
        type = "acre",
        quality = 0.12
    },

    -- Bisheriger Funkklang vor der Umstellung auf ACRE.
    klassisch = {
        lowCut = 250,
        highCut = 4500,
        gain = 1.2,
        clip = 32767,
        bits = 16,
        noise = 50,
        reverb = 0,
        mix = 0.35
    },

    -- Bisheriger Intercom-Klang vor der Umstellung auf ACRE.
    intercom_klassisch = {
        lowCut = 400,
        highCut = 5000,
        gain = 2,
        clip = 22000,
        bits = 14,
        noise = 10,
        reverb = 1,
        reverbDecay = 0.9,
        reverbDamping = 0.2,
        mix = 0.9
    }
}

-- Welches Preset in welcher Situation gilt.
PD.VoiceFX.Assign = {
    funk = "funk",
    intercom = "intercom"
}

-- Soll eine per pd_funk_situation gesetzte Situation auch das Intercom
-- ueberschreiben? false = nur Comlink-Funk.
PD.VoiceFX.SituationAffectsIntercom = false

-- Beim Lua-Refresh dieser Datei die neuen Werte uebernehmen. Beim Serverstart
-- existiert die Funktion noch nicht - dann baut sv_voice_effect.lua selbst.
if PD.VoiceFX.Rebuild then
    PD.VoiceFX.Rebuild()
end
