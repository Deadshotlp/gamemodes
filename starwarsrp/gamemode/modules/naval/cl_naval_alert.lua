--[[
    Naval - Alarmstufe und Bordmeldungen (Client).

    Gelb: Hinweis oben, kurzer Gong. Rot: Hinweis und Rotlicht
    (alert_red_light; den Alarmton liefert die Map-Sirene ueber die
    Alarm-Knoepfe, sv_naval_alert.lua):
    roter Farbfilter, bei 1 zusaetzlich abgedunkeltes Map-Licht (Server setzt
    den Lichtstil, hier werden die Lightmaps neu geladen).
    Dazu kurze Bordmeldungen (Hyperraum-Austritt erkannt).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

local lastLevel

net.Receive("PD.Naval.AlertLight", function()
    render.RedownloadAllLightmaps(false, false)
end)

local function RedLight()
    local s = C.static and C.static.settings
    return tonumber(s and s.alert_red_light) or 1
end

-- Rotlicht: Farben ins Rote ziehen, leicht pulsierend
hook.Add("RenderScreenspaceEffects", "PD.Naval.Alert", function()
    if GetGlobalInt("PD.Naval.Alert", 0) ~= 2 or RedLight() == 0 then return end
    if not Naval.IsNavalMap or not Naval.IsNavalMap() then return end

    local pulse = (math.sin(CurTime() * 2.2) + 1) * 0.5
    DrawColorModify({
        ["$pp_colour_addr"] = 0.05 + pulse * 0.04,
        ["$pp_colour_addg"] = 0,
        ["$pp_colour_addb"] = 0,
        ["$pp_colour_brightness"] = -0.03,
        ["$pp_colour_contrast"] = 1.08,
        ["$pp_colour_colour"] = 0.45,
        ["$pp_colour_mulr"] = 0.5,
        ["$pp_colour_mulg"] = 0,
        ["$pp_colour_mulb"] = 0,
    })
end)

-- Bordmeldungen gibt es nicht mehr auf dem Bildschirm (nur an den Konsolen);
-- die Funktion bleibt fuer aeltere Aufrufer erhalten.
function Naval.ShipMessage()
end

hook.Add("PD.Naval.ClientEvent", "PD.Naval.Alert", function(kind, data)
    if kind == "comms" and not data.own then
        surface.PlaySound("buttons/button17.wav")
    elseif kind == "contact_arrival" then
        surface.PlaySound("buttons/blip1.wav")
    end
end)

hook.Add("Think", "PD.Naval.Alert", function()
    if not Naval.IsNavalMap or not Naval.IsNavalMap() then return end

    local level = GetGlobalInt("PD.Naval.Alert", 0)
    if lastLevel ~= nil and level ~= lastLevel and level == 1 then surface.PlaySound("ambient/alarms/warningbell1.wav") end
    lastLevel = level
end)

