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

    -- Sonne und Nebel der Map: unsere Darstellung hat eigene Sterne
    if profile.disableSun then
        for _, ent in ipairs(ents.FindByClass("env_sun")) do ent:Fire("TurnOff") end
        for _, ent in ipairs(ents.FindByClass("env_lensflare")) do ent:Fire("TurnOff") end
    end
    if profile.disableFog then
        for _, ent in ipairs(ents.FindByClass("env_fog_controller")) do ent:Fire("TurnOff") end
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

--------------------------------------------------------------------------------
-- Kalibrierung im Spiel
--   pd_naval_calibrate vorne        am vordersten Punkt des Schiffs ausfuehren
--   pd_naval_calibrate hinten       am hintersten Punkt ausfuehren
--       -> aus beiden: Laenge in Map-Einheiten, Massstab (Klassenlaenge /
--          Map-Laenge), Schiffsmitte (Mitte der Strecke) und Bugrichtung
--   pd_naval_calibrate bug          Blickrichtung = Bug des Schiffs (auf der
--                                   Bruecke gerade durch die Frontfenster schauen)
--   pd_naval_calibrate mitte        eigene Position = Schiffsmitte
--   pd_naval_calibrate massstab <m> Meter pro Map-Einheit (Standard 0.01905)
--   pd_naval_calibrate zeigen | reset
-- Gespeichert als mapcal_<profil> in pd_naval_settings, sofort an alle.
--------------------------------------------------------------------------------

local function SaveCalibration(profile, cal)
    local key = "mapcal_" .. profile.key
    Naval.Settings[key] = cal

    PD.SQL.Query("REPLACE INTO `pd_naval_settings` (`config_key`, `config_value`) VALUES ("
        .. PD.SQL.EscapeString(key) .. ", " .. PD.SQL.EscapeString(Naval.DB.Encode(cal or {})) .. ")")

    if Naval.SendStatic then Naval.SendStatic() end
end

concommand.Add("pd_naval_calibrate", function(ply, _, args)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local profile = Naval.GetProfile()
    if not profile then ply:ChatPrint("[Naval] Keine Naval-Map") return end

    local cal = table.Copy(Naval.Settings["mapcal_" .. profile.key] or {})
    local what = string.lower(args[1] or "zeigen")

    if what == "vorne" or what == "hinten" then
        local pos = ply:GetPos()
        cal[what] = {math.Round(pos.x), math.Round(pos.y), math.Round(pos.z)}
        ply:ChatPrint(("[Naval] %s gemerkt: %d %d %d"):format(what == "vorne" and "Bug" or "Heck", cal[what][1], cal[what][2], cal[what][3]))

        if cal.vorne and cal.hinten then
            local front = Vector(cal.vorne[1], cal.vorne[2], cal.vorne[3])
            local back = Vector(cal.hinten[1], cal.hinten[2], cal.hinten[3])
            local axis = front - back
            local units = Vector(axis.x, axis.y, 0):Length()
            local class = Naval.Classes[profile.classId]

            if units < 100 then
                ply:ChatPrint("[Naval] Bug und Heck liegen zu nah beieinander - nochmal messen")
            elseif class then
                local mid = (front + back) * 0.5
                cal.metersPerUnit = math.Round(class.lengthM / units, 5)
                cal.origin = {math.Round(mid.x), math.Round(mid.y), math.Round(mid.z)}
                cal.yaw = math.Round(axis:Angle().y, 1)
                cal.lengthUnits = math.Round(units)

                ply:ChatPrint(("[Naval] Schiff %d Einheiten lang = %d m (%s) -> %.4f m pro Einheit"):format(units, class.lengthM,
                    class.name, cal.metersPerUnit))
                ply:ChatPrint(("[Naval] Mitte %d %d %d, Bug zeigt nach Yaw %.1f°"):format(cal.origin[1], cal.origin[2], cal.origin[3], cal.yaw))
            end
        else
            ply:ChatPrint("[Naval] Jetzt am anderen Ende: pd_naval_calibrate " .. (what == "vorne" and "hinten" or "vorne"))
        end
    elseif what == "bug" then
        cal.yaw = math.Round(ply:EyeAngles().y, 1)
        ply:ChatPrint("[Naval] Bug zeigt in der Map nach Yaw " .. cal.yaw .. "°")
    elseif what == "mitte" then
        local pos = ply:GetPos()
        cal.origin = {math.Round(pos.x), math.Round(pos.y), math.Round(pos.z)}
        cal.metersPerUnit = cal.metersPerUnit or 0.01905
        ply:ChatPrint(("[Naval] Schiffsmitte %d %d %d, Massstab %.5f m/Einheit"):format(cal.origin[1], cal.origin[2], cal.origin[3], cal.metersPerUnit))
    elseif what == "massstab" then
        local m = tonumber(args[2])
        if not m or m <= 0 or m > 10 then ply:ChatPrint("[Naval] pd_naval_calibrate massstab <meter pro einheit>, z.B. 0.01905") return end
        cal.metersPerUnit = m
        ply:ChatPrint("[Naval] Massstab " .. m .. " m/Einheit")
    elseif what == "reset" then
        cal = {}
        ply:ChatPrint("[Naval] Kalibrierung zurueckgesetzt (Werte aus dem Profil)")
    else
        local p = Naval.GetProfile()
        ply:ChatPrint(("[Naval] Bug-Yaw %s, Mitte %s, Massstab %s"):format(tostring(p.mapToBody.y), tostring(p.shipOriginMap),
            tostring(p.metersPerUnit or "aus")))
        return
    end

    SaveCalibration(profile, cal)

    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("Naval", ply:Nick() .. " kalibriert Map-Schiff: " .. what, Color(120, 170, 255))
    end
end)
