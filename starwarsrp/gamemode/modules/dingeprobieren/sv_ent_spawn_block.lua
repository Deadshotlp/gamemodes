local last_ent_spawned = 0

hook.Add("SpawnFunction", "Deadshot_probiert_dinge", function(ply, tr, ClassName)
    if not ply:IsAdmin() or not ply:IsSuperAdmin() then
        RunConsoleCommand("sam", "banid", ply:SteamID64(), 525600,
        "Wir wünschen viel Erfolg beim nächsten mal! \n Du kannst im Discord Gegen den Ban einspruch erheben: https://discord.gg/YEHfCffp4M")
        return false
    end 
    
    if CurTime() > last_ent_spawned + 0.1 then
        RunConsoleCommand("sam", "banid", ply:SteamID64(), 525600,
        "Wir wünschen viel Erfolg beim nächsten mal! \n Du kannst im Discord Gegen den Ban einspruch erheben: https://discord.gg/YEHfCffp4M")
        return false
    end 
    
    last_ent_spawned = CurTime()
    return true
end)