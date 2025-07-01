PD.Char = PD.Char or {}

PD.Char.Background = "mario/void_logo.png" -- Hintergrund Bild
PD.Char.Discord = "" -- Discord Link
PD.Char.Kollektion = "" -- Kollektion Link
PD.Char.MaxChars = 5 -- Maximale Anzahl an Charakteren
PD.Char.MinName = 3 -- Minimale Länge des Namens
PD.Char.MaxName = 20 -- Maximale Länge des Namens
PD.Char.NameBlacklist = {} -- Blacklist für Namen
PD.Char.DefaultJob = "" -- Default Job
PD.Char.UserGroupChar = {
    ["user"] = 1,
    ["superadmin"] = 5
}

PD.Char.OpenMenuBind = KEY_F6 -- Charaktermenü öffnen
PD.Char.OpenAdminMenuBind = KEY_F7 -- Adminmenü öffnen

PD.Char.OpenAdminMenuTeam = { -- Welche Teams können das Adminmenü öffnen
    ["superadmin"] = true
}

PD.Char.Characters = {} -- Wer hat wie viele Charaktere
PD.Char.Characters["user"] = 1
PD.Char.Characters["superadmin"] = 5

PD.Char.NotAllowedNumbers = {
    [""] = true
}

