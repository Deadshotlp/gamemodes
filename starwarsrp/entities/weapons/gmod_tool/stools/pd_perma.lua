-- Eigenes PermaProps

TOOL.Name = "#tool.pd_perma.name"
TOOL.Category = "P & D"
TOOL.Command = nil
TOOL.ConfigName = ""

if CLIENT then
    language.Add("tool.pd_perma.name", "PermaProps")
    language.Add("tool.pd_perma.desc", "Pops dauerhaft Speichern")
    language.Add("tool.pd_perma.0", "Linksklick: Prop speichern | Rechtsklick: Prop löschen")
end

-- Menu, eine aktuelle liste aller prop aktuelle map und buttons goto delete highlighted prop

local TABLE_NAME = "pd_perma_props"

-- Entities mit eigenem State (Text/Farbe/Zeilen etc.), der über die generischen
-- Prop-Felder hinausgeht. Ohne das hier würde SpawnStoredProp diese Entities
-- zwar neu erstellen, aber mit ihren Initialize()-Standardwerten statt dem,
-- was der Spieler zuletzt gesetzt hatte.
local function CaptureExtraData(ent)
    local class = ent:GetClass()

    if class == "gb_rp_sign" or class == "gb_rp_sign_wire" then
        local tColor = ent:GetTColor()
        return {
            Text = ent:GetText(),
            TColor = { x = tColor.x, y = tColor.y, z = tColor.z },
            Type = ent:GetType(),
            Speed = ent:GetSpeed(),
            Wide = ent:GetWide(),
            On = ent:GetOn(),
            FX = ent:GetFX()
        }
    elseif class == "sammyservers_textscreen" then
        local lines = {}
        for i, line in pairs(ent.lines or {}) do
            local c = line.color or Color(255, 255, 255, 255)
            lines[tostring(i)] = {
                text = line.text,
                color = { r = c.r, g = c.g, b = c.b, a = c.a },
                size = line.size,
                font = line.font,
                rainbow = line.rainbow
            }
        end
        return { Lines = lines }
    end

    return nil
end

local function ApplyExtraData(ent, extraData)
    if not extraData then return end

    local class = ent:GetClass()

    if class == "gb_rp_sign" or class == "gb_rp_sign_wire" then
        ent:SetText(extraData.Text or "")
        if extraData.TColor then
            ent:SetTColor(Vector(extraData.TColor.x, extraData.TColor.y, extraData.TColor.z))
        end
        ent:SetType(extraData.Type or 1)
        ent:SetSpeed(extraData.Speed or 1.5)
        ent:SetWide(extraData.Wide or 6)
        ent:SetOn(extraData.On or 1)
        ent:SetFX(extraData.FX or 0)
    elseif class == "sammyservers_textscreen" then
        for i, line in pairs(extraData.Lines or {}) do
            local c = line.color or {}
            ent:SetLine(
                tonumber(i),
                line.text,
                Color(c.r or 255, c.g or 255, c.b or 255, c.a or 255),
                line.size,
                line.font,
                line.rainbow
            )
        end
    end
end

local function RowToContent(row)
    local extraData = nil
    if row.extradata and row.extradata ~= "" then
        extraData = util.JSONToTable(row.extradata)
    end

    return {
        map = row.map,
        id = tonumber(row.id),
        Class = row.class,
        Pos = Vector(tonumber(row.pos_x), tonumber(row.pos_y), tonumber(row.pos_z)),
        Angle = Angle(tonumber(row.ang_p), tonumber(row.ang_y), tonumber(row.ang_r)),
        Model = row.model,
        Skin = tonumber(row.skin),
        ColGroup = tonumber(row.colgroup),
        Name = row.name,
        ModelScale = tonumber(row.modelscale),
        Color = Color(tonumber(row.color_r), tonumber(row.color_g), tonumber(row.color_b), tonumber(row.color_a)),
        Material = row.material or "",
        Solid = tonumber(row.solid),
        RenderMode = tonumber(row.rendermode),
        ExtraData = extraData
    }
end

local function SpawnStoredProp(content)
    if not util.IsValidModel(content.Model) then
        print("[PermaProps] Ungültiges Model: " .. content.Model .. " für Prop ID: " .. content.id)
        return
    end

    -- Leerer String = kein Material-Override, das ist der Normalfall und kein Fehler
    if content.Material and content.Material ~= "" and Material(content.Material):IsError() then
        print("[PermaProps] Ungültiges Material: " .. content.Material .. " für Prop ID: " .. content.id)
        return
    end

    local newEnt = ents.Create(content.Class)
    if not IsValid(newEnt) then
        print("[PermaProps] Unbekannte Klasse: " .. tostring(content.Class) .. " für Prop ID: " .. tostring(content.id))
        return
    end

    -- Fehler in Spawn/Initialize der Klasse: halb erstelltes Entity wieder
    -- entfernen und den Fehler an den Aufrufer weitergeben.
    local success, err = pcall(function()
        newEnt:SetPos(content.Pos)
        newEnt:SetAngles(content.Angle)
        newEnt:SetModel(content.Model)
        newEnt:SetSkin(content.Skin)
        newEnt:SetCollisionGroup(content.ColGroup)
        newEnt:SetName(content.Name)
        newEnt:SetModelScale(content.ModelScale)
        newEnt:SetColor(content.Color)
        newEnt:SetMaterial(content.Material)
        newEnt:SetSolid(content.Solid)
        newEnt:SetRenderMode(content.RenderMode)
        newEnt:SetMoveType(MOVETYPE_NONE)

        newEnt:Spawn()
        newEnt:Activate()

        ApplyExtraData(newEnt, content.ExtraData)

        local phys = newEnt:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
        end

        newEnt.id = content.id
        newEnt.PD_PermaProp = true
    end)

    if not success then
        if IsValid(newEnt) then newEnt:Remove() end
        error(err, 0)
    end
end

local function LoadProps(callback)
    if not SERVER then return end

    local mapName = tostring(game.GetMap() or "")
    local query = "SELECT * FROM `" .. TABLE_NAME .. "` WHERE `map` = " .. SQLStr(mapName)

    PD.SQL.FetchAll(query, function(rows)
        callback(rows or {})
    end)
end

local function InsertProp(content, callback)
    local queryString, err = PD.SQL.BuildInsert(TABLE_NAME, {
        map = tostring(game.GetMap() or ""),
        class = content.Class,
        pos_x = content.Pos.x,
        pos_y = content.Pos.y,
        pos_z = content.Pos.z,
        ang_p = content.Angle.p,
        ang_y = content.Angle.y,
        ang_r = content.Angle.r,
        model = content.Model,
        skin = content.Skin,
        colgroup = content.ColGroup,
        name = content.Name,
        modelscale = content.ModelScale,
        color_r = content.Color.r,
        color_g = content.Color.g,
        color_b = content.Color.b,
        color_a = content.Color.a,
        material = content.Material,
        solid = content.Solid,
        rendermode = content.RenderMode,
        extradata = content.ExtraData and util.TableToJSON(content.ExtraData) or ""
    })

    if not queryString then
        PD.SQL.Print("BuildInsert error (" .. TABLE_NAME .. "): " .. tostring(err))
        if callback then callback(nil) end
        return
    end

    local insertQuery
    insertQuery = PD.SQL.Query(queryString, function()
        local id = insertQuery and insertQuery.lastInsert and insertQuery:lastInsert() or nil
        if callback then callback(id) end
    end)
end

local function DeleteProp(id)
    PD.SQL.Execute("DELETE FROM `" .. TABLE_NAME .. "` WHERE `id` = " .. tostring(tonumber(id) or 0))
end

if SERVER then
    PD.SQL.Query([[
        CREATE TABLE IF NOT EXISTS `]] .. TABLE_NAME .. [[` (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `map` VARCHAR(128) NOT NULL DEFAULT '',
            `class` VARCHAR(64) NOT NULL,
            `pos_x` DOUBLE NOT NULL,
            `pos_y` DOUBLE NOT NULL,
            `pos_z` DOUBLE NOT NULL,
            `ang_p` DOUBLE NOT NULL,
            `ang_y` DOUBLE NOT NULL,
            `ang_r` DOUBLE NOT NULL,
            `model` VARCHAR(255) NOT NULL,
            `skin` INT NOT NULL DEFAULT 0,
            `colgroup` INT NOT NULL DEFAULT 0,
            `name` VARCHAR(255) NOT NULL DEFAULT '',
            `modelscale` FLOAT NOT NULL DEFAULT 1,
            `color_r` INT NOT NULL DEFAULT 255,
            `color_g` INT NOT NULL DEFAULT 255,
            `color_b` INT NOT NULL DEFAULT 255,
            `color_a` INT NOT NULL DEFAULT 255,
            `material` VARCHAR(255) NOT NULL DEFAULT '',
            `solid` INT NOT NULL DEFAULT 0,
            `rendermode` INT NOT NULL DEFAULT 0,
            `extradata` LONGTEXT NOT NULL DEFAULT '',
            PRIMARY KEY (`id`)
        )
    ]])

    --[[
        Alle Props einer Map (bis ~1300) wurden in einem einzigen Tick
        gespawnt. Ein Lua-Fehler in einem einzigen Entity (Initialize/Spawn
        einer Klasse) brach die ganze Schleife ab - alle folgenden Props
        fehlten dann. Jetzt: jeder Prop einzeln abgesichert, in Paketen pro
        Tick, und am Ende eine Zusammenfassung in der Konsole.
    ]]
    local SPAWN_BATCH = 50
    local loadRun = 0

    local function SpawnAllProps(rows, reason)
        loadRun = loadRun + 1
        local run = loadRun
        local total, ok, failed = #rows, 0, {}
        local i = 0
        local timerName = "PD.PermaProps.Spawn"

        timer.Remove(timerName)

        local function step()
            -- Ein neuerer Ladevorgang (Reload/Cleanup) hat diesen abgeloest.
            if run ~= loadRun then return end

            for _ = 1, SPAWN_BATCH do
                i = i + 1
                local row = rows[i]

                if not row then
                    timer.Remove(timerName)

                    print(("[PermaProps] %s: %d von %d Props gespawnt%s"):format(
                        reason, ok, total, #failed > 0 and (", Fehler bei IDs " .. table.concat(failed, ", ")) or ""))
                    return
                end

                local success, err = pcall(function()
                    SpawnStoredProp(RowToContent(row))
                end)

                if success then
                    ok = ok + 1
                else
                    failed[#failed + 1] = tostring(row.id)
                    print(("[PermaProps] Fehler bei Prop ID %s (%s): %s"):format(tostring(row.id), tostring(row.class), tostring(err)))
                end
            end
        end

        timer.Create(timerName, 0, 0, step)
        step()
    end

    PD.PermaProps = PD.PermaProps or {}

    function PD.PermaProps.Reload(reason)
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and ent.id then
                ent:Remove()
            end
        end

        LoadProps(function(rows)
            SpawnAllProps(rows, reason or "Neu geladen")
        end)
    end

    --[[
        Laden beim Serverstart.

        Nur InitPostEntity reichte nicht: hook.Call bricht ab, sobald ein Hook
        einen Wert zurueckgibt - gibt ein Addon dort etwas zurueck, kam dieser
        Hook je nach Reihenfolge nie dran, und die Props fehlten ohne jede
        Meldung. Ausserdem hiess er wie der Hook des verbreiteten
        PermaProps-Addons ("SpawnPermaProps") und konnte davon ersetzt werden.

        Jetzt: eigener Hook-Name plus Timer als Rueckfall. StartupDone haengt
        an PD und verhindert doppeltes Laden - auch beim Lua-Refresh dieser
        Datei mitten im Spiel.
    ]]
    local function StartupLoad(source)
        if PD.PermaProps.StartupDone then return end
        PD.PermaProps.StartupDone = true

        print("[PermaProps] Lade Props fuer " .. game.GetMap() .. " (ausgeloest durch " .. source .. ")")

        LoadProps(function(rows)
            print("[PermaProps] Datenbank lieferte " .. #rows .. " Props")
            SpawnAllProps(rows, "Serverstart")
        end)
    end

    -- Lua-Refresh im laufenden Spiel: stehen schon Perma-Props, nicht noch
    -- einmal laden (sonst doppelt).
    if not PD.PermaProps.StartupDone then
        for _, ent in ipairs(ents.GetAll()) do
            if ent.id and ent.PD_PermaProp then
                PD.PermaProps.StartupDone = true
                break
            end
        end
    end

    hook.Remove("InitPostEntity", "SpawnPermaProps")
    hook.Add("InitPostEntity", "PD.PermaProps.Startup", function()
        StartupLoad("InitPostEntity")
    end)

    timer.Simple(10, function()
        StartupLoad("Timer")
    end)

    -- Ein Map-Cleanup (Admin-Menue, game.CleanUpMap) entfernt auch die
    -- Perma-Props - danach neu spawnen.
    hook.Remove("PostCleanupMap", "SpawnPermaProps")
    hook.Add("PostCleanupMap", "PD.PermaProps.Cleanup", function()
        PD.PermaProps.Reload("Nach Map-Cleanup")
    end)
end

function TOOL:LeftClick(trace)
    if CLIENT then return true end
    if not trace.Entity then return false end
    if not IsFirstTimePredicted() then return false end

    local ent = trace.Entity
    if not IsValid(ent) then
        self:GetOwner():ChatPrint("Ungültiges Entity.")
        return false
    end
    if ent:IsPlayer() then
        self:GetOwner():ChatPrint("Du kannst keine Spieler speichern.")
        return false
    end
    if ent.id then
        self:GetOwner():ChatPrint("Dieser Prop ist bereits gespeichert.")
        return false
    end

    local content = {}
	content.Class = ent:GetClass()
	content.Pos = ent:GetPos()
	content.Angle = ent:GetAngles()
	content.Model = ent:GetModel()
	content.Skin = ent:GetSkin()
	content.ColGroup = ent:GetCollisionGroup()
	content.Name = ent:GetName()
	content.ModelScale = ent:GetModelScale()
	content.Color = ent:GetColor()
	content.Material = ent:GetMaterial()
	content.Solid = ent:GetSolid()
	content.RenderMode = ent:GetRenderMode()
	content.ExtraData = CaptureExtraData(ent)

    local owner = self:GetOwner()

    ent:Remove()

    InsertProp(content, function(id)
        content.id = id
        SpawnStoredProp(content)

        if IsValid(owner) then
            owner:ChatPrint("Prop gespeichert: ID " .. tostring(id))
        end
    end)

    return true
end

function TOOL:RightClick(trace)
    if CLIENT then return true end
    if not IsFirstTimePredicted() then return false end

    local ent = trace.Entity
    if not IsValid(ent) then
        self:GetOwner():ChatPrint("Ungültiges Entity.")
        return false
    end
    if ent:IsPlayer() then
        self:GetOwner():ChatPrint("Du kannst keine Spieler löschen.")
        return false
    end
    if not ent.id then
        self:GetOwner():ChatPrint("Dieser Prop ist nicht gespeichert.")
        return false
    end

    local id = ent.id

    DeleteProp(id)

    ent:Remove()

    self:GetOwner():ChatPrint("Prop gelöscht: ID " .. tostring(id))

    return true
end

function TOOL:Reload(trace)
    if CLIENT then return true end
    if not IsFirstTimePredicted() then return false end

    PD.PermaProps.Reload("Manuell neu geladen")

    return true
end

if CLIENT then
    function TOOL:DrawHUD()
        local tr = util.GetPlayerTrace(LocalPlayer())
        local trace = util.TraceLine(tr)

        if not IsValid(trace.Entity) then return end
        if not trace.Entity:IsValid() then return end

        local text = "Prop speichern"
        if trace.Entity.id then
            text = "Prop löschen"
        end

        -- draw.SimpleText(text, "DermaLarge", ScrW() / 2, ScrH() / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.RoundedBox(10, ScrW() / 2 - 3, ScrH() / 2 - 3, 6, 6, Color(255, 255, 255))
    end
end
