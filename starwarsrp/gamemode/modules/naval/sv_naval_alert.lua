--[[
    Naval - Alarmstufen des Map-Schiffs (Server).

      0 Normal, 1 Gelb, 2 Rot  ->  GetGlobalInt("PD.Naval.Alert")

    Wechsel an der Alarm-Konsole, per pd_naval_alert <0-2> (Admins) oder
    automatisch Gelb beim ersten Treffer (alert_auto_yellow). Jede Stufe
    setzt auf Wunsch das DEFCON (alert_defcon_*, 0 = nicht aendern). Bei Rot
    gehen die Schilde automatisch hoch. Ton und roter Schimmer: Client
    (cl_naval_alert.lua).

    Rotlicht (alert_red_light): 1 = Map-Licht abgedunkelt (Lichtstil 0) und
    roter Farbfilter bei den Spielern, 2 = nur Farbfilter, 0 = aus.

    Map-Knoepfe (Sirene, rote Lichtpaneele): im Admin-Tab den angeschauten
    Knopf einer Stufe zuordnen. Beim Wechsel auf diese Stufe wird er
    gedrueckt, beim Verlassen auf Wunsch noch einmal (Schalter wieder aus).
    Gespeichert als alertbtn_<map> in pd_naval_settings (MapCreationID).
]]

util.AddNetworkString("PD.Naval.AlertLight")

PD.Naval = PD.Naval or {}

local Naval = PD.Naval

local DEFCON_KEY = {[0] = "alert_defcon_normal", [1] = "alert_defcon_yellow", [2] = "alert_defcon_red"}

function Naval.GetAlert()
    return GetGlobalInt("PD.Naval.Alert", 0)
end

--------------------------------------------------------------------------------
-- Map-Knoepfe und Licht
--------------------------------------------------------------------------------

local function ButtonKey() return "alertbtn_" .. game.GetMap() end

function Naval.AlertButtons()
    local list = Naval.Settings and Naval.Settings[ButtonKey()]
    return istable(list) and list or {}
end

function Naval.SaveAlertButtons(list)
    Naval.Settings[ButtonKey()] = list
    PD.SQL.Query("REPLACE INTO `pd_naval_settings` (`config_key`, `config_value`) VALUES ("
        .. PD.SQL.EscapeString(ButtonKey()) .. ", " .. PD.SQL.EscapeString(Naval.DB.Encode(list)) .. ")")
end

function Naval.PressMapButton(entry)
    local ent = ents.GetMapCreatedEntity(tonumber(entry.id) or -1)
    if not IsValid(ent) then return false end

    if string.find(ent:GetClass(), "button", 1, true) then
        ent:Fire("Press")
    else
        ent:Input("Use", game.GetWorld(), game.GetWorld())
    end
    return true
end

local function Buttons(oldLevel, newLevel)
    for _, entry in ipairs(Naval.AlertButtons()) do
        local level = tonumber(entry.level) or 2
        if level == newLevel or (level == oldLevel and entry.leave) then
            Naval.PressMapButton(entry)
        end
    end
end

local function Light(level)
    local mode = tonumber(Naval.Settings.alert_red_light) or 1
    local dim = level == 2 and mode == 1
    if dim == (Naval.AlertDimmed == true) then return end

    Naval.AlertDimmed = dim
    engine.LightStyle(0, dim and (Naval.Settings.alert_red_lightstyle or "e") or "m")
    timer.Simple(0.2, function()
        net.Start("PD.Naval.AlertLight")
        net.Broadcast()
    end)
end

function Naval.SetAlert(level, by)
    level = math.Clamp(math.floor(tonumber(level) or 0), 0, 2)
    local oldLevel = Naval.GetAlert()
    if level == oldLevel then return false end

    SetGlobalInt("PD.Naval.Alert", level)
    SetGlobalFloat("PD.Naval.AlertSince", CurTime())

    Buttons(oldLevel, level)
    Light(level)

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
