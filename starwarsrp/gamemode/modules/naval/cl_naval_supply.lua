--[[
    Naval - Nachschub (Client, Stufe 4e): Logistik-Leitstand und Hinweise an
    Anlieferung und Nachschub-Annahme (Ortsmarker, sonst unsichtbar).
    Daten: C.status.logistics (sv_naval_supply.lua).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

surface.CreateFont("PD.NavalSupply.3D2D", {font = "Roboto", size = 60, weight = 700, extended = true})

local function L() return C.status and C.status.logistics end

local function Time(s)
    if s >= 120 then return math.ceil(s / 60) .. " min" end
    return math.ceil(s) .. " s"
end

--------------------------------------------------------------------------------
-- Leitstand
--------------------------------------------------------------------------------

local function OpenLogistics(console)
    local UI = Naval.UI
    local COL = UI.COL
    local frame = UI.Frame("LOGISTIK-LEITSTAND", 980, 640)
    frame.Console = console

    local order = {}
    for _, kind in ipairs(Naval.SupplyOrder) do order[kind] = 0 end
    local function Total()
        local n = 0
        for _, v in pairs(order) do n = n + v end
        return n
    end

    -- Bestand
    local stock = vgui.Create("DPanel", frame)
    stock:SetPos(20, 55)
    stock:SetSize(460, 300)
    stock.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL.panel)
        local l = L()
        draw.SimpleText("BESTAND AN BORD", "MLIB.14", 14, 8, COL.dim)
        if not l then return end
        if not l.enabled then
            draw.SimpleText("Nachschub-System AUS: Munition wird nicht verbraucht", "MLIB.12", w - 14, 10, COL.warn, TEXT_ALIGN_RIGHT)
        end
        local y = 34
        local function Row(name, cur, max, col, note)
            draw.SimpleText(("%s: %d / %d"):format(name, cur, max), "MLIB.16", 14, y, max > 0 and COL.text or COL.dim)
            if note then draw.SimpleText(note, "MLIB.12", w - 14, y + 3, COL.dim, TEXT_ALIGN_RIGHT) end
            UI.Bar(14, y + 22, w - 28, 8, max > 0 and cur / max or 0, col)
            y = y + 48
        end
        for _, kind in ipairs(Naval.SupplyOrder) do
            local def = Naval.SupplyKinds[kind]
            local a = l.ammo[kind]
            if a then Row(def.weapon == "torpedo" and "Protonentorpedos" or "Erschütterungsraketen", a.cur, a.max, def.color) end
        end
        Row("Hülle", l.hull, l.hullMax, COL.ok, ("Ersatzteile bis %d %%"):format(l.partsMax))
        Row("Maschinen (Hangar)", l.craft.cur, l.craft.max, COL.accent)
    end

    -- Anforderung
    local req = vgui.Create("DPanel", frame)
    req:SetPos(500, 55)
    req:SetSize(460, 300)
    req.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL.panel)
        local l = L()
        draw.SimpleText("NACHSCHUB ANFORDERN", "MLIB.14", 14, 8, COL.dim)
        if not l then return end
        for i, kind in ipairs(Naval.SupplyOrder) do
            local def = Naval.SupplyKinds[kind]
            local y = 34 + (i - 1) * 44
            draw.SimpleText(def.name, "MLIB.16", 14, y + 4, def.color or COL.text)
            draw.SimpleText(def.desc, "MLIB.12", 14, y + 24, COL.dim)
            draw.SimpleText(tostring(order[kind]), "MLIB.18", w - 92, y + 8, COL.text, TEXT_ALIGN_CENTER)
        end
        draw.SimpleText(("Kisten: %d / %d"):format(Total(), l.maxCrates), "MLIB.14", 14, 214, COL.dim)
        local status
        if l.delivery then status = "Lieferung unterwegs - Ankunft in " .. Time(l.delivery.eta)
        elseif l.available then status = "Verfügbar (" .. (l.reason or "") .. ")"
        else status = l.reason or "" end
        draw.SimpleText(status, "MLIB.12", 14, 236, (l.available or l.delivery) and COL.ok or COL.warn)
    end

    for i, kind in ipairs(Naval.SupplyOrder) do
        local y = 34 + (i - 1) * 44 + 4
        local minus = UI.Button(req, "-", function() order[kind] = math.max(0, order[kind] - 1) end, function() return COL.dim end)
        minus:SetPos(req:GetWide() - 140, y) minus:SetSize(30, 30)
        local plus = UI.Button(req, "+", function()
            local l = L()
            if l and Total() < l.maxCrates then order[kind] = order[kind] + 1 end
        end, function() return COL.accent end)
        plus:SetPos(req:GetWide() - 60, y) plus:SetSize(30, 30)
    end

    local send = UI.Button(req, "Anfordern", function()
        Naval.CombatCmd("logistics", "order", {crates = order})
        for k in pairs(order) do order[k] = 0 end
    end, function() return COL.ok end)
    send:SetPos(14, 256) send:SetSize(200, 32)

    local adminNow = UI.Button(req, "Admin: sofort liefern", function()
        Naval.CombatCmd("logistics", "adminDeliver", {crates = order})
        for k in pairs(order) do order[k] = 0 end
    end, function() return COL.warn end)
    adminNow:SetPos(224, 256) adminNow:SetSize(222, 32)
    adminNow:SetVisible(LocalPlayer():IsAdmin())

    -- Hauptschalter (nur Admins)
    local toggle = UI.Button(frame, "Admin: Nachschub-System AN/AUS", function()
        Naval.CombatCmd("logistics", "adminToggle", {})
    end, function() local l = L() return l and l.enabled and COL.ok or COL.bad end)
    toggle:SetPos(frame:GetWide() - 360, 9) toggle:SetSize(310, 28)
    toggle:SetVisible(LocalPlayer():IsAdmin())

    -- Ablauf und Kisten an Bord
    local info = vgui.Create("DPanel", frame)
    info:SetPos(20, 365)
    info:SetSize(frame:GetWide() - 40, frame:GetTall() - 385)
    info.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL.panel)
        local l = L()
        draw.SimpleText("ABLAUF", "MLIB.14", 14, 8, COL.dim)
        local lines = {
            "1. Kisten anfordern (eigenes Gebiet oder verbündetes Schiff in 100 km, nicht im Gefecht).",
            "2. Die Kisten erscheinen an der Anlieferung.",
            "3. Kisten zur Nachschub-Annahme tragen oder fahren und dort abstellen - sie werden verbucht.",
        }
        for i, t in ipairs(lines) do draw.SimpleText(t, "MLIB.14", 14, 30 + (i - 1) * 22, COL.text) end
        if not l then return end

        local parts = {}
        for _, kind in ipairs(Naval.SupplyOrder) do
            if (l.onBoard[kind] or 0) > 0 then parts[#parts + 1] = l.onBoard[kind] .. "x " .. Naval.SupplyKinds[kind].name end
        end
        draw.SimpleText("Kisten an Bord: " .. (#parts > 0 and table.concat(parts, ", ") or "keine"), "MLIB.16", 14, 104, COL.text)
        if l.cooldown > 0 and not l.delivery then
            draw.SimpleText("Nächste Anforderung in " .. Time(l.cooldown), "MLIB.14", 14, 130, COL.dim)
        end
        if l.drops == 0 or l.intakes == 0 then
            draw.SimpleText("Admin: Ortsmarker \"Anlieferung\" und \"Nachschub-Annahme\" mit dem Konsolen-Tool setzen!", "MLIB.14", 14, 156, COL.bad)
        end
    end

    local baseThink = frame.Think
    frame.Think = function(s)
        if baseThink then baseThink(s) end
        if not IsValid(s) then return end
        local l = L()
        send.Disabled = not (l and l.available) or Total() == 0
        toggle.Label = l and l.enabled and "Admin: Nachschub-System ist AN" or "Admin: Nachschub-System ist AUS"
    end
end

Naval.StationUI = Naval.StationUI or {}
Naval.StationUI.logistics = OpenLogistics

--------------------------------------------------------------------------------
-- Hinweise an den Ortsmarkern (fuer alle sichtbar)
--------------------------------------------------------------------------------

local MARKER_TEXT = {
    supply_intake = {"NACHSCHUB-ANNAHME", "Kisten hier abstellen", Color(120, 220, 160)},
    supply_drop = {"ANLIEFERUNG", "Nachschubkisten", Color(240, 200, 90)},
}

hook.Add("PostDrawTranslucentRenderables", "PD.Naval.SupplyMarkers", function(depth, sky)
    if sky or depth or Naval.ClientShutdown then return end
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local eye = ply:EyePos()

    for _, ent in ipairs(ents.FindByClass("pd_naval_console")) do
        local t = ent.GetStation and MARKER_TEXT[ent:GetStation()]
        if t and eye:DistToSqr(ent:GetPos()) < 700 * 700 then
            local pos = ent:GetPos()
            -- Ring am Boden
            render.SetColorMaterial()
            local last
            for a = 0, 360, 15 do
                local p = pos + Vector(math.cos(math.rad(a)) * 90, math.sin(math.rad(a)) * 90, 2)
                if last then render.DrawLine(last, p, t[3], true) end
                last = p
            end
            local ang = Angle(0, ply:EyeAngles().y - 90, 90)
            cam.Start3D2D(pos + Vector(0, 0, 70), ang, 0.1)
                draw.SimpleText(t[1], "PD.NavalSupply.3D2D", 0, -36, t[3], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(t[2], "PD.NavalSupply.3D2D", 0, 24, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            cam.End3D2D()
        end
    end
end)
