-- Server
DEFCON = DEFCON or {}

util.AddNetworkString("ChangeDefcon")
util.AddNetworkString("SyncDefcon")

local nr = DEFCON.Default
local text = ""

-- Setzen und Auslesen liegen jetzt in Funktionen statt direkt im Chat-Hook, damit
-- auch die Serverkonsole (pd_defcon) und der Heartbeat an den Stand kommen.
function DEFCON.Set(id, extraText, byName)
    id = tonumber(id)

    if not id or not DEFCON:GetID(id) then return false end

    nr = id
    text = extraText or ""

    net.Start("ChangeDefcon")
        net.WriteInt(nr, 4)
        net.WriteString(text)
        net.WriteString(byName or "System")
    net.Broadcast()

    return true
end

function DEFCON.GetCurrent()
    return nr, text
end

hook.Add("PlayerSay", "MariosDefconSystem", function(ply, txt)
    if DEFCON.Commands[string.sub(txt, 1, 7)] then
        if DEFCON.Jobs[team.GetName(ply:Team())] or DEFCON.Team[ply:GetUserGroup()] then
            local id = tonumber(string.sub(txt, 9, 9))
            local extraText = string.sub(txt, 11, 11 + 150)

            if not DEFCON.Set(id, extraText, ply:Nick()) then
                ply:ChatPrint("Die Nummer gibt es nicht!")
            end
        else
            ply:ChatPrint("Du hast keine Berechtigung für das Defcon!")
        end

        return ""
    end
end)

net.Receive("SyncDefcon", function(_, ply)
    net.Start("SyncDefcon")
    net.WriteInt(nr, 4)
    net.WriteString(text)
    net.Send(ply)
end)

