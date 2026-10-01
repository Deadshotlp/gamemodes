--[[
    Einschlaggeraeusch der UGL-Granaten (Kraken's Effects & Resources).

    Die Granaten spielen ihren Explosionssound mit self:EmitSound und
    entfernen sich direkt danach mit self:Remove(). Ein per EmitSound
    gestarteter Sound haengt am Entity - wird es im selben Tick entfernt,
    kommt er beim Client oft nicht mehr an. Deshalb war der Einschlag nur
    manchmal zu hoeren.

    EmitSound laesst sich pro Entity nicht ueberschreiben: der Aufruf findet
    die Methode in der Entity-Metatabelle, bevor er in die Tabelle der Klasse
    schaut. Deshalb werden Detonate und PhysicsCollide der Basisklasse
    eingewickelt: nur waehrend sie laufen, und nur fuer genau diese Granate,
    geht EmitSound ueber sound.Play an ihre Position. Ein so abgespielter Sound
    haengt an der Stelle und ueberlebt das Entfernen.

    Flash, Brand und HE erben Detonate von arccw_ubgl_nade und sind damit
    mit abgedeckt. Das Workshop-Addon bleibt unveraendert.
]]

PD = PD or {}
PD.ACW = PD.ACW or {}

local ENTITY = FindMetaTable("Entity")

-- Beim ersten Laden sichern, damit ein Lua-Refresh nicht die eigene Fassung
-- als Original einwickelt.
PD.ACW.RealEmitSound = PD.ACW.RealEmitSound or ENTITY.EmitSound
local realEmitSound = PD.ACW.RealEmitSound

local function withPositionalSound(fn)
    return function(self, ...)
        local target = self

        ENTITY.EmitSound = function(ent, snd, level, pitch, volume, ...)
            if ent == target and isstring(snd) then
                sound.Play(PD.ACW.FixSoundPath and PD.ACW.FixSoundPath(snd) or snd, ent:GetPos(), level or 75, pitch or 100, volume or 1)
                return
            end

            return realEmitSound(ent, snd, level, pitch, volume, ...)
        end

        local ok, err = pcall(fn, self, ...)

        ENTITY.EmitSound = realEmitSound

        if not ok then
            ErrorNoHalt("[UGL-Sound] " .. tostring(err) .. "\n")
        end
    end
end

PD.ACW.UBGLOriginal = PD.ACW.UBGLOriginal or {}

function PD.ACW.ApplyUBGLSounds()
    local stored = scripted_ents.GetStored("arccw_ubgl_nade")
    if not stored or not istable(stored.t) then return false end

    local t = stored.t

    for _, name in ipairs({"Detonate", "PhysicsCollide"}) do
        -- Original einmal sichern; nach einem Neuladen des Addons ist die
        -- Funktion wieder die urspruengliche und wird neu gesichert.
        if isfunction(t[name]) and not t["PD_Wrapped_" .. name] then
            PD.ACW.UBGLOriginal[name] = t[name]
            t[name] = withPositionalSound(t[name])
            t["PD_Wrapped_" .. name] = true
        end
    end

    return true
end

hook.Add("InitPostEntity", "PD.ACW.UBGLSounds", PD.ACW.ApplyUBGLSounds)
timer.Simple(0, PD.ACW.ApplyUBGLSounds)
