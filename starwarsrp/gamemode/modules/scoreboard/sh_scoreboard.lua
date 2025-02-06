PD.Scoreboard = PD.Scoreboard or {}

PD.Scoreboard.Gruppen = {}
PD.Scoreboard.Gruppen["user"] = {
    name = "User",
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

PD.Scoreboard.Buttons = {{
    name = "Goto", -- Name des Commandes 
    func = function(ply, target) -- Funktion
        RunConsoleCommand("sam", "goto", target:GetName())
    end
}, {
    name = "Bring", -- Name des Commandes 
    func = function(ply, target) -- Funktion
        RunConsoleCommand("sam", "bring", target:GetName())
    end
}, {
    name = "Return", -- Name des Commandes 
    func = function(ply, target) -- Funktion
        RunConsoleCommand("sam", "return", target:GetName())
    end
}, {
    name = "Kill", -- Name des Commandes 
    func = function(ply, target) -- Funktion
        RunConsoleCommand("sam", "slay", target:GetName())
    end
}, {
    name = "Respawn", -- Name des Commandes 
    func = function(ply, target) -- Funktion
        RunConsoleCommand("sam", "respawn", target:GetName())
    end
}, {
    name = "Kick", -- Name des Commandes 
    func = function(ply, target) -- Funktion
        RunConsoleCommand("sam", "kick", target:GetName())
    end
}, {
    name = "Ban", -- Name des Commandes 
    func = function(ply, target) -- Funktion
        RunConsoleCommand("sam", "ban", target:GetName())
    end
}}
