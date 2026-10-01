--[[
    Werte der ArcCW-Waffen aus der Datenbank.

    ArcCW-Waffen bringen ihre Werte fest im Addon mit. Wer sie aendern will,
    muesste sonst die Dateien im addons-Ordner anfassen - und beim naechsten
    Update des Addons ist die Aenderung wieder weg.

    Dieses Modul legt sich stattdessen daneben: die Ausgangswerte jeder Waffe
    werden beim Start festgehalten, Abweichungen kommen aus der Datenbank und
    werden darauf angewendet. Das Addon selbst bleibt unberuehrt.

    Drei Dinge sind einstellbar:
      * die Werte der Waffe selbst (Schaden, Feuerrate, Rueckstoss, Streuung)
      * die Schadensfaktoren je Trefferzone
      * die Werte der Aufsaetze
]]

PD = PD or {}
PD.ACW = PD.ACW or {}

-- Ausgangswerte, wie sie das Addon mitbringt. Wird einmal beim Start gefuellt
-- und danach nicht mehr angefasst - sie sind der Bezugspunkt fuer alles.
PD.ACW.Defaults = PD.ACW.Defaults or {}
PD.ACW.AttDefaults = PD.ACW.AttDefaults or {}

-- Abweichungen aus der Datenbank, nur die tatsaechlich gesetzten Felder.
PD.ACW.Overrides = PD.ACW.Overrides or {}
PD.ACW.AttOverrides = PD.ACW.AttOverrides or {}
PD.ACW.ZoneMults = PD.ACW.ZoneMults or {}

-- Gesperrte Aufsaetze. Unter "*" die ueberall gesperrten, sonst je Waffenklasse.
PD.ACW.Blocked = PD.ACW.Blocked or {}

--------------------------------------------------------------------------------
-- Was sich einstellen laesst
--------------------------------------------------------------------------------

--[[
    key    Schluessel im Panel und in der Datenbank
    swep   Feld in der Waffentabelle
    group  Ueberschrift im Panel
    whole  ganze Zahl statt Kommazahl
    invert Waffe und Panel rechnen umgekehrt, siehe PD.ACW.Convert

    Bei der Feuerrate steht in der Waffe nicht die Rate, sondern der Abstand
    zwischen zwei Schuessen (Delay = 60 / 300 fuer 300 Schuss pro Minute). Im
    Panel steht die Zahl, die man auch im Kopf hat.
]]
PD.ACW.Fields = {
    {key = "damage",          swep = "Damage",           label = "Schaden nah",          group = "Schaden"},
    {key = "damage_min",      swep = "DamageMin",        label = "Schaden fern",         group = "Schaden"},
    {key = "range_min",       swep = "RangeMin",         label = "Voller Schaden bis",   group = "Schaden", unit = "m"},
    {key = "range",           swep = "Range",            label = "Mindestschaden ab",    group = "Schaden", unit = "m"},
    {key = "penetration",     swep = "Penetration",      label = "Durchschlag",          group = "Schaden"},
    {key = "num",             swep = "Num",              label = "Projektile je Schuss", group = "Schaden", whole = true},

    {key = "rpm",             swep = "Delay",            label = "Schuss pro Minute",    group = "Feuer", whole = true, invert = 60},
    {key = "muzzle_velocity", swep = "MuzzleVelocity",   label = "Projektiltempo",       group = "Feuer"},

    {key = "recoil",          swep = "Recoil",           label = "Rueckstoss",           group = "Handhabung"},
    {key = "recoil_side",     swep = "RecoilSide",       label = "Rueckstoss seitlich",  group = "Handhabung"},
    {key = "recoil_rise",     swep = "RecoilRise",       label = "Rueckstoss Anstieg",   group = "Handhabung"},
    {key = "accuracy_moa",    swep = "AccuracyMOA",      label = "Streuung",             group = "Handhabung", unit = "MOA"},
    {key = "hip_dispersion",  swep = "HipDispersion",    label = "Streuung Huefte",      group = "Handhabung"},
    {key = "move_dispersion", swep = "MoveDispersion",   label = "Streuung Bewegung",    group = "Handhabung"},
    {key = "sight_time",      swep = "SightTime",        label = "Zielzeit",             group = "Handhabung", unit = "s"},
    {key = "speed_mult",      swep = "SpeedMult",        label = "Tempo mit Waffe",      group = "Handhabung"},
    {key = "sighted_speed",   swep = "SightedSpeedMult", label = "Tempo im Visier",      group = "Handhabung"},
    {key = "jump_dispersion", swep = "JumpDispersion",   label = "Streuung im Sprung",   group = "Handhabung"},
    {key = "sights_dispersion", swep = "SightsDispersion", label = "Streuung im Visier", group = "Handhabung"},
    {key = "recoil_punch",    swep = "RecoilPunch",      label = "Kameraschlag",         group = "Handhabung"},
    {key = "visual_recoil",   swep = "VisualRecoilMult", label = "Sichtbarer Rueckstoss",group = "Handhabung"},
    {key = "sway",            swep = "Sway",             label = "Schwanken",            group = "Handhabung"},

    {key = "clip_size",       swep = "Primary.ClipSize", label = "Magazin",              group = "Munition", whole = true},
    {key = "clip_extended",   swep = "ExtendedClipSize", label = "Magazin gross",        group = "Munition", whole = true},
    {key = "clip_reduced",    swep = "ReducedClipSize",  label = "Magazin klein",        group = "Munition", whole = true},
    {key = "ammo_per_shot",   swep = "AmmoPerShot",      label = "Verbrauch je Schuss",  group = "Munition", whole = true},
    {key = "damage_rand",     swep = "DamageRand",       label = "Schadensstreuung",     group = "Munition"},

    {key = "heat_capacity",   swep = "HeatCapacity",     label = "Hitze bis Sperre",     group = "Hitze"},
    {key = "heat_gain",       swep = "HeatGain",         label = "Hitze je Schuss",      group = "Hitze"},
    {key = "heat_dissipation",swep = "HeatDissipation",  label = "Abkuehlung",           group = "Hitze"},
    {key = "heat_delay",      swep = "HeatDelayTime",    label = "Verzoegerung",         group = "Hitze", unit = "s"},

    {key = "melee_damage",    swep = "MeleeDamage",      label = "Nahkampfschaden",      group = "Nahkampf"},
    {key = "melee_range",     swep = "MeleeRange",       label = "Nahkampfreichweite",   group = "Nahkampf"}
}

-- Trefferzonen. Die Nummern kommen von Source, nicht von ArcCW.
PD.ACW.Zones = {
    {key = "head",     group = HITGROUP_HEAD,     label = "Kopf"},
    {key = "chest",    group = HITGROUP_CHEST,    label = "Brust"},
    {key = "stomach",  group = HITGROUP_STOMACH,  label = "Bauch"},
    {key = "leftarm",  group = HITGROUP_LEFTARM,  label = "Linker Arm"},
    {key = "rightarm", group = HITGROUP_RIGHTARM, label = "Rechter Arm"},
    {key = "leftleg",  group = HITGROUP_LEFTLEG,  label = "Linkes Bein"},
    {key = "rightleg", group = HITGROUP_RIGHTLEG, label = "Rechtes Bein"},
    {key = "gear",     group = HITGROUP_GEAR,     label = "Ausruestung"}
}

--[[
    Felder der Aufsaetze.

    Mult_ sind Faktoren auf den Wert der Waffe: 1 heisst unveraendert, 0.9 sind
    zehn Prozent weniger. Belegt sind sie in den Aufsatzdateien der
    Inhaltspakete, etwa mode_overcharged.lua mit Mult_Damage = 1.2.
]]
PD.ACW.AttFields = {
    {key = "mult_damage",          att = "Mult_Damage",         label = "Schaden"},
    {key = "mult_rpm",             att = "Mult_RPM",            label = "Feuerrate"},
    {key = "mult_range",           att = "Mult_Range",          label = "Reichweite"},
    {key = "mult_penetration",     att = "Mult_Penetration",    label = "Durchschlag"},
    {key = "mult_recoil",          att = "Mult_Recoil",         label = "Rueckstoss"},
    {key = "mult_recoil_side",     att = "Mult_RecoilSide",     label = "Rueckstoss seitlich"},
    {key = "mult_accuracy_moa",    att = "Mult_AccuracyMOA",    label = "Streuung"},
    {key = "mult_move_dispersion", att = "Mult_MoveDispersion", label = "Streuung Bewegung"},
    {key = "mult_sight_time",      att = "Mult_SightTime",      label = "Zielzeit"},
    {key = "mult_speed",           att = "Mult_MoveSpeed",      label = "Tempo"},
    {key = "mult_visual_recoil",   att = "Mult_VisualRecoilMult", label = "Sichtbarer Rueckstoss"},
    {key = "clip_size",            att = "OverrideClipSize",    label = "Magazin (fest)", whole = true}
}

--------------------------------------------------------------------------------
-- Umrechnung zwischen Panel und Waffentabelle
--------------------------------------------------------------------------------

--[[
    Manche Felder stehen in der Waffe anders herum als im Panel. Bei der
    Feuerrate ist es dieselbe Rechnung in beide Richtungen (60 geteilt durch
    den Wert), deshalb genuegt eine Funktion fuer hin und zurueck.
]]
function PD.ACW.Convert(field, value)
    value = tonumber(value)
    if value == nil then return nil end

    if field.invert then
        if value <= 0 then return 0 end

        return field.invert / value
    end

    return value
end

--------------------------------------------------------------------------------
-- Erkennung
--------------------------------------------------------------------------------

--[[
    Gehoert die Waffe zu ArcCW?

    Der Klassenname allein reicht nicht: die Inhaltspakete erben von eigenen
    Basen wie arccw_masita_base_updated, die ihrerseits von arccw_base erben.
    Deshalb wird die Basiskette mit abgelaufen.
]]
function PD.ACW.IsArcCW(class, swep)
    if not istable(swep) then return false end

    -- Ohne diese Felder gibt es nichts zu aendern, egal welche Basis.
    if not isnumber(swep.Damage) or not isnumber(swep.DamageMin) then
        return false
    end

    -- ArcCW setzt dieses Feld auf jeder seiner Waffen. Das ist verlaesslicher
    -- als der Klassenname oder die Basiskette und wird deshalb zuerst geprueft.
    if swep.ArcCW == true then
        return true
    end

    if string.StartWith(string.lower(class or ""), "arccw") then
        return true
    end

    local base = swep.Base
    local depth = 0

    while isstring(base) and depth < 10 do
        if string.find(string.lower(base), "arccw", 1, true) then
            return true
        end

        local parent = weapons.GetStored(base)
        base = istable(parent) and parent.Base or nil
        depth = depth + 1
    end

    return false
end

--[[
    Die Registrierung der Aufsaetze.

    ArcCW legt sie in eine eigene Tabelle. Deren Name steht nicht in den
    Inhaltspaketen, sondern im Grundaddon - und das liegt als Workshop-Paket
    nicht auf der Platte. Deshalb wird der uebliche Name zuerst probiert und
    danach die bekannten Alternativen. pd_arccw_probe zeigt, was da ist.
]]
function PD.ACW.AttachmentRegistry()
    if not istable(ArcCW) then return nil, "ArcCW ist nicht geladen" end

    for _, name in ipairs({"AttachmentTable", "Attachments", "AttTable"}) do
        local candidate = ArcCW[name]

        if istable(candidate) and table.Count(candidate) > 0 then
            return candidate, name
        end
    end

    return nil, "keine Aufsatztabelle in ArcCW gefunden"
end

--------------------------------------------------------------------------------
-- Sollwerte
--------------------------------------------------------------------------------

local function merge(defaults, override, fields)
    if not istable(defaults) then return nil end

    local out = {}
    override = override or {}

    for _, field in ipairs(fields) do
        local value = override[field.key]

        if value == nil then
            out[field.key] = defaults[field.key]
        else
            out[field.key] = value
        end
    end

    return out
end

-- Die Werte, die fuer eine Waffe gelten sollen.
function PD.ACW.Effective(class)
    return merge(PD.ACW.Defaults[class], PD.ACW.Overrides[class], PD.ACW.Fields)
end

-- Dasselbe fuer einen Aufsatz.
function PD.ACW.EffectiveAtt(id)
    return merge(PD.ACW.AttDefaults[id], PD.ACW.AttOverrides[id], PD.ACW.AttFields)
end

--------------------------------------------------------------------------------
-- Anwenden
--------------------------------------------------------------------------------

--[[
    Werte auf eine Waffentabelle schreiben.

    Gilt fuer die gespeicherte Vorlage genauso wie fuer eine Waffe, die schon in
    jemandes Haenden liegt: ArcCW liest self.Damage beim Schuss, deshalb wirkt
    die Aenderung sofort und nicht erst beim naechsten Aufheben.
]]
--[[
    Ein Feld lesen, das in einer Untertabelle liegt - Primary.ClipSize etwa.
]]
function PD.ACW.GetField(tbl, path)
    local node = tbl

    for _, part in ipairs(string.Explode(".", path)) do
        if not istable(node) then return nil end

        node = node[part]
    end

    return node
end

--[[
    Dasselbe zum Schreiben.

    Untertabellen werden vorher kopiert. Waffen, die Primary nicht selbst
    setzen, teilen sich sonst die Tabelle ihrer Basis - eine Aenderung am
    Magazin der einen Waffe wuerde dann alle anderen mitziehen.
]]
function PD.ACW.SetField(tbl, path, value)
    local parts = string.Explode(".", path)

    if #parts == 1 then
        tbl[path] = value
        return
    end

    local node = tbl

    for index = 1, #parts - 1 do
        local part = parts[index]

        if not istable(node[part]) then
            node[part] = {}
        else
            node[part] = table.Copy(node[part])
        end

        node = node[part]
    end

    node[parts[#parts]] = value
end

--[[
    Werte auf eine Waffentabelle schreiben.

    Zwei Feinheiten, die beide teuer waren:

    Gerundet wird der Wert aus dem Panel, nicht der aus der Waffe. Bei der
    Feuerrate ist der Panelwert 300 und der Waffenwert 0.2 - wer den Waffenwert
    rundet, macht daraus eine 0, und die Waffe feuert ohne jede Pause.

    Geschrieben wird nur, was die Waffe auch vorher hatte, oder was ausdruecklich
    eingestellt wurde. Sonst legt das Modul Felder an, die es im Addon nie gab,
    und ArcCW wertet sie aus - ein OverrideClipSize von 0 etwa nimmt der Waffe
    das Magazin.
]]
function PD.ACW.ApplyTo(target, values, allowed)
    if not istable(target) or not istable(values) then return end

    for _, field in ipairs(PD.ACW.Fields) do
        if allowed and not allowed[field.key] then continue end

        local raw = tonumber(values[field.key])

        if raw ~= nil then
            if field.whole then raw = math.Round(raw) end

            PD.ACW.SetField(target, field.swep, PD.ACW.Convert(field, raw))
        end
    end
end

function PD.ACW.ApplyToAtt(target, values, allowed)
    if not istable(target) or not istable(values) then return end

    for _, field in ipairs(PD.ACW.AttFields) do
        if allowed and not allowed[field.key] then continue end

        local value = tonumber(values[field.key])

        if value ~= nil then
            target[field.att] = field.whole and math.Round(value) or value
        end
    end
end

--[[
    Eine Waffenklasse auf ihren aktuellen Sollzustand bringen - Vorlage und alle
    bereits existierenden Exemplare.
]]
--[[
    Welche Felder ueberhaupt geschrieben werden duerfen: die, die das Addon
    selbst mitbringt, plus die, die jemand ausdruecklich eingestellt hat.
]]
local function allowedFields(fields, defaults, override)
    local allowed = {}

    for _, field in ipairs(fields) do
        local present = istable(defaults.present) and defaults.present[field.key]

        allowed[field.key] = present or (istable(override) and override[field.key] ~= nil)
    end

    return allowed
end

function PD.ACW.Refresh(class)
    local defaults = PD.ACW.Defaults[class]
    if not defaults then return false end

    local values = PD.ACW.Effective(class)
    if not values then return false end

    local allowed = allowedFields(PD.ACW.Fields, defaults, PD.ACW.Overrides[class])

    local stored = weapons.GetStored(class)
    if istable(stored) then
        PD.ACW.ApplyTo(stored, values, allowed)
    end

    for _, wep in ipairs(ents.FindByClass(class)) do
        if IsValid(wep) then
            PD.ACW.ApplyTo(wep:GetTable(), values, allowed)
        end
    end

    return true
end

function PD.ACW.RefreshAll()
    local count = 0

    for class in pairs(PD.ACW.Defaults) do
        if PD.ACW.Refresh(class) then
            count = count + 1
        end
    end

    return count
end

function PD.ACW.RefreshAttachments()
    local registry = PD.ACW.AttachmentRegistry()
    if not registry then return 0 end

    local count = 0

    for id, defaults in pairs(PD.ACW.AttDefaults) do
        local entry = registry[id]

        if istable(entry) then
            local allowed = allowedFields(PD.ACW.AttFields, defaults, PD.ACW.AttOverrides[id])

            PD.ACW.ApplyToAtt(entry, PD.ACW.EffectiveAtt(id), allowed)
            count = count + 1
        end
    end

    return count
end

--------------------------------------------------------------------------------
-- Trefferzonen
--------------------------------------------------------------------------------

--[[
    Faktor fuer eine Trefferzone.

    Erst die Einstellung fuer genau diese Waffe, sonst die allgemeine unter dem
    Schluessel "*", sonst 1 - also unveraendert.
]]
function PD.ACW.ZoneMult(class, hitgroup)
    local zone

    for _, entry in ipairs(PD.ACW.Zones) do
        if entry.group == hitgroup then
            zone = entry.key
            break
        end
    end

    if not zone then return 1 end

    local perWeapon = PD.ACW.ZoneMults[class or ""]
    if istable(perWeapon) and isnumber(perWeapon[zone]) then
        return perWeapon[zone]
    end

    local general = PD.ACW.ZoneMults["*"]
    if istable(general) and isnumber(general[zone]) then
        return general[zone]
    end

    return 1
end

--------------------------------------------------------------------------------
-- Gesperrte Aufsaetze
--------------------------------------------------------------------------------

--[[
    Darf dieser Aufsatz an diese Waffe?

    Zwei Ebenen: unter "*" stehen die Aufsaetze, die es auf dem Server gar nicht
    geben soll, unter dem Klassennamen die, die nur an dieser einen Waffe nicht
    erlaubt sind.
]]
function PD.ACW.IsBlocked(class, attID)
    if not isstring(attID) or attID == "" then return false end

    local everywhere = PD.ACW.Blocked["*"]
    if istable(everywhere) and everywhere[attID] then return true end

    local perWeapon = PD.ACW.Blocked[class or ""]
    if istable(perWeapon) and perWeapon[attID] then return true end

    return false
end

--------------------------------------------------------------------------------
-- Sperren durchsetzen - auf Server und Client
--------------------------------------------------------------------------------

--[[
    Warum das hier steht und nicht mehr in sv_arccw.lua:

    ArcCWs Aufsatzmenue laeuft beim Client. Solange die Sperre nur auf dem
    Server galt, bot das Menue gesperrte Aufsaetze trotzdem an. Dazu baut ArcCW
    die Liste je Steckplatz ueber SlotAcceptsAtt und GetAttsForSlot und merkt
    sie sich in AttachmentCachedLists - beide Funktionen waren nicht
    umschlossen, und eine einmal gebaute Liste blieb stehen. So konnte dieselbe
    Sperre an der einen Waffe alles ausblenden und an der anderen nichts.
]]

-- Originale der ArcCW-Funktionen. Ueberlebt einen Lua-Refresh, damit nicht
-- jeder Refresh eine weitere Huelle um die vorige legt.
PD.ACW.OriginalFns = PD.ACW.OriginalFns or {}

-- Eigenes RejectAttachments der Waffe, wie das Addon es mitbringt (false: keins).
PD.ACW.OriginalReject = PD.ACW.OriginalReject or {}

local cachedRegistry

local function registry()
    if not cachedRegistry then
        cachedRegistry = PD.ACW.AttachmentRegistry()
    end

    return cachedRegistry
end

--[[
    Ist die Zeichenkette eine Aufsatzkennung?

    AttDefaults fuellt nur der Server beim Start. Auf dem Client ist die
    Tabelle leer - dort hilft nur ArcCWs eigene Registrierung.
]]
local function isAttID(value)
    if PD.ACW.AttDefaults[value] then return true end

    local reg = registry()

    return reg ~= nil and istable(reg[value])
end

--[[
    Waffenklasse und Aufsatz aus den Argumenten einer ArcCW-Funktion suchen.

    Die Reihenfolge wird nicht angenommen, sondern gesucht. Als Waffe zaehlt nur
    eine Entity, die IsWeapon() bejaht: PlayerCanAttach bekommt den Spieler vor
    der Waffe, und frueher landete dessen Klasse "player" als Waffenklasse in der
    Pruefung - die Sperre je Waffe griff dort nie.
]]
local function argsOf(...)
    local class, attID

    for index = 1, select("#", ...) do
        local value = select(index, ...)

        if isstring(value) then
            if not attID and isAttID(value) then attID = value end
        elseif isentity(value) then
            -- isentity zuerst: IsValid bricht bei Zahlen ab.
            if not class and IsValid(value) and value:IsWeapon() then
                class = value:GetClass()
            end
        elseif istable(value) and isstring(value.ShortName) then
            if not attID then attID = value.ShortName end
        end
    end

    return class, attID
end

local function passesTrue(...)
    for index = 1, select("#", ...) do
        if select(index, ...) == true then return true end
    end

    return false
end

--[[
    ArcCW-Funktionen umschliessen - auf beiden Seiten.

    Die globale Sperre (*) wird immer geprueft, auch wenn keine Waffe
    uebergeben wird; WeaponAcceptsAtt bekommt nie eine, und frueher fiel die
    Pruefung dort deshalb ganz aus. Die Sperre je Waffe greift nur, wenn eine
    Waffe dabei ist.

    Abnehmen bleibt immer erlaubt: PlayerCanAttach wird auch fuer das Entfernen
    gefragt (letztes Argument true). Wuerde das verweigert, liesse sich ein
    gesperrter, aber schon verbauter Aufsatz nie mehr loswerden.
]]
function PD.ACW.WrapChecks()
    if not istable(ArcCW) then return 0 end

    local count = 0

    for _, name in ipairs({"SlotAcceptsAtt", "WeaponAcceptsAtt", "PlayerCanAttach"}) do
        local original = PD.ACW.OriginalFns[name] or ArcCW[name]

        if isfunction(original) then
            PD.ACW.OriginalFns[name] = original

            ArcCW[name] = function(...)
                if not (name == "PlayerCanAttach" and passesTrue(...)) then
                    local class, attID = argsOf(...)

                    if attID and PD.ACW.IsBlocked(class, attID) then
                        return false
                    end
                end

                return original(...)
            end

            count = count + 1
        end
    end

    local originalList = PD.ACW.OriginalFns.GetAttsForSlot or ArcCW.GetAttsForSlot

    if isfunction(originalList) then
        PD.ACW.OriginalFns.GetAttsForSlot = originalList

        -- Die Liste wird gefiltert zurueckgegeben, nie veraendert: sie kann
        -- ArcCWs zwischengespeicherte Tabelle selbst sein.
        ArcCW.GetAttsForSlot = function(...)
            local result = originalList(...)

            if not istable(result) then return result end

            local class = argsOf(...)
            local out = {}

            local function blocked(entry, key)
                local id = (isstring(entry) and entry)
                    or (istable(entry) and entry.ShortName)
                    or (isstring(key) and key)

                return isstring(id) and PD.ACW.IsBlocked(class, id)
            end

            if result[1] ~= nil then
                for _, entry in ipairs(result) do
                    if not blocked(entry) then out[#out + 1] = entry end
                end
            else
                for key, entry in pairs(result) do
                    if not blocked(entry, key) then out[key] = entry end
                end
            end

            return out
        end

        count = count + 1
    end

    return count
end

local function clearInPlace(tbl)
    if not istable(tbl) then return end

    for key in pairs(tbl) do
        tbl[key] = nil
    end
end

--[[
    Sperre je Waffe ueber ArcCWs eigenes RejectAttachments.

    Aufgebaut aus dem, was das Addon selbst mitbringt, plus Sperrliste. Faellt
    die letzte Sperre einer Waffe weg, wird das Feld wieder geleert und die
    Waffe erbt wie vorher vom Grundaddon.
]]
local function applyRejects(class, set)
    local stored = weapons.GetStored(class)
    if not istable(stored) then return end

    if PD.ACW.OriginalReject[class] == nil then
        local own = rawget(stored, "RejectAttachments")

        PD.ACW.OriginalReject[class] = istable(own) and table.Copy(own) or false
    end

    local original = PD.ACW.OriginalReject[class]
    local merged = nil

    if original or (istable(set) and next(set) ~= nil) then
        merged = original and table.Copy(original) or {}

        for id in pairs(set or {}) do
            merged[id] = true
        end
    end

    stored.RejectAttachments = merged

    for _, wep in ipairs(ents.FindByClass(class)) do
        if IsValid(wep) then
            wep.RejectAttachments = merged
        end
    end
end

--[[
    Die Sperrliste anwenden. Laeuft auf dem Server nach dem Laden aus der
    Datenbank und auf dem Client nach jedem Sync.
]]
function PD.ACW.ApplyBlocks()
    local count = 0
    local reg = registry()
    local everywhere = PD.ACW.Blocked["*"] or {}
    local arccwOwn = istable(ArcCW) and ArcCW.AttachmentBlacklistTable or nil

    if reg then
        for id, att in pairs(reg) do
            if istable(att) then
                -- ArcCWs eigene Blacklist bleibt erhalten, statt ueberschrieben zu werden.
                local blocked = everywhere[id] == true
                    or (istable(arccwOwn) and arccwOwn[id] == true)

                att.Blacklisted = blocked

                if everywhere[id] then count = count + 1 end
            end
        end
    end

    local classes = {}

    for class in pairs(PD.ACW.Blocked) do
        if class ~= "*" then classes[class] = true end
    end

    for class in pairs(PD.ACW.OriginalReject) do
        classes[class] = true
    end

    for class in pairs(classes) do
        applyRejects(class, PD.ACW.Blocked[class])
    end

    -- Zwischengespeicherte Listen verwerfen, sonst behaelt eine Waffe die Liste,
    -- die vor der Aenderung gebaut wurde.
    if istable(ArcCW) then
        clearInPlace(ArcCW.AttachmentCachedLists)
    end

    PD.ACW.WrapChecks()

    return count
end

--------------------------------------------------------------------------------
-- Diagnose
--------------------------------------------------------------------------------

local function fmt(value)
    if value == true then return "ja" end
    if value == false then return "nein" end
    if value == nil then return "-" end

    return tostring(value)
end

local function tryCall(fn, ...)
    if not isfunction(fn) then return "fehlt" end

    local ok, result = pcall(fn, ...)

    if not ok then return "Fehler" end

    return result
end

local function countOf(value)
    if istable(value) then return tostring(table.Count(value)) end

    return fmt(value)
end

--[[
    pd_arccw_blockcheck <klasse> [steckplatz]

    Laeuft in der Serverkonsole und im Client, damit beide Seiten
    nebeneinanderliegen. Fuer jeden Aufsatz, der auf die Waffe passt, steht die
    Antwort von ArcCW selbst neben der Antwort mit Sperre.
]]
concommand.Add("pd_arccw_blockcheck", function(ply, _, args)
    if SERVER and IsValid(ply) and not ply:IsSuperAdmin() then return end

    local realm = SERVER and "Server" or "Client"

    local function out(text)
        print("[ArcCW " .. realm .. "] " .. text)
    end

    local class = args[1]
    local slotFilter = args[2]

    if not class or class == "" then
        out("Aufruf: pd_arccw_blockcheck <klasse> [steckplatz]")
        return
    end

    if not istable(ArcCW) then
        out("ArcCW ist nicht geladen.")
        return
    end

    local merged = weapons.Get(class)

    if not istable(merged) then
        out("Die Waffe " .. class .. " gibt es nicht.")
        return
    end

    local everywhere = PD.ACW.Blocked["*"] or {}
    local perWeapon = PD.ACW.Blocked[class] or {}

    out("Sperren: " .. table.Count(everywhere) .. " ueberall, " .. table.Count(perWeapon) .. " fuer " .. class)

    local wep

    if CLIENT then
        local lp = LocalPlayer()
        if IsValid(lp) then wep = lp:GetWeapon(class) end
    else
        for _, candidate in ipairs(ents.FindByClass(class)) do
            if IsValid(candidate) then
                wep = candidate
                break
            end
        end
    end

    if not IsValid(wep) then wep = nil end

    out("Lebendes Exemplar: " .. (wep and tostring(wep) or "keins - geprueft wird mit den Klassendaten"))

    local reject = (wep and wep.RejectAttachments) or merged.RejectAttachments
    local rejectCount = 0

    for key, value in pairs(istable(reject) and reject or {}) do
        if isstring(key) and value == true then rejectCount = rejectCount + 1 end
    end

    out("RejectAttachments: " .. rejectCount .. " Eintraege")

    -- Steckplaetze der Waffe
    local slots = {}

    for _, entry in pairs(istable(merged.Attachments) and merged.Attachments or {}) do
        local slot = istable(entry) and entry.Slot

        if isstring(slot) then
            slots[slot] = true
        elseif istable(slot) then
            for _, name in pairs(slot) do
                if isstring(name) then slots[name] = true end
            end
        end
    end

    local target = wep or merged
    local own = PD.ACW.OriginalFns
    local shown, fitting = 0, 0

    out("Aufsatz  |  gesperrt  Blacklisted  |  SlotAcceptsAtt ArcCW/mit Sperre  |  WeaponAcceptsAtt ArcCW/mit Sperre")

    for id, att in SortedPairs(registry() or {}) do
        if istable(att) then
            local matched

            if isstring(att.Slot) and slots[att.Slot] then
                matched = att.Slot
            elseif istable(att.Slot) then
                for _, name in pairs(att.Slot) do
                    if slots[name] then
                        matched = name
                        break
                    end
                end
            end

            if matched and (not slotFilter or matched == slotFilter) then
                fitting = fitting + 1

                if shown < 60 then
                    shown = shown + 1

                    out(string.format("  %-30s %-10s | %-4s %-4s | %s/%s | %s/%s",
                        id, matched,
                        fmt(PD.ACW.IsBlocked(class, id)), fmt(att.Blacklisted),
                        fmt(tryCall(own.SlotAcceptsAtt or ArcCW.SlotAcceptsAtt, ArcCW, matched, target, id)),
                        fmt(tryCall(ArcCW.SlotAcceptsAtt, ArcCW, matched, target, id)),
                        fmt(tryCall(own.WeaponAcceptsAtt or ArcCW.WeaponAcceptsAtt, ArcCW, matched, id)),
                        fmt(tryCall(ArcCW.WeaponAcceptsAtt, ArcCW, matched, id))))
                end
            end
        end
    end

    out(fitting .. " passende Aufsaetze" .. (fitting > shown and (", " .. shown .. " gezeigt") or ""))

    local listSlot = slotFilter or "perk"

    out("GetAttsForSlot(" .. listSlot .. "): ArcCW "
        .. countOf(tryCall(own.GetAttsForSlot or ArcCW.GetAttsForSlot, ArcCW, listSlot, target))
        .. ", mit Sperre " .. countOf(tryCall(ArcCW.GetAttsForSlot, ArcCW, listSlot, target)))

    local cache = ArcCW.AttachmentCachedLists

    if istable(cache) then
        local keys = {}

        for key in pairs(cache) do
            keys[#keys + 1] = tostring(key)
            if #keys >= 10 then break end
        end

        out("AttachmentCachedLists: " .. table.Count(cache) .. " Eintraege"
            .. (#keys > 0 and (" (" .. table.concat(keys, ", ") .. ")") or ""))
    end

    if wep and istable(wep.Attachments) then
        for index, entry in pairs(wep.Attachments) do
            if istable(entry) and isstring(entry.Installed) then
                out("  verbaut an " .. tostring(entry.PrintName or index) .. ": " .. entry.Installed
                    .. (PD.ACW.IsBlocked(class, entry.Installed) and "   <- GESPERRT" or ""))
            end
        end
    end

    local methods, seen = {}, {}
    local node, depth = merged, 0

    while istable(node) and depth < 6 do
        for key, value in pairs(node) do
            if isstring(key) and isfunction(value) and not seen[key]
                and string.find(string.lower(key), "ttach", 1, true) then
                seen[key] = true
                methods[#methods + 1] = key
            end
        end

        node = node.BaseClass
        depth = depth + 1
    end

    table.sort(methods)

    out("Methoden mit 'ttach': " .. (#methods > 0 and table.concat(methods, ", ") or "keine gefunden"))
end)


--------------------------------------------------------------------------------
-- Falsche Soundpfade der Kraken-Packs
--------------------------------------------------------------------------------

--[[
    UGL-Aufsatz, UGL-Granaten und DC-17m-Werfer spielen ihre Sounds unter
    "arccw/rep_ubgl/...", das Pack "Kraken's Effects & Resources" liefert die
    Dateien aber unter "rep_ubgl/..." aus. Die Sounds gab es also schlicht
    nicht - weder Abschuss noch Einschlag waren zu hoeren.

    Beim Abspielen wird der Pfad umgeschrieben. Laeuft auf Server und Client,
    weil ArcCW Waffensounds auf beiden Seiten abspielt.
]]
PD.ACW.SoundPathFixes = {
    ["arccw/rep_ubgl/"] = "rep_ubgl/",
}

function PD.ACW.FixSoundPath(snd)
    if not isstring(snd) then return snd end

    for wrong, right in pairs(PD.ACW.SoundPathFixes) do
        local s, e = string.find(snd, wrong, 1, true)

        if s then
            return string.sub(snd, 1, s - 1) .. right .. string.sub(snd, e + 1)
        end
    end

    return snd
end

hook.Add("EntityEmitSound", "PD.ACW.FixSoundPaths", function(data)
    local fixed = PD.ACW.FixSoundPath(data.SoundName)

    if fixed ~= data.SoundName then
        data.SoundName = fixed
        return true
    end
end)
