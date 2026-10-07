--[[
    Naval - Alarmstufen des Map-Schiffs (Server).

      0 Normal, 1 Gelb, 2 Rot  ->  GetGlobalInt("PD.Naval.Alert")

    Wechsel an der Alarm-Konsole, per pd_naval_alert <0-2> (Admins) oder
    automatisch Gelb beim ersten Treffer (alert_auto_yellow). Jede Stufe
    setzt auf Wunsch das DEFCON (alert_defcon_*, 0 = nicht aendern). Bei Rot
    gehen die Schilde automatisch hoch. Ton und roter Schimmer: Client
    (cl_naval_alert.lua).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval

local DEFCON_KEY = {[0] = "alert_defcon_normal", [1] = "alert_defcon_yellow", [2] = "alert_defcon_red"}

function Naval.GetAlert()
    return GetGlobalInt("PD.Naval.Alert", 0)
end

function Naval.SetAlert(level, by)
    level = math.Clamp(math.floor(tonumber(level) or 0), 0, 2)
    if level == Naval.GetAlert() then return false end

    SetGlobalInt("PD.Naval.Alert", level)
    SetGlobalFloat("PD.Naval.AlertSince", CurTime())

    local ship = Naval.GetMapShip()
    if ship then
        ship:Log("combat", by or "", Naval.AlertNames[level] or tostring(level))

        if level == 2 and Naval.Combat then
            local _, sh = Naval.Combat(ship)
            sh.up = true
            ship.dirty = true
        end
    end

    local defcon = tonumber(Naval.Settings[DEFCON_KEY[level]]) or 0
    if defcon > 0 and DEFCON and DEFCON.Set then
        local current = DEFCON.GetCurrent and DEFCON.GetCurrent()
        if current ~= defcon then DEFCON.Set(defcon, Naval.AlertNames[level], by or "Schiff") end
    end

    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("Naval", (by or "System") .. ": " .. (Naval.AlertNames[level] or level), Color(255, 160, 60))
    end

    return true
end

-- Erster Treffer: Gelb, falls noch Normal
hook.Add("PD.Naval.MapShipHit", "PD.Naval.Alert", function()
    if (tonumber(Naval.Settings.alert_auto_yellow) or 0) == 1 and Naval.GetAlert() == 0 then
        Naval.SetAlert(1, "Automatisch (Beschuss)")
    end
end)

Naval.CombatCommands = Naval.CombatCommands or {}
Naval.CombatCommands.alert = Naval.CombatCommands.alert or {}

Naval.CombatCommands.alert.set = function(ply, ship, args)
    Naval.SetAlert(args.level, ply:Nick())
end

Naval.StatusExtras = Naval.StatusExtras or {}
Naval.StatusExtras.alert = function()
    return Naval.GetAlert()
end

concommand.Add("pd_naval_alert", function(ply, _, args)
    if IsValid(ply) and not ply:IsAdmin() then return end

    local level = tonumber(args[1])
    if not level then
        print("[Naval] pd_naval_alert <0 Normal | 1 Gelb | 2 Rot>")
        return
    end

    Naval.SetAlert(level, IsValid(ply) and ply:Nick() or "Konsole")
end)
