PD.WB = PD.WB or {}

PD.WB.StripWeapons = false
PD.WB.StripWeapnsDead = false
PD.WB.GiveDeadWeapons = false

PD.WB.MaxWeight = 20 -- Maximalgewicht in Kg
PD.WB.MaxWeigth = PD.WB.MaxWeight -- alter Schreibfehler, für bestehenden Code

-- Ausrüstung, die ein Spieler immer trägt: wird beim Spawn automatisch gegeben,
-- taucht in der Kiste nicht als wählbar auf, wiegt nichts und lässt sich nicht
-- ablegen. Ersetzt das frühere DontStrip.
PD.WB.Always = {
    "mhands",
    "idcard"
}

PD.WB.DontStrip = PD.WB.Always -- alter Name

-- Reihenfolge und Limits der Kategorien. max = 0 bedeutet unbegrenzt.
PD.WB.Categories = {
    {name = "Primär Waffe", max = 1},
    {name = "Sekundär Waffe", max = 1},
    {name = "Granaten", max = 2},
    {name = "Gadget 1", max = 3},
    {name = "Gadget 2", max = 3},
    {name = "Sonstiges", max = 0}
}

-- Waffen ohne Kategoriezuordnung landen hier, statt aus der Kiste zu verschwinden.
PD.WB.DefaultCategory = "Sonstiges"
PD.WB.DefaultWeight = 0

PD.WB.Weapons = {}

PD.WB.Weapons["Primär Waffe"] = {
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

PD.WB.Weapons["Sekundär Waffe"] = {
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

PD.WB.Weapons["Gadget 2"] = {}
PD.WB.Weapons["Sonstiges"] = {}

--------------------------------------------------------------------------------
-- Konfiguration aus der Datenbank
--------------------------------------------------------------------------------

-- Die Werte oben sind ab hier nur noch Startwerte. Führend ist die Datenbank
-- (Tabellen pd_wb_*), die beim ersten Start aus genau diesen Werten befüllt
-- wird. Das Web-Panel schreibt dort hinein, der Server lädt neu und schickt die
-- Konfiguration an die Clients.
PD.WB.Defaults = {
    MaxWeight = PD.WB.MaxWeight,
    DefaultCategory = PD.WB.DefaultCategory,
    DefaultWeight = PD.WB.DefaultWeight,
    Always = table.Copy(PD.WB.Always),
    Categories = table.Copy(PD.WB.Categories),
    Weapons = table.Copy(PD.WB.Weapons)
}

-- Übernimmt eine Konfiguration. Auf beiden Realms benutzt: der Server nach dem
-- Laden aus der Datenbank, der Client nach dem Empfang über das Netz. Beide
-- müssen zwingend dieselben Werte haben, sonst rechnet die Anzeige anders als
-- die Serverprüfung.
function PD.WB.ApplyConfig(config)
    if not istable(config) then return end

    PD.WB.MaxWeight = tonumber(config.max_weight) or PD.WB.Defaults.MaxWeight
    PD.WB.MaxWeigth = PD.WB.MaxWeight
    PD.WB.DefaultWeight = tonumber(config.default_weight) or PD.WB.Defaults.DefaultWeight
    PD.WB.DefaultCategory = config.default_category or PD.WB.Defaults.DefaultCategory

    if istable(config.categories) and #config.categories > 0 then
        PD.WB.Categories = config.categories
    end

    if istable(config.weapons) then
        PD.WB.Weapons = config.weapons

        -- Jede Kategorie braucht einen Eintrag, sonst greifen die Suchen ins Leere
        for _, category in ipairs(PD.WB.Categories) do
            PD.WB.Weapons[category.name] = PD.WB.Weapons[category.name] or {}
        end
    end

    if istable(config.always) then
        PD.WB.Always = config.always
        PD.WB.DontStrip = PD.WB.Always
    end
end

--------------------------------------------------------------------------------
-- Kategorien und Gewichte
--------------------------------------------------------------------------------

function PD.WB.IsAlways(class)
    return table.HasValue(PD.WB.Always, class)
end

function PD.WB.GetCategoryData(name)
    for _, category in ipairs(PD.WB.Categories) do
        if category.name == name then
            return category
        end
    end

    return nil
end

function PD.WB.GetCategoryMax(name)
    local category = PD.WB.GetCategoryData(name)

    return category and category.max or 0
end

-- Kategorie einer Waffenklasse. Unbekannte Klassen landen in DefaultCategory,
-- damit Job-Ausrüstung nicht stillschweigend aus der Kiste verschwindet.
function PD.WB.GetWeaponCategory(class)
    for categoryName, weapons in pairs(PD.WB.Weapons) do
        if weapons[class] then
            return categoryName
        end
    end

    return PD.WB.DefaultCategory
end

function PD.WB.GetWeaponWeight(class)
    if PD.WB.IsAlways(class) then return 0 end

    for _, weapons in pairs(PD.WB.Weapons) do
        if weapons[class] then
            return weapons[class]
        end
    end

    return PD.WB.DefaultWeight
end

-- Alter Name, bleibt für bestehenden Code erhalten.
function PD.WB.GetWeaponWeights(class)
    return PD.WB.GetWeaponWeight(class)
end

--------------------------------------------------------------------------------
-- Verfügbare und getragene Ausrüstung
--------------------------------------------------------------------------------

-- Alles, was der Spieler aus der Kiste nehmen darf: Job, Subunit und - sofern
-- vorhanden - die durch Fortbildungen freigeschaltete Ausrüstung.
-- Bewusst dieselbe Implementierung auf beiden Realms, damit Client-Anzeige und
-- Server-Prüfung nicht auseinanderlaufen.
function PD.WB.GetAllowedClasses(ply)
    local allowed = {}

    if not IsValid(ply) then return allowed end

    local _, jobTbl = ply:GetJob()

    if istable(jobTbl) then
        for _, class in pairs(jobTbl.equip or {}) do
            allowed[class] = true
        end

        local _, subunit = PD.JOBS.GetSubUnit(jobTbl.unit)

        if istable(subunit) then
            for _, class in pairs(subunit.equip or {}) do
                allowed[class] = true
            end
        end
    end

    if PD.FB and PD.FB.GetCourseEquip and PD.FB.GetCharID then
        for _, class in ipairs(PD.FB.GetCourseEquip(PD.FB.GetCharID(ply))) do
            allowed[class] = true
        end
    end

    -- Immer-Ausrüstung ist nicht wählbar, sie wird automatisch gegeben.
    for _, class in ipairs(PD.WB.Always) do
        allowed[class] = nil
    end

    return allowed
end

-- Verfügbare Ausrüstung nach Kategorie: {[kategorie] = {klasse, ...}}
function PD.WB.GetAvailableByCategory(ply)
    local byCategory = {}

    for class in pairs(PD.WB.GetAllowedClasses(ply)) do
        local category = PD.WB.GetWeaponCategory(class)

        byCategory[category] = byCategory[category] or {}
        table.insert(byCategory[category], class)
    end

    for _, list in pairs(byCategory) do
        table.sort(list)
    end

    return byCategory
end

-- Was der Spieler gerade trägt, abgeleitet aus ply:GetWeapons(). Das ist die
-- einzige verlässliche Quelle - eine clientseitige Merkliste läuft nach Respawn,
-- Tod oder Jobwechsel aus dem Ruder.
function PD.WB.GetCarried(ply)
    local carried = {}

    if not IsValid(ply) then return carried end

    local allowed = PD.WB.GetAllowedClasses(ply)

    for _, weapon in ipairs(ply:GetWeapons()) do
        local class = weapon:GetClass()

        -- Nur Ausrüstung zählen, die aus der Kiste stammen kann. Admin-Werkzeug
        -- und Immer-Ausrüstung bleiben außen vor.
        if allowed[class] then
            local category = PD.WB.GetWeaponCategory(class)

            carried[category] = carried[category] or {}
            table.insert(carried[category], class)
        end
    end

    for _, list in pairs(carried) do
        table.sort(list)
    end

    return carried
end

function PD.WB.GetCarriedWeight(ply)
    local weight = 0

    for _, list in pairs(PD.WB.GetCarried(ply)) do
        for _, class in ipairs(list) do
            weight = weight + PD.WB.GetWeaponWeight(class)
        end
    end

    return weight
end

function PD.WB.GetCarriedInCategory(ply, category)
    local carried = PD.WB.GetCarried(ply)

    return carried[category] and #carried[category] or 0
end

-- Darf der Spieler diese Ausrüstung zusätzlich nehmen? Liefert den Grund mit,
-- damit Client und Server dieselbe Meldung anzeigen.
function PD.WB.CanTake(ply, class)
    if not IsValid(ply) then return false, "Ungültiger Spieler" end

    local allowed = PD.WB.GetAllowedClasses(ply)

    if not allowed[class] then
        return false, "Für deinen Job nicht freigegeben"
    end

    if ply:HasWeapon(class) then
        return false, "Bereits ausgerüstet"
    end

    local category = PD.WB.GetWeaponCategory(class)
    local max = PD.WB.GetCategoryMax(category)

    if max > 0 and PD.WB.GetCarriedInCategory(ply, category) >= max then
        return false, "Maximal " .. max .. " aus " .. category
    end

    local weight = PD.WB.GetWeaponWeight(class)

    if PD.WB.GetCarriedWeight(ply) + weight > PD.WB.MaxWeight then
        return false, "Zu schwer (max. " .. PD.WB.MaxWeight .. " Kg)"
    end

    return true
end
