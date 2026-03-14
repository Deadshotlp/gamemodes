-- HUD by Mario

hook.Add("EntityTakeDamage", "DamageHandler", function(target, dmginfo)

end)

util.AddNetworkString("PD.WeaponSelector:SelectWeapon")

net.Receive("PD.WeaponSelector:SelectWeapon", function(len, p)
    local selectedWeapon = net.ReadInt(32)
    local ply = net.ReadEntity()
    local weaponList = ply:GetWeapons()
    local activeWep = ply:GetActiveWeapon()

    for k, v in pairs(weaponList) do
        if k == selectedWeapon then
            ply:SelectWeapon(v:GetClass())
        end
    end
end)

