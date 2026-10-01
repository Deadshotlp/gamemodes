PD.Scoreboard = PD.Scoreboard or {}

PD.Scoreboard.Gruppen = {}
PD.Scoreboard.Gruppen["user"] = {
    name = "Spieler",
    col = Color(255, 255, 255)
}
PD.Scoreboard.Gruppen["superadmin"] = {
    name = "Repub. Ingenieur",
    col = Color(140, 0, 255)
}
PD.Scoreboard.Gruppen["admin"] = {
    name = "Administration",
    col = Color(255, 0, 0)
}
PD.Scoreboard.Gruppen["projekt"] = {
    name = "Projektleitung",
    col = Color(255, 0, 0)
}

PD.Scoreboard.Gruppen["teamleitung"] = {
    name = "Teamleitung",
    col = Color(255, 0, 0)
}

PD.Scoreboard.Gruppen["moderator"] = {
    name = "Moderation",
    col = Color(255, 0, 0)
}

PD.Scoreboard.Gruppen["supporter"] = {
    name = "Suppoter",
    col = Color(255, 0, 0)
}

PD.Scoreboard.Gruppen["eventler"] = {
    name = "Eventler",
    col = Color(255, 0, 0)
}

PD.Scoreboard.Buttons = {{
    name = "Goto", -- Name des Commandes 
    func = function(ply, target) -- Funktion
        RunConsoleCommand("sam", "goto", target:Nick())
    end
}, {
    name = "Bring", -- Name des Commandes 
    func = function(ply, target) -- Funktion
        RunConsoleCommand("sam", "bring", target:Nick())
    end
}, {
    name = "Return", -- Name des Commandes 
    func = function(ply, target) -- Funktion
        RunConsoleCommand("sam", "return", target:Nick())
    end
}, {
    name = "Kill", -- Name des Commandes 
    func = function(ply, target) -- Funktion
        RunConsoleCommand("sam", "slay", target:Nick())
    end
}, {
    name = "Respawn", -- Name des Commandes 
    func = function(ply, target) -- Funktion
        RunConsoleCommand("sam", "respawn", target:Nick())
    end
}, {
    name = "Kick", -- Name des Commandes 
    func = function(ply, target) -- Funktion
        RunConsoleCommand("sam", "kick", target:Nick())
    end
}, {
    name = "Ban", -- Name des Commandes 
    func = function(ply, target) -- Funktion
        RunConsoleCommand("sam", "ban", target:Nick())
    end
}}
