PD.WB = PD.WB or {}

util.AddNetworkString("PD.WB:GiveWeapon")
util.AddNetworkString("PD.WB:RemoveWeapon")

net.Receive("PD.WB:GiveWeapon", function(len, ply)
    local wep = net.ReadString()
    local jobID, jobTbl = ply:GetJob()
    local id, jobTbl = PD.JOBS.GetJob(jobID)

    if jobTbl.equip[wep] then
        ply:Give(wep)
    else
        print(ply:Nick() .. "[" .. ply:SteamID64() .. "] versucht sich " .. wep .. " zu geben, obwohl er es nicht darf!")
    end
end)

net.Receive("PD.WB:RemoveWeapon", function(len, ply)
    local wep = net.ReadString()
    
    if ply:HasWeapon(wep) then
        ply:StripWeapon(wep)
    end
end)

local wepDeadTbl = {}
hook.Add("PlayerDeath", "PD.WB:PlayerDeath", function(victim, inflictor, attacker)
    if PD.WB.StripWeaponsDead then
        local wep = victim:GetWeapons()

        if not wepDeadTbl[victim:SteamID64()] then
            wepDeadTbl[victim:SteamID64()] = {}
        end

        for _, wep in ipairs(wep) do
            table.insert(wepDeadTbl[victim:SteamID64()], wep:GetClass())
        end
    end
end)

hook.Add("PlayerSpawn", "PD.WB:PlayerSpawn", function(ply)
    if PD.WB.StripWeapons then
        local wep = ply:GetWeapons()
        for _, wep in ipairs(wep) do
            if PD.WB.DontStrip[wep:GetClass()] and ply:IsAdmin() then
                continue
            end

            ply:StripWeapon(wep:GetClass())
        end
    end

    if PD.WB.GiveDeadWeapons and wepDeadTbl[ply:SteamID64()] then
        for _, wep in ipairs(wepDeadTbl[ply:SteamID64()]) do
            ply:Give(wep)
        end

        wepDeadTbl[ply:SteamID64()] = nil
    end
end)