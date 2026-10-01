-- dd

function PD.Notify(msg, col, all, ply)
    if CLIENT then
        local pop = PD.Popup(msg, col)
    end

    if SERVER then 
        net.Start("PD.Notify")
        net.WriteString(msg)
        net.WriteColor(col)
        
        if all then
            net.Broadcast()
        else
            net.Send(ply)
        end
    end
end

--[[
    PD.Announce - Durchsage in der Bildschirmmitte

    Funktioniert wie PD.Notify, nur groesser und mittig. Aufruf ist auf Server
    und Client identisch; die Darstellung liegt in cl_ui.lua.

    Zwei Schreibweisen, beide gleichwertig:

        PD.Announce("Titel", "Inhalt", Color(200, 60, 60), 12, ply)

        PD.Announce({
            title    = "ALARMSTUFE ROT",
            text     = "Alle Einheiten sammeln sich am Hangar.",
            color    = Color(200, 60, 60),      -- Farbe des Randes
            duration = 12,                      -- Sekunden, 2 bis 120
            sound    = "buttons/button17.wav",  -- optional
            pulse    = true,                    -- optional, pulsierender Rand
            target   = ply,                     -- nur Server, siehe unten
        })

    target bestimmt serverseitig die Empfaenger:
        nil      -> alle Spieler
        Spieler  -> nur dieser
        Tabelle  -> diese Spieler
]]
function PD.Announce(a, b, c, d, e)
    local src = istable(a) and a or {title = a, text = b, color = c, duration = d, target = e}

    local title    = tostring(src.title or "")
    local text     = tostring(src.text or src.content or "")
    local color    = IsColor(src.color) and src.color or Color(30, 90, 178, 255)
    local duration = math.Clamp(tonumber(src.duration) or 8, 2, 120)
    local snd      = tostring(src.sound or "")
    local pulse    = src.pulse and true or false

    if CLIENT then
        PD.ShowAnnouncement({
            title = title, text = text, color = color,
            duration = duration, sound = snd, pulse = pulse
        })
        return
    end

    net.Start("PD.Announce")
        net.WriteString(title)
        net.WriteString(text)
        net.WriteColor(color)
        net.WriteFloat(duration)
        net.WriteString(snd)
        net.WriteBool(pulse)

    local target = src.target or src.ply
    if target == nil then
        net.Broadcast()
    else
        net.Send(target)
    end
end
