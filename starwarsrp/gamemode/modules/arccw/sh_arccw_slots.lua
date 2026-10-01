--[[
    Zusaetzliche Aufsatz-Slots fuer ArcCW-Waffen.

    Manche Aufsaetze passen technisch an eine Waffe, das Addon sieht den Slot
    dort aber nicht vor - etwa der Grappling Hook (Slot swrp_ubgl_grapple) aus
    dem Special-Forces-Pack an den DC-15a/s Grenadier. Statt die Addon-Dateien
    zu aendern (beim naechsten Update waere es weg), wird der Slot hier an
    einen vorhandenen Platz der Waffe angehaengt.

    Aufbau: [Waffenklasse] = { [vorhandener Slot] = {zusaetzliche Slots} }
    Der vorhandene Slot bestimmt den Platz (Position am Modell, Anzeige im
    Menue); die zusaetzlichen Slots werden an dieser Stelle erlaubt.
]]

PD = PD or {}
PD.ACW = PD.ACW or {}

PD.ACW.ExtraSlots = {
    ["arccw_k_dc15a_grenadier"] = {
        ["ubgl_republica"] = {"swrp_ubgl_grapple"},
    },
    ["arccw_k_dc15s_grenadier"] = {
        ["ubgl_republica"] = {"swrp_ubgl_grapple"},
    },
}

local function slotList(entry)
    if isstring(entry.Slot) then
        entry.Slot = {entry.Slot}
    end

    return istable(entry.Slot) and entry.Slot or nil
end

local function hasValue(list, value)
    for _, v in pairs(list) do
        if v == value then return true end
    end

    return false
end

-- Erweitert eine Attachments-Liste. Mehrfacher Aufruf ist unschaedlich.
local function extend(attachments, rules)
    if not istable(attachments) then return 0 end

    local added = 0

    for _, entry in pairs(attachments) do
        if istable(entry) then
            local slots = slotList(entry)

            if slots then
                for anchor, extra in pairs(rules) do
                    if hasValue(slots, anchor) then
                        for _, slot in ipairs(extra) do
                            if not hasValue(slots, slot) then
                                table.insert(slots, slot)
                                added = added + 1
                            end
                        end
                    end
                end
            end
        end
    end

    return added
end

function PD.ACW.ApplyExtraSlots()
    local total = 0

    for class, rules in pairs(PD.ACW.ExtraSlots) do
        local stored = weapons.GetStored(class)

        if istable(stored) then
            total = total + extend(stored.Attachments, rules)

            -- Bereits ausgegebene Waffen haben ggf. eine eigene Kopie der Liste.
            for _, wep in ipairs(ents.FindByClass(class)) do
                if IsValid(wep) and rawget(wep:GetTable(), "Attachments") then
                    extend(wep.Attachments, rules)
                end
            end
        end
    end

    return total
end

-- Beim Start sind die Waffen erst nach dem Gamemode registriert; bei einem
-- Lua-Refresh sind sie schon da.
hook.Add("InitPostEntity", "PD.ACW.ExtraSlots", PD.ACW.ApplyExtraSlots)
timer.Simple(0, PD.ACW.ApplyExtraSlots)
