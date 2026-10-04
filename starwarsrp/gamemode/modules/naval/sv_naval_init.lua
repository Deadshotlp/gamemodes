--[[
    Naval - Start.

    Reihenfolge: Tabellen anlegen -> Startwerte -> Konfiguration -> Galaxie.
    Ist die Galaxie leer, wird sie beim ersten Start aus SWU importiert.

    Die Datenbank-Teile laufen auf jeder Map (das Web-Panel braucht die
    Tabellen); Simulation und Darstellung nur auf Maps mit Naval-Profil.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval

-- Andere Teile haengen sich hier ein (z. B. Simulation startet erst danach).
Naval.Ready = Naval.Ready or false

function Naval.ReloadConfig(callback)
    Naval.DB.LoadConfig(function(classes, factions)
        Naval.Log(classes .. " Klassen, " .. factions .. " Fraktionen geladen")

        if Naval.OnConfigLoaded then Naval.OnConfigLoaded() end
        if callback then callback(classes, factions) end
    end)
end

function Naval.ReloadGalaxy(callback)
    Naval.DB.LoadGalaxy(function(systems, bodies)
        Naval.Log(systems .. " Systeme, " .. bodies .. " Himmelskoerper geladen")

        if Naval.OnGalaxyLoaded then Naval.OnGalaxyLoaded() end
        if callback then callback(systems, bodies) end
    end)
end

local function Start()
    Naval.DB.EnsureTables(function()
        Naval.DB.Seed(function()
            Naval.ReloadConfig(function()
                Naval.ReloadGalaxy(function(systems)
                    if systems == 0 then
                        Naval.Log("Galaxie leer - importiere aus Star Wars Universe")

                        Naval.ImportSWU(false, function(ok, text)
                            Naval.Log("SWU-Import: " .. tostring(text))

                            Naval.ReloadGalaxy(function()
                                Naval.Ready = true
                                hook.Run("PD.Naval.Ready")
                            end)
                        end)

                        return
                    end

                    Naval.Ready = true
                    hook.Run("PD.Naval.Ready")
                end)
            end)
        end)
    end)
end

-- Wie die anderen Module per Timer nach dem Laden; beim Lua-Refresh erneut.
timer.Simple(4, Start)

concommand.Add("pd_naval_status", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end

    local profile = Naval.GetProfile()

    print("[Naval] Status")
    print("  Bereit: " .. tostring(Naval.Ready) .. ", Map-Profil: " .. (profile and profile.key or "keins"))
    print("  Klassen: " .. table.Count(Naval.Classes) .. ", Fraktionen: " .. table.Count(Naval.Factions)
        .. ", Systeme: " .. table.Count(Naval.Systems) .. ", Koerper: " .. table.Count(Naval.Bodies))

    if Naval.Ships then
        print("  Schiffe: " .. table.Count(Naval.Ships))

        for id, ship in SortedPairs(Naval.Ships) do
            local speed = ship.vel and PD.Naval.V3.Len(ship.vel) or 0
            print(("    #%d %s [%s/%s] %s %s %.0f m/s%s"):format(id, ship.name or "?", ship.classId or "?",
                ship.factionId or "?", ship.systemId or "?", ship.state or "?", speed,
                ship.flags and ship.flags.player and " (Map-Schiff)" or ""))
        end
    end
end)
