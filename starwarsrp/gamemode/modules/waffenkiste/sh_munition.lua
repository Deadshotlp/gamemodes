--[[
    Munitionskisten je Munitionsart.

    Jede Kiste gibt nur ihre eigene Munition aus. Die Kisten selbst sind die
    Entities pd_munitionskiste_<art> (Spawnmenue, Kategorie "PD - Gamemode"),
    alle mit der gemeinsamen Basis pd_munitionskiste. Hier steht, was sie
    ausgeben.

        name      Anzeigename an der Kiste
        ammo      Munitionstypen (Namen wie in SWEP.Primary.Ammo)
        perUse    Menge je Benutzung und Munitionstyp
        stock     Anzahl Benutzungen, bis die Kiste leer ist
        cooldown  Sekunden, bis eine leere Kiste wieder voll ist
        color     Farbe der Kiste und der Anzeige

    Eine neue Art: Eintrag hier ergaenzen und eine Datei
    entities/entities/pd_munitionskiste_<art>.lua nach dem Muster der
    vorhandenen anlegen.
]]

PD = PD or {}
PD.WB = PD.WB or {}

PD.WB.AmmoKinds = {
    blaster = {
        name = "Blaster-Energiezellen",
        ammo = {"ar2"},
        perUse = 100,
        stock = 100,
        cooldown = 40,
        color = Color(60, 140, 255),
    },
    granate = {
        name = "Handgranaten",
        ammo = {"grenade"},
        perUse = 1,
        stock = 20,
        cooldown = 120,
        color = Color(255, 170, 40),
    },
    ugl = {
        name = "UGL-Granaten",
        ammo = {"SMG1_Grenade"},
        perUse = 2,
        stock = 20,
        cooldown = 120,
        color = Color(90, 200, 90),
    },
    rakete = {
        name = "Raketen",
        ammo = {"RPG_Round"},
        perUse = 1,
        stock = 10,
        cooldown = 180,
        color = Color(220, 60, 60),
    },
}

-- Obergrenze je Munitionstyp aus dem Ammo-Modul (ammo/sh_maxammo.lua).
function PD.WB.GetMaxAmmo(ammoID)
    local jobs = Ammo and Ammo.config and Ammo.config.jobs
    local types = jobs and jobs[-99] and jobs[-99].types

    if not istable(types) then return 9999 end

    local entry = types[ammoID] or types[-99]

    return entry and tonumber(entry.maxammo) or 9999
end

if SERVER then
    local USE_COOLDOWN = 0.5

    --[[
        Munition aus einer Kiste nehmen. Gibt je Typ hoechstens so viel, wie bis
        zur Obergrenze fehlt. Bekommt der Spieler nichts, wird auch nichts vom
        Lager abgezogen.
    ]]
    function PD.WB.UseAmmoBox(box, ply)
        if not IsValid(box) or not IsValid(ply) or not ply:IsPlayer() then return end

        local now = CurTime()
        if (ply.PD_AmmoBoxNext or 0) > now then return end
        ply.PD_AmmoBoxNext = now + USE_COOLDOWN

        local kind = box:GetKind()
        if not kind then return end

        if box:GetStock() <= 0 then
            local rest = math.max(0, math.ceil(box:GetRefillAt() - now))
            PD.Notify("Die Kiste ist leer. Wieder voll in " .. rest .. " s.", Color(200, 150, 40), false, ply)
            return
        end

        local given = 0

        for _, name in ipairs(kind.ammo) do
            local id = game.GetAmmoID(name)

            if id and id >= 0 then
                local missing = PD.WB.GetMaxAmmo(id) - ply:GetAmmoCount(id)
                local amount = math.min(kind.perUse, missing)

                if amount > 0 then
                    ply:GiveAmmo(amount, id, true)
                    given = given + amount
                end
            end
        end

        if given == 0 then
            PD.Notify("Du trägst bereits die maximale Menge " .. kind.name .. ".", Color(200, 150, 40), false, ply)
            return
        end

        box:EmitSound("items/ammo_pickup.wav", 75, 100, 1)
        box:SetStock(box:GetStock() - 1)

        if box:GetStock() <= 0 then
            box:SetRefillAt(now + kind.cooldown)
        end
    end
end
