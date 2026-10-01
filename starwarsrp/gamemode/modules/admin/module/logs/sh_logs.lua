PD.LOGS = PD.LOGS or {}

--[[
    Logs gehen nur an Admins, und zwar als einzelner neuer Eintrag.

    Frueher wurde bei jedem Eintrag die gesamte Historie per WriteTable an
    alle Spieler geschickt: jeder konnte die Admin-Logs mitlesen, und ab etwa
    64 KB Daten brach die Nachricht mit einem Netzwerkfehler ab. Den vollen
    Stand bekommt ein Admin nur noch auf Anfrage (PD.LOGS.Sync), komprimiert
    und auf die letzten Eintraege begrenzt - siehe sv_logs.lua.
]]

function PD.LOGS.CanSee(ply)
    return IsValid(ply) and ply:IsAdmin()
end

function PD.LOGS.Add(typ, text, color)
    typ = string.sub(tostring(typ or "INFO"), 1, 64)
    text = string.sub(tostring(text or ""), 1, 1024)
    color = IsColor(color) and color or Color(255, 255, 255)

    if CLIENT then
        net.Start("PD.LOGS.Addcl")
            net.WriteString(typ)
            net.WriteString(text)
            net.WriteColor(color)
        net.SendToServer()
        return
    end

    PD.LOGS.Insert(typ, text, color)
end

function PD.LOGS.GetTbl()
    return PD.LOGS.Tbl
end
