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

-- Kampfstationen (Stufe 2)
PD.Naval.Stations.weapons = {
    name = "Waffenleitstand",
    model = "models/lordtrilobite/starwars/isd/imp_console_large01.mdl",
    desc = "Ziel, Batterien, Feuer",
}
PD.Naval.Stations.shields = {
    name = "Schildkontrolle",
    model = "models/lordtrilobite/starwars/isd/imp_console_medium03.mdl",
    desc = "Zonen, Strahlen/Partikel, heben/senken",
}
PD.Naval.Stations.engineering = {
    name = "Maschinenraum",
    model = "models/lordtrilobite/starwars/isd/imp_console_large01.mdl",
    desc = "Reaktor, Energieverteilung, Schäden",
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
PD.Naval.Stations.holo_mode = {
    name = "Hologramm: Taktik / Galaxie",
    model = "models/kingpommes/starwars/misc/misc_panel_1.mdl",
    desc = "Ansicht umschalten",
    action = "holo_mode",
}
PD.Naval.Stations.holo_tilt = {
    name = "Hologramm: liegend / Wand",
    model = "models/kingpommes/starwars/misc/misc_panel_2.mdl",
    desc = "Ausrichtung umschalten",
    action = "holo_tilt",
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

-- Galaxie-Ansicht des Hologramms: Umkreis in Parsec
PD.Naval.HoloGalaxyRanges = {100, 200, 400, 800, 1500, 3000, 6000, 12000, 25000}
PD.Naval.HoloGalaxyDefaultZoom = 4

PD.Naval.StationUseRange = 160

-- Stufe 2b: Schadenskontrolle, Sensoren, Alarmstufe
PD.Naval.Stations.damagecontrol = {
    name = "Schadenskontrolle",
    model = "models/lordtrilobite/starwars/isd/imp_console_large01.mdl",
    desc = "Schäden, Brandherde, Reparaturtrupps",
}
PD.Naval.Stations.sensors = {
    name = "Sensoren",
    model = "models/lordtrilobite/starwars/isd/imp_console_medium03.mdl",
    desc = "Kontakte scannen und identifizieren",
}
PD.Naval.Stations.alert = {
    name = "Alarmstufe",
    model = "models/lordtrilobite/starwars/isd/imp_console_medium03.mdl",
    desc = "Normal, Gelb, Rot",
}

-- Schadenspunkt: Ort, an dem bei Treffern Funken, Rauch oder Feuer entstehen.
-- Unsichtbar wie der Projektor; welches Subsystem dort sitzt, legt der Admin
-- im Admin-Tab fest (Konsolen-Daten "sub").
PD.Naval.Stations.damage_point = {
    name = "Schadenspunkt",
    model = "models/hunter/plates/plate025x025.mdl",
    desc = "Ort für Schäden an Bord",
    noUse = true,
    marker = true,
}

PD.Naval.AlertNames = {[0] = "Normal", [1] = "Alarmstufe Gelb", [2] = "Alarmstufe Rot"}

-- Schadensarten an Bord (Schweregrad = Reparaturaufwand)
PD.Naval.IncidentKinds = {
    sparks = {name = "Kurzschluss", severity = 1},
    smoke = {name = "Rauchentwicklung", severity = 2},
    fire = {name = "Brand", severity = 3},
}

-- Stufe 3: Kommunikation und Flottenfuehrung
PD.Naval.Stations.comms = {
    name = "Kommunikation",
    model = "models/lordtrilobite/starwars/isd/imp_console_medium03.mdl",
    desc = "Rufen, Kapitulation, Notruf",
}
PD.Naval.Stations.fleetcmd = {
    name = "Flottenführung",
    model = "models/lordtrilobite/starwars/isd/imp_console_large01.mdl",
    desc = "Formation und Befehle an die eigene Flotte",
}

-- Formationen (Plaetze relativ zum Flaggschiff: x vorn, y links, z oben)
PD.Naval.Formations = {
    {id = "line", name = "Linie"},
    {id = "column", name = "Kolonne"},
    {id = "wedge", name = "Keil"},
    {id = "wall", name = "Wand"},
    {id = "sphere", name = "Kugel"},
}

-- Flottenmodus: formation = Formation halten und auf das Ziel des
-- Flaggschiffs feuern, engage = ausschwaermen und angreifen, hold = Position halten
PD.Naval.FleetModes = {
    {id = "formation", name = "Formation halten"},
    {id = "engage", name = "Angreifen"},
    {id = "hold", name = "Position halten"},
}
