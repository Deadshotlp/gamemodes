--[[
    Naval - Editor fuer Geschuetzstellungen (Client, nur Admins, Stufe 4a).

    Links das Schiffsmodell mit allen Stellungen und ihren Feuerboegen
    (Ziehen = drehen, Mausrad = zoomen), rechts Liste und Werte der gewaehlten
    Stellung. Ziel: eine Schiffsklasse oder das Map-Schiff (eigene Stellungen
    je Map-Profil). Fuer das Map-Schiff: "Stellung hier" nimmt Position und
    Blickrichtung des Spielers (an der Kanone stehen, in Schussrichtung
    schauen).

    Oeffnen: Admin-Tab Raumflotte, Flottenkommando oder pd_naval_geschuetze.
    Speichern: Admin-Aktion hardpoints_save (sv_naval_admintool.lua).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

local TYPE_COLOR = {
    turbolaser = Color(255, 120, 90), heavyturbolaser = Color(255, 70, 50), laser = Color(255, 200, 90),
    ion = Color(120, 190, 255), pd = Color(200, 200, 200), missile = Color(255, 160, 60), torpedo = Color(255, 110, 200),
}

local frame

local function MapClassId()
    for _, info in pairs(C.info or {}) do
        if info.mapShip then return info.classId end
    end
    local profile = Naval.GetProfile and Naval.GetProfile()
    return profile and profile.classId
end

local function CurrentList(target)
    local static = C.static
    if not static then return {} end
    if target == "__map" then
        local profile = Naval.GetProfile and Naval.GetProfile()
        local list = profile and static.settings and static.settings["hardpoints_" .. profile.key]
        return table.Copy(istable(list) and list or {})
    end
    local class = static.classes[target]
    return table.Copy(class and class.hardpoints or {})
end

function Naval.OpenHardpointEditor()
    if IsValid(frame) then frame:Close() return end
    if not LocalPlayer():IsAdmin() or not C.static then return end

    local UI = Naval.UI
    local COL = UI.COL
    local Send = Naval.AdminSend

    frame = UI.Frame("GESCHÜTZSTELLUNGEN", math.min(ScrW() - 60, 1500), math.min(ScrH() - 60, 900))
    frame.Think = nil

    local target = "__map"
    local list = CurrentList(target)
    local selected = nil

    -- Ziel waehlen
    local cTarget = vgui.Create("DComboBox", frame)
    cTarget:SetPos(20, 50)
    cTarget:SetSize(420, 30)
    cTarget:SetFont("MLIB.16")
    cTarget:AddChoice("Map-Schiff (Stellungen dieser Map)", "__map", true)
    for id, class in SortedPairsByMemberValue(C.static.classes, "name") do cTarget:AddChoice("Klasse: " .. class.name, id) end

    local function ClassOf(t)
        return C.static.classes[t == "__map" and (MapClassId() or "") or t]
    end

    ----------------------------------------------------------------------------
    -- Modellansicht
    ----------------------------------------------------------------------------

    local view = vgui.Create("DModelPanel", frame)
    view:SetPos(20, 90)
    view:SetSize(frame:GetWide() - 520, frame:GetTall() - 110)
    view:SetFOV(35)
    view.camYaw, view.camPitch, view.camDist = 210, 25, 2
    view.LayoutEntity = function() end

    local function Info()
        local class = ClassOf(target)
        local info = class and class.model and Naval.ModelInfo and Naval.ModelInfo(class.model)
        return class, info
    end

    local function SetModelFor()
        local class = ClassOf(target)
        if class and class.model then view:SetModel(class.model) end
    end
    SetModelFor()

    local oldPaint = view.Paint
    view.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(6, 9, 14))
        local _, info = Info()
        if info then
            local center = info.center
            local dist = info.length * s.camDist
            local dir = Angle(-s.camPitch, s.camYaw, 0):Forward()
            s:SetCamPos(center - dir * dist)
            s:SetLookAt(center)
            s.FarZ = dist * 4 -- Feld des DModelPanel (keine Set-Methode); grosse Schiffe sonst abgeschnitten
        end
        oldPaint(s, w, h)
        draw.SimpleText("Ziehen = drehen, Mausrad = zoomen. Vorn = +x (rote Linie).", "MLIB.14", 8, h - 22, COL.dim)
    end

    view.PostDrawModel = function(s, ent)
        local _, info = Info()
        if not info then return end
        local len, center = info.length, info.center

        render.SetColorMaterial()
        -- Achsen: vorn rot, links gruen, oben blau
        render.DrawLine(center, center + Vector(len * 0.6, 0, 0), Color(255, 60, 60), true)
        render.DrawLine(center, center + Vector(0, len * 0.2, 0), Color(60, 255, 60), true)
        render.DrawLine(center, center + Vector(0, 0, len * 0.2), Color(60, 120, 255), true)

        for i, hp in ipairs(list) do
            local pos = center + Vector(hp.x or 0, hp.y or 0, hp.z or 0) * len
            local col = i == selected and Color(255, 255, 80) or (TYPE_COLOR[hp.type] or Color(255, 255, 255))
            render.DrawSphere(pos, len * (i == selected and 0.012 or 0.008), 8, 8, col)

            -- Feuerbogen: waagerechter Faecher und senkrechte Grenzen
            local reach = len * (i == selected and 0.3 or 0.15)
            local alpha = i == selected and 220 or 90
            local function Dir(yaw, pitch)
                local y, p = math.rad(yaw), math.rad(pitch)
                return Vector(math.cos(p) * math.cos(y), math.cos(p) * math.sin(y), math.sin(p))
            end
            local arcH, arcV = hp.arcH or 90, hp.arcV or 60
            local last
            for a = -arcH, arcH, math.max(arcH / 8, 2) do
                local p = pos + Dir((hp.yaw or 0) + a, hp.pitch or 0) * reach
                render.DrawLine(pos, p, Color(col.r, col.g, col.b, alpha * 0.4), true)
                if last then render.DrawLine(last, p, Color(col.r, col.g, col.b, alpha), true) end
                last = p
            end
            render.DrawLine(pos, pos + Dir(hp.yaw or 0, (hp.pitch or 0) + arcV) * reach, Color(col.r, col.g, col.b, alpha), true)
            render.DrawLine(pos, pos + Dir(hp.yaw or 0, (hp.pitch or 0) - arcV) * reach, Color(col.r, col.g, col.b, alpha), true)
        end
    end

    view.OnMousePressed = function(s, code)
        if code ~= MOUSE_LEFT then return end
        s.Drag = {gui.MousePos()}
        s.DragStart = {s.camYaw, s.camPitch}
        s:MouseCapture(true)
    end
    view.OnMouseReleased = function(s) s.Drag = nil s:MouseCapture(false) end
    view.Think = function(s)
        if not s.Drag then return end
        local mx, my = gui.MousePos()
        s.camYaw = s.DragStart[1] - (mx - s.Drag[1]) * 0.4
        s.camPitch = math.Clamp(s.DragStart[2] + (my - s.Drag[2]) * 0.4, -89, 89)
    end
    view.OnMouseWheeled = function(s, delta)
        s.camDist = math.Clamp(s.camDist * (delta > 0 and 0.85 or 1.18), 0.15, 6)
        return true
    end

    ----------------------------------------------------------------------------
    -- Liste und Werte
    ----------------------------------------------------------------------------

    local side = vgui.Create("DScrollPanel", frame)
    side:SetPos(frame:GetWide() - 490, 50)
    side:SetSize(470, frame:GetTall() - 66)
    local B = Naval.UIBuilder(side)

    B.Header("Stellungen")
    local lv = vgui.Create("DListView", B.Row(220))
    lv:Dock(FILL)
    lv:SetMultiSelect(false)
    lv:AddColumn("#"):SetFixedWidth(30)
    lv:AddColumn("Gruppe")
    lv:AddColumn("Typ")
    lv:AddColumn("Anz."):SetFixedWidth(40)

    local fields = {}
    local function FillList()
        lv:Clear()
        for i, hp in ipairs(list) do
            local wt = Naval.WeaponTypes[hp.type] or {}
            local line = lv:AddLine(i, hp.group ~= "" and hp.group or "-", wt.name or hp.type, hp.count or 1)
            line.Index = i
            if i == selected then line:SetSelected(true) end
        end
    end

    local function FillFields()
        local hp = selected and list[selected]
        for key, f in pairs(fields) do
            f.Updating = true
            if f.SetValue and hp then
                if f.IsCombo then
                    local pick = 1
                    for id = 1, #f.Choices do pick = f.Data[id] == hp[key] and id or pick end
                    f:ChooseOptionID(pick)
                else
                    f:SetValue(hp[key] or f.Default or 0)
                end
            end
            f:SetEnabled(hp ~= nil)
            f.Updating = nil
        end
    end

    lv.OnRowSelected = function(_, _, line)
        selected = line.Index
        FillFields()
    end

    local function Changed(key, value)
        local hp = selected and list[selected]
        if not hp then return end
        hp[key] = value
        if key == "group" or key == "type" or key == "count" then
            local line = lv:GetLine(lv:GetSelectedLine() or 0)
            if line then
                local wt = Naval.WeaponTypes[hp.type] or {}
                line:SetColumnText(2, hp.group ~= "" and hp.group or "-")
                line:SetColumnText(3, wt.name or hp.type)
                line:SetColumnText(4, hp.count or 1)
            end
        end
    end

    B.Header("Gewählte Stellung")
    local eGroup = B.Entry("Gruppe (z. B. Turbolaser Backbord)")
    eGroup.OnChange = function(s) if not s.Updating then Changed("group", s:GetValue()) end end
    fields.group = eGroup

    local types = {}
    for _, id in ipairs(Naval.WeaponTypeList) do types[#types + 1] = {id, Naval.WeaponTypes[id].name} end
    local cType = B.Combo(types, "turbolaser")
    cType.IsCombo = true
    cType.OnSelect = function(s, _, _, data) if not s.Updating then Changed("type", data) end end
    fields.type = cType

    local function Slider(key, label, min, max, decimals, default)
        local row = B.Row(34)
        local sl = vgui.Create("DNumSlider", row)
        sl:Dock(FILL)
        sl:SetText(label)
        sl:SetMin(min) sl:SetMax(max) sl:SetDecimals(decimals)
        sl:SetValue(default)
        sl.Default = default
        sl.Label:SetTextColor(COL.text)
        sl.Label:SetFont("MLIB.14")
        sl.OnValueChanged = function(s, v)
            if s.Updating then return end
            Changed(key, decimals == 0 and math.Round(v) or math.Round(v, decimals))
        end
        fields[key] = sl
        return sl
    end

    Slider("count", "Anzahl Geschütze", 1, 50, 0, 1)
    Slider("x", "Vorn (+) / hinten (−)", -0.6, 0.6, 3, 0)
    Slider("y", "Links (+) / rechts (−)", -0.6, 0.6, 3, 0)
    Slider("z", "Oben (+) / unten (−)", -0.6, 0.6, 3, 0)
    Slider("yaw", "Richtung: links (+) / rechts (−)", -180, 180, 0, 0)
    Slider("pitch", "Richtung: hoch (+) / runter (−)", -90, 90, 0, 0)
    Slider("arcH", "Feuerbogen waagerecht ±", 1, 180, 0, 90)
    Slider("arcV", "Feuerbogen senkrecht ±", 1, 90, 0, 60)
    Slider("ammo", "Munition (Raketen/Torpedos)", 0, 500, 0, 50)
    FillFields()

    local function Add(hp)
        list[#list + 1] = hp
        selected = #list
        FillList()
        FillFields()
    end

    B.Buttons({
        {"Neu", function()
            Add({group = "", type = "turbolaser", count = 1, x = 0, y = 0, z = 0.05, yaw = 0, pitch = 0, arcH = 90, arcV = 60})
        end, COL.ok},
        {"Spiegeln", function()
            local hp = selected and list[selected]
            if not hp then return end
            local copy = table.Copy(hp)
            copy.y = -(hp.y or 0)
            copy.yaw = -(hp.yaw or 0)
            copy.group = string.find(hp.group or "", "Backbord", 1, true) and string.gsub(hp.group, "Backbord", "Steuerbord")
                or (string.find(hp.group or "", "Steuerbord", 1, true) and string.gsub(hp.group, "Steuerbord", "Backbord") or hp.group)
            Add(copy)
        end},
        {"Löschen", function()
            if not selected then return end
            table.remove(list, selected)
            selected = nil
            FillList()
            FillFields()
        end, COL.bad},
    })

    -- Map-Schiff: an der Kanone stehen und in Schussrichtung schauen
    local hereBtn = B.Buttons({{"Stellung hier (Position + Blickrichtung)", function()
        local profile = Naval.GetProfile and Naval.GetProfile()
        local class = ClassOf("__map")
        if not profile or not profile.metersPerUnit or not class then
            notification.AddLegacy("Map-Schiff nicht vermessen (Admin-Tab: Map-Schiff vermessen)", NOTIFY_ERROR, 5)
            return
        end
        local Q, V3 = Naval.Q, Naval.V3
        local a = profile.mapToBody or Angle(0, 0, 0)
        local qbm = Q.FromAngle(a.p, a.y, a.r)
        local d = (LocalPlayer():EyePos() - (profile.shipOriginMap or Vector())) * profile.metersPerUnit
        local body = Q.RotateVec(Q.Conj(qbm), V3.FromVector(d))
        local aim = Q.RotateVec(Q.Conj(qbm), V3.FromVector(LocalPlayer():GetAimVector()))
        local len = class.lengthM or 1000

        local hp = selected and list[selected]
        local values = {x = math.Round(body.x / len, 3), y = math.Round(body.y / len, 3), z = math.Round(body.z / len, 3),
            yaw = math.Round(math.deg(math.atan2(aim.y, aim.x))), pitch = math.Round(math.deg(math.asin(math.Clamp(aim.z, -1, 1))))}
        if hp then
            for k, v in pairs(values) do hp[k] = v end
            FillFields()
        else
            values.group, values.type, values.count, values.arcH, values.arcV = "", "turbolaser", 1, 90, 60
            Add(values)
        end
    end}})[1]

    B.Buttons({{"SPEICHERN", function()
        Send("hardpoints_save", {target = target, list = list})
    end, COL.ok}})

    B.Text("Stellungen derselben Gruppe bilden eine Batterie am Waffenleitstand. Eine Stellung feuert nur, wenn das Ziel "
        .. "in ihrem Bogen liegt. Ohne Stellungen gelten die pauschalen Batterien der Klasse. Lage in Schiffslängen ab der "
        .. "Schiffsmitte. Für das Map-Schiff zuerst die Map vermessen.")

    cTarget.OnSelect = function(_, _, _, data)
        target = data
        list = CurrentList(target)
        selected = nil
        SetModelFor()
        FillList()
        FillFields()
    end

    frame.Think = function()
        hereBtn:SetVisible(target == "__map")
    end

    FillList()
end

concommand.Add("pd_naval_geschuetze", function() Naval.OpenHardpointEditor() end)
