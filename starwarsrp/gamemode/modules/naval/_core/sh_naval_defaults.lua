--[[
    Naval - Startwerte.

    Beim ersten Start werden Klassen, Fraktionen, Beziehungen und
    Einstellungen in die Datenbank geschrieben (pd_naval_*) und sind danach
    im Web-Panel pflegbar. Diese Datei wird danach nur noch als Vorlage
    benutzt (fehlende Einstellungs-Schluessel werden nachgetragen).

    Groessen und Geschwindigkeiten sind fuer RP-Tempo verdichtet: Anfluege im
    System dauern Minuten, Hyperraumspruenge 1-5 Minuten.
    Modelle stammen aus "[LVS] Automatic Capital Ship V2" (aura_lvs_*).
]]

PD.Naval = PD.Naval or {}

local D = {}
PD.Naval.Defaults = D

--------------------------------------------------------------------------------
-- Einstellungen (pd_naval_settings)
--------------------------------------------------------------------------------

D.Settings = {
    start_system = "",            -- leer = erstes System mit "Coruscant" im Namen
    autosave_interval = 60,       -- Sekunden
    render_far = 40000,           -- Render-Einheiten, Grenze der Impostor-Projektion
    render_scale = 50,            -- Meter pro Render-Einheit in der Skybox
    near_ship_range = 50000,      -- m: bis hier echte Modelle, dahinter Punkte
    sensor_default = 300000,      -- m
    system_scale = 1,             -- Faktor fuer Orbitradien
    hyper_base_time = 45,         -- s: kuerzester Sprung
    hyper_time_per_gu = 0.13,     -- s pro Galaxie-Einheit
    hyper_max_time = 300,         -- s
    nav_calc_base = 30,           -- s: Kursberechnung minimal
    nav_calc_per_gu = 0.03,       -- s pro Galaxie-Einheit
    nav_calc_max = 90,            -- s
    nav_valid_seconds = 600,      -- so lange gilt eine Kursloesung
    nav_max_drift = 50000,        -- m: weiter weg bewegt = Loesung ungueltig
    jump_align_tolerance = 2,     -- Grad
    spool_time = 10,              -- s Hochfahren
    jump_anim_time = 3,           -- s Eintritt (Sterne)
    exit_anim_time = 3,           -- s Austritt
    mass_shadow_factor = 4,       -- vielfacher Koerperradius ohne Sprung
    arrival_scatter = 20000,      -- m Streuung beim Austritt
    admin_override_level = 50,    -- PD.Admin.Ranks-Stufe fuer Admin-Befehle
    galaxy_unit = "swu",          -- "parsec" nach dem Import von swgalaxymap
    galaxy_version = "",          -- Stand der importierten Galaxie-Datei
    route_speed_factor = 0.5,     -- Sprungzeit-Faktor entlang einer Hauptroute
    route_minor_factor = 0.7,     -- Sprungzeit-Faktor entlang einer Nebenroute
    route_junction_dist = 25,     -- pc: Umstieg zwischen Routen bis zu diesem Abstand
    combat_damage_mult = 0.5,     -- Faktor auf allen Waffenschaden (Kampfdauer)
    combat_shield_regen_mult = 1, -- Faktor auf das Nachladen der Schilde
    combat_wreck_time = 20,       -- s: Wrack sichtbar, dann entfernt
    holo_radius = 60,             -- Einheiten: Radius des Taktik-Hologramms
    holo_height = 45,             -- Einheiten ueber dem Projektor
    dc_max_incidents = 6,         -- gleichzeitige Schaeden an Bord
    dc_incident_chance = 0.35,    -- Chance je Huellentreffer-Takt auf einen neuen Schaden
    dc_repair_time = 6,           -- s Reparatur (E halten) je Schweregrad
    dc_repair_sub = 0.25,         -- Anteil Subsystem-Haltbarkeit je behobenem Schaden
    dc_team_count = 2,            -- Reparaturtrupps
    dc_team_rate = 0.004,         -- Anteil Haltbarkeit je Sekunde und Trupp
    dc_fire_damage = 4,           -- Schaden je Sekunde an Spielern im Feuer
    dc_fire_spread = 90,          -- s bis ein Brand auf einen weiteren Punkt uebergreift
    alert_auto_yellow = 1,        -- bei Treffern automatisch Gelb (1 = an)
    alert_defcon_normal = 5,      -- DEFCON bei Normal (0 = nicht aendern)
    alert_defcon_yellow = 3,      -- DEFCON bei Gelb
    alert_defcon_red = 2,         -- DEFCON bei Rot
    alert_alarm_seconds = 20,     -- s Alarmton nach dem Wechsel auf Rot
    alert_red_light = 1,          -- Rot: 1 = Map-Licht abdunkeln + roter Filter, 2 = nur Filter, 0 = aus
    alert_red_lightstyle = "e",   -- Helligkeit der Map bei Rot (a = dunkel, m = normal)
    sensor_ident_range = 15000,   -- m: Kontakte naeher als das sind automatisch erkannt
    sensor_scan_time = 8,         -- s je Scan (laenger mit Entfernung, kuerzer mit Sensorenergie)
    shield_mod_bonus = 0.35,      -- Schildmodulation: so viel weniger Schildverbrauch
    shield_mod_duration = 90,     -- s
    shield_mod_cooldown = 20,     -- s nach einem Fehlversuch
    autopilot_clearance = 1.6,    -- Autopilot: Sicherheitsabstand in Koerperradien
    autopilot_margin = 5000,      -- m zusaetzlich
    fleet_spacing = 2.5,          -- Formationsabstand in Schiffslaengen (groesstes Schiff)
    morale_enabled = 1,           -- KI-Moral (Flucht und Kapitulation), 0 = nur Fluchtregel bei 20 % Huelle
    morale_flee = 30,             -- unter dieser Moral flieht ein KI-Schiff
    morale_surrender = 12,        -- darunter kapituliert es (wenn es nicht fliehen kann)
    comms_auto_reply = 1,         -- KI-Schiffe beantworten Funkrufe selbst (0 = nur Spielleitung)
    comms_distress_range = 3000,  -- pc: Notruf erreicht verbuendete Schiffe bis hier
    comms_distress_ships = 3,     -- so viele Schiffe kommen hoechstens
    comms_distress_cooldown = 300, -- s zwischen zwei Notrufen
    interdict_range = 1000000,    -- m: Abfangfeld eines Abfangkreuzers
    ship_inertia = 0,             -- 1 = Traegheit (Rutschen nach dem Drehen, Nachlaufen der Drehung)
    tractor_range = 5000,         -- m: Reichweite des Traktorstrahls (x Staerke der Klasse)
    tractor_reel_speed = 150,     -- m/s: Heranziehen
    boarding_time = 90,           -- s: Entern eines 600-m-Schiffs (kapituliert halb so lang)
    boarding_cooldown = 120,      -- s nach einem abgewehrten Enterversuch
    boarding_live = 0,            -- 1 = Spielleitung entscheidet den Ausgang beim Entern durch das Map-Schiff
    boarding_ai = 1,              -- KI-Schiffe entern kapitulierte Feinde in Reichweite
    field_procedural = 1,         -- Asteroidenfelder/Nebel automatisch erzeugen (0 = nur eigene aus pd_naval_fields)
    field_asteroid_safe = 0.35,   -- sichere Fahrt in Asteroidenfeldern (Anteil der Hoechstfahrt)
    field_asteroid_damage = 1,    -- Faktor fuer Einschlagschaden
    field_asteroid_sensors = 0.7, -- Sensorreichweite im Asteroidenfeld
    field_asteroid_hide = 40000,  -- m: Schiffe im Asteroidenfeld erst ab hier sichtbar
    field_nebula_sensors = 0.35,  -- Sensorreichweite im Nebel
    field_nebula_shields = 0.4,   -- Schildladung im Nebel
    field_nebula_hide = 20000,    -- m: Schiffe im Nebel erst ab hier sichtbar
    supply_delivery_time = 90,    -- s von der Anforderung bis zur Anlieferung
    supply_cooldown = 900,        -- s zwischen zwei Lieferungen (nach der Anlieferung)
    supply_max_crates = 8,        -- Kisten je Lieferung
    supply_require_friendly = 1,  -- nur in eigenem Gebiet oder bei verbuendetem Schiff in 100 km (0 = ueberall)
    supply_parts_hull = 5,        -- % Huelle je Ersatzteilkiste
    supply_parts_max = 80,        -- % Huelle, bis zu der Ersatzteile reparieren (Rest nur in der Werft/Admin)
    supply_npc_rate = 0.1,        -- KI-Schiffe in eigenem Gebiet: Anteil Munition je Minute
}

--------------------------------------------------------------------------------
-- Fraktionen und Beziehungen
--------------------------------------------------------------------------------

D.Factions = {
    {id = "republik", name = "Galaktische Republik", color = {80, 150, 255}, iff = "REP", player = true},
    {id = "kus", name = "Konföderation unabhängiger Systeme", color = {230, 70, 60}, iff = "KUS", player = false},
    {id = "neutral", name = "Neutral", color = {190, 190, 190}, iff = "NEU", player = false},
    {id = "piraten", name = "Piraten", color = {240, 150, 40}, iff = "PIR", player = false},
}

D.Relations = {
    {"republik", "kus", "hostile"},
    {"republik", "piraten", "hostile"},
    {"kus", "piraten", "hostile"},
    {"republik", "neutral", "neutral"},
    {"kus", "neutral", "neutral"},
    {"piraten", "neutral", "hostile"},
}

--------------------------------------------------------------------------------
-- Schiffsklassen (pd_naval_classes)
--------------------------------------------------------------------------------

--[[
    Bewegung:   maxSpeed m/s, accel/decel m/s^2, maxRate Grad/s (p/y/r),
                angAccel Grad/s^2, thrusterSpeed m/s (Manoevrierduesen)
    Hyperantrieb: rating = Faktor auf die Sprungzeit (1 = normal, 2 = halb so
                lang), spool s
    Sensoren:   range m
    Subsysteme, Schilde, Waffen, Energie: ab Stufe 2 benutzt, die Struktur
    steht aber schon - siehe BuildSubsystems.
]]

-- Standard-Subsysteme, Position relativ zur Schiffslaenge (x = Bug +0.5).
local function BuildSubsystems(lengthM, hull)
    local hp = math.Round(hull * 0.15)

    return {
        {id = "engines", type = "engine", hp = hp * 2, pos = {-0.45, 0, 0}},
        {id = "maneuver", type = "maneuver", hp = hp, pos = {0, 0, -0.05}},
        {id = "hyperdrive", type = "hyperdrive", hp = hp, pos = {-0.3, 0, 0}},
        {id = "reactor", type = "reactor", hp = hp * 2, pos = {-0.15, 0, 0}},
        {id = "bridge", type = "bridge", hp = hp, pos = {-0.25, 0, 0.12}},
        {id = "sensors", type = "sensors", hp = hp, pos = {-0.2, 0, 0.15}},
        {id = "comms", type = "comms", hp = hp, pos = {-0.22, 0, 0.14}},
        {id = "shieldgen", type = "shieldgen", hp = hp, pos = {-0.2, 0, 0.1}},
        {id = "lifesupport", type = "lifesupport", hp = hp, pos = {0, 0, 0}},
    }
end

local function Class(def)
    def.subsystems = def.subsystems or BuildSubsystems(def.lengthM, def.hull)
    def.shields = def.shields or {perZone = math.Round(def.hull * 0.4), regen = math.Round(def.hull * 0.01), energyRatio = 0.7}
    def.power = def.power or {reactor = 100}
    def.weapons = def.weapons or {}
    def.hangar = def.hangar or {}
    def.crew = def.crew or {}
    return def
end

D.Classes = {
    -- Republik
    Class({id = "venator", name = "Venator-Klasse Sternzerstörer", faction = "republik",
        model = "models/salty/venator-class-cruiser.mdl", lengthM = 1137, hull = 10000,
        move = {maxSpeed = 4000, accel = 40, decel = 60, maxRate = {p = 3, y = 3, r = 4}, angAccel = {p = 1, y = 1, r = 1.5}, thrusterSpeed = 40},
        hyper = {rating = 1, spool = 10}, sensors = {range = 300000}}),
    Class({id = "acclamator", name = "Acclamator-Klasse Angriffsschiff", faction = "republik",
        model = "models/salty/acclamator-class-ship.mdl", lengthM = 752, hull = 6000,
        move = {maxSpeed = 4500, accel = 50, decel = 70, maxRate = {p = 4, y = 4, r = 5}, angAccel = {p = 1.5, y = 1.5, r = 2}, thrusterSpeed = 45},
        hyper = {rating = 1, spool = 10}, sensors = {range = 250000}}),
    Class({id = "arquitens", name = "Arquitens-Klasse Leichter Kreuzer", faction = "republik",
        model = "models/salty/repubarquitens-cruiser.mdl", lengthM = 325, hull = 3000,
        move = {maxSpeed = 5500, accel = 80, decel = 100, maxRate = {p = 7, y = 7, r = 9}, angAccel = {p = 3, y = 3, r = 4}, thrusterSpeed = 60},
        hyper = {rating = 1.2, spool = 8}, sensors = {range = 250000}}),
    Class({id = "pelta", name = "Pelta-Klasse Fregatte", faction = "republik",
        model = "models/sweaw/ships/rep_pelta_servius.mdl", lengthM = 282, hull = 2500,
        move = {maxSpeed = 5000, accel = 70, decel = 90, maxRate = {p = 7, y = 7, r = 9}, angAccel = {p = 3, y = 3, r = 4}, thrusterSpeed = 55},
        hyper = {rating = 1, spool = 8}, sensors = {range = 200000}}),
    Class({id = "cr90", name = "CR90-Korvette", faction = "republik",
        model = "models/squadrons/cr90.mdl", lengthM = 150, hull = 1200,
        move = {maxSpeed = 7000, accel = 150, decel = 180, maxRate = {p = 14, y = 14, r = 18}, angAccel = {p = 7, y = 7, r = 9}, thrusterSpeed = 80},
        hyper = {rating = 1.5, spool = 6}, sensors = {range = 200000}}),
    Class({id = "consular", name = "Consular-Klasse Kreuzer", faction = "republik",
        model = "models/diggerthings/consular/unarmed1.mdl", lengthM = 115, hull = 900,
        move = {maxSpeed = 6500, accel = 140, decel = 170, maxRate = {p = 14, y = 14, r = 18}, angAccel = {p = 7, y = 7, r = 9}, thrusterSpeed = 80},
        hyper = {rating = 1.5, spool = 6}, sensors = {range = 180000}}),

    -- KUS
    Class({id = "munificent", name = "Munificent-Klasse Fregatte", faction = "kus",
        model = "models/salty/munificent-class.mdl", lengthM = 825, hull = 6500,
        move = {maxSpeed = 4200, accel = 45, decel = 60, maxRate = {p = 4, y = 4, r = 5}, angAccel = {p = 1.5, y = 1.5, r = 2}, thrusterSpeed = 40},
        hyper = {rating = 1, spool = 10}, sensors = {range = 250000}}),
    Class({id = "recusant", name = "Recusant-Klasse Zerstörer", faction = "kus",
        model = "models/salty/recusant-class-destroyer.mdl", lengthM = 1187, hull = 8000,
        move = {maxSpeed = 4000, accel = 40, decel = 55, maxRate = {p = 3, y = 3, r = 4}, angAccel = {p = 1, y = 1, r = 1.5}, thrusterSpeed = 35},
        hyper = {rating = 1, spool = 10}, sensors = {range = 280000}}),
    Class({id = "providence", name = "Providence-Klasse Träger", faction = "kus",
        model = "models/salty/providence.mdl", lengthM = 1088, hull = 11000,
        move = {maxSpeed = 3800, accel = 35, decel = 50, maxRate = {p = 3, y = 3, r = 4}, angAccel = {p = 1, y = 1, r = 1.5}, thrusterSpeed = 35},
        hyper = {rating = 1, spool = 12}, sensors = {range = 320000}}),
    Class({id = "lucrehulk", name = "Lucrehulk-Klasse Schlachtschiff", faction = "kus",
        model = "models/salty/lucrehulk.mdl", lengthM = 3170, hull = 30000,
        move = {maxSpeed = 2500, accel = 15, decel = 25, maxRate = {p = 1, y = 1, r = 1.5}, angAccel = {p = 0.3, y = 0.3, r = 0.5}, thrusterSpeed = 20},
        hyper = {rating = 0.8, spool = 20}, sensors = {range = 400000}}),
    Class({id = "bulwark", name = "Bulwark-Klasse Schlachtkreuzer", faction = "kus",
        model = "models/salty/cis-bulwark-mk2.mdl", lengthM = 820, hull = 7000,
        move = {maxSpeed = 4200, accel = 45, decel = 60, maxRate = {p = 4, y = 4, r = 5}, angAccel = {p = 1.5, y = 1.5, r = 2}, thrusterSpeed = 40},
        hyper = {rating = 1, spool = 10}, sensors = {range = 260000}}),

    -- Zivil
    Class({id = "frachter", name = "Frachter", faction = "neutral",
        model = "models/jk3/acship_servius.mdl", lengthM = 200, hull = 800,
        move = {maxSpeed = 3500, accel = 50, decel = 70, maxRate = {p = 6, y = 6, r = 8}, angAccel = {p = 2, y = 2, r = 3}, thrusterSpeed = 40},
        hyper = {rating = 0.8, spool = 12}, sensors = {range = 120000}}),
}
