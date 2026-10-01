--[[
    Serverseite der Transportkisten. Ablauf:

      Client waehlt im Interaktionsmenue "Zusammenpacken"/"Auspacken"
        -> PD.Kiste.Start (Entity, Aktion)
      Server prueft und startet einen Vorgang mit Packzeit
        -> PD.Kiste.Progress an den Client (Balken)
      Waehrenddessen: Abbruch, wenn der Spieler sich bewegt, stirbt, in ein
      Fahrzeug steigt oder das Objekt verschwindet/zu weit weg ist.
      Am Ende: Objekt -> Kiste bzw. Kiste -> Objekt.

    Die Kiste merkt sich alles, was zum Wiederaufbau noetig ist (Klasse,
    Modell, Skin, Farbe, Material, Bodygroups, ob eingefroren, Besitzer).
]]

local TBL = "pd_kiste_packables"
local ACTION_PACK, ACTION_UNPACK = 1, 2
local MIN_TIME, MAX_TIME = 0, 120

local ERROR_COLOR = Color(255, 60, 60)
local OK_COLOR = Color(60, 200, 90)

util.AddNetworkString("PD.Kiste.Config")
util.AddNetworkString("PD.Kiste.Start")
util.AddNetworkString("PD.Kiste.Cancel")
util.AddNetworkString("PD.Kiste.Progress")

-- Spieler -> laufender Vorgang
local jobs = {}

local function notify(ply, text, ok)
    PD.Notify(text, ok and OK_COLOR or ERROR_COLOR, false, ply)
end

--------------------------------------------------------------------------------
-- Konfiguration aus der Datenbank
--------------------------------------------------------------------------------

function PD.Kiste.SendConfig(target)
    net.Start("PD.Kiste.Config")
    net.WriteTable(PD.Kiste.Packables)

    if target then net.Send(target) else net.Broadcast() end
end

function PD.Kiste.LoadConfig(callback)
    local create = "CREATE TABLE IF NOT EXISTS `" .. TBL .. "` ("
        .. "`model` VARCHAR(255) NOT NULL,"
        .. "`name` VARCHAR(64) NOT NULL DEFAULT '',"
        .. "`pack_time` FLOAT NOT NULL DEFAULT 5,"
        .. "`crate_model` VARCHAR(255) NOT NULL DEFAULT '',"
        .. "`position` INT NOT NULL DEFAULT 0,"
        .. "PRIMARY KEY (`model`)"
        .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

    PD.SQL.Query(create, function()
        PD.SQL.FetchAll("SELECT * FROM `" .. TBL .. "` ORDER BY `position`, `model`", function(rows)
            local packables = {}

            for _, row in ipairs(rows or {}) do
                local model = PD.Kiste.NormalizeModel(row.model)

                if model ~= "" then
                    packables[model] = {
                        name = (row.name ~= "" and row.name) or string.StripExtension(string.GetFileFromFilename(model)),
                        pack_time = math.Clamp(tonumber(row.pack_time) or 5, MIN_TIME, MAX_TIME),
                        crate_model = row.crate_model ~= "" and row.crate_model or nil,
                    }
                end
            end

            PD.Kiste.Packables = packables
            PD.Kiste.SendConfig()

            if callback then callback(true, table.Count(packables)) end
        end)
    end)
end

hook.Add("PlayerInitialSpawn", "PD.Kiste.Config", function(ply)
    timer.Simple(5, function()
        if IsValid(ply) then PD.Kiste.SendConfig(ply) end
    end)
end)

timer.Simple(3, function()
    PD.Kiste.LoadConfig(function(ok, count)
        print("[Transportkiste] " .. tostring(count) .. " packbare Modelle geladen")
    end)
end)

-- Kisten duerfen ins Fahrzeuginventar. Dieses Modul laedt vor
-- vehical_inventory (alphabetisch); das legt die Tabelle mit "or {}" an und
-- uebernimmt den Eintrag.
PD.VehicalInventory = PD.VehicalInventory or {}
PD.VehicalInventory.ExtraCargo = PD.VehicalInventory.ExtraCargo or {}
PD.VehicalInventory.ExtraCargo[PD.Kiste.CrateClass] = true

--------------------------------------------------------------------------------
-- Hilfen
--------------------------------------------------------------------------------

local function InRange(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return false end

    return ent:NearestPoint(ply:EyePos()):Distance(ply:EyePos()) <= PD.Kiste.Range
end

local function IsPermaProp(ent)
    return ent.id ~= nil or ent.PD_PermaProp == true
end

local function IsFrozen(ent)
    local phys = ent:GetPhysicsObject()

    return IsValid(phys) and not phys:IsMotionEnabled()
end

local function GetOwner(ent)
    if ent.CPPIGetOwner then
        local owner = ent:CPPIGetOwner()
        if IsValid(owner) then return owner end
    end
end

local function SetOwner(ent, owner)
    if IsValid(owner) and ent.CPPISetOwner then
        ent:CPPISetOwner(owner)
    end
end

-- Bodenpunkt unter einer Position (Spieler und das Objekt selbst ignoriert).
local function GroundBelow(pos, filter)
    local tr = util.TraceLine({
        start = pos + Vector(0, 0, 10),
        endpos = pos - Vector(0, 0, 500),
        filter = filter,
        mask = MASK_SOLID_BRUSHONLY,
    })

    return tr.Hit and tr.HitPos or pos
end

local function Capture(ent)
    local bodygroups = {}

    for _, bg in ipairs(ent:GetBodyGroups() or {}) do
        bodygroups[bg.id] = ent:GetBodygroup(bg.id)
    end

    local col = ent:GetColor()

    return {
        class = ent:GetClass(),
        model = ent:GetModel(),
        skin = ent:GetSkin(),
        color = {r = col.r, g = col.g, b = col.b, a = col.a},
        material = ent:GetMaterial(),
        rendermode = ent:GetRenderMode(),
        scale = ent:GetModelScale(),
        bodygroups = bodygroups,
        frozen = IsFrozen(ent),
        -- Ausrichtung relativ zur Kiste, damit das Objekt beim Auspacken so
        -- steht, wie die Kiste gedreht wurde.
        angles = ent:GetAngles(),
        mins = ent:OBBMins(),
        maxs = ent:OBBMaxs(),
    }
end

--------------------------------------------------------------------------------
-- Packen / Auspacken
--------------------------------------------------------------------------------

local function Pack(ply, ent)
    local packable = PD.Kiste.GetPackable(ent)
    if not packable then return end

    local data = Capture(ent)
    local owner = GetOwner(ent)

    local center = ent:LocalToWorld(ent:OBBCenter())
    local ground = GroundBelow(center, {ent, ply})

    local crate = ents.Create(PD.Kiste.CrateClass)
    if not IsValid(crate) then
        notify(ply, "Die Kiste konnte nicht erstellt werden.")
        return
    end

    local crateModel = packable.crate_model
    if not crateModel or not util.IsValidModel(crateModel) then
        crateModel = PD.Kiste.DefaultCrateModel
    end

    crate:SetModel(crateModel)
    crate:SetAngles(Angle(0, ent:GetAngles().y, 0))
    crate:SetPos(ground)
    crate:Spawn()
    crate:Activate()

    -- Auf den Boden stellen: Unterkante der Kiste auf den Bodenpunkt.
    crate:SetPos(ground - Vector(0, 0, crate:OBBMins().z) + Vector(0, 0, 2))

    data.crate_yaw = crate:GetAngles().y
    crate.PD_Packed = data
    crate:SetContentName(packable.name)

    SetOwner(crate, owner or ply)

    ent:Remove()

    notify(ply, packable.name .. " zusammengepackt.", true)
end

local function Unpack(ply, crate)
    local data = crate.PD_Packed
    if not istable(data) then
        notify(ply, "Diese Kiste ist leer.")
        return
    end

    local ground = GroundBelow(crate:GetPos() + Vector(0, 0, 20), {crate, ply})

    -- Drehung der Kiste seit dem Packen auf das Objekt uebertragen.
    local ang = Angle(data.angles.p, data.angles.y + (crate:GetAngles().y - (data.crate_yaw or crate:GetAngles().y)), data.angles.r)

    local pos = ground - Vector(0, 0, data.mins.z * (data.scale or 1)) + Vector(0, 0, 2)

    -- Platz pruefen: Weltgeometrie und andere Objekte (die Kiste selbst
    -- nicht). Steht ein Spieler darin, wird nicht aufgebaut.
    local hull = util.TraceHull({
        start = pos + Vector(0, 0, 4),
        endpos = pos + Vector(0, 0, 4),
        mins = data.mins * (data.scale or 1) * 0.9,
        maxs = data.maxs * (data.scale or 1) * 0.9,
        filter = {crate},
        mask = MASK_SOLID,
    })

    if hull.Hit then
        local blocker = hull.Entity
        if IsValid(blocker) and blocker:IsPlayer() then
            notify(ply, "Hier steht jemand im Weg.")
        else
            notify(ply, "Hier ist nicht genug Platz zum Aufbauen.")
        end
        return
    end

    local ent = ents.Create(data.class)
    if not IsValid(ent) then
        notify(ply, "Das Objekt konnte nicht erstellt werden (" .. tostring(data.class) .. ").")
        return
    end

    ent:SetModel(data.model)
    ent:SetPos(pos)
    ent:SetAngles(ang)
    ent:SetSkin(data.skin or 0)
    ent:SetModelScale(data.scale or 1)
    ent:Spawn()
    ent:Activate()

    if data.color then
        ent:SetColor(Color(data.color.r, data.color.g, data.color.b, data.color.a))
    end
    if data.material and data.material ~= "" then ent:SetMaterial(data.material) end
    if data.rendermode then ent:SetRenderMode(data.rendermode) end

    for id, value in pairs(data.bodygroups or {}) do
        ent:SetBodygroup(tonumber(id) or id, value)
    end

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        if data.frozen then
            phys:EnableMotion(false)
        else
            phys:Wake()
        end
    end

    SetOwner(ent, GetOwner(crate) or ply)

    local name = crate:GetContentName()
    crate:Remove()

    notify(ply, (name ~= "" and name or "Objekt") .. " aufgebaut.", true)
end

--------------------------------------------------------------------------------
-- Vorgaenge mit Fortschritt
--------------------------------------------------------------------------------

local function SendProgress(ply, duration, label)
    net.Start("PD.Kiste.Progress")
    net.WriteFloat(duration)
    net.WriteString(label or "")
    net.Send(ply)
end

local function CancelJob(ply, reason)
    if not jobs[ply] then return end

    jobs[ply] = nil

    if IsValid(ply) then
        SendProgress(ply, 0, "")
        if reason then notify(ply, reason) end
    end
end

local function JobStillValid(ply, job)
    if not IsValid(ply) or not ply:Alive() or ply:InVehicle() then return false, "Abgebrochen." end
    if not IsValid(job.ent) then return false, "Das Objekt ist nicht mehr da." end
    if ply:GetPos():Distance(job.startPos) > PD.Kiste.MoveTolerance then return false, "Abgebrochen - du hast dich bewegt." end
    if not InRange(ply, job.ent) then return false, "Abgebrochen - zu weit entfernt." end

    -- Ins Fahrzeug geladen o. ae. waehrend des Packens
    if IsValid(job.ent:GetParent()) or job.ent:GetNoDraw() then return false, "Abgebrochen." end

    return true
end

local function Finish(ply, job)
    if job.action == ACTION_PACK then
        Pack(ply, job.ent)
    else
        Unpack(ply, job.ent)
    end
end

net.Receive("PD.Kiste.Start", function(len, ply)
    local ent = net.ReadEntity()
    local action = net.ReadUInt(2)

    if jobs[ply] then return end
    if not IsValid(ent) or not ply:Alive() or ply:InVehicle() then return end

    if not InRange(ply, ent) then
        notify(ply, "Zu weit entfernt.")
        return
    end

    -- Belegt ein anderer Spieler das Objekt schon?
    for other, job in pairs(jobs) do
        if job.ent == ent and other ~= ply then
            notify(ply, "Daran arbeitet schon jemand.")
            return
        end
    end

    local duration, label

    if action == ACTION_PACK then
        if not PD.Kiste.CanPackEntity(ent) then return end

        if IsPermaProp(ent) then
            notify(ply, "Fest gespeicherte Objekte lassen sich nicht einpacken.")
            return
        end

        local packable = PD.Kiste.GetPackable(ent)
        duration = packable.pack_time
        label = packable.name .. " wird zusammengepackt"
    elseif action == ACTION_UNPACK then
        if ent:GetClass() ~= PD.Kiste.CrateClass then return end
        if IsValid(ent:GetParent()) or ent:GetNoDraw() then return end

        if not istable(ent.PD_Packed) then
            notify(ply, "Diese Kiste ist leer.")
            return
        end

        local packable = PD.Kiste.Packables[PD.Kiste.NormalizeModel(ent.PD_Packed.model)]
        duration = packable and packable.pack_time or 5
        label = (ent:GetContentName() ~= "" and ent:GetContentName() or "Objekt") .. " wird aufgebaut"
    else
        return
    end

    local job = {
        ent = ent,
        action = action,
        startPos = ply:GetPos(),
        finishAt = CurTime() + duration,
    }

    if duration <= 0 then
        Finish(ply, job)
        return
    end

    jobs[ply] = job
    SendProgress(ply, duration, label)
end)

net.Receive("PD.Kiste.Cancel", function(len, ply)
    CancelJob(ply)
end)

hook.Add("Think", "PD.Kiste.Jobs", function()
    if next(jobs) == nil then return end

    local now = CurTime()

    for ply, job in pairs(jobs) do
        local ok, reason = JobStillValid(ply, job)

        if not ok then
            CancelJob(ply, reason)
        elseif now >= job.finishAt then
            jobs[ply] = nil
            SendProgress(ply, 0, "")
            Finish(ply, job)
        end
    end
end)

hook.Add("PlayerDisconnected", "PD.Kiste.Jobs", function(ply)
    jobs[ply] = nil
end)
