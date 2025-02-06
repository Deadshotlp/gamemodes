-- Configuration File for Defcon System
DEFCON = DEFCON or {}

DEFCON.Commands = { -- Commands die Defcon ändern dürfen
    ["!defcon"] = true,
    ["/defcon"] = true,
}

DEFCON.Enabled = true -- Defcon aktivieren oder deaktivieren
DEFCON.Picture = false -- Bilder aktivieren oder deaktivieren bei deaktivierung wird der Text angezeigt
DEFCON.PictureSize = 70 -- Bild Größe
DEFCON.Default = 5 -- Standart Defcon Nummer
DEFCON.Jobs = {
    -- ["JOB NAME"] = true
}
DEFCON.Team = {
    ["superadmin"] = true
}
DEFCON.XPostion = 30 -- X Position des Defcons
DEFCON.YPostion = 20 -- Y Position des Defcons

DEFCON.ID = {}
DEFCON.ID[5] = { 
    nr = 5,
    txt = "Normalbetrieb",
    col = Color(0,255,0),
    sound = "mario/defcon.mp3", -- .mp3/.wav/.ogg
    bild = "mario/defcon/defcon5.png"
}

DEFCON.ID[4] = {
    nr = 4,
    txt = "Erhöhte Wachsamkeit",
    col = Color(255,255,0),
    sound = "mario/defcon.mp3",
    bild = "mario/defcon/defcon4.png"
}

DEFCON.ID[3] = {
    nr = 3,
    txt = "Auf Gefechtsstation",
    col = Color(255,165,0),
    sound = "mario/defcon.mp3",
    bild = "mario/defcon/defcon3.png"
}

DEFCON.ID[2] = {
    nr = 2,
    txt = "Verteidigung der Herzelemente",
    col = Color(255,0,0),
    sound = "mario/defcon.mp3",
    bild = "mario/defcon/defcon2.png"
}

DEFCON.ID[1] = {
    nr = 1,
    txt = "Evakuieren",
    col = Color(139,0,0),
    sound = "mario/defcon.mp3",
    bild = "mario/defcon/defcon1.png"
}

DEFCON.ID[0] = {
    nr = 0,
    txt = "Evakuieren",
    col = Color(139,0,0),
    sound = "mario/defcon.mp3",
    bild = "mario/defcon/defcon0.png"
}

DEFCON.Active = DEFCON.ID[DEFCON.Default]

function DEFCON:GetID(id)
    return DEFCON.ID[id] and true or false
end

