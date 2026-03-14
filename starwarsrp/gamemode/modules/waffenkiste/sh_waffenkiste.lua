PD.WB = PD.WB or {}

PD.WB.StripWeapons = true
PD.WB.StripWeapnsDead = true
PD.WB.GiveDeadWeapons = true
PD.WB.Weigths = true
PD.WB.MaxWeigth = 20 -- Maximalgewicht in Kg

PD.WB.DontStrip = {
    "idcard",
    "mhands"
}

PD.WB.CategoryAmount = {
    ["Primär"] = 1,
    ["Sekundär"] = 1,
    ["Granaten"] = 2,
    ["Gadget 1"] = 3
}

PD.WB.Weapons = {}
PD.WB.Weapons["Primär"] = {
    ["arccw_k_dlt19"] = 6,
    ["arccw_k_t21"] = 10,
    ["arccw_k_e11"] = 3,
    ["arccw_k_launcher_plx1_empire"] = 15,
    ["arccw_k_e11s"] = 4,
    ["arccw_k_e11t"] = 3.5,
    ["arccw_k_e11_stun"] = 3,
    ["arccw_k_e11d"] = 4,
    ["arccw_k_launcher_smartlauncher"] = 15,
    ["arccw_sops_empire_dlt19d"] = 7
}

PD.WB.Weapons["Sekundär"] = {
    ["arccw_k_se14"] = 1,
    ["arccw_k_e11pistol"] = 1,
    ["arccw_k_rk3"] = 1

}

PD.WB.Weapons["Granaten"] = {
    ["arccw_k_nade_thermal"] = 0.5,
    ["arccw_k_nade_c14"] = 1,
    ["arccw_k_nade_bacta"] = 0.5,
    ["arccw_k_nade_smoke"] = 0.5,
    ["arccw_k_nade_impact"] = 0.5,
    ["seal6-c4"] = 3,
    ["weapon_breachingcharge"] = 3,
    ["arccw_k_nade_flashbang"] = 1,
    ["arccw_k_nade_thermalimploder"] = 2,
    ["arccw_k_nade_sonar"] = 0.5,
    ["arccw_k_nade_c25"] = 1
  
}

PD.WB.Weapons["Gadget 1"] = {
    ["weapon_imds_datapad"] = 0.8,
    ["fort_datapad"] = 0.8,
    ["realistic_hook"] = 2,
    ["rw_sw_bino_white"] = 2.5,
    ["rw_sw_bino_dark"] = 2.5,
    ["weapon_bactainjector"] = 0.3,
    ["tfa_defi_swrp"] = 0.3,
    ["the_flare_gun_update"] = 0.3,
    ["weapon_extinguisher"] = 4,
    ["weapon_extinguisher_infinite"] = 6,
    ["alydus_fusioncutter"] = 2,
    ["mortar_constructor_dark"] = 20,
    ["weapon_lvsrepair"] = 1,
    ["defuser_bomb"] = 0.2,
    ["mortar_range_finder"] = 0.1,
    ["weapon_armorkit"] = 0.5,
    ["dt_decrypter"] = 0,
    ["weapon_cuff_sf"] = 0.3,
    ["arccw_k_melee_empireshield"] = 7,
    ["arccw_k_melee_riotbaton"] = 0.8,
    ["choke_swep"] = 0,
    ["dt_encrypter"] = 0
} 

function PD.WB.GetWeaponWeights(weapon)
    for k, v in SortedPairs(PD.WB.Weapons) do
        for wep, weight in SortedPairs(v) do
            if wep == weapon then
                return weight
            end
        end
    end
end