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

-- Kampfwerte einer Klasse: Panel-Daten (class.combat) vor Standard
function Naval.ClassCombat(class)
    if not class then return {weapons = {}, shields = {perZone = 0, regen = 0, ratio = 0.7}, reactor = 100} end

    local custom = istable(class.combat) and class.combat or {}
    local hull = class.hull or 1000

    return {
        weapons = istable(custom.weapons) and custom.weapons or Naval.CombatDefaults[class.id] or {},
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
