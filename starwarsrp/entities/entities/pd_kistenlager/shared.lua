--[[
    Kistenlager: gibt fertig gepackte Transportkisten aus (z. B. Barrikaden).

    Mit E (Benutzen) oeffnet sich das Menue. Sortiment und Limit pro Spieler
    stehen in pd_kiste_spawnables (Web-Panel, Seite Transportkisten); die
    Logik liegt in gamemode/modules/transportkiste/.

    Aufstellen: als Admin aus dem Spawnmenue, dann mit dem PermaProps-Tool
    festspeichern.
]]

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Kistenlager"
ENT.Author = "PD"
ENT.Category = "PD - Gamemode"
ENT.Spawnable = true
ENT.AdminOnly = true

ENT.Model = "models/props/de_port/cargo_container01.mdl"
