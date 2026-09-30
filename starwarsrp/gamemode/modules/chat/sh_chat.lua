GLOBAL = 0
LOCAL = 1

PD.Chat = PD.Chat or {}

PD.Chat.Command = PD.Chat.Command or {}

PD.Chat.Command.List = PD.Chat.Command.List or {
    ["/"] = {
        ["system"] = {
            description = "Global System Information",
            visibility = GLOBAL,
            color = Color(255, 255, 255),
            callback = function(ply, args)
                local text = table.concat(args, " ")
                local name = ply:Nick()

                PD.Chat.BroadcastMessage(PD.Chat.Compose("***", ply, tostring(text)), "system")
            end
        },
        ["looc"] = {
            description = "Local Out of Character Chat",
            visibility = LOCAL,
            color = Color(255, 255, 255),
            callback = function(ply, args)
                local text = table.concat(args, " ")
                local name = ply:Nick()

                PD.Chat.SendToPlayerMessage(ply, PD.Chat.Compose("LOOC", ply, tostring(text)), "looc")
            end
        },
        ["ooc"] = {
            description = "Global Out of Character Chat",
            visibility = GLOBAL,
            color = Color(255, 255, 255),
            callback = function(ply, args)
                local text = table.concat(args, " ")
                local name = ply:Nick()

                PD.Chat.SendToPlayerMessage(ply, PD.Chat.Compose("OOC", ply, tostring(text)), "ooc")
            end
        },
        ["/"] = {
            description = "Global Out of Character Chat",
            visibility = GLOBAL,
            color = Color(255, 255, 255),
            callback = function(ply, args)
                local text = table.concat(args, " ")
                local name = ply:Nick()

                PD.Chat.BroadcastMessage(PD.Chat.Compose("OOC", ply, tostring(text)), "/")
            end
        },
        ["me"] = {
            description = "Perform an action. (local)",
            visibility = LOCAL,
            color = Color(255, 255, 255),
            callback = function(ply, args)
                local text = table.concat(args, " ")
                local name = ply:Nick()

                PD.Chat.SendToPlayerMessage(ply, PD.Chat.Compose("ME", ply, tostring(text)), "me")
            end
        },
        ["akt"] = {
            description = "Aktion (local)",
            visibility = GLOBAL,
            color = Color(255, 0, 0),
            callback = function(ply, args)
                local text = table.concat(args, " ")
                local name = ply:Nick()

                PD.Chat.BroadcastMessage(PD.Chat.Compose("AKT", ply, tostring(text)), "akt")
            end
        },
        ["makt"] = {
            description = "Medical Aktion",
            visibility = GLOBAL,
            color = Color(125, 125, 0),
            callback = function(ply, args)
                local text = table.concat(args, " ")
                local name = ply:Nick()

                PD.Chat.BroadcastMessage(PD.Chat.Compose("MAKT", ply, tostring(text)), "makt")
            end
        },
        ["eakt"] = {
            description = "Event Aktion",
            visibility = GLOBAL,
            color = Color(0, 255, 0),
            callback = function(ply, args)
                local text = table.concat(args, " ")
                local name = ply:Nick()

                PD.Chat.BroadcastMessage(PD.Chat.Compose("EAKT", ply, tostring(text)), "eakt")
            end
        },
        ["fakt"] = {
            description = "FC Aktion",
            visibility = GLOBAL,
            color = Color(0, 255, 0),
            callback = function(ply, args)
                local text = table.concat(args, " ")
                local name = ply:Nick()

                PD.Chat.BroadcastMessage(PD.Chat.Compose("FAKT", ply, tostring(text)), "fakt")
            end
        },
        ["it"] = {
            description = "Local Interaction",
            visibility = LOCAL,
            color = Color(255, 0, 0),
            callback = function(ply, args)
                local text = table.concat(args, " ")
                local name = ply:Nick()

                PD.Chat.SendToPlayerMessage(ply, PD.Chat.Compose("***", nil, text), "it")
            end
        },
        ["git"] = {
            description = "Global Interaction",
            visibility = GLOBAL,
            color = Color(255, 255, 255),
            callback = function(ply, args)
                local text = table.concat(args, " ")
                local name = ply:Nick()

                PD.Chat.BroadcastMessage(PD.Chat.Compose("***", nil, text), "git")
            end
        },
        ["roll"] = {
            description = "Global Roll",
            visibility = GLOBAL,
            color = Color(0, 255, 0),
            callback = function(ply, args)
                local roll = math.random(1, 100)
                local name = ply:Nick()

                PD.Chat.BroadcastMessage(PD.Chat.Compose("ROLL", ply, tostring(roll)), "roll")
            end
        },
        ["drop"] = {
            description = "Drop the Weapon your Holding.",
            visibility = GLOBAL,
            color = Color(0, 255, 0),
            callback = function(ply, args)
                ply:DropWeapon()
            end
        }
    },
    ["!"] = {
        ["tobi-announce"] = {
            description = "Tobis Server aNnOuNcE",
            visibility = GLOBAL,
            color = Color(0, 255, 0),
            callback = function(ply, args)
                if not ply:IsAdmin() then return end
                PD.Announce("Tobis aNnOuNcE", "Tobie ist ein Dofi", Color(200, 60, 60), 5, nil)
            end
        },
        ["s-announce"] = {
            description = "Tobis Server aNnOuNcE",
            visibility = GLOBAL,
            color = Color(0, 255, 0),
            callback = function(ply, args)
                if not ply:IsAdmin() then return end
                local text = table.concat(args, " ")

                PD.Announce("Server Announcement", text, Color(200, 60, 60), 5, nil)
            end
        }
    },
    ["."] = {

    }
}

PD.Chat.AdminChat = {
    description = "Admin Chat",
    visibility = GLOBAL,
    color = Color(255, 0, 0),
    -- Geht an alle Admins und an den Absender, damit auch Spieler ohne Rechte
    -- sehen, dass ihre Nachricht abgeschickt wurde. Frueher per Broadcast an
    -- alle Spieler.
    callback = function(ply, args)
        local text = table.concat(args, " ")
        local msg = PD.Chat.Compose("ADMIN", ply, tostring(text))

        local targets = {}
        for _, p in ipairs(player.GetAll()) do
            if p == ply or p:IsAdmin() then
                targets[#targets + 1] = p
            end
        end

        net.Start("PD.Chat.SendMSG")
            net.WriteString(msg)
            net.WriteString("admin")
        net.Send(targets)
    end
}

PD.Chat.Command.Flat = PD.Chat.Command.Flat or {}

for _, group in pairs(PD.Chat.Command.List) do
    for name, command in pairs(group) do
        PD.Chat.Command.Flat[name] = command
    end
end

PD.Chat.Command.Flat["admin"] = PD.Chat.AdminChat

if SERVER then
    function PD.Chat.AddCommand(key, name, CommandTbl)
        PD.Chat.Command.List[key][name] = CommandTbl
        PD.Chat.Command.Flat[name] = CommandTbl
    end
end 