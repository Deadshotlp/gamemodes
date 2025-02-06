PD.Char = PD.Char or {}

CONFIG:AddConfig("charakter_minname",{
    type = "number",
    default = 3,
    category = "Charakter",
    desc = "Wie lang soll der Name mindestens sein?",
    min = 1,
    max = 50
})

CONFIG:AddConfig("charakter_maxname",{
    type = "number",
    default = 20,
    category = "Charakter",
    desc = "Wie lang darf der Name maximal sein?",
    min = 1,
    max = 50
})

CONFIG:AddConfig("charakter_nameblacklist",{
    type = "simpletable",
    default = {},
    category = "Charakter",
    desc = "Welche Namen sollen nicht erlaubt sein?",
})

CONFIG:AddConfig("charakter_maxchars",{
    type = "number",
    default = 5,
    category = "Charakter",
    desc = "Wie viele Charaktere soll es geben?",
    min = 1,
    max = 5
})

CONFIG:AddConfig("charakter_backgroundbild",{
    type = "string",
    default = "mario/void_logo.png",
    category = "Charakter",
    desc = "Hintergrundbild für den Charakterbildschirm",
})

CONFIG:AddConfig("charakter_openmenubind",{
    type = "bind",
    default = KEY_F6,
    category = "Charakter",
    desc = "Öffnet das Charaktermenü",
})

CONFIG:AddConfig("charakter_openadminmenubind",{
    type = "bind",
    default = KEY_F7,
    category = "Charakter",
    desc = "Öffnet das Adminmenü"
})

CONFIG:AddConfig("charakter_openadminmenuteam",{
    type = "team",
    default = {["superadmin"] = true},
    category = "Charakter",
    desc = "Wer darf das Adminmenü öffnen?"
})

CONFIG:AddConfig("charakter_defaultjob", {
    type = "string",
    default = "",
    category = "Charakter",
    desc = "Schreibe den Namen des Jobs rein, der als Standardjob genommen werden soll"
})


CONFIG:AddConfig("charakter_kolli",{
    type = "string",
    default = "",
    category = "Charakter",
    desc = "Füge den Kollektionslink ein",
})

CONFIG:AddConfig("charakter_discord",{
    type = "string",
    default = "",
    category = "Charakter",
    desc = "Füge den Discordlink ein",
})

CONFIG:AddConfig("charakter_usergroupchar",{
    type = "simpletableplus",
    default = {["user"] = 1, ["superadmin"] = 5},
    category = "Charakter",
    desc = "Wie viele Charaktere darf die Gruppe haben?",
    options = {
        {
            type = "string",
            desc = "Gruppe"
        },
        {
            type = "number",
            desc = "Anzahl",
            min = 1,
            max = 5
        }
    }
})

-- CONFIG:AddConfig("charakter_",{
--     type = "",
--     default = ,
--     category = "Charakter",
--     desc = ""
-- })