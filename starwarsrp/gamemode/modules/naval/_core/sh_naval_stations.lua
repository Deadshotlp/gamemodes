--[[
    Naval - Stationen (Konsolen auf der Map).

    Ein Entity (pd_naval_console) fuer alle Stationen; welche es ist, steht
    in seiner Netzwerkvariable. Neue Stationen (Stufe 2: Schilde, Waffen ...)
    brauchen so keinen weiteren Server-Neustart.

    Bedienen darf jeder (Entscheidung des Users); Admins koennen einzelne
    Konsolen sperren.
]]

PD.Naval = PD.Naval or {}

PD.Naval.Stations = {
    helm = {
        name = "Steuer",
        model = "models/lordtrilobite/starwars/isd/imp_console_medium03.mdl",
        desc = "Schub, Drehung, Manövrierdüsen",
    },
    navcomputer = {
        name = "Navigationscomputer",
        model = "models/lordtrilobite/starwars/isd/imp_console_large01.mdl",
        desc = "Ziel wählen, Kurs berechnen",
    },
    hyperdrive = {
        name = "Hyperantrieb",
        model = "models/lordtrilobite/starwars/isd/imp_console_medium03.mdl",
        desc = "Ausrichten, Springen, Abbrechen",
    },
    shiplog = {
        name = "Logbuch",
        model = "models/lordtrilobite/starwars/isd/imp_console_medium03.mdl",
        desc = "Einträge lesen und schreiben",
    },
}

-- Taktik-Hologramm: Schalter loesen direkt eine Aktion aus (kein Fenster),
-- der Projektor markiert nur den Ort, an dem das Hologramm erscheint.
PD.Naval.Stations.holo_power = {
    name = "Taktik-Hologramm",
    model = "models/kingpommes/starwars/misc/misc_panel_1.mdl",
    desc = "Ein / Aus",
    action = "holo_toggle",
}
PD.Naval.Stations.holo_zoom_in = {
    name = "Hologramm: näher",
    model = "models/kingpommes/starwars/misc/misc_panel_2.mdl",
    desc = "Hineinzoomen",
    action = "holo_zoom_in",
}
PD.Naval.Stations.holo_zoom_out = {
    name = "Hologramm: weiter",
    model = "models/kingpommes/starwars/misc/misc_panel_2.mdl",
    desc = "Herauszoomen",
    action = "holo_zoom_out",
}
PD.Naval.Stations.holo_projector = {
    name = "Hologramm-Projektor",
    model = "models/hunter/plates/plate025x025.mdl",
    desc = "Ort des Taktik-Hologramms",
    noUse = true,
    marker = true,   -- unsichtbar, nicht fest; nur fuer Admins als Markierung
}

-- Zoomstufen des Hologramms: Radius in Metern
PD.Naval.HoloRanges = {5000, 10000, 25000, 50000, 100000, 250000, 500000, 1e6, 2.5e6, 1e7, 5e7, 2e8, 1e9}
PD.Naval.HoloDefaultZoom = 4

PD.Naval.StationUseRange = 160
