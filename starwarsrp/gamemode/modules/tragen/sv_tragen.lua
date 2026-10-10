--[[
    Serverseite des Trage-Systems. Ueberblick in sh_tragen.lua.
]]

PD.Carry = PD.Carry or {}
PD.Carry.Active = PD.Carry.Active or {} -- [Spieler] = Datensatz

util.AddNetworkString("PD.Carry.Rotate")
util.AddNetworkString("PD.Carry.Drop")
util.AddNetworkString("PD.Carry.Query")

local COLOR_INFO = Color(90, 170, 255)
local COLOR_WARN = Color(255, 170, 60)

local function notify(ply, text, col)
    if not IsValid(ply) or not PD.Notify then return end

    PD.Notify(text, col or COLOR_INFO, false, ply)
end

local function log(text)
    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("[Tragen]", text, Color(90, 170, 255))
    end
end

local function applySpeed(ply)
    if IsValid(ply) and PD.Char and PD.Char.ApplySpeed then
        PD.Char.ApplySpeed(ply)
    end
end

local function displayName(ent)
    if PD.Carry.IsCorpse(ent) then
        return "Leiche von " .. ent:GetNW2Entity("PD.DM.RagdollOwner"):Nick()
    end

    local name = string.StripExtension(string.GetFileFromFilename(ent:GetModel() or ""))

    return name ~= "" and name or ent:GetClass()
end

local function eachPhys(ent, fn)
    local count = ent:GetPhysicsObjectCount()

    if count <= 0 then
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then fn(phys) end
        return
    end

    for i = 0, count - 1 do
        local phys = ent:GetPhysicsObjectNum(i)
        if IsValid(phys) then fn(phys) end
    end
end

local function eyeTrace(ply)
    local eye = ply:EyePos()

    -- Maske siehe sh_tragen.lua: Ragdoll-Knochen und Gitterzaeune.
    return util.TraceLine({
        start = eye,
        endpos = eye + ply:GetAimVector() * PD.Carry.Config.Reach,
        filter = ply,
        mask = PD.Carry.TraceMask
    })
end

-- Das PhysObj, das gefuehrt wird. Bei Ragdolls die Brust, damit der Koerper
-- natuerlich herunterhaengt; ohne passenden Knochen der angeschaute.
local function controlledPhys(ent, bone)
    if not ent:IsRagdoll() then
        return ent:GetPhysicsObject(), 0
    end

    local spine = ent:LookupBone("ValveBiped.Bip01_Spine2")
    local physBone = spine and ent:TranslateBoneToPhysBone(spine)

    if physBone and physBone >= 0 then
        local phys = ent:GetPhysicsObjectNum(physBone)
        if IsValid(phys) then return phys, physBone end
    end

    bone = bone or 0

    return ent:GetPhysicsObjectNum(bone), bone
end

local function physOf(ent, physBone)
    if ent:IsRagdoll() then
        return ent:GetPhysicsObjectNum(physBone)
    end

    return ent:GetPhysicsObject()
end

--[[
    Kollisionsgruppe zuruecksetzen, sobald kein Spieler mehr im Objekt steht.
    Sofort zurueckgesetzt wuerde ein Spieler, der gerade darin steht, stecken
    bleiben oder weggeschleudert.
]]
local function restoreGroup(ent)
    local name = "PD.Carry.Group." .. ent:EntIndex()

    timer.Create(name, 0.25, 0, function()
        if not IsValid(ent) or IsValid(ent:GetNW2Entity("PD.Carry.By")) then
            timer.Remove(name)
            return
        end

        local mins, maxs = ent:WorldSpaceAABB()

        for _, other in ipairs(ents.FindInBox(mins, maxs)) do
            if other:IsPlayer() and other:Alive() then return end
        end

        ent:SetCollisionGroup(ent.PD_CarryOrigGroup or COLLISION_GROUP_NONE)
        ent.PD_CarryOrigGroup = nil
        timer.Remove(name)
    end)
end

--[[
    Aufheben
]]
function PD.Carry.Pickup(ply, ent, bone)
    local cfg = PD.Carry.Config
    local phys, physBone = controlledPhys(ent, bone)

    if not IsValid(phys) then return false end

    local base = Angle(0, ply:EyeAngles().y, 0)
    local localAng

    if ent:IsRagdoll() then
        -- Ragdolls behalten ihre Lage: der gefuehrte Brustknochen hat andere
        -- Achsen als das Modell, "aufrecht" hiesse dort ein stehender Koerper.
        localAng = select(2, WorldToLocal(vector_origin, phys:GetAngles(), vector_origin, base))
    else
        -- Props immer aufrecht tragen. Nur die Blickrichtung zum Spieler
        -- bleibt erhalten, damit sich nichts beim Aufheben herumdreht.
        localAng = Angle(0, math.NormalizeAngle(phys:GetAngles().y - base.y), 0)
    end
    local radius = ent:BoundingRadius()

    -- Laeuft noch eine Ruecksetzung vom letzten Ablegen, ist die aktuelle
    -- Gruppe schon unsere - dann gilt die gemerkte.
    if ent.PD_CarryOrigGroup == nil then
        ent.PD_CarryOrigGroup = ent:GetCollisionGroup()
    end

    timer.Remove("PD.Carry.Group." .. ent:EntIndex())
    timer.Remove("PD.Carry.Anchor." .. ent:EntIndex())

    local rec = {
        ent = ent,
        physBone = physBone,
        localAng = localAng,
        rotate = 0,
        distance = math.Clamp(cfg.HoldDistance + radius * 0.5, 40, 90),
        back = math.min(radius, 30),
        gravity = phys:IsGravityEnabled(),
        heavy = ent:IsRagdoll() or PD.Carry.Size(ent) >= cfg.HeavySize,
        shadow = {}
    }

    PD.Carry.Active[ply] = rec
    ply:SetNW2Entity("PD.Carry.Ent", ent)
    ent:SetNW2Entity("PD.Carry.By", ply)

    -- Kollidiert weiter mit Welt und Props, aber nicht mit Spielern: kein
    -- Wegschieben, kein Draufstellen und Hochklettern.
    ent:SetCollisionGroup(COLLISION_GROUP_WEAPON)

    phys:EnableGravity(false)
    phys:Wake()

    if ent:IsRagdoll() then
        ent:EmitSound("physics/body/body_medium_impact_soft" .. math.random(1, 7) .. ".wav", 60)
    else
        ent:EmitSound("physics/cardboard/cardboard_box_impact_soft" .. math.random(1, 7) .. ".wav", 60)
    end

    applySpeed(ply)

    return true
end

--[[
    Ablegen, optional mit Verankern. skipEntity bei EntityRemoved: das
    Entity ist dann schon im Abbau und wird nicht mehr angefasst.
]]
function PD.Carry.Drop(ply, anchor, skipEntity)
    local cfg = PD.Carry.Config
    local rec = PD.Carry.Active[ply]

    PD.Carry.Active[ply] = nil

    if IsValid(ply) then
        ply:SetNW2Entity("PD.Carry.Ent", NULL)
        ply.PD_CarryReleaseButtons = true
        applySpeed(ply)
    end

    if not rec or skipEntity then return end

    local ent = rec.ent

    if not IsValid(ent) then return end

    ent:SetNW2Entity("PD.Carry.By", NULL)
    ent.PD_CarryDroppedAt = CurTime()

    local controlled = physOf(ent, rec.physBone)

    if IsValid(controlled) then
        controlled:EnableGravity(rec.gravity ~= false)
    end

    -- Nicht als Wurfgeschoss missbrauchen.
    eachPhys(ent, function(phys)
        local vel = phys:GetVelocity()

        if vel:Length() > cfg.DropSpeed then
            phys:SetVelocity(vel:GetNormalized() * cfg.DropSpeed)
        end

        phys:AddAngleVelocity(-phys:GetAngleVelocity() * 0.5)
    end)

    restoreGroup(ent)

    if not anchor then return end

    if not PD.Carry.IsEngineer(ply) then
        notify(ply, "Nur Engineers können Dinge im Boden verankern.", COLOR_WARN)
        return
    end

    if PD.Carry.IsCorpse(ent) then
        notify(ply, "Leichen lassen sich nicht verankern.", COLOR_WARN)
        return
    end

    PD.Carry.StartAnchor(ply, ent)
end

--[[
    Verankern

    Erst wenn das Objekt ruht und festen Boden unter sich hat - sonst liesse
    sich etwas in der Luft festfrieren.
]]
local function isResting(ent)
    local resting = true

    eachPhys(ent, function(phys)
        if phys:GetVelocity():Length() > 8 then resting = false end
    end)

    return resting
end

local function onGround(ent)
    local mins, maxs = ent:WorldSpaceAABB()
    local center = (mins + maxs) * 0.5

    local tr = util.TraceLine({
        start = center,
        endpos = Vector(center.x, center.y, mins.z - 6),
        filter = ent,
        mask = MASK_SOLID
    })

    if not tr.Hit then return false end
    if tr.HitWorld then return true end

    return IsValid(tr.Entity) and PD.Carry.IsFrozen(tr.Entity)
end

function PD.Carry.StartAnchor(ply, ent)
    local name = "PD.Carry.Anchor." .. ent:EntIndex()
    local deadline = CurTime() + PD.Carry.Config.AnchorTimeout

    timer.Create(name, 0.1, 0, function()
        if not IsValid(ent) or IsValid(ent:GetNW2Entity("PD.Carry.By")) or IsValid(ent:GetParent()) then
            timer.Remove(name)
            return
        end

        if isResting(ent) and onGround(ent) then
            timer.Remove(name)
            PD.Carry.Anchor(ent, ply)
            return
        end

        if CurTime() > deadline then
            timer.Remove(name)
            notify(ply, "Kein fester Boden - nicht verankert.", COLOR_WARN)
        end
    end)
end

function PD.Carry.Anchor(ent, ply)
    eachPhys(ent, function(phys)
        phys:EnableMotion(false)
    end)

    ent:SetNW2Bool("PD.Carry.Anchored", true)
    ent:EmitSound("physics/metal/metal_solid_impact_hard" .. math.random(1, 5) .. ".wav", 70, 90)

    if IsValid(ply) then
        notify(ply, "Im Boden verankert.")
        log(ply:Nick() .. " (" .. ply:SteamID64() .. ") hat " .. displayName(ent) .. " verankert.")
    end
end

function PD.Carry.Unanchor(ent)
    eachPhys(ent, function(phys)
        phys:EnableMotion(true)
        phys:Wake()
    end)

    ent:SetNW2Bool("PD.Carry.Anchored", false)
end

--[[
    Aufheben per gehaltenem E
]]
local luaUseCache = {}

local function hasLuaUse(ent)
    if not ent:IsScripted() then return false end

    local class = ent:GetClass()

    if luaUseCache[class] == nil then
        local stored = scripted_ents.Get(class)
        luaUseCache[class] = istable(stored) and isfunction(stored.Use) or false
    end

    return luaUseCache[class]
end

-- Einmal pro Tastendruck. KeyPress und PlayerUse koennen in beliebiger
-- Reihenfolge kommen, deshalb von beiden aus aufrufbar.
local function beginPress(ply)
    local press = ply.PD_CarryPress

    if press and press.t == CurTime() then return press end

    ply.PD_CarryPress = nil

    if PD.Carry.Active[ply] then return nil end

    -- Alt+E gehoert "Sit Anywhere".
    if ply:KeyDown(IN_WALK) then return nil end

    local tr = eyeTrace(ply)
    local ent = tr.Entity

    if not IsValid(ent) then return nil end

    local ok, reason, tell = PD.Carry.CanPickup(ply, ent)

    -- Verankertes kann ein Engineer per E halten loesen. Gilt dann wie ein
    -- gueltiger Druck: kurz E holt die normale Benutzung nach.
    local unanchor = not ok and PD.Carry.CanUnanchor(ply, ent)

    if unanchor then
        ok = true
    elseif not ok and not tell then
        return nil
    end

    press = {
        ent = ent,
        bone = tr.PhysicsBone or 0,
        t = CurTime(),
        ok = ok,
        unanchor = unanchor,
        reason = reason
    }

    ply.PD_CarryPress = press

    return press
end

hook.Add("AllowPlayerPickup", "PD.Carry.NoEnginePickup", function()
    return false
end)

hook.Add("KeyPress", "PD.Carry.Press", function(ply, key)
    if key == IN_USE then
        beginPress(ply)
    end
end)

hook.Add("PlayerUse", "PD.Carry.DeferUse", function(ply, ent)
    if PD.Carry.Active[ply] then return false end

    local press = ply.PD_CarryPress

    if (not press or press.t ~= CurTime()) and ply:KeyPressed(IN_USE) then
        press = beginPress(ply)
    end

    -- Benutzung zurueckstellen: kurz losgelassen wird sie in KeyRelease
    -- nachgeholt, gehalten wird aufgehoben.
    if press and press.ok and not press.cancel and press.ent == ent then
        return false
    end
end)

hook.Add("PlayerTick", "PD.Carry.Hold", function(ply)
    local press = ply.PD_CarryPress

    if not press or press.done or press.cancel then return end
    if not ply:KeyDown(IN_USE) then return end

    local ent = press.ent

    if not IsValid(ent) or eyeTrace(ply).Entity ~= ent then
        press.cancel = true
        return
    end

    if CurTime() - press.t < PD.Carry.Config.HoldTime then return end

    press.done = true

    if press.unanchor then
        if PD.Carry.CanUnanchor(ply, ent) then
            PD.Carry.Unanchor(ent)
            ent:EmitSound("physics/metal/metal_solid_impact_soft" .. math.random(1, 3) .. ".wav", 70, 110)
            notify(ply, "Verankerung gelöst.")
            log(ply:Nick() .. " (" .. ply:SteamID64() .. ") hat die Verankerung von " .. displayName(ent) .. " geloest.")
        end
    elseif press.ok then
        local ok, reason, tell = PD.Carry.CanPickup(ply, ent)

        if ok then
            PD.Carry.Pickup(ply, ent, press.bone)
        elseif tell then
            notify(ply, reason, COLOR_WARN)
        end
    elseif not hasLuaUse(ent) then
        -- Bei Dingen mit eigener E-Funktion (eingefrorene Munitionsbox) war
        -- das Halten die normale Benutzung, kein Trageversuch.
        notify(ply, press.reason, COLOR_WARN)
    end
end)

hook.Add("KeyRelease", "PD.Carry.Release", function(ply, key)
    if key ~= IN_USE then return end

    local press = ply.PD_CarryPress
    ply.PD_CarryPress = nil

    if not press or not press.ok or press.done or press.cancel then return end
    if PD.Carry.Active[ply] then return end

    local ent = press.ent

    if not IsValid(ent) then return end
    if ply:EyePos():Distance(ent:NearestPoint(ply:EyePos())) > PD.Carry.Config.Reach * 1.5 then return end

    -- Kurz gedrueckt: die zurueckgestellte Benutzung nachholen.
    ent:Use(ply, ply, USE_ON, 1)
end)

--[[
    Halten
]]
local function shouldDrop(ply, rec)
    if not ply:Alive() or ply:InVehicle() or ply:GetMoveType() == MOVETYPE_NOCLIP then return true end

    local ent = rec.ent

    if not IsValid(ent) or IsValid(ent:GetParent()) or ent:GetNoDraw() then return true end
    if ply:GetNW2Entity("PD.Carry.Ent") ~= ent then return true end

    -- Etwa ein Admin hat es per Physgun eingefroren.
    if PD.Carry.IsFrozen(ent) then return true end

    -- Waffe gewechselt: nur mit den Haenden wird getragen
    if not PD.Carry.HoldsHands(ply) then return true end

    return false
end

hook.Add("Think", "PD.Carry.Tick", function()
    local cfg = PD.Carry.Config
    local now = CurTime()

    for ply, rec in pairs(PD.Carry.Active) do
        if not IsValid(ply) then
            PD.Carry.Drop(ply, false)
        elseif shouldDrop(ply, rec) then
            PD.Carry.Drop(ply, false)
        else
            local phys = physOf(rec.ent, rec.physBone)

            if not IsValid(phys) then
                PD.Carry.Drop(ply, false)
            else
                local eye = ply:EyePos()
                local aim = ply:GetAimVector()
                local pos = eye + aim * rec.distance

                -- Nicht in Waende druecken.
                local tr = util.TraceLine({
                    start = eye,
                    endpos = pos,
                    filter = {ply, rec.ent},
                    mask = MASK_SOLID
                })

                if tr.Hit then
                    pos = eye + aim * math.max(rec.distance * tr.Fraction - rec.back, 16)
                end

                local _, ang = LocalToWorld(vector_origin, rec.localAng, vector_origin,
                    Angle(0, ply:EyeAngles().y + rec.rotate, 0))

                local shadow = rec.shadow

                for key, value in pairs(cfg.Shadow) do
                    shadow[key] = value
                end

                shadow.pos = pos
                shadow.angle = ang
                shadow.deltatime = FrameTime()

                phys:Wake()
                phys:ComputeShadowControl(shadow)

                if phys:GetPos():DistToSqr(pos) > cfg.StuckDistance * cfg.StuckDistance
                    or eye:DistToSqr(phys:GetPos()) > cfg.DropReach * cfg.DropReach then
                    rec.stuckSince = rec.stuckSince or now

                    if now - rec.stuckSince > cfg.StuckTime then
                        PD.Carry.Drop(ply, false)
                    end
                else
                    rec.stuckSince = nil
                end
            end
        end
    end
end)

--[[
    Eingaben beim Tragen
]]
net.Receive("PD.Carry.Rotate", function(_, ply)
    local rec = PD.Carry.Active[ply]

    if not rec then return end

    local now = CurTime()

    if (ply.PD_CarryRotateAt or 0) > now then return end

    ply.PD_CarryRotateAt = now + 1 / 30

    local steps = math.Clamp(net.ReadInt(4), -3, 3)

    rec.rotate = math.NormalizeAngle(rec.rotate + steps * PD.Carry.Config.RotateStep)
end)

net.Receive("PD.Carry.Drop", function(_, ply)
    if not PD.Carry.Active[ply] then return end

    PD.Carry.Drop(ply, net.ReadBool())
end)

-- Der Client fragt fuer das angeschaute Objekt nach, ob es tragbar ist. Nur
-- der Server kennt Einfrieren und Physik - ohne Nachfrage liefe der Balken
-- auch bei Dingen voll, die sich dann nicht aufheben lassen.
net.Receive("PD.Carry.Query", function(_, ply)
    local now = CurTime()

    if (ply.PD_CarryQueryAt or 0) > now then return end

    ply.PD_CarryQueryAt = now + 0.1

    local ent = net.ReadEntity()

    if not IsValid(ent) then return end

    -- 0 = nichts, 1 = tragen, 2 = Verankerung loesen (Engineers)
    local mode = 0

    if PD.Carry.CanPickup(ply, ent) then
        mode = 1
    elseif PD.Carry.CanUnanchor(ply, ent) then
        mode = 2
    end

    net.Start("PD.Carry.Query")
    net.WriteEntity(ent)
    net.WriteUInt(mode, 2)
    net.Send(ply)
end)

-- Waehrend des Tragens und bis die Taste nach dem Ablegen losgelassen ist
-- feuert keine Waffe. Ablegen selbst kommt per Netzmeldung vom Client.
hook.Add("StartCommand", "PD.Carry.Buttons", function(ply, cmd)
    local carrying = PD.Carry.Active[ply] ~= nil

    if not carrying and not ply.PD_CarryReleaseButtons then return end

    if not carrying and bit.band(cmd:GetButtons(), bit.bor(IN_ATTACK, IN_ATTACK2)) == 0 then
        ply.PD_CarryReleaseButtons = nil
        return
    end

    cmd:RemoveKey(IN_ATTACK)
    cmd:RemoveKey(IN_ATTACK2)
end)

--[[
    Schutz und Tempo
]]
hook.Add("EntityTakeDamage", "PD.Carry.NoCrush", function(target, dmg)
    if not target:IsPlayer() or not dmg:IsDamageType(DMG_CRUSH) then return end

    local window = PD.Carry.Config.CrushProtection

    for _, ent in ipairs({dmg:GetInflictor(), dmg:GetAttacker()}) do
        if IsValid(ent) and not ent:IsPlayer() then
            if IsValid(ent:GetNW2Entity("PD.Carry.By")) then return true end
            if ent.PD_CarryDroppedAt and CurTime() - ent.PD_CarryDroppedAt < window then return true end
        end
    end
end)

hook.Add("PD_Speed_Applied", "PD.Carry.Slow", function(ply, walk)
    local rec = PD.Carry.Active[ply]

    if not rec or not rec.heavy then return end

    local slow = math.Round(walk * PD.Carry.Config.SlowFactor)

    return slow, slow
end)

--[[
    Aufraeumen
]]
local function dropFor(ply)
    if PD.Carry.Active[ply] then
        PD.Carry.Drop(ply, false)
    end
end

hook.Add("PlayerDeath", "PD.Carry.Cleanup", function(ply)
    dropFor(ply)
end)

hook.Add("PlayerSpawn", "PD.Carry.Cleanup", function(ply)
    dropFor(ply)
    ply.PD_CarryPress = nil
end)

hook.Add("PlayerEnteredVehicle", "PD.Carry.Cleanup", function(ply)
    dropFor(ply)
end)

hook.Add("PlayerDisconnected", "PD.Carry.Cleanup", function(ply)
    dropFor(ply)
end)

hook.Add("PlayerNoClip", "PD.Carry.Cleanup", function(ply, desired)
    if desired then dropFor(ply) end
end)

hook.Add("EntityRemoved", "PD.Carry.Cleanup", function(ent)
    for ply, rec in pairs(PD.Carry.Active) do
        if rec.ent == ent then
            PD.Carry.Drop(ply, false, true)
        end
    end
end)

-- Ein Admin nimmt es per Physgun: der Traeger laesst los.
hook.Add("PhysgunPickup", "PD.Carry.PhysgunTakes", function(_, ent)
    local carrier = IsValid(ent) and ent:GetNW2Entity("PD.Carry.By")

    if IsValid(carrier) then
        PD.Carry.Drop(carrier, false)
    end
end)

hook.Add("PlayerUnfrozeObject", "PD.Carry.Unanchored", function(_, ent)
    if IsValid(ent) and ent:GetNW2Bool("PD.Carry.Anchored") then
        ent:SetNW2Bool("PD.Carry.Anchored", false)
    end
end)

--[[
    Admin-Befehle
]]
concommand.Add("pd_tragen_loesen", function(ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local ent = ply:GetEyeTrace().Entity

    if not IsValid(ent) or ent:IsWorld() then
        notify(ply, "Du schaust auf nichts.", COLOR_WARN)
        return
    end

    PD.Carry.Unanchor(ent)
    notify(ply, "Verankerung geloest: " .. displayName(ent))
    log(ply:Nick() .. " (" .. ply:SteamID64() .. ") hat die Verankerung von " .. displayName(ent) .. " geloest.")
end)

concommand.Add("pd_tragen_debug", function(caller)
    if IsValid(caller) and not caller:IsAdmin() then return end

    local function say(text)
        if IsValid(caller) then caller:PrintMessage(HUD_PRINTCONSOLE, text) else print(text) end
    end

    local cfg = PD.Carry.Config

    say("[Tragen] Aktive Traeger: " .. table.Count(PD.Carry.Active))

    for ply, rec in pairs(PD.Carry.Active) do
        say("  " .. (IsValid(ply) and ply:Nick() or "?") .. " -> " .. tostring(rec.ent)
            .. ", PhysObj " .. tostring(rec.physBone)
            .. ", schwer " .. tostring(rec.heavy)
            .. ", Drehung " .. tostring(rec.rotate))
    end

    if not IsValid(caller) then return end

    -- Gleiche Maske wie beim Aufheben, nur weiter - sonst saehe die Diagnose
    -- etwas anderes als das System.
    local eye = caller:EyePos()
    local ent = util.TraceLine({
        start = eye,
        endpos = eye + caller:GetAimVector() * 1000,
        filter = caller,
        mask = PD.Carry.TraceMask
    }).Entity

    if not IsValid(ent) or ent:IsWorld() then
        say("[Tragen] Du schaust auf nichts.")
        return
    end

    local phys = ent:GetPhysicsObject()

    say("[Tragen] Ziel: " .. tostring(ent) .. ", Modell " .. tostring(ent:GetModel()))
    say("  Groesse " .. math.Round(PD.Carry.Size(ent)) .. " (max " .. cfg.MaxSize .. ", langsam ab " .. cfg.HeavySize .. ")"
        .. ", Masse " .. tostring(IsValid(phys) and math.Round(phys:GetMass(), 1) or "-")
        .. " (max " .. tostring(cfg.MaxMass or "aus") .. ")"
        .. ", Bewegungsart " .. tostring(ent:GetMoveType()) .. " (6 = Physik)")
    say("  Fahrzeug " .. tostring(PD.Carry.IsVehicleLike(ent))
        .. ", eingefroren " .. tostring(PD.Carry.IsFrozen(ent))
        .. ", verankert " .. tostring(ent:GetNW2Bool("PD.Carry.Anchored"))
        .. ", Leiche " .. tostring(PD.Carry.IsCorpse(ent))
        .. ", Lua-Use " .. tostring(hasLuaUse(ent)))

    local ok, reason = PD.Carry.CanPickup(caller, ent)

    say("  Aufhebbar: " .. (ok and "ja" or ("nein - " .. tostring(reason))))
    say("  Du bist Engineer: " .. tostring(PD.Carry.IsEngineer(caller))
        .. ", darfst Verankerung loesen: " .. tostring(PD.Carry.CanUnanchor(caller, ent)))
end)
