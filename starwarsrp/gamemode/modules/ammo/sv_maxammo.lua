-- 

hook.Add("PlayerSay","maxammofunction", function(ply, txt)
    if (string.lower(txt) == "!ammoid") then
        local plammo = ply:GetActiveWeapon():GetPrimaryAmmoType()
        local slammo = ply:GetActiveWeapon():GetSecondaryAmmoType()

        if (plammo ~= nil) then
            ply:ChatPrint("Primary AmmoID:" .. plammo .. " Name: " .. game.GetAmmoName(plammo))
        end

        if (slammo ~= nil) then
            ply:ChatPrint("Secondary AmmoID:" .. slammo .. " Name: " .. game.GetAmmoName(slammo))
        end

        return ""
    end
end) 