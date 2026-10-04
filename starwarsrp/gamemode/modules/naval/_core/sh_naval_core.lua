--[[
    Naval System - Kern.

    Ein Marine-System: die Map (zuerst rp_venator_extensive_v1_4) ist ein
    Schiff, das durch eine 3D-Galaxie fliegt. NPC-Schiffe bewegen sich
    persistent, Konsolen auf der Map steuern das eigene Schiff, Admins
    platzieren und befehligen den Rest.

    Aufbau (Ordner gamemode/modules/naval/):
      _core/   gemeinsame Grundlagen (laedt zuerst): Namensraum, Mathematik,
               Map-Profile, SWU-Abschaltung, Netzwerknamen
      sv_/cl_/sh_ Dateien der einzelnen Teile

    Darstellung rein clientseitig im Skybox-Renderpass, Simulation auf dem
    Server in Tabellen (keine Entities). Positionen sind Lua-doubles in Metern
    (system-lokal), nie Vector - der hat nur float32-Genauigkeit.

    Plan: C:\Users\Deadshot\.claude\plans\luminous-skipping-russell.md
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval

Naval.Version = 1

-- Schiffszustaende
Naval.State = {
    NORMAL = "normal",
    SPOOLING = "spooling",     -- Hyperantrieb faehrt hoch
    JUMPING = "jumping",       -- Eintritt (Sterne-Animation)
    HYPERSPACE = "hyperspace", -- im Tunnel
    EXITING = "exiting",       -- Austritt
    DISABLED = "disabled",     -- kampfunfaehig (Map-Schiff bei 0 % Huelle)
    DESTROYED = "destroyed",
}

-- Schildzonen (Stufe 2), Reihenfolge fest fuer Netz und UI
Naval.Zones = {"front", "back", "left", "right", "top", "bottom"}

-- Beziehungen zwischen Fraktionen
Naval.Relation = {
    ALLY = "ally",
    NEUTRAL = "neutral",
    HOSTILE = "hostile",
}

-- Typen von Himmelskoerpern
Naval.BodyType = {
    STAR = "star",
    PLANET = "planet",
    MOON = "moon",
    STATION = "station",
    SHIPYARD = "shipyard",
    ASTEROIDS = "asteroidfield",
}

Naval.Debug = CreateConVar("pd_naval_debug", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED, "Naval: zusaetzliche Konsolenausgaben")

function Naval.Log(text)
    print("[Naval] " .. tostring(text))
end

function Naval.DebugLog(text)
    if Naval.Debug:GetBool() then
        print("[Naval:debug] " .. tostring(text))
    end
end

-- GetProfile/IsNavalMap: siehe sh_naval_profiles.lua
