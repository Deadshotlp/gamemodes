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
    eingeschaltet, beim Verlassen auf Wunsch wieder aus. Venator-Knoepfe
    (alarmBut1/alarmbut2): Druck schaltet ein und sperrt den Knopf, Benutzen
    des gesperrten Knopfs (OnUseLocked) schaltet aus - daher nach Sperrzustand.
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

-- Aus der Datenbank laden (die Datenbank ist massgeblich, z. B. nach
-- Aenderungen ueber das Web-Panel); bei jedem Laden des Moduls und Sim-Start
function Naval.LoadAlertButtons()
    if not PD.SQL or not PD.SQL.FetchAll then return end
    PD.SQL.FetchAll("SELECT `config_value` FROM `pd_naval_settings` WHERE `config_key` = " .. PD.SQL.EscapeString(ButtonKey()), function(rows)
        local row = rows and rows[1]
        if row and Naval.Settings then Naval.Settings[ButtonKey()] = util.JSONToTable(row.config_value or "") or {} end
    end)
end

hook.Add("PD.Naval.SimStarted", "PD.Naval.AlertButtons", Naval.LoadAlertButtons)

function Naval.SaveAlertButtons(list)
    Naval.Settings[ButtonKey()] = list
    PD.SQL.Query("REPLACE INTO `pd_naval_settings` (`config_key`, `config_value`) VALUES ("
        .. PD.SQL.EscapeString(ButtonKey()) .. ", " .. PD.SQL.EscapeString(Naval.DB.Encode(list)) .. ")")
end

-- Knopf ein- (on = true) oder ausschalten. Gesperrt gilt als "an": die
-- Map sperrt ihre Alarm-Knoepfe beim Einschalten und schaltet beim
-- Benutzen des gesperrten Knopfs aus. on = nil: umschalten (Testen).
function Naval.SetMapButton(entry, on)
    local ent = ents.GetMapCreatedEntity(tonumber(entry.id) or -1)
    if not IsValid(ent) then return false end

    local world = game.GetWorld()
    if not string.find(ent:GetClass(), "button", 1, true) then
        ent:Input("Use", world, world)
        return true
    end

    local locked = ent:GetInternalVariable("m_bLocked") == true
    if on == nil then on = not locked end

    if on and not locked then
        ent:Fire("Press")
    elseif not on and locked then
        ent:Input("Use", world, world)
    end
    return true
end

local function Buttons(oldLevel, newLevel)
    for _, entry in ipairs(Naval.AlertButtons()) do
        local level = tonumber(entry.level) or 2
        if level == newLevel then
            Naval.SetMapButton(entry, true)
        elseif level == oldLevel and entry.leave then
            Naval.SetMapButton(entry, false)
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

if Naval.SimRunning then Naval.LoadAlertButtons() end

concommand.Add("pd_naval_alert", function(ply, _, args)
    if IsValid(ply) and not ply:IsAdmin() then return end

    local level = tonumber(args[1])
    if not level then
        print("[Naval] pd_naval_alert <0 Normal | 1 Gelb | 2 Rot>")
        return
    end

    Naval.SetAlert(level, IsValid(ply) and ply:Nick() or "Konsole")
end)

