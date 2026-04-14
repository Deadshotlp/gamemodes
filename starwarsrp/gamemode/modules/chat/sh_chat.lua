PD.Chat = PD.Chat or {}

PD.Chat.Command = PD.Chat.Command or {}

PD.Chat.Command.List = PD.Chat.Command.List or {
    ["system"] = {
        description = "Global System Information",
        visibility = GLOBAL,
        color = Color(255, 255, 255),
        callback = function(ply, args)
            local text = table.concat(args, " ")
            local name = ply:Nick()

            PD.Chat.BroadcastMessage(string.format("[%s] %s: %s", "***", name, text), "system")
        end
    },
    ["looc"] = {
        description = "Local Out of Character Chat",
        visibility = LOCAL,
        color = Color(255, 255, 255),
        callback = function(ply, args)
            local text = table.concat(args, " ")
            local name = ply:Nick()

            PD.Chat.SendToPlayerMessage(ply, string.format("[%s] %s: %s", "LOOC", name, text), "looc")
        end
    },
    ["ooc"] = {
        description = "Global Out of Character Chat",
        visibility = GLOBAL,
        color = Color(255, 255, 255),
        callback = function(ply, args)
            local text = table.concat(args, " ")
            local name = ply:Nick()

            PD.Chat.SendToPlayerMessage(ply, string.format("[%s] %s: %s", "OOC", name, text), "ooc")
        end
    },
    ["/"] = {
        description = "Global Out of Character Chat",
        visibility = GLOBAL,
        color = Color(255, 255, 255),
        callback = function(ply, args)
            local text = table.concat(args, " ")
            local name = ply:Nick()

            PD.Chat.BroadcastMessage(string.format("[%s] %s: %s", "OOC", name, text), "/")
        end
    },
    ["me"] = {
        description = "Perform an action. (local)",
        visibility = LOCAL,
        color = Color(255, 255, 0255),
        callback = function(ply, args)
            local text = table.concat(args, " ")
            local name = ply:Nick()

            PD.Chat.SendToPlayerMessage(ply, string.format("[%s] %s: %s", "ME", name, text), "me")
        end
    },
    ["akt"] = {
        description = "Aktion (local)",
        visibility = GLOBAL,
        color = Color(255, 0, 0),
        callback = function(ply, args)
            local text = table.concat(args, " ")
            local name = ply:Nick()

            PD.Chat.SendToPlayerMessage(ply, string.format("[%s] %s: %s", "AKT", name, text), "akt")
        end
    },
    ["makt"] = {
        description = "Medical Aktion",
        visibility = GLOBAL,
        color = Color(125, 125, 0),
        callback = function(ply, args)
            local text = table.concat(args, " ")
            local name = ply:Nick()

            PD.Chat.SendToPlayerMessage(ply, string.format("[%s] %s: %s", "MAKT", name, text), "makt")
        end
    },
    ["eakt"] = {
        description = "Event Aktion",
        visibility = GLOBAL,
        color = Color(0, 255, 0),
        callback = function(ply, args)
            local text = table.concat(args, " ")
            local name = ply:Nick()

            PD.Chat.SendToPlayerMessage(ply, string.format("[%s] %s: %s", "EAKT", name, text), "eakt")
        end
    },
    ["fakt"] = {
        description = "FC Aktion",
        visibility = GLOBAL,
        color = Color(0, 255, 0),
        callback = function(ply, args)
            local text = table.concat(args, " ")
            local name = ply:Nick()

            PD.Chat.SendToPlayerMessage(ply, string.format("[%s] %s: %s", "FAKT", name, text), "fakt")
        end
    },
    ["it"] = {
        description = "Local Interaction",
        visibility = LOCAL,
        color = Color(255, 0, 0),
        callback = function(ply, args)
            local text = table.concat(args, " ")
            local name = ply:Nick()

            PD.Chat.SendToPlayerMessage(ply, string.format("[%s] %s", "***", text), "it")
        end
    },
    ["git"] = {
        description = "Global Interaction",
        visibility = GLOBAL,
        color = Color(255, 255, 255),
        callback = function(ply, args)
            local text = table.concat(args, " ")
            local name = ply:Nick()

            PD.Chat.BroadcastMessage(string.format("[%s] %s", "***", text), "git")
        end
    },
    ["roll"] = {
        description = "Global Roll",
        visibility = GLOBAL,
        color = Color(0, 255, 0),
        callback = function(ply, args)
            local text = table.concat(args, " ")
            local name = ply:Nick()

            PD.Chat.BroadcastMessage(string.format("[%s] %s: %s", "ROLL", name, text), "roll")
        end
    }

}

PD.Chat.AdminChat = {
    description = "Admin Chat",
    visibility = GLOBAL,
    color = Color(255, 0, 0),
    callback = function(ply, args)
        local text = table.concat(args, " ")
        local name = ply:Nick()

        

        PD.Chat.BroadcastMessage(string.format("[%s] %s: %s", "ADMIN", name, text), "admin")
    end
}

PD.Chat.Command.Prefix = {
    [1] = "/",
    [2] = "!",
    [3] = "."
}

GLOBAL = 0
LOCAL = 1