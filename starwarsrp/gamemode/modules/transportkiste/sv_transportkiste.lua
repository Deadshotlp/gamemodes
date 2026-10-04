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
    net.WriteTable({packables = PD.Kiste.Packables, spawnables = PD.Kiste.Spawnables})

    if target then net.Send(target) else net.Broadcast() end
end

-- Was das Kistenlager hergibt: Liste in pd_kiste_spawnables (Web-Panel).
local TBL_SPAWN = "pd_kiste_spawnables"

local function LoadSpawnables(callback)
    local create = "CREATE TABLE IF NOT EXISTS `" .. TBL_SPAWN .. "` ("
        .. "`model` VARCHAR(255) NOT NULL,"
        .. "`name` VARCHAR(64) NOT NULL DEFAULT '',"
        .. "`max_per_player` INT NOT NULL DEFAULT 3,"
        .. "`position` INT NOT NULL DEFAULT 0,"
        .. "PRIMARY KEY (`model`)"
        .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

    PD.SQL.Query(create, function()
        PD.SQL.FetchAll("SELECT * FROM `" .. TBL_SPAWN .. "` ORDER BY `position`, `model`", function(rows)
            local list = {}

            for _, row in ipairs(rows or {}) do
                local model = PD.Kiste.NormalizeModel(row.model)

                if model ~= "" then
                    local packable = PD.Kiste.Packables[model]

                    list[#list + 1] = {
                        model = model,
                        name = (row.name ~= "" and row.name)
                            or (packable and packable.name)
                            or string.StripExtension(string.GetFileFromFilename(model)),
                        limit = math.Clamp(tonumber(row.max_per_player) or 3, 0, 50),
                    }
                end
            end

            PD.Kiste.Spawnables = list
            callback(#list)
        end)
    end)
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

            LoadSpawnables(function(spawnCount)
                PD.Kiste.SendConfig()

                if callback then callback(true, table.Count(packables), spawnCount) end
            end)
        end)
    end)
end

hook.Add("PlayerInitialSpawn", "PD.Kiste.Config", function(ply)
    timer.Simple(5, function()
        if IsValid(ply) then PD.Kiste.SendConfig(ply) end
    end)
end)

timer.Simple(3, function()
    PD.Kiste.LoadConfig(function(ok, count, spawnCount)
        print("[Transportkiste] " .. tostring(count) .. " packbare Modelle, " .. tostring(spawnCount) .. " im Kistenlager geladen")
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
        -- Aus einem Kistenlager geholt: zaehlt weiter gegen das Limit des Spielers.
        spawnedBy = ent.PD_SpawnedBy,
    }
end

--------------------------------------------------------------------------------
-- Packen / Auspacken
--------------------------------------------------------------------------------

-- Kiste mit Inhalt data auf den Bodenpunkt ground stellen.
local function MakeCrate(data, name, ground, yaw, owner)
    local crate = ents.Create(PD.Kiste.CrateClass)
    if not IsValid(crate) then return nil end

    local packable = PD.Kiste.Packables[PD.Kiste.NormalizeModel(data.model)]
    local crateModel = packable and packable.crate_model
    if not crateModel or not util.IsValidModel(crateModel) then
        crateModel = PD.Kiste.DefaultCrateModel
    end

    crate:SetModel(crateModel)
    crate:SetAngles(Angle(0, yaw, 0))
    crate:SetPos(ground)
    crate:Spawn()
    crate:Activate()

    -- Auf den Boden stellen: Unterkante der Kiste auf den Bodenpunkt.
    crate:SetPos(ground - Vector(0, 0, crate:OBBMins().z) + Vector(0, 0, 2))

    data.crate_yaw = crate:GetAngles().y
    crate.PD_Packed = data
    crate.PD_SpawnedBy = data.spawnedBy
    crate:SetContentName(name)

    SetOwner(crate, owner)

    return crate
end

PD.Kiste.MakeCrate = MakeCrate

local function Pack(ply, ent)
    local packable = PD.Kiste.GetPackable(ent)
    if not packable then return end

    local data = Capture(ent)
    local owner = GetOwner(ent)

    local center = ent:LocalToWorld(ent:OBBCenter())
    local ground = GroundBelow(center, {ent, ply})

    local crate = MakeCrate(data, packable.name, ground, ent:GetAngles().y, owner or ply)
    if not crate then
        notify(ply, "Die Kiste konnte nicht erstellt werden.")
        return
    end

    ent:Remove()

    notify(ply, packable.name .. " zusammengepackt.", true)
end

local function Unpack(ply, crate)
    local data = crate.PD_Packed
    if not istable(data) then
        notify(ply, "Diese Kiste ist leer.")
        return
    end

    -- Gemeinsame Berechnung mit der Vorschau (sh_transportkiste.lua).
    -- Steht ein Spieler im Platz, wird nicht aufgebaut.
    local pos, ang, hull = PD.Kiste.ComputePlacement(crate, data)

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
    ent.PD_SpawnedBy = data.spawnedBy

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

--------------------------------------------------------------------------------
-- Kistenlager (Entity pd_kistenlager)
--------------------------------------------------------------------------------

--[[
    Ein Lager gibt fertig gepackte Kisten aus (z. B. Barrikaden), die sich
    wie jede Transportkiste tragen, verladen und aufbauen lassen. Was es
    gibt und wie viel pro Spieler, steht in pd_kiste_spawnables (Web-Panel,
    Seite Transportkisten).

    Jede ausgegebene Kiste und das daraus aufgebaute Objekt tragen die
    SteamID des Spielers (PD_SpawnedBy) - daran haengt das Limit. Gepackte
    Kisten in der Naehe eines Lagers lassen sich zurueckgeben.
]]

PD.Kiste.SpawnerClass = "pd_kistenlager"

local SPAWNER_RANGE = 200
local RETURN_RADIUS = 300
local TAKE_COOLDOWN = 3

util.AddNetworkString("PD.Kiste.Spawner.Open")
util.AddNetworkString("PD.Kiste.Spawner.Take")
util.AddNetworkString("PD.Kiste.Spawner.Return")

local function FindSpawnable(model)
    for index, entry in ipairs(PD.Kiste.Spawnables or {}) do
        if entry.model == model then return entry, index end
    end
end

local function SpawnerInRange(ply, spawner)
    if not IsValid(ply) or not ply:Alive() then return false end
    if not IsValid(spawner) or spawner:GetClass() ~= PD.Kiste.SpawnerClass then return false end

    return spawner:NearestPoint(ply:EyePos()):Distance(ply:EyePos()) <= SPAWNER_RANGE
end

-- Wie viele Objekte dieses Modells hat der Spieler aus Lagern (gepackt oder aufgebaut)?
function PD.Kiste.CountSpawned(sid, model)
    local count = 0

    for _, ent in ipairs(ents.GetAll()) do
        if ent.PD_SpawnedBy == sid then
            local entModel = ent.PD_Packed and ent.PD_Packed.model or ent:GetModel()

            if PD.Kiste.NormalizeModel(entModel) == model then
                count = count + 1
            end
        end
    end

    return count
end

-- Gepackte Kisten aus dem Lager-Sortiment in Rueckgabe-Reichweite.
local function ReturnableCrates(spawner)
    local list = {}

    for _, ent in ipairs(ents.FindInSphere(spawner:GetPos(), RETURN_RADIUS)) do
        if ent:GetClass() == PD.Kiste.CrateClass and istable(ent.PD_Packed)
            and not IsValid(ent:GetParent()) and not ent:GetNoDraw()
            and FindSpawnable(PD.Kiste.NormalizeModel(ent.PD_Packed.model)) then
            list[#list + 1] = ent
        end
    end

    return list
end

function PD.Kiste.OpenSpawner(ply, spawner)
    if not SpawnerInRange(ply, spawner) then return end

    local sid = ply:SteamID64()
    local counts = {}

    for index, entry in ipairs(PD.Kiste.Spawnables or {}) do
        counts[index] = PD.Kiste.CountSpawned(sid, entry.model)
    end

    net.Start("PD.Kiste.Spawner.Open")
    net.WriteEntity(spawner)
    net.WriteTable(counts)
    net.WriteUInt(math.min(#ReturnableCrates(spawner), 255), 8)
    net.Send(ply)
end

-- Inhalt einer neuen Kiste aus einem Modell (ohne vorhandenes Objekt).
local function BuildData(model)
    local probe = ents.Create("prop_physics")
    if not IsValid(probe) then return nil end

    probe:SetModel(model)
    local mins, maxs = probe:OBBMins(), probe:OBBMaxs()
    probe:Remove()

    return {
        class = "prop_physics",
        model = model,
        skin = 0,
        color = {r = 255, g = 255, b = 255, a = 255},
        material = "",
        rendermode = RENDERMODE_NORMAL,
        scale = 1,
        bodygroups = {},
        -- Barrikaden & Co. sollen nach dem Aufbauen stehen bleiben.
        frozen = true,
        angles = Angle(0, 0, 0),
        mins = mins,
        maxs = maxs,
    }
end

-- Ablageort: zwischen Lager und Spieler, neben dem Lager auf dem Boden.
-- Groesse der Kiste, in die ein Modell gepackt wird (fuer die Platzsuche).
local function CrateBounds(model)
    local packable = PD.Kiste.Packables[model]
    local crateModel = packable and packable.crate_model
    if not crateModel or not util.IsValidModel(crateModel) then
        crateModel = PD.Kiste.DefaultCrateModel
    end

    local probe = ents.Create("prop_physics")
    if not IsValid(probe) then return Vector(-24, -24, 0), Vector(24, 24, 48) end

    probe:SetModel(crateModel)
    local mins, maxs = probe:OBBMins(), probe:OBBMaxs()
    probe:Remove()

    return mins, maxs
end

--[[
    Freien Platz fuer die neue Kiste neben dem Lager suchen.

    Frueher: fester Abstand von der Lagermitte Richtung Spieler - bei grossen
    Lagern (Container) genau da, wo der Spieler steht, die Kiste spawnte in
    ihm. Jetzt werden Stellen rund um das Lager probiert, zuerst auf der Seite
    des Spielers, und die erste genommen, an der die Kiste weder Spieler noch
    Wand noch andere Objekte trifft.
]]
local SPOT_OFFSETS = {0, 40, -40, 80, -80, 120, -120, 160, -160, 180}

local function SpawnPosition(ply, spawner, model)
    local toPlayer = ply:GetPos() - spawner:GetPos()
    toPlayer.z = 0

    if toPlayer:LengthSqr() < 1 then toPlayer = spawner:GetForward() toPlayer.z = 0 end

    local baseYaw = math.deg(math.atan2(toPlayer.y, toPlayer.x))
    local mins, maxs = CrateBounds(model)

    local origin = spawner:LocalToWorld(spawner:OBBCenter())
    local spawnerRadius = math.max(spawner:OBBMaxs():Length2D(), spawner:OBBMins():Length2D(), 20)
    local crateRadius = math.max(maxs.x - mins.x, maxs.y - mins.y) * 0.75

    for _, extra in ipairs({0, 40}) do
        for _, offset in ipairs(SPOT_OFFSETS) do
            local yaw = baseYaw + offset
            local dir = Angle(0, yaw, 0):Forward()
            local pos = origin + dir * (spawnerRadius + crateRadius + 10 + extra)

            -- Keine Wand zwischen Lager und Ablageort.
            local side = util.TraceLine({start = origin, endpos = pos, filter = {spawner}, mask = MASK_SOLID_BRUSHONLY})

            if not side.Hit then
                local ground = GroundBelow(pos, {spawner})
                local test = ground - Vector(0, 0, mins.z) + Vector(0, 0, 4)

                -- Platz fuer die Kiste: Spieler, Props und Welt zaehlen.
                local hull = util.TraceHull({
                    start = test,
                    endpos = test,
                    mins = Vector(mins.x * 1.05, mins.y * 1.05, mins.z),
                    maxs = Vector(maxs.x * 1.05, maxs.y * 1.05, maxs.z),
                    filter = {spawner},
                    mask = MASK_SOLID,
                })

                if not hull.Hit then
                    return ground, yaw
                end
            end
        end
    end

    return nil
end

net.Receive("PD.Kiste.Spawner.Take", function(len, ply)
    local spawner = net.ReadEntity()
    local model = PD.Kiste.NormalizeModel(net.ReadString())

    if not SpawnerInRange(ply, spawner) then return end

    local now = CurTime()
    if (ply.PD_KisteTakeNext or 0) > now then
        notify(ply, "Bitte kurz warten.")
        return
    end
    ply.PD_KisteTakeNext = now + TAKE_COOLDOWN

    local entry = FindSpawnable(model)
    if not entry then return end

    if not util.IsValidModel(model) then
        notify(ply, entry.name .. " ist auf dem Server nicht installiert.")
        return
    end

    local sid = ply:SteamID64()

    if entry.limit > 0 and PD.Kiste.CountSpawned(sid, model) >= entry.limit then
        notify(ply, "Du hast schon " .. entry.limit .. "x " .. entry.name .. ". Gib erst eine zurück oder pack eine wieder ein.")
        return
    end

    local data = BuildData(model)
    if not data then return end

    data.spawnedBy = sid

    local ground, yaw = SpawnPosition(ply, spawner, model)
    if not ground then
        notify(ply, "Rund um das Lager ist kein Platz frei - räum etwas weg und versuch es nochmal.")
        return
    end

    local crate = MakeCrate(data, entry.name, ground, yaw, ply)

    if not crate then
        notify(ply, "Die Kiste konnte nicht erstellt werden.")
        return
    end

    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("Kistenlager", ply:Nick() .. " (" .. sid .. ") hat " .. entry.name .. " geholt", Color(120, 180, 255))
    end

    notify(ply, entry.name .. " steht neben dem Lager bereit.", true)
    PD.Kiste.OpenSpawner(ply, spawner)
end)

net.Receive("PD.Kiste.Spawner.Return", function(len, ply)
    local spawner = net.ReadEntity()
    if not SpawnerInRange(ply, spawner) then return end

    local crates = ReturnableCrates(spawner)

    if #crates == 0 then
        notify(ply, "Keine gepackten Kisten aus dem Lager in der Nähe.")
        return
    end

    for _, crate in ipairs(crates) do
        crate:Remove()
    end

    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("Kistenlager", ply:Nick() .. " (" .. ply:SteamID64() .. ") hat " .. #crates .. " Kiste(n) zurückgegeben", Color(120, 180, 255))
    end

    notify(ply, #crates .. " Kiste(n) zurückgegeben.", true)

    -- Erst im naechsten Tick neu zaehlen: entfernte Entities sind sonst noch gueltig.
    timer.Simple(0, function()
        if IsValid(ply) and IsValid(spawner) then PD.Kiste.OpenSpawner(ply, spawner) end
    end)
end)

--------------------------------------------------------------------------------
-- Vorschau beim Aufbauen
--------------------------------------------------------------------------------

-- Der Client zeigt ein Geisterbild an der Stelle, an der das Objekt aufgebaut
-- wuerde. Dafuer braucht er Modell und Ausrichtung aus den Kistendaten - die
-- kennt nur der Server.
util.AddNetworkString("PD.Kiste.PreviewRequest")
util.AddNetworkString("PD.Kiste.PreviewData")

local PREVIEW_RANGE = 600

net.Receive("PD.Kiste.PreviewRequest", function(len, ply)
    local crate = net.ReadEntity()

    if not IsValid(crate) or crate:GetClass() ~= PD.Kiste.CrateClass then return end
    if ply:GetPos():Distance(crate:GetPos()) > PREVIEW_RANGE then return end

    local data = crate.PD_Packed
    if not istable(data) then
        notify(ply, "Diese Kiste ist leer.")
        return
    end

    net.Start("PD.Kiste.PreviewData")
    net.WriteEntity(crate)
    net.WriteString(data.model or "")
    net.WriteAngle(data.angles or angle_zero)
    net.WriteFloat(data.crate_yaw or crate:GetAngles().y)
    net.WriteVector(data.mins or vector_origin)
    net.WriteVector(data.maxs or vector_origin)
    net.WriteFloat(data.scale or 1)
    net.WriteUInt(data.skin or 0, 8)
    net.Send(ply)
end)
