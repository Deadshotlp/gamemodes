--[[
    Transportkiste: ein zusammengepacktes Objekt (z. B. ein Zelt).

    Entsteht nur ueber "Zusammenpacken" im Interaktionsmenue und laesst sich
    wie andere Fracht in Fahrzeuge einladen. Was in der Kiste steckt, haelt
    der Server in self.PD_Packed; die Logik steht in
    gamemode/modules/transportkiste/.
]]

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Transportkiste"
ENT.Author = "PD"
ENT.Category = "PD - Gamemode"
ENT.Spawnable = false

ENT.DefaultModel = "models/reizer_props/srsp/sci_fi/crate_01/crate_01.mdl"

function ENT:SetupDataTables()
    -- Anzeigename des Inhalts (z. B. "Zelt"), fuer Beschriftung und Menue.
    self:NetworkVar("String", 0, "ContentName")
end
