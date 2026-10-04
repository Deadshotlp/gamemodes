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
    tactical = {
        name = "Taktik",
        model = "models/lordtrilobite/starwars/isd/imp_console_large01.mdl",
        desc = "3D-Lage, Kontakte",
    },
    bridgescreen = {
        name = "Brückenanzeige",
        model = "models/hunter/plates/plate2x3.mdl",
        desc = "Status für alle",
        noUse = true,
    },
    shiplog = {
        name = "Logbuch",
        model = "models/lordtrilobite/starwars/isd/imp_console_medium03.mdl",
        desc = "Einträge lesen und schreiben",
    },
}

PD.Naval.StationUseRange = 160
