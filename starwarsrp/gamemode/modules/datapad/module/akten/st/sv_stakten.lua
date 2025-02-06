 
util.AddNetworkString("ST_Akten_Create")

net.Receive("ST_Akten_Create", function(len, ply)
    local paragraf = net.ReadString()
    local sachlage = net.ReadString()
    local aktetext = net.ReadString()
    local strafe = net.ReadString()

    if not paragraf or not sachlage or not aktetext or not strafe then return end

    local data = {
        paragraf = paragraf,
        sachlage = sachlage,
        aktetext = aktetext,
        strafe = strafe,
        date = os.date("%d/%m/%Y %H:%M:%S"),
        st_ply = ply:Nick(),
    }

    local json = util.TableToJSON(data)

    file.Write("stakten/" .. ply:SteamID64() .. ".txt", json)
end)