--[[
    LVS-Sitzliste mit RP-Namen statt Steam-Namen.

    Die Liste oben rechts im Fahrzeug ist das HUD-Element "SeatSwitcher" aus
    dem LVS-Framework (lua/entities/lvs_base/cl_seatswitcher.lua). Es holt die
    Namen per player:GetName(). Das Gamemode biegt nur Nick() und Name() auf
    den RP-Namen um (cl_init.lua) - GetName() liefert weiter den Steam-Namen.

    Anzeige wie beim restlichen HUD: der volle RP-Name ("95-3404 Test").

    Das Workshop-Addon selbst bleibt unangetastet. Stattdessen wird die
    Zeichenfunktion des Elements eingewickelt: nur waehrend sie laeuft, liefert
    GetName() den Anzeigenamen, ueberall sonst den Steam-Namen wie immer.
]]

PD.LVSSeats = PD.LVSSeats or {}

local PLAYER = FindMetaTable("Player")

-- Einmal sichern, damit ein Lua-Refresh nicht die eigene Ueberschreibung als
-- Original speichert und sich dann selbst aufruft.
PD.LVSSeats.OriginalGetName = PD.LVSSeats.OriginalGetName
    or PLAYER.GetName
    or FindMetaTable("Entity").GetName

local active = false

-- "95-3404 Test" -> "95-3404"
function PD.LVSSeats.GetID(ply)
    local full = ply:Nick()

    return string.match(full, "^(%S+)") or full
end

-- Voller RP-Name wie im uebrigen HUD. Frueher nur die ID fuer Spieler, die man
-- nicht "kannte" - das Kennenlernen-Modul gibt es aber nicht mehr, damit
-- stand bei allen anderen nur noch die Nummer.
function PD.LVSSeats.DisplayName(ply)
    return ply:Nick()
end

function PLAYER:GetName()
    if active then
        local ok, name = pcall(PD.LVSSeats.DisplayName, self)

        if ok and isstring(name) then
            return name
        end
    end

    return PD.LVSSeats.OriginalGetName(self)
end

--[[
    Die Zeichenfunktion des SeatSwitcher-Elements einwickeln.

    LVS legt das Element erst beim Laden seiner Entities an, also nach dem
    Gamemode, und legt es bei einem Refresh des Addons neu an. Deshalb wird
    regelmaessig nachgesehen, ob das aktuelle Element schon eingewickelt ist.
]]
local function wrap()
    local editors = LVS and LVS.HudEditors
    local editor = istable(editors) and editors["SeatSwitcher"]

    if not istable(editor) or editor.PD_NamesWrapped or not isfunction(editor.func) then return end

    local original = editor.func

    editor.func = function(...)
        active = true
        local ok, err = pcall(original, ...)
        active = false

        if not ok then
            ErrorNoHalt("[LVS-Sitzliste] " .. tostring(err) .. "\n")
        end
    end

    editor.PD_NamesWrapped = true
end

hook.Add("InitPostEntity", "PD.LVSSeats.Wrap", wrap)
timer.Create("PD.LVSSeats.Wrap", 2, 0, wrap)
wrap()
