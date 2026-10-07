--[[
    Naval - Alarmstufe und Bordmeldungen (Client).

    Gelb: Hinweis oben, kurzer Gong. Rot: Hinweis, Alarmton fuer
    alert_alarm_seconds nach dem Wechsel und Rotlicht (alert_red_light):
    roter Farbfilter, bei 1 zusaetzlich abgedunkeltes Map-Licht (Server setzt
    den Lichtstil, hier werden die Lightmaps neu geladen).
    Dazu kurze Bordmeldungen (Hyperraum-Austritt erkannt).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

local COLORS = {[1] = Color(240, 200, 60), [2] = Color(240, 70, 60)}

local lastLevel
local nextKlaxon = 0
local messages = {}

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

local function AlarmSeconds()
    local s = C.static and C.static.settings
    return tonumber(s and s.alert_alarm_seconds) or 20
end

function Naval.ShipMessage(text, col)
    table.insert(messages, 1, {text = text, col = col or Color(225, 230, 240), t = CurTime()})
    while #messages > 4 do table.remove(messages) end
end

hook.Add("PD.Naval.ClientEvent", "PD.Naval.Alert", function(kind, data)
    if kind == "contact_arrival" then
        surface.PlaySound("buttons/blip1.wav")
        Naval.ShipMessage(("Sensoren: Hyperraum-Austritt - %s in %s"):format(data.name or "unbekannter Kontakt",
            Naval.FormatDist and Naval.FormatDist(tonumber(data.dist) or 0) or "?"), Color(120, 190, 255))
    end
end)

hook.Add("Think", "PD.Naval.Alert", function()
    if not Naval.IsNavalMap or not Naval.IsNavalMap() then return end

    local level = GetGlobalInt("PD.Naval.Alert", 0)
    if lastLevel ~= nil and level ~= lastLevel then
        if level == 1 then surface.PlaySound("ambient/alarms/warningbell1.wav") end
        if level >= 1 then Naval.ShipMessage(Naval.AlertNames[level], COLORS[level]) end
        if level == 0 and lastLevel > 0 then Naval.ShipMessage("Alarm aufgehoben", Color(90, 210, 130)) end
    end
    lastLevel = level

    if level == 2 and CurTime() < GetGlobalFloat("PD.Naval.AlertSince", 0) + AlarmSeconds() and CurTime() >= nextKlaxon then
        nextKlaxon = CurTime() + 2.4
        LocalPlayer():EmitSound("ambient/alarms/klaxon1.wav", 75, 100, 0.35)
    end
end)

hook.Add("HUDPaint", "PD.Naval.Alert", function()
    if not Naval.IsNavalMap or not Naval.IsNavalMap() then return end

    local level = GetGlobalInt("PD.Naval.Alert", 0)
    local w = ScrW()

    if level > 0 then
        local col = COLORS[level]
        local text = string.upper(Naval.AlertNames[level] or "")
        surface.SetFont("MLIB.16")
        local tw = surface.GetTextSize(text)
        draw.RoundedBox(4, w / 2 - tw / 2 - 14, 8, tw + 28, 28, Color(14, 18, 24, 200))
        surface.SetDrawColor(col)
        surface.DrawOutlinedRect(w / 2 - tw / 2 - 14, 8, tw + 28, 28, 2)
        draw.SimpleText(text, "MLIB.16", w / 2, 22, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Bordmeldungen (8 s sichtbar)
    local y = 44
    for i = #messages, 1, -1 do
        if CurTime() - messages[i].t > 8 then table.remove(messages, i) end
    end
    for _, m in ipairs(messages) do
        local alpha = math.Clamp((8 - (CurTime() - m.t)) * 255, 0, 255)
        draw.SimpleTextOutlined(m.text, "MLIB.16", w / 2, y, Color(m.col.r, m.col.g, m.col.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, alpha * 0.7))
        y = y + 22
    end
end)
