--[[
    Naval - "Star Wars Universe" (SWU) auf Naval-Maps abschalten.

    SWU (Workshop-Addon) steuert sonst selbst die Skybox der Venator: eigene
    Planeten-Entities, Drehung der Skybox, Nebel, Steuer-Entities. Das wuerde
    mit unserem System kollidieren. Wir aendern das Addon nicht, sondern
    entfernen auf Naval-Maps seine Hooks und ersetzen die Lade-Funktion.
    Seine Inhalte (Planeten-Texturen, Galaxie-Koordinaten, Hyperraum-Modelle)
    nutzen wir weiter.

    Auf allen anderen Maps bleibt SWU unangetastet.
]]

PD.Naval = PD.Naval or {}

local SWU_HOOKS = {
    {"InitPostEntity", "SWU_InitializeStarWarsUniverse"},
    {"PostCleanupMap", "SWU_ReInitializeStarWarsUniverse"},
    {"PlayerInitialSpawn", "SWU_FixPlayerNetworking"},
    {"ShutDown", "SWU_PersistShipData"},
    {"PreCleanupMap", "SWU_PersistShipData"},
    {"ClientSignOnStateChanged", "SWU_InitializeStarWarsUniverseClientSide"},
    {"PreDrawSkyBox", "SWU_RotateSkybox"},
    {"PostDrawSkyBox", "SWU_ResetSkyboxRotation"},
    {"SetupWorldFog", "SWU_DisableWorldFog"},
    {"SetupSkyboxFog", "SWU_DisableSkyboxFog"},
    {"PlayerButtonDown", "RegisterSWUInteractableBinds"},
    {"SetupMove", "SWU_CheckWhenPlayerIsHere"},
    {"PlayerBindPress", "BlockBindsOnSWUInteractable"},
}

local function Neuter()
    if not PD.Naval.IsNavalMap() then return false end

    local profile = PD.Naval.GetProfile()
    if not profile.disableSWU then return false end

    for _, entry in ipairs(SWU_HOOKS) do
        hook.Remove(entry[1], entry[2])
    end

    if SWU then
        SWU.LoadMap = function()
            PD.Naval.Log("SWU deaktiviert auf " .. game.GetMap())
        end

        if SWU.MapConfig then
            SWU.MapConfig[game.GetMap()] = nil
        end
    end

    return true
end

PD.Naval.NeuterSWU = Neuter

-- Das Addon kann vor oder nach dem Gamemode laden - deshalb mehrfach.
Neuter()

hook.Add("Initialize", "PD.Naval.SWUCompat", Neuter)

timer.Simple(0, Neuter)

if SERVER then
    timer.Simple(5, function()
        if not Neuter() then return end

        local removed = 0
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and string.StartWith(ent:GetClass(), "swu_") then
                ent:Remove()
                removed = removed + 1
            end
        end

        PD.Naval.Log("SWU deaktiviert (" .. removed .. " SWU-Entities entfernt)")
    end)
end
