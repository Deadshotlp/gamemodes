--[[
    Clientseite der Transportkisten: Eintraege im Interaktionsmenue und der
    Fortschrittsbalken. Ob gepackt werden darf, entscheidet der Server.
]]

-- cl_ laedt vor sh_ (alphabetisch): PD.Kiste gibt es hier beim Serverstart
-- noch nicht. sh_transportkiste.lua legt es ebenfalls mit "or {}" an.
PD.Kiste = PD.Kiste or {}

local ACTION_PACK, ACTION_UNPACK = 1, 2

net.Receive("PD.Kiste.Config", function()
    local cfg = net.ReadTable()

    PD.Kiste.Packables = istable(cfg.packables) and cfg.packables or {}
    PD.Kiste.Spawnables = istable(cfg.spawnables) and cfg.spawnables or {}
end)

local function StartJob(ent, action)
    if not IsValid(ent) then return end

    net.Start("PD.Kiste.Start")
    net.WriteEntity(ent)
    net.WriteUInt(action, 2)
    net.SendToServer()
end

-- Interaktionspunkt: der erste Bone des Modells (bei Props meist der
-- einzige). So braucht es keine Bone-Angabe in der Packliste.
local function RootBone(ent)
    local name = ent:GetBoneName(0)
    if not name or name == "" or name == "__INVALIDBONE__" then return nil end

    return name
end

hook.Add("PD.Interaction.Requested", "PD.Kiste.Interaction", function(entClass)
    local ent = PD.IA.LastEntity and PD.IA.LastEntity.ent
    if not IsValid(ent) then return end

    local bone = RootBone(ent)
    if not bone then return end

    if entClass == PD.Kiste.CrateClass then
        local name = ent:GetContentName()
        local previewOn = PD.Kiste.PreviewActive(ent)

        local actions = {}

        -- Aufbauen nur fuer Engineers
        if PD.Kiste.CanUnpack(LocalPlayer()) then
            actions[#actions + 1] = {
                id = "kiste_unpack",
                name = name ~= "" and (name .. " aufbauen") or "Auspacken",
                func = function(ply, target)
                    StartJob(target, ACTION_UNPACK)
                end,
                ad = {bone}
            }
        end

        actions[#actions + 1] = {
            id = "kiste_preview",
            name = previewOn and "Vorschau aus" or "Vorschau an",
            func = function(ply, target)
                PD.Kiste.TogglePreview(target)
            end,
            ad = {bone}
        }

        PD.IA.AddEntityActions(actions, "Transportkiste")

        return
    end

    if not PD.Kiste.CanPackEntity(ent) then return end

    local packable = PD.Kiste.GetPackable(ent)

    PD.IA.AddEntityActions({
        [1] = {
            id = "kiste_pack",
            name = packable.name .. " zusammenpacken",
            func = function(ply, target)
                StartJob(target, ACTION_PACK)
            end,
            ad = {bone}
        }
    }, "Transportkiste")
end)

--------------------------------------------------------------------------------
-- Fortschrittsbalken
--------------------------------------------------------------------------------

local progress = nil -- {start, finish, label}

net.Receive("PD.Kiste.Progress", function()
    local duration = net.ReadFloat()
    local label = net.ReadString()

    if duration <= 0 then
        progress = nil
        return
    end

    progress = {start = CurTime(), finish = CurTime() + duration, label = label}
end)

hook.Add("HUDPaint", "PD.Kiste.Progress", function()
    if not progress then return end

    local now = CurTime()
    if now >= progress.finish + 0.5 then
        progress = nil
        return
    end

    local frac = math.Clamp((now - progress.start) / (progress.finish - progress.start), 0, 1)

    local w, h = PD.W(420), PD.H(26)
    local x, y = ScrW() / 2 - w / 2, ScrH() * 0.7

    draw.SimpleTextOutlined(progress.label, "MLIB.20", ScrW() / 2, y - PD.H(16), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200))
    PD.DrawProgressBar(x, y, w, h, frac, PD.Theme.Colors.StatusActive, PD.Theme.Colors.BackgroundDark)

    local rest = math.max(0, progress.finish - now)
    draw.SimpleText(string.format("%.1f s  -  Bewegen bricht ab", rest), "MLIB.14", ScrW() / 2, y + h + PD.H(12), PD.Theme.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

--------------------------------------------------------------------------------
-- Kistenlager-Menue
--------------------------------------------------------------------------------

local function TakeItem(spawner, model)
    net.Start("PD.Kiste.Spawner.Take")
    net.WriteEntity(spawner)
    net.WriteString(model)
    net.SendToServer()
end

local function ReturnCrates(spawner)
    net.Start("PD.Kiste.Spawner.Return")
    net.WriteEntity(spawner)
    net.SendToServer()
end

local function BuildRow(parent, spawner, entry, count)
    local full = entry.limit > 0 and count >= entry.limit

    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:SetTall(PD.H(64))
    row:DockMargin(0, 0, 0, PD.H(5))
    row.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)

        surface.SetDrawColor(full and PD.Theme.Colors.StatusInactive or PD.Theme.Colors.AccentBlue)
        surface.DrawRect(0, 0, PD.W(3), h)

        draw.DrawText(entry.name, "MLIB.18", PD.H(76), h / 2 - PD.H(18), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)

        local limitText = entry.limit > 0 and (count .. " / " .. entry.limit .. " im Einsatz") or (count .. " im Einsatz")
        draw.DrawText(limitText, "MLIB.14", PD.H(76), h / 2 + PD.H(2), full and PD.Theme.Colors.AccentRed or PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
    end

    local icon = vgui.Create("SpawnIcon", row)
    icon:SetModel(entry.model)
    icon:SetSize(PD.H(56), PD.H(56))
    icon:SetPos(PD.W(8), PD.H(4))
    icon:SetTooltip(entry.model)
    icon.DoClick = function() end

    local btn = PD.Button(full and "Limit erreicht" or "Holen", row, function()
        TakeItem(spawner, entry.model)
    end)
    btn:Dock(RIGHT)
    btn:SetWide(PD.W(150))
    btn:DockMargin(0, PD.H(12), PD.W(8), PD.H(12))
    btn:SetDisabled(full)
end

net.Receive("PD.Kiste.Spawner.Open", function()
    local spawner = net.ReadEntity()
    local counts = net.ReadTable()
    local returnable = net.ReadUInt(8)

    if not IsValid(spawner) then return end

    -- Offenes Menue fuer dasselbe Lager nur auffrischen (nach Holen/Zurueckgeben).
    local frame = PD.Kiste.SpawnerFrame
    if IsValid(frame) and frame.Spawner ~= spawner then
        frame:Remove()
        frame = nil
    end

    if not IsValid(frame) then
        frame = PD.Frame("Kistenlager", PD.W(620), PD.H(640), true)
        frame.Spawner = spawner
        PD.Kiste.SpawnerFrame = frame

        frame.Think = function(s)
            -- Weggelaufen: schliessen.
            if not IsValid(s.Spawner) or LocalPlayer():GetPos():DistToSqr(s.Spawner:GetPos()) > 400 * 400 then
                s:Remove()
            end
        end
    end

    local content = frame:GetContentPanel()
    content:Clear()

    PD.Label("Ausrüstung", content, {font = "MLIB.20", height = PD.H(35)})

    local scroll = PD.Scroll(content)

    if #PD.Kiste.Spawnables == 0 then
        local lbl = vgui.Create("DLabel", scroll)
        lbl:Dock(TOP)
        lbl:SetTall(PD.H(40))
        lbl:SetText("Das Lager ist leer. Das Sortiment wird im Web-Panel gepflegt.")
        lbl:SetTextColor(PD.Theme.Colors.TextMuted)
        lbl:SetFont("MLIB.14")
        lbl:SetContentAlignment(5)
    else
        for index, entry in ipairs(PD.Kiste.Spawnables) do
            BuildRow(scroll, spawner, entry, tonumber(counts[index]) or 0)
        end
    end

    local returnBtn = PD.Button(returnable > 0 and ("Gepackte Kisten zurückgeben (" .. returnable .. " in der Nähe)") or "Keine Kisten zum Zurückgeben in der Nähe", content, function()
        ReturnCrates(spawner)
    end)
    returnBtn:Dock(BOTTOM)
    returnBtn:SetDisabled(returnable == 0)
end)

--------------------------------------------------------------------------------
-- Vorschau beim Aufbauen
--------------------------------------------------------------------------------

--[[
    Geisterbild an der Stelle, an der das Objekt aufgebaut wuerde - gruen,
    wenn Platz ist, rot, wenn etwas im Weg steht. Position und Pruefung kommen
    aus PD.Kiste.ComputePlacement, derselben Funktion, die der Server beim
    Aufbauen benutzt. Dreht oder verschiebt man die Kiste, wandert die
    Vorschau mit.
]]
local PREVIEW_MAX_DIST = 1500
local COLOR_FREE = Color(80, 255, 120, 140)
local COLOR_BLOCKED = Color(255, 70, 70, 140)

local preview = nil -- {crate, model (ClientsideModel), info}
local UpdatePreview -- weiter unten definiert

-- Alle je erzeugten Geisterbilder - haengt an PD, damit auch nach einem
-- Lua-Refresh (der die lokale Variable verliert) keines stehen bleibt.
PD.Kiste.PreviewGhosts = PD.Kiste.PreviewGhosts or {}

local function StopPreview()
    for ghost in pairs(PD.Kiste.PreviewGhosts) do
        if IsValid(ghost) then ghost:Remove() end
    end

    PD.Kiste.PreviewGhosts = {}
    timer.Remove("PD.Kiste.Preview")
    preview = nil
end

function PD.Kiste.PreviewActive(crate)
    return preview ~= nil and preview.crate == crate
end

function PD.Kiste.TogglePreview(crate)
    if PD.Kiste.PreviewActive(crate) then
        StopPreview()
        return
    end

    StopPreview()

    net.Start("PD.Kiste.PreviewRequest")
    net.WriteEntity(crate)
    net.SendToServer()
end

net.Receive("PD.Kiste.PreviewData", function()
    local crate = net.ReadEntity()
    local model = net.ReadString()
    local info = {
        angles = net.ReadAngle(),
        crate_yaw = net.ReadFloat(),
        mins = net.ReadVector(),
        maxs = net.ReadVector(),
        scale = net.ReadFloat(),
    }
    local skin = net.ReadUInt(8)

    if not IsValid(crate) or model == "" then return end

    StopPreview()

    local ghost = ClientsideModel(model, RENDERGROUP_TRANSLUCENT)
    if not IsValid(ghost) then return end

    ghost:SetSkin(skin)
    ghost:SetModelScale(info.scale or 1)
    ghost:SetRenderMode(RENDERMODE_TRANSCOLOR)
    -- Einfarbig, damit Gruen/Rot klar zu sehen ist.
    ghost:SetMaterial("models/debug/debugwhite")
    ghost:SetNoDraw(false)

    PD.Kiste.PreviewGhosts[ghost] = true
    preview = {crate = crate, model = ghost, info = info}

    -- Wird die Kiste entfernt (Aufbauen, Remover, Cleanup), sofort weg.
    crate:CallOnRemove("PD.Kiste.Preview", function(removed)
        -- Nur wenn die Vorschau noch zu dieser Kiste gehoert.
        if preview and preview.crate == removed then StopPreview() end
    end)

    -- Timer statt Think-Hook: hook.Call bricht ab, sobald ein anderer
    -- Think-Hook einen Wert zurueckgibt - dann bemerkte die Vorschau nicht,
    -- dass die Kiste weg war.
    timer.Create("PD.Kiste.Preview", 0, 0, UpdatePreview)
    UpdatePreview()
end)

hook.Remove("Think", "PD.Kiste.Preview")

UpdatePreview = function()
    if not preview then return end

    local crate = preview.crate
    local ghost = preview.model

    -- Kiste weg, verladen oder Spieler zu weit weg: Vorschau beenden.
    if not IsValid(crate) or not IsValid(ghost) or IsValid(crate:GetParent()) or crate:GetNoDraw()
        or LocalPlayer():GetPos():DistToSqr(crate:GetPos()) > PREVIEW_MAX_DIST * PREVIEW_MAX_DIST then
        StopPreview()
        return
    end

    local pos, ang, hull = PD.Kiste.ComputePlacement(crate, preview.info)

    ghost:SetPos(pos)
    ghost:SetAngles(ang)
    ghost:SetColor(hull.Hit and COLOR_BLOCKED or COLOR_FREE)
end

-- Hinweis unten am Bildschirm, solange die Vorschau laeuft.
hook.Add("HUDPaint", "PD.Kiste.PreviewHint", function()
    if not preview then return end

    -- Zweite Absicherung: Kiste oder Geisterbild weg -> Vorschau beenden.
    if not IsValid(preview.crate) or not IsValid(preview.model) then
        StopPreview()
        return
    end

    local name = preview.crate:GetContentName()
    local blocked = preview.model:GetColor().r > 200

    draw.SimpleTextOutlined(
        "Vorschau: " .. (name ~= "" and name or "Objekt") .. (blocked and " - kein Platz" or " - Platz frei"),
        "MLIB.18", ScrW() / 2, ScrH() * 0.82,
        blocked and COLOR_BLOCKED or COLOR_FREE,
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200))
end)
