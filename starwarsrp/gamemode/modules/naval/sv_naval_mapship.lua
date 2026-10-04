--[[
    Naval - Map-Anbindung (Server).

    Die Venator hat eine eigene Hyperraum-Logik (logic_relay, Buttons) und
    fertige Skybox-Szenen fuer einzelne Planeten. Beim Start wird auf "leerer
    Raum" geschaltet (unsere Darstellung uebernimmt), die eigenen Bedien-
    elemente werden gesperrt, und bei Spruengen loesen wir die Tunnel-Relais
    der Map aus (originaler Effekt). Abschaltbar: pd_naval_maprelays 0.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval

local cvRelays = CreateConVar("pd_naval_maprelays", "1", FCVAR_ARCHIVE, "Naval: Hyperraum-Relais der Map ausloesen")

local function Fire(name, input)
    if not name or name == "" then return 0 end

    local count = 0
    for _, ent in ipairs(ents.FindByName(name)) do
        ent:Fire(input or "Trigger")
        count = count + 1
    end

    return count
end

Naval.FireMapRelay = Fire

function Naval.ApplyMapProfile()
    local profile = Naval.GetProfile()
    if not profile then return end

    -- Map-eigene Hyperraum-Bedienung sperren
    for _, name in ipairs(profile.lockMapControls or {}) do
        Fire(name, "Lock")
    end

    for _, pos in ipairs(profile.blockMapControls or {}) do
        for _, ent in ipairs(ents.FindInSphere(pos, 64)) do
            local class = ent:GetClass()
            if class == "func_button" or class == "momentary_rot_button" then
                ent:Fire("Lock")
            end
        end
    end

    if cvRelays:GetBool() and profile.mapRelays then
        local n = Fire(profile.mapRelays.start)
        Naval.Log("Map auf leeren Raum geschaltet (" .. n .. " Relais)")
    end
end

hook.Add("PD.Naval.SimStarted", "PD.Naval.MapShip", function()
    -- Kurz warten, bis Map-Logik nach dem Start bereit ist
    timer.Simple(2, Naval.ApplyMapProfile)
end)

hook.Add("PostCleanupMap", "PD.Naval.MapShip", function()
    if Naval.SimRunning then timer.Simple(1, Naval.ApplyMapProfile) end
end)

hook.Add("PD.Naval.Event", "PD.Naval.MapShip", function(ship, kind)
    if not ship:IsPlayerShip() or not cvRelays:GetBool() then return end

    local profile = Naval.GetProfile()
    local relays = profile and profile.mapRelays
    if not relays then return end

    if kind == "jump_start" then
        Fire(relays.jump)
        util.ScreenShake(Vector(0, 0, 0), 4, 5, 2.5, 60000)
    elseif kind == "jump_exit" then
        Fire(relays.exit)
        util.ScreenShake(Vector(0, 0, 0), 3, 5, 1.5, 60000)
    elseif kind == "jump_done" then
        Fire(relays.start)
    end
end)
