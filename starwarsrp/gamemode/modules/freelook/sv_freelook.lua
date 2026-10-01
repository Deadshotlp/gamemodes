--[[
    Kopfhaltung weiterreichen.

    Der Server rechnet hier nichts aus - er nimmt den Wert des Clients entgegen,
    begrenzt ihn und legt ihn als Netzwerkvariable ab. Von dort holen ihn alle
    anderen Clients in PrePlayerDraw.

    Ueber SetNW2Float statt einer eigenen Broadcast-Nachricht: die Engine
    verteilt den Wert dann nur an die, die den Spieler auch sehen, und drosselt
    selbst. Bei einer eigenen Nachricht muessten wir beides nachbauen.
]]

PD = PD or {}
PD.Freelook = PD.Freelook or {}

util.AddNetworkString("PD.Freelook")

-- Haerter als der Client sendet. Wer schneller schickt, wird ignoriert statt
-- gekickt: ein Ruckler soll niemanden aus dem Spiel werfen.
local MIN_INTERVAL = 1 / 15

net.Receive("PD.Freelook", function(_, ply)
    if not IsValid(ply) then return end

    local now = CurTime()

    if (ply.PD_FreelookNext or 0) > now then return end
    ply.PD_FreelookNext = now + MIN_INTERVAL

    local yaw   = net.ReadFloat()
    local pitch = net.ReadFloat()

    -- Nach NaN sieht kein Kopf mehr aus. tonumber faengt es nicht, der
    -- Selbstvergleich schon.
    if yaw ~= yaw or pitch ~= pitch then return end

    ply:SetNW2Float("PD.Freelook.Yaw", math.Clamp(yaw, -180, 180))
    ply:SetNW2Float("PD.Freelook.Pitch", math.Clamp(pitch, -90, 90))
end)

local function reset(ply)
    if not IsValid(ply) then return end

    ply:SetNW2Float("PD.Freelook.Yaw", 0)
    ply:SetNW2Float("PD.Freelook.Pitch", 0)
end

-- Beim Tod und beim Spawn zuruecksetzen, sonst startet man mit verdrehtem Kopf.
hook.Add("PlayerSpawn", "PD.Freelook.Reset", reset)
hook.Add("PlayerDeath", "PD.Freelook.Reset", reset)
hook.Add("PlayerChangedChar", "PD.Freelook.Reset", reset)
