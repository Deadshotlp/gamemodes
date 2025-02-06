CONFIG:AddConfig("officerleisteconfig_enabled",{
    type = "bool",
    default = true,
    category = "Officer-Leiste",
    desc = "Aktiviert die Officer-Leiste"
})

CONFIG:AddConfig("officerleisteconfig_fontsize",{
    type = "number",
    default = 20,
    category = "Officer-Leiste",
    desc = "Schriftgröße",
    min = 10,
    max = 100,
})

CONFIG:AddConfig("officerleisteconfig_x",{
    type = "number",
    default = 10,
    category = "Officer-Leiste",
    desc = "Position X",
    min = 0,
    max = 1920,
})

CONFIG:AddConfig("officerleisteconfig_y",{
    type = "number",
    default = 10,
    category = "Officer-Leiste",
    desc = "Position Y",
    min = 0,
    max = 1080,
})

CONFIG:AddConfig("officerleisteconfig_dock",{
    type = "select",
    default = "LEFT",
    category = "Officer-Leiste",
    desc = "Text ausrichtung",
    options = {"LEFT", "RIGHT", "CENTER"}
})

CONFIG:AddConfig("officerleisteconfig_jobs",{
    type = "jobs",
    default = {["Developer"] = true},
    category = "Officer-Leiste",
    desc = "Wer darf die Befehle benutzten (Jobs)",
})

CONFIG:AddConfig("officerleisteconfig_team",{
    type = "team",
    default = {["superadmin"] = true},
    category = "Officer-Leiste",
    desc = "Wer darf die Befehle benutzten (Team)",
})