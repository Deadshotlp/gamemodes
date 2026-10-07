--[[
    Naval - Kampfwerte (geteilt).

    Waffentypen (Naval.WeaponTypes): Schadensart energy (Strahlenschild)
    oder matter (Partikelschild), Schaden je Schuss, Reichweite (m),
    Kadenz (Schuss/min je Geschuetz), Grundtreffer, Fluggeschwindigkeit
    (nur Darstellung/Flugzeit), Munition begrenzt?

    Bewaffnung je Klasse (Naval.CombatDefaults[classId]): Batterien mit
    Typ, Anzahl, Feuerbogen (Zonen, in die sie schiessen kann) und Munition.
    Im Web-Panel ueberschreibbar: Klassen-Zusatzdaten {"combat": {...}}.

    Zonen: front, back, left, right, top, bottom (Naval.Zones).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval

Naval.WeaponTypes = {
    turbolaser = {name = "Turbolaser", dmgType = "energy", damage = 80, range = 60000, rof = 10, accuracy = 0.55, speed = 9000},
    heavyturbolaser = {name = "Schwerer Turbolaser", dmgType = "energy", damage = 220, range = 70000, rof = 4, accuracy = 0.5, speed = 8000},
    laser = {name = "Laserkanone", dmgType = "energy", damage = 6, range = 25000, rof = 40, accuracy = 0.7, speed = 14000},
    ion = {name = "Ionenkanone", dmgType = "ion", damage = 50, range = 45000, rof = 8, accuracy = 0.55, speed = 9000},
    pd = {name = "Punktverteidigung", dmgType = "energy", damage = 2, range = 8000, rof = 90, accuracy = 0.8, speed = 16000, pointDefense = true},
    missile = {name = "Erschütterungsraketen", dmgType = "matter", damage = 140, range = 40000, rof = 6, accuracy = 0.85, speed = 2500, ammo = true},
    torpedo = {name = "Protonentorpedos", dmgType = "matter", damage = 450, range = 30000, rof = 2, accuracy = 0.8, speed = 1800, ammo = true},
}

-- Reihenfolge fuers Netz (Index statt Name)
Naval.WeaponTypeList = {"turbolaser", "heavyturbolaser", "laser", "ion", "pd", "missile", "torpedo"}
Naval.WeaponTypeIndex = {}
for i, id in ipairs(Naval.WeaponTypeList) do Naval.WeaponTypeIndex[id] = i end

-- Energiesysteme des Maschinenraums
Naval.PowerSystems = {
    {id = "engines", name = "Antrieb"},
    {id = "shields", name = "Schilde"},
    {id = "weapons", name = "Waffen"},
    {id = "sensors", name = "Sensoren"},
}

Naval.SubsystemNames = {
    engines = "Haupttriebwerke", maneuver = "Manövriertriebwerke", hyperdrive = "Hyperantrieb",
    reactor = "Reaktor", bridge = "Brücke", sensors = "Sensoren", comms = "Kommunikation",
    shieldgen = "Schildgeneratoren", lifesupport = "Lebenserhaltung",
}

Naval.ZoneNames = {front = "Bug", back = "Heck", left = "Backbord", right = "Steuerbord", top = "Oben", bottom = "Unten"}

-- Welche Subsysteme ein Treffer aus einer Zone eher trifft
Naval.ZoneSubsystems = {
    front = {"sensors", "comms", "maneuver"},
    back = {"engines", "hyperdrive", "reactor"},
    left = {"shieldgen", "maneuver", "lifesupport"},
    right = {"shieldgen", "maneuver", "lifesupport"},
    top = {"bridge", "sensors", "comms"},
    bottom = {"reactor", "lifesupport", "hyperdrive"},
}

local ALL = {"front", "back", "left", "right", "top", "bottom"}
local FWD = {"front", "left", "right", "top"}
local SIDES = {"left", "right", "top", "front"}

local function B(type, count, arc, ammo) return {type = type, count = count, arc = arc, ammo = ammo} end


Naval.CombatDefaults = {
    venator = {B("heavyturbolaser", 8, FWD), B("laser", 24, ALL), B("pd", 20, ALL)},
    acclamator = {B("turbolaser", 12, FWD), B("laser", 24, ALL), B("missile", 4, {"front", "top"}, 80)},
    arquitens = {B("turbolaser", 4, {"front", "left", "right"}), B("laser", 6, ALL), B("missile", 2, {"front"}, 30)},
    pelta = {B("laser", 10, ALL), B("pd", 6, ALL)},
    cr90 = {B("turbolaser", 6, FWD), B("laser", 2, ALL)},
    consular = {B("laser", 2, {"front"})},
    munificent = {B("heavyturbolaser", 2, {"front"}), B("turbolaser", 26, SIDES), B("laser", 20, ALL), B("pd", 20, ALL)},
    recusant = {B("heavyturbolaser", 4, {"front"}), B("turbolaser", 12, SIDES), B("laser", 60, ALL), B("pd", 30, ALL)},
    providence = {B("turbolaser", 14, SIDES), B("laser", 34, ALL), B("torpedo", 4, {"front"}, 100), B("pd", 20, ALL)},
    lucrehulk = {B("turbolaser", 10, ALL), B("laser", 100, ALL), B("pd", 40, ALL)},
    bulwark = {B("turbolaser", 20, SIDES), B("laser", 30, ALL), B("missile", 10, {"front"}, 120)},
    frachter = {B("laser", 2, ALL)},
}

--[[
    Geschuetzstellungen (Stufe 4a). Liste je Klasse (class.hardpoints, in den
    Klassendaten) bzw. je Map-Profil fuer das Map-Schiff
    (Einstellung hardpoints_<profil>):
      {group = "Turbolaser Backbord", type = "turbolaser", count = 2,
       x, y, z  = Lage am Schiff in Schiffslaengen (x vorn, y links, z oben,
                  0 = Mitte, -0.5..0.5),
       yaw, pitch = Richtung der Stellung in Grad (0/0 = nach vorn,
                  yaw + = nach links, pitch + = nach oben),
       arcH, arcV = halber Feuerbogen waagerecht/senkrecht in Grad,
       ammo     = Munition (nur Raketen/Torpedos)}
    Stellungen derselben Gruppe bilden eine Batterie (Waffenleitstand). Eine
    Stellung feuert nur, wenn das Ziel in ihrem Bogen liegt. Ohne Stellungen
    gelten die pauschalen Batterien mit Zonen-Boegen.
]]

function Naval.HardpointDir(hp)
    local yaw, pitch = math.rad(tonumber(hp.yaw) or 0), math.rad(tonumber(hp.pitch) or 0)
    return {x = math.cos(pitch) * math.cos(yaw), y = math.cos(pitch) * math.sin(yaw), z = math.sin(pitch)}
end

-- dir: Richtung von der Stellung zum Ziel in Schiffsachsen (normiert)
function Naval.InArc(hp, dir)
    local arcH, arcV = tonumber(hp.arcH) or 90, tonumber(hp.arcV) or 60
    local pitch = math.deg(math.asin(math.Clamp(dir.z, -1, 1)))
    if math.abs(pitch - (tonumber(hp.pitch) or 0)) > arcV then return false end
    if arcH >= 180 or math.abs(dir.x) + math.abs(dir.y) < 1e-6 then return true end
    local yaw = math.deg(math.atan2(dir.y, dir.x))
    return math.abs(math.AngleDifference(yaw, tonumber(hp.yaw) or 0)) <= arcH
end

-- Stellungen zu Batterien buendeln (je Gruppe, Reihenfolge des ersten Auftretens)
local function GroupHardpoints(list)
    local weapons, byName = {}, {}
    for i, hp in ipairs(list) do
        if Naval.WeaponTypes[hp.type or ""] then
            local name = (hp.group and hp.group ~= "") and hp.group or ((Naval.WeaponTypes[hp.type].name or hp.type) .. " " .. i)
            local key = name .. "|" .. hp.type
            local b = byName[key]
            if not b then
                b = {type = hp.type, count = 0, group = name, hps = {}, ammo = 0}
                byName[key] = b
                weapons[#weapons + 1] = b
            end
            b.count = b.count + (tonumber(hp.count) or 1)
            b.ammo = b.ammo + (tonumber(hp.ammo) or 0)
            b.hps[#b.hps + 1] = i
        end
    end
    for _, b in ipairs(weapons) do
        if b.ammo <= 0 then b.ammo = nil end
    end
    return weapons
end

-- Kampfwerte einer Klasse: Panel-Daten (class.combat) vor Standard.
-- hardpoints (optional): Stellungen, die die Batterien ersetzen (Map-Profil);
-- sonst die der Klasse.
function Naval.ClassCombat(class, hardpoints)
    if not class then return {weapons = {}, shields = {perZone = 0, regen = 0, ratio = 0.7}, reactor = 100} end

    local custom = istable(class.combat) and class.combat or {}
    local hull = class.hull or 1000
    local hps = (istable(hardpoints) and #hardpoints > 0) and hardpoints or (istable(class.hardpoints) and #class.hardpoints > 0 and class.hardpoints) or nil

    return {
        hardpoints = hps,
        weapons = hps and GroupHardpoints(hps) or (istable(custom.weapons) and custom.weapons or Naval.CombatDefaults[class.id] or {}),
        shields = {
            perZone = custom.shields and tonumber(custom.shields.perZone) or math.Round(hull * 0.25),
            regen = custom.shields and tonumber(custom.shields.regen) or math.Round(hull * 0.002, 1),
            ratio = custom.shields and tonumber(custom.shields.ratio) or 0.7,
        },
        reactor = tonumber(custom.reactor) or 100,
    }
end

-- Zone, in der eine Richtung (Schiffsachsen) liegt
function Naval.ZoneOf(dir)
    local ax, ay, az = math.abs(dir.x), math.abs(dir.y), math.abs(dir.z)
    if ax >= ay and ax >= az then return dir.x >= 0 and "front" or "back" end
    if ay >= az then return dir.y >= 0 and "left" or "right" end
    return dir.z >= 0 and "top" or "bottom"
end

--[[
    Hangar und Staffeln (Stufe 4e). Eine Staffel = 12 Maschinen.
      fighter  Jaeger: gegen Staffeln, Begleitschutz, wenig gegen Schiffe
      bomber   Bomber: Torpedos gegen Schiffe, schwach gegen Jaeger
    Staffeln je Klasse: class.hangar = {fighter = n, bomber = m} (Panel),
    sonst Naval.HangarDefaults.
]]

Naval.SquadronTypes = {
    fighter = {name = "Jägerstaffel", craft = 12, speed = 900, vsCraft = 0.05, vsShip = 0.6, dmgType = "laser", pdHit = 1},
    bomber = {name = "Bomberstaffel", craft = 12, speed = 600, vsCraft = 0.015, vsShip = 9, dmgType = "torpedo", pdHit = 1.4},
}

Naval.SquadronTasks = {
    {id = "escort", name = "Begleitschutz"},
    {id = "attack", name = "Ziel angreifen"},
    {id = "intercept", name = "Staffeln abfangen"},
}

Naval.HangarDefaults = {
    venator = {fighter = 4, bomber = 2},
    acclamator = {fighter = 1},
    providence = {fighter = 6, bomber = 4},
    lucrehulk = {fighter = 12, bomber = 4},
    recusant = {fighter = 1},
    munificent = {fighter = 1},
    bulwark = {fighter = 2},
}

function Naval.ClassHangar(class)
    if not class then return {} end
    local h = istable(class.hangar) and class.hangar or {}
    if tonumber(h.fighter) or tonumber(h.bomber) then
        return {fighter = tonumber(h.fighter) or 0, bomber = tonumber(h.bomber) or 0}
    end
    local d = Naval.HangarDefaults[class.id] or {}
    return {fighter = d.fighter or 0, bomber = d.bomber or 0}
end

--[[
    Traktorstrahl (Stufe 4e): Staerke je Klasse (0 = keiner). Bestimmt
    Reichweite und wie gut sich nicht wehrlose Ziele losreissen koennen.
    class.tractor (Panel) ueberschreibt Naval.TractorDefaults.
]]
Naval.TractorDefaults = {
    venator = 1, acclamator = 0.7, arquitens = 0.4, consular = 0.3, pelta = 0.5,
    providence = 1, lucrehulk = 1.4, recusant = 0.7, munificent = 0.6, bulwark = 1,
}

function Naval.ClassTractor(class)
    if not class then return 0 end
    return tonumber(class.tractor) or Naval.TractorDefaults[class.id] or 0
end
