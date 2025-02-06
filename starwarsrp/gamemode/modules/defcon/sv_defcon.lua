-- Server
DEFCON = DEFCON or {}

util.AddNetworkString("ChangeDefcon")
util.AddNetworkString("SyncDefcon")

local nr = DEFCON.Default
local text = "" 

hook.Add("PlayerSay", "MariosDefconSystem", function(ply, txt)
    if DEFCON.Commands[string.sub(txt, 1, 7)] then
        if DEFCON.Jobs[team.GetName(ply:Team())] or DEFCON.Team[ply:GetUserGroup()] then
            local id = tonumber(string.sub(txt, 9, 9))
            local extraText = string.sub(txt, 11)
            
            if DEFCON:GetID(id) then
                nr = id
                net.Start("ChangeDefcon")
                net.WriteInt(id, 4)
                
                if extraText and extraText ~= "" then
                    net.WriteString(extraText)
                    text = extraText
                else
                    net.WriteString("")
                    text = ""
                end
                net.WriteString(ply:Nick())
                net.Broadcast()
            else
                ply:ChatPrint("Die Nummer gibt es nicht!")
            end
        else
            ply:ChatPrint("Du hast keine Berechtigung für das Defcon!")
        end
        
        return ""
    end
end)

net.Receive("SyncDefcon",function(_,ply)
    net.Start("SyncDefcon")
        net.WriteInt(nr,4)
        net.WriteString(text)
    net.Send(ply)
end)

