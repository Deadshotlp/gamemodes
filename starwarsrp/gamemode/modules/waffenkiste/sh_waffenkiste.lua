PD.WB = PD.WB or {}

PD.WB.StripWeapons = true
PD.WB.StripWeapnsDead = true
PD.WB.GiveDeadWeapons = true
PD.WB.Weigths = true
PD.WB.MaxWeigth = 100 -- Maximalgewicht in Kg

PD.WB.DontStrip = {
    "weapon_physgun",
    "gmod_tool"
}

PD.WB.CategoryAmount = {
    ["Primär"] = 1
}

PD.WB.Weapons = {}
PD.WB.Weapons["Primär"] = {
    ["arccw_dual_e5"] = 25
}

function PD.WB.GetWeaponWeights(weapon)
    for k, v in pairs(PD.WB.Weapons) do
        for wep, weight in pairs(v) do
            if wep == weapon then
                return weight
            end
        end
    end
end