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
        ui3d = true, -- Bedienung per 3D2D auf der Konsole (cl_naval_console3d.lua), kein Menue
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

-- Taktik-Hologramm: eine Steuerkonsole (Fenster: an/aus, Taktik/Galaxie,
-- Zoom, Drehen in 45-Grad-Schritten, Ebenen); der Projektor markiert nur den
-- Ort, an dem das Hologramm erscheint.
PD.Naval.Stations.holo_control = {
    name = "Hologramm-Steuerung",
    model = "models/lordtrilobite/starwars/isd/imp_console_medium03.mdl",
    desc = "Ansicht, Zoom, Drehen, Ebenen",
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

-- Ebenen des Hologramms (Bitmaske in GetGlobalInt("PD.Naval.HoloLayers"))
PD.Naval.HoloLayers = {
    {id = "territory", bit = 1, name = "Gebiete und Frontlinien"},
    {id = "routes", bit = 2, name = "Hyperraumrouten"},
    {id = "bodies", bit = 4, name = "Himmelskörper"},
    {id = "course", bit = 8, name = "Kurs"},
    {id = "shields", bit = 16, name = "Schildzonen"},
    {id = "labels", bit = 32, name = "Beschriftungen"},
}
PD.Naval.HoloLayersDefault = 63

function PD.Naval.HoloLayer(id)
    local mask = GetGlobalInt("PD.Naval.HoloLayers", PD.Naval.HoloLayersDefault)
    for _, l in ipairs(PD.Naval.HoloLayers) do
        if l.id == id then return bit.band(mask, l.bit) ~= 0 end
    end
    return true
end

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

-- Stufe 4e: Traktorstrahl und Enterkommando
PD.Naval.Stations.tractor = {
    name = "Traktorstrahl & Entern",
    model = "models/lordtrilobite/starwars/isd/imp_console_large01.mdl",
    desc = "Schiffe greifen, heranziehen und entern",
}

-- Stufe 4e: Nachschub. Leitstand plus zwei Ortsmarker (fuer alle mit
-- Hinweis am Boden sichtbar, siehe cl_naval_supply.lua)
PD.Naval.Stations.logistics = {
    name = "Logistik-Leitstand",
    model = "models/lordtrilobite/starwars/isd/imp_console_medium03.mdl",
    desc = "Nachschub anfordern, Bestand",
}
PD.Naval.Stations.supply_drop = {
    name = "Anlieferung",
    model = "models/hunter/plates/plate1x1.mdl",
    desc = "Hier erscheinen angeforderte Nachschubkisten",
    noUse = true,
    marker = true,
}
PD.Naval.Stations.supply_intake = {
    name = "Nachschub-Annahme",
    model = "models/hunter/plates/plate1x1.mdl",
    desc = "Hier abgestellte Nachschubkisten werden verbucht",
    noUse = true,
    marker = true,
}

-- Stufe 4f: Umstationieren auf Planeten-Maps (auch auf der Planeten-Map fuer
-- den Rueckflug, daher offline = ohne laufende Simulation bedienbar)
PD.Naval.Stations.relocation = {
    name = "Umstationierung",
    model = "models/lordtrilobite/starwars/isd/imp_console_medium03.mdl",
    desc = "Landezone auf dem Planeten im Orbit wählen, Rückflug zum Schiff",
    offline = true,
}

-- Demo-Konsolen fuer die beiden Konsolenmodelle: Admins legen dort Flaechen
-- fest, die spaeter Knoepfe und Anzeigen tragen (cl_naval_layouts.lua)
PD.Naval.Stations.demo_large = {
    name = "Demo: große Konsole",
    model = "models/lordtrilobite/starwars/isd/imp_console_large01.mdl",
    desc = "Flächen für Knöpfe und Anzeigen festlegen (Admins)",
    offline = true,
}
PD.Naval.Stations.demo_medium = {
    name = "Demo: mittlere Konsole",
    model = "models/lordtrilobite/starwars/isd/imp_console_medium03.mdl",
    desc = "Flächen für Knöpfe und Anzeigen festlegen (Admins)",
    offline = true,
}

-- 3D2D-Bedienung direkt auf der Konsole (cl_naval_console3d*.lua) statt Menue.
-- Die alten Menues bleiben im Code; zum Zurueckschalten eine Station aus
-- dieser Liste nehmen.
for _, id in ipairs({
    "helm", "navcomputer", "hyperdrive", "shiplog", "weapons", "shields", "engineering", "holo_control",
    "damagecontrol", "sensors", "alert", "comms", "fleetcmd", "tractor", "logistics", "relocation", "radar",
}) do
    if PD.Naval.Stations[id] then PD.Naval.Stations[id].ui3d = true end
end

-- Radar-Konsole (grosse Konsole, 3D-Radar)
PD.Naval.Stations.radar = {
    name = "Radar",
    model = "models/lordtrilobite/starwars/isd/imp_console_large01.mdl",
    desc = "3D-Radar, Verfolgung, Störsender, Schleichfahrt, Täuschkörper",
    ui3d = true,
}
