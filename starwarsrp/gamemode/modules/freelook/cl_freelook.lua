--[[
    Umsehen, ohne den Koerper zu drehen.

    Solange die Taste gehalten wird, bekommt der Server weiterhin die
    eingefrorene Blickrichtung: Koerper, Waffe und Bewegungsrichtung bleiben
    stehen. Die Mausbewegung sammeln wir stattdessen selbst ein und legen sie
    nur auf die Kamera.

    In der Ich-Perspektive dreht der Kopf des Spielermodells mit, damit andere
    sehen, wohin man schaut, und der Blick endet dort, wo ein Hals endet. In der
    Schulterperspektive laeuft die Kamera dagegen frei um die Figur herum - dort
    schaut man sich um sich selbst um, nicht aus sich heraus.
]]

PD = PD or {}
PD.Freelook = PD.Freelook or {}

-- Ich-Perspektive: so weit dreht ein Hals.
local MAX_YAW_FIRST   = 115
local MAX_PITCH_FIRST = 70

-- Schulterperspektive: seitlich unbegrenzt, die Kamera umrundet die Figur.
-- Nur die Hoehe bleibt begrenzt, sonst kippt die Ansicht ueber den Kopf.
local MAX_PITCH_THIRD = 80

--[[
    Anteil der normalen Mausempfindlichkeit beim Umsehen.

    Bewusst langsamer als beim Zielen: in der Ich-Perspektive faehrt der Blick
    gegen einen festen Anschlag statt frei weiterzudrehen, und bei voller
    Empfindlichkeit steht er schon nach einem kurzen Ruck am Rand.
]]
local SENS_SCALE = 0.5

--[[
    Glaettung der Kamerabewegung, in Anteilen je Sekunde.

    Groesser heisst direkter und haerter, kleiner heisst weicher und traeger.
    35 entspricht knapp 30 Millisekunden Nachlauf - genug, um einzelne
    Mausstufen zu verschleifen, ohne dass sich die Kamera schwammig anfuehlt.
]]
local SMOOTH = 35

-- Nur solange gehalten wird, und dann hoechstens so oft je Sekunde.
local SEND_RATE = 1 / 12
-- Unter dieser Aenderung lohnt sich keine Nachricht.
local SEND_EPS  = 1.5

PD.Freelook.Active = false
PD.Freelook.Offset = Angle(0, 0, 0)

-- Wohin die Maus zeigt (ungeglaettet) und wo der Koerper steht.
local target = Angle(0, 0, 0)
local locked = Angle(0, 0, 0)

local nextSend = 0
local sentYaw, sentPitch = 0, 0
local wasSending = false

--------------------------------------------------------------------------------
-- Nach aussen
--------------------------------------------------------------------------------

--[[
    Blickwinkel mit Freelook-Anteil. Wird aus cl_fov.lua aufgerufen, damit es
    nur einen CalcView-Hook im Gamemode gibt statt zweier, die sich um die
    Rueckgabe streiten.

    Waehrend Freelook laeuft, wird bewusst nicht der uebergebene Winkel benutzt,
    sondern die festgehaltene Richtung: EyeAngles des eigenen Spielers haengt an
    der Vorhersage und springt an Tickgrenzen. Genau daraus entsteht ein
    Ruckeln, das mit der Mausbewegung selbst nichts zu tun hat.
]]
function PD.Freelook.Apply(ang)
    local off = PD.Freelook.Offset

    if off.p == 0 and off.y == 0 then return ang end

    --[[
        Waehrend gehalten wird, ist die festgehaltene Richtung die Grundlage.
        Beim Rueckschwenk danach nicht mehr: dort darf die Maus schon wieder
        normal drehen, und wuerde weiter locked als Grundlage dienen, haenge die
        Sicht fuer die Dauer des Rueckschwenks fest.
    ]]
    local base = PD.Freelook.Active and locked or ang

    return Angle(
        math.NormalizeAngle(base.p + off.p),
        math.NormalizeAngle(base.y + off.y),
        ang.r
    )
end

function PD.Freelook.Stop()
    PD.Freelook.Active = false
end

--------------------------------------------------------------------------------
-- Eingabe
--------------------------------------------------------------------------------

local function canFreelook(ply)
    return IsValid(ply) and ply:Alive() and not ply:InVehicle()
end

function PD.Freelook.Start()
    local ply = LocalPlayer()
    if not canFreelook(ply) then return end
    if PD.Freelook.Active then return end

    locked = ply:EyeAngles()

    target.p = 0
    target.y = 0

    PD.Freelook.Active = true
end

--[[
    Die Blickrichtung festhalten und die Maus selbst auswerten.

    cmd:SetViewAngles setzt die Sicht auf den festgehaltenen Wert zurueck, damit
    Koerper und Zielrichtung stehen bleiben.

    GetMouseX/GetMouseY liefern die Mausbewegung dieses Frames - und zwar
    bereits mit der Mausempfindlichkeit des Spielers verrechnet. Es fehlt nur
    noch der Grad-Faktor aus m_yaw beziehungsweise m_pitch. Die Empfindlichkeit
    ein zweites Mal daraufzumultiplizieren war der Grund, warum sich das
    Umsehen genau um den Faktor der eigenen Einstellung zu schnell anfuehlte.
]]
hook.Add("CreateMove", "PD.Freelook.Hold", function(cmd)
    if not PD.Freelook.Active then return end

    local ply = LocalPlayer()

    if not canFreelook(ply) then
        PD.Freelook.Active = false
        return
    end

    local myaw   = GetConVar("m_yaw")
    local mpitch = GetConVar("m_pitch")

    local sy = (myaw and myaw:GetFloat() or 0.022) * SENS_SCALE
    local sp = (mpitch and mpitch:GetFloat() or 0.022) * SENS_SCALE

    local dy = cmd:GetMouseX() * sy
    local dp = cmd:GetMouseY() * sp

    if PD.FOV and PD.FOV.thirdPerson then
        -- Voller Umlauf um die Figur: normalisieren statt begrenzen.
        target.y = math.NormalizeAngle(target.y - dy)
        target.p = math.Clamp(target.p + dp, -MAX_PITCH_THIRD, MAX_PITCH_THIRD)
    else
        target.y = math.Clamp(target.y - dy, -MAX_YAW_FIRST, MAX_YAW_FIRST)
        target.p = math.Clamp(target.p + dp, -MAX_PITCH_FIRST, MAX_PITCH_FIRST)
    end

    cmd:SetViewAngles(locked)
end)

--[[
    Glaettung und Rueckschwenk.

    Beides ueber denselben Weg: die Kamera laeuft immer dem Ziel hinterher, und
    beim Loslassen ist das Ziel eben die Null. Der Gierwinkel wird dabei ueber
    NormalizeAngle gefuehrt, damit die Kamera nach einem vollen Umlauf in der
    Schulterperspektive den kurzen Weg zurueck nimmt statt einmal herum.

    Der Hook haengt am Zustand, nicht am Bind: bleibt die Taste einmal haengen -
    Menue im Vordergrund, Fokusverlust - faellt Freelook trotzdem zurueck,
    sobald sie nicht mehr gedrueckt ist.
]]
hook.Add("Think", "PD.Freelook.Follow", function()
    if PD.Freelook.Active then
        local bind = PD.Binds and PD.Binds.List and PD.Binds.List["freelook"]

        if bind and bind.Key and bind.Key ~= KEY_NONE and not input.IsKeyDown(bind.Key) then
            PD.Freelook.Active = false
        end
    end

    if not PD.Freelook.Active then
        target.p = 0
        target.y = 0
    end

    local off = PD.Freelook.Offset

    if off.p == target.p and off.y == target.y then return end

    local f = math.Clamp(FrameTime() * SMOOTH, 0, 1)

    off.p = off.p + (target.p - off.p) * f
    off.y = math.NormalizeAngle(off.y + math.NormalizeAngle(target.y - off.y) * f)

    -- Sonst kriecht der Wert endlos gegen null und die Kamera bliebe dauerhaft
    -- ein Zehntelgrad verdreht.
    if math.abs(off.p - target.p) < 0.05 then off.p = target.p end
    if math.abs(math.NormalizeAngle(off.y - target.y)) < 0.05 then off.y = target.y end
end)

--------------------------------------------------------------------------------
-- Kopfdrehung fuer die anderen
--------------------------------------------------------------------------------

--[[
    Der Kopf dreht nur in der Ich-Perspektive mit.

    In der Schulterperspektive sieht man sich selbst - dort soll die Figur ruhig
    stehen bleiben, waehrend die Kamera um sie kreist. Deshalb wird in dem Fall
    eine Null geschickt statt gar nichts: sonst bliebe der zuletzt gesendete
    Wert bei allen anderen stehen.
]]
hook.Add("Think", "PD.Freelook.Send", function()
    if CurTime() < nextSend then return end

    local off = PD.Freelook.Offset
    local thirdPerson = PD.FOV and PD.FOV.thirdPerson

    local yaw, pitch = 0, 0

    if PD.Freelook.Active and not thirdPerson then
        yaw, pitch = off.y, off.p
    end

    local sending = yaw ~= 0 or pitch ~= 0

    if not sending and not wasSending then return end

    if sending
        and math.abs(yaw - sentYaw) < SEND_EPS
        and math.abs(pitch - sentPitch) < SEND_EPS then
        return
    end

    nextSend = CurTime() + SEND_RATE
    sentYaw, sentPitch = yaw, pitch
    wasSending = sending

    net.Start("PD.Freelook")
        net.WriteFloat(yaw)
        net.WriteFloat(pitch)
    net.SendToServer()
end)

--[[
    Die Kopfhaltung kurz vor dem Zeichnen setzen.

    Bewusst hier und nicht in UpdateAnimation: die Animationslogik des
    Gamemodes laeuft danach und wuerde die Pose-Parameter wieder ueberschreiben.
    PrePlayerDraw ist die letzte Station vor dem Rendern.
]]
hook.Add("PrePlayerDraw", "PD.Freelook.Head", function(ply)
    if not IsValid(ply) then return end

    local yaw   = ply:GetNW2Float("PD.Freelook.Yaw", 0)
    local pitch = ply:GetNW2Float("PD.Freelook.Pitch", 0)

    if yaw == 0 and pitch == 0 then return end

    if ply:LookupPoseParameter("head_yaw") >= 0 then
        ply:SetPoseParameter("head_yaw", yaw)
    end

    if ply:LookupPoseParameter("head_pitch") >= 0 then
        ply:SetPoseParameter("head_pitch", pitch)
    end

    ply:InvalidateBoneCache()
end)

--------------------------------------------------------------------------------
-- Diagnose
--------------------------------------------------------------------------------

--[[
    Ob ein Spielermodell den Kopf ueberhaupt drehen kann, steht in der .mdl und
    laesst sich von aussen nicht ablesen. Deshalb hier nachsehen statt raten.
]]
concommand.Add("pd_freelook_debug", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    print("[Freelook] Model: " .. ply:GetModel())
    print("[Freelook] head_yaw   : " .. ply:LookupPoseParameter("head_yaw"))
    print("[Freelook] head_pitch : " .. ply:LookupPoseParameter("head_pitch"))
    print("[Freelook] Pose-Parameter des Models:")

    for i = 0, ply:GetNumPoseParameters() - 1 do
        local min, max = ply:GetPoseParameterRange(i)

        print(string.format("  %2d  %-20s %.0f bis %.0f",
            i, ply:GetPoseParameterName(i), min, max))
    end

    print("[Freelook] Aktiv: " .. tostring(PD.Freelook.Active)
        .. ", Ziel: " .. tostring(target)
        .. ", Kamera: " .. tostring(PD.Freelook.Offset))

    local myaw = GetConVar("m_yaw")
    local sens = GetConVar("sensitivity")

    print(string.format("[Freelook] m_yaw %.4f, sensitivity %.2f, Faktor %.2f",
        myaw and myaw:GetFloat() or -1,
        sens and sens:GetFloat() or -1,
        SENS_SCALE))
end)
