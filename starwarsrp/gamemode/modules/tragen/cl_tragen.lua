--[[
    Clientseite des Trage-Systems: Eingaben beim Tragen und Hinweise.
    Ueberblick in sh_tragen.lua.

    Wird vor sh_tragen.lua geladen (alphabetisch) - deshalb hier nichts aus
    PD.Carry beim Laden in lokale Variablen ziehen.
]]

PD.Carry = PD.Carry or {}

local attackWas, attack2Was = false, false
local dropSent = false
local releaseButtons = false
local wheelSum, wheelSentAt = 0, 0

--[[
    Linksklick legt ab, Rechtsklick legt ab und verankert, das Mausrad dreht.
    Die Tasten werden aus dem Befehl entfernt, damit keine Waffe schiesst oder
    zielt - der Server erfaehrt das Ablegen deshalb per Netzmeldung.
]]
hook.Add("StartCommand", "PD.Carry.Input", function(ply, cmd)
    if ply ~= LocalPlayer() then return end

    local buttons = cmd:GetButtons()
    local attack = bit.band(buttons, IN_ATTACK) ~= 0
    local attack2 = bit.band(buttons, IN_ATTACK2) ~= 0
    local carrying = PD.Carry.IsCarrying and PD.Carry.IsCarrying(ply)

    if carrying then
        releaseButtons = true

        if not dropSent and ((attack and not attackWas) or (attack2 and not attack2Was)) then
            dropSent = true

            net.Start("PD.Carry.Drop")
            net.WriteBool(attack2 and not attack)
            net.SendToServer()
        end

        local wheel = cmd:GetMouseWheel()

        if wheel ~= 0 then
            wheelSum = math.Clamp(wheelSum + wheel, -3, 3)
            cmd:SetMouseWheel(0)
        end

        if wheelSum ~= 0 and RealTime() - wheelSentAt >= 0.05 then
            net.Start("PD.Carry.Rotate")
            net.WriteInt(wheelSum, 4)
            net.SendToServer()

            wheelSum = 0
            wheelSentAt = RealTime()
        end
    else
        dropSent = false
        wheelSum = 0

        if not attack and not attack2 then
            releaseButtons = false
        end
    end

    attackWas, attack2Was = attack, attack2

    if carrying or releaseButtons then
        cmd:RemoveKey(IN_ATTACK)
        cmd:RemoveKey(IN_ATTACK2)
    end
end)

--[[
    Hinweise
]]
local COLOR_TEXT = Color(255, 255, 255)
local COLOR_SHADOW = Color(0, 0, 0, 200)
local COLOR_BAR_BG = Color(0, 0, 0, 160)
local COLOR_BAR = Color(90, 170, 255)
local COLOR_ANCHORED = Color(255, 170, 60)

--[[
    Tragbar? Beim Server nachfragen

    Einfrieren und Physik kennt nur der Server. Die Antwort gilt kurz und wird
    beim Anschauen laufend erneuert, damit sie beim Druecken schon da ist.
    Antwort: 0 = nichts, 1 = tragen, 2 = Verankerung loesen (Engineers).
]]
local answers = setmetatable({}, {__mode = "k"})
local ANSWER_TTL = 0.5
local lastQuery = 0

net.Receive("PD.Carry.Query", function()
    local ent = net.ReadEntity()
    local mode = net.ReadUInt(2)

    if IsValid(ent) then
        answers[ent] = {mode = mode, t = RealTime()}
    end
end)

local function askServer(ent)
    local now = RealTime()
    local answer = answers[ent]

    if (not answer or now - answer.t > ANSWER_TTL) and now - lastQuery >= 0.15 then
        lastQuery = now

        net.Start("PD.Carry.Query")
        net.WriteEntity(ent)
        net.SendToServer()
    end

    if answer and now - answer.t <= ANSWER_TTL * 2 then
        return answer.mode
    end

    return 0
end

local useWas = false
local holdEnt, holdStart = nil, 0

local function hint(text, y, col)
    draw.SimpleTextOutlined(text, "MLIB.25", ScrW() * 0.5, y, col or COLOR_TEXT,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, COLOR_SHADOW)
end

hook.Add("HUDPaint", "PD.Carry.Hints", function()
    local ply = LocalPlayer()

    if not IsValid(ply) or not PD.Carry.Config then return end

    local useDown = ply:KeyDown(IN_USE)
    local pressed = useDown and not useWas
    useWas = useDown

    local y = ScrH() * 0.5 + PD.H(90)

    if not ply:Alive() or ply:InVehicle() then
        holdEnt = nil
        return
    end

    if PD.Carry.IsCarrying(ply) then
        holdEnt = nil
        if PD.Carry.IsEngineer(ply) then
            hint("Linksklick  Ablegen   ·   Rechtsklick  Verankern   ·   Mausrad  Drehen", y)
        else
            hint("Linksklick  Ablegen   ·   Mausrad  Drehen", y)
        end
        return
    end

    local eye = ply:EyePos()
    local tr = util.TraceLine({
        start = eye,
        endpos = eye + ply:GetAimVector() * PD.Carry.Config.Reach,
        filter = ply,
        mask = PD.Carry.TraceMask or MASK_SHOT
    })

    local ent = tr.Entity
    local anchored = IsValid(ent) and ent:GetNW2Bool("PD.Carry.Anchored")
    local candidate

    if anchored then
        -- Verankertes koennen nur Engineers per E halten loesen.
        candidate = PD.Carry.IsEngineer(ply) and not ply:KeyDown(IN_WALK)
    else
        candidate = IsValid(ent) and not ply:KeyDown(IN_WALK) and PD.Carry.CanPickup(ply, ent)
    end

    -- Schon beim Anschauen nachfragen, damit die Antwort beim Druecken da ist.
    local mode = candidate and askServer(ent) or 0

    -- Wie auf dem Server: nur ein Druck, der auf dem Objekt beginnt, zaehlt;
    -- wegschauen bricht ab.
    if pressed then
        holdEnt = candidate and ent or nil
        holdStart = CurTime()
    end

    local holding = useDown and IsValid(holdEnt) and ent == holdEnt

    if not holding then
        holdEnt = nil
    end

    -- Balken nur, wenn der Server es wirklich zulaesst.
    if not holding or mode == 0 then
        if anchored then
            hint("Verankert", y, COLOR_ANCHORED)
        end

        return
    end

    local frac = math.Clamp((CurTime() - holdStart) / PD.Carry.Config.HoldTime, 0, 1)

    if frac >= 1 then return end

    local w, h = PD.W(160), PD.H(6)
    local x = ScrW() * 0.5 - w * 0.5

    hint(mode == 2 and "Lösen" or "Tragen", y)
    draw.RoundedBox(3, x, y + PD.H(20), w, h, COLOR_BAR_BG)
    draw.RoundedBox(3, x, y + PD.H(20), w * frac, h, COLOR_BAR)
end)
