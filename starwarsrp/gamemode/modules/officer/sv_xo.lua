PG.COBar = PG.COBar or {}

util.AddNetworkString("Update")
util.AddNetworkString("SyncBar")

local co,xo,ao = "N/A","N/A","N/A"

hook.Add("PlayerSay","MarioCOBarSay",function(ply,txt)
    if (txt == "/co") then
        if co == ply:Nick() then
            co = "N/A"
        else
            co = ply:Nick()
        end

        net.Start("Update")
            net.WriteString(co)
            net.WriteString("co")
        net.Broadcast()

        return ""
    elseif (txt == "/xo") then
        if xo == ply:Nick() then
            xo = "N/A"
        else
            xo = ply:Nick()
        end

        net.Start("Update")
            net.WriteString(xo)
            net.WriteString("xo")
        net.Broadcast()
        
        return ""
    elseif (txt == "/ao") then
        if ao == ply:Nick() then
            ao = "N/A"
        else
            ao = ply:Nick()
        end

        net.Start("Update")
            net.WriteString(ao)
            net.WriteString("ao")
        net.Broadcast()
        
        return ""
    end
end)

net.Receive("SyncBar",function(len,ply)
    net.Start("SyncBar")
    net.WriteString(co)
    net.WriteString(xo)
    net.WriteString(ao)
    net.Send(ply)
end)

