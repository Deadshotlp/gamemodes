--[[
    Trage-System: Props, Kisten und Leichen mit gehaltenem E aufheben.

    Das Objekt schwebt vor dem Spieler, das Mausrad dreht es, Linksklick legt
    es ab, Rechtsklick legt es ab und verankert es im Boden (einfrieren).
    Eingefrorenes laesst sich nicht aufheben, Fahrzeuge nie.

    Verankern und wieder loesen (E halten auf Verankertem) duerfen nur
    Engineers - Job oder Untereinheit mit "Ist Engineer" im Job-Editor.

    Kurz E bleibt die normale Benutzung - erst wer E haelt, hebt auf. Deshalb
    stellt der Server die Benutzung tragbarer Dinge zurueck und loest sie beim
    Loslassen nach, falls nicht aufgehoben wurde (sv_tragen.lua).

    Entschieden wird auf dem Server, der Client zeigt nur an.
]]

PD.Carry = PD.Carry or {}

PD.Carry.Config = {
    HoldTime = 0.4,          -- Sekunden E halten bis zum Aufheben
    Reach = 100,             -- Reichweite zum Aufheben (Units)
    DropReach = 250,         -- weiter von den Augen weg -> Objekt faellt
    -- Groesse statt Gewicht: die Masse eigener Modelle (Kisten, Zaeune aus
    -- Addons) ist oft willkuerlich hoch und sagt nichts darueber, wie gross
    -- etwas ist. pd_tragen_debug zeigt beides an.
    MaxSize = 256,           -- laengste Seite in Units (~6,5 m), Ragdolls ausgenommen
    MaxMass = false,         -- kg, false = keine Gewichtsgrenze
    HeavySize = 100,         -- ab dieser Laenge langsamer (~2,5 m), Ragdolls immer
    SlowFactor = 0.6,        -- Gehtempo beim schweren Tragen, Sprint aus
    RotateStep = 5,          -- Grad pro Mausrad-Raste
    HoldDistance = 45,       -- Abstand vor den Augen, plus halbe Objektgroesse
    StuckDistance = 90,      -- so weit vom Ziel gilt als festgehangen ...
    StuckTime = 0.5,         -- ... so lange, dann faellt es
    AnchorTimeout = 3,       -- so lange wird nach dem Ablegen Boden gesucht
    CrushProtection = 1.5,   -- Sekunden nach dem Ablegen ohne Quetschschaden
    DropSpeed = 200,         -- Hoechstgeschwindigkeit beim Loslassen

    -- Haltekraft fuer PhysObj:ComputeShadowControl. Hoehere maxspeed/
    -- maxangular = strafferes Halten, kleinere secondstoarrive = schneller.
    Shadow = {
        secondstoarrive = 0.05,
        maxangular = 5000,
        maxangulardamp = 10000,
        maxspeed = 1500,
        maxspeeddamp = 10000,
        dampfactor = 0.8,
        teleportdistance = 0
    },

    -- Nie tragbar. Die Bomben brauchen gehaltenes E fuer sich selbst.
    Blacklist = {
        joe_bomb = true,
        joe_cable = true,
        joe_train_bomb = true
    },

    -- LVS und simfphys melden sich nicht per IsVehicle.
    VehiclePrefixes = {"lvs_", "gmod_sent_vehicle_fphysics"}
}

function PD.Carry.GetCarried(ply)
    if not IsValid(ply) then return NULL end

    return ply:GetNW2Entity("PD.Carry.Ent")
end

function PD.Carry.IsCarrying(ply)
    return IsValid(PD.Carry.GetCarried(ply))
end

function PD.Carry.IsVehicleLike(ent)
    if ent:IsVehicle() or ent.LVS or ent.IsSimfphyscar then return true end

    local class = ent:GetClass()

    for _, prefix in ipairs(PD.Carry.Config.VehiclePrefixes) do
        if class:sub(1, #prefix) == prefix then return true end
    end

    return false
end

-- Leiche eines Spielers aus dem Todesmodul (wartet ggf. auf Wiederbelebung).
function PD.Carry.IsCorpse(ent)
    return ent:IsRagdoll() and IsValid(ent:GetNW2Entity("PD.DM.RagdollOwner"))
end

-- Laengste Seite der Modell-Box. Auch auf dem Client bekannt.
function PD.Carry.Size(ent)
    local size = ent:OBBMaxs() - ent:OBBMins()

    return math.max(size.x, size.y, size.z)
end

-- MASK_SHOT trifft Ragdoll-Hitboxen und liefert so den Knochen, laesst aber
-- Gitter durch - Maschendrahtzaeune waeren fuer die Suche sonst unsichtbar.
PD.Carry.TraceMask = bit.bor(MASK_SHOT, CONTENTS_GRATE)

-- Nur auf dem Server aussagekraeftig: der Bewegungszustand der PhysObjs wird
-- nicht an Clients uebertragen.
function PD.Carry.IsFrozen(ent)
    local count = ent:GetPhysicsObjectCount()

    if count <= 0 then
        local phys = ent:GetPhysicsObject()
        return IsValid(phys) and not phys:IsMotionEnabled()
    end

    for i = 0, count - 1 do
        local phys = ent:GetPhysicsObjectNum(i)

        if IsValid(phys) and not phys:IsMotionEnabled() then
            return true
        end
    end

    return false
end

--[[
    Darf ply das Entity aufheben?

    Rueckgabe: ok, Grund, melden. "melden" ist true, wenn der Grund dem Spieler
    nach gehaltenem E angezeigt werden soll (zu schwer, eingefroren ...). Bei
    Fahrzeugen, Spielern usw. passiert still nichts.
]]
-- Getragen wird nur mit den Haenden in der Hand
function PD.Carry.HoldsHands(ply)
    local wep = IsValid(ply) and ply:GetActiveWeapon()
    return IsValid(wep) and wep:GetClass() == ((PD.Equip and PD.Equip.Hands) or "mhands")
end

function PD.Carry.CanPickup(ply, ent)
    local cfg = PD.Carry.Config

    if not IsValid(ply) or not ply:Alive() or ply:InVehicle() then return false, "Gerade nicht moeglich." end
    if not PD.Carry.HoldsHands(ply) then return false, "Nur mit den Haenden." end
    if PD.Carry.IsCarrying(ply) then return false, "Du traegst bereits etwas." end
    if not IsValid(ent) or ent:IsWorld() then return false, "Nichts zum Tragen." end
    if ent:IsPlayer() or ent:IsNPC() or ent:IsNextBot() then return false, "Lebewesen lassen sich nicht tragen." end
    if PD.Carry.IsVehicleLike(ent) then return false, "Fahrzeuge lassen sich nicht tragen." end
    if ent:GetMoveType() ~= MOVETYPE_VPHYSICS then return false, "Nicht beweglich." end
    if IsValid(ent:GetParent()) or ent:GetNoDraw() then return false, "Gerade nicht erreichbar." end
    if cfg.Blacklist[ent:GetClass()] or ent.PD_NoCarry then return false, "Laesst sich nicht tragen." end
    if IsValid(ent:GetNW2Entity("PD.Carry.By")) then return false, "Wird schon getragen.", true end

    local eye = ply:EyePos()

    if eye:DistToSqr(ent:NearestPoint(eye)) > cfg.Reach * cfg.Reach then
        return false, "Zu weit weg."
    end

    if not ent:IsRagdoll() and PD.Carry.Size(ent) > cfg.MaxSize then
        return false, "Zu gross zum Tragen.", true
    end

    if SERVER then
        if PD.Carry.IsFrozen(ent) then
            if ent:GetNW2Bool("PD.Carry.Anchored") then
                return false, "Im Boden verankert.", true
            end

            return false, "Eingefroren.", true
        end

        if not ent:IsRagdoll() then
            local phys = ent:GetPhysicsObject()

            if not IsValid(phys) then return false, "Keine Physik." end

            if cfg.MaxMass and phys:GetMass() > cfg.MaxMass then
                return false, "Zu schwer zum Tragen.", true
            end
        end
    elseif ent:GetNW2Bool("PD.Carry.Anchored") then
        return false, "Im Boden verankert.", true
    end

    local allowed, reason = hook.Run("PD.Carry.CanPickup", ply, ent)

    if allowed == false then
        return false, reason or "Laesst sich nicht tragen.", reason ~= nil
    end

    return true
end

-- Die Flags kommen je nach Weg als Boolean oder als Zahl aus der Datenbank.
local function flag(value)
    return value == true or value == 1 or value == "1"
end

--[[
    Engineer: der Job selbst oder seine Untereinheit ist im Job-Editor als
    Engineer markiert. Laeuft auf Server und Client (Job-Tabelle wird
    synchronisiert).
]]
function PD.Carry.IsEngineer(ply)
    if not IsValid(ply) or not isfunction(ply.GetJob) then return false end

    local _, job = ply:GetJob()

    if not istable(job) then return false end
    if flag(job.isengineer) then return true end

    local unit = job.unit

    if not unit or not PD.JOBS or not PD.JOBS.GetSubUnit then return false end

    -- Direkt suchen statt GetSubUnit(name): das faellt bei unbekanntem Namen
    -- auf die Standard-Untereinheit zurueck und koennte so falsch "ja" sagen.
    for key, sub in pairs(PD.JOBS.GetSubUnit(false, true) or {}) do
        if istable(sub) and (key == unit or sub.name == unit) then
            return flag(sub.isengineer)
        end
    end

    return false
end

-- Darf ply die Verankerung von ent per E halten loesen?
function PD.Carry.CanUnanchor(ply, ent)
    if not IsValid(ply) or not ply:Alive() or ply:InVehicle() then return false end
    if PD.Carry.IsCarrying(ply) then return false end
    if not IsValid(ent) or not ent:GetNW2Bool("PD.Carry.Anchored") then return false end
    if not PD.Carry.IsEngineer(ply) then return false end

    local reach = PD.Carry.Config.Reach
    local eye = ply:EyePos()

    return eye:DistToSqr(ent:NearestPoint(eye)) <= reach * reach
end
