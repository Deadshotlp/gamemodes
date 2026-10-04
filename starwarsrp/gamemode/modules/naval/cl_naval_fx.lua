--[[
    Naval - Kampfeffekte (Client).

    Schuesse kommen als PD.Naval.Shots (Schuetze, Ziel, Waffentyp, Treffer,
    Flugzeit). Gezeichnet im Skybox-Pass (cl_naval_render ruft
    Naval.DrawFX): Turbolaser als Strahlen in Fraktionsfarbe, Raketen und
    Torpedos als Leuchtpunkte, Einschlaege als Blitze, zerstoerte Schiffe
    mit Explosionen.

    Treffer am eigenen Schiff (Ereignis "hit"): Wackeln, Geraeusche,
    bei Huellentreffern kurzes rotes Aufblitzen.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

local MAT_BEAM = Material("effects/laser1")
local MAT_GLOW = Material("sprites/light_glow02_add")
local MAT_FLARE = Material("effects/fire_cloud1")

local MAX_BOLTS = 400
local bolts = {}
local flashes = {}
local wrecks = {}

local TYPE_COLOR = {
    ion = Color(150, 200, 255),
    missile = Color(255, 170, 80),
    torpedo = Color(255, 120, 60),
}

local function FactionColor(id)
    local info = C.info[id]
    local f = info and C.static and C.static.factions[info.factionId]
    if f and f.color then
        return Color(math.min(255, f.color[1] + 60), math.min(255, f.color[2] + 60), math.min(255, f.color[3] + 60))
    end
    return Color(255, 120, 100)
end

net.Receive("PD.Naval.Shots", function()
    local now = Naval.Now()
    local count = net.ReadUInt(8)

    for _ = 1, count do
        local from = net.ReadUInt(16)
        local to = net.ReadUInt(16)
        local typeIdx = net.ReadUInt(4)
        local hit = net.ReadBool()
        local travel = net.ReadFloat()

        if #bolts < MAX_BOLTS then
            local wtype = Naval.WeaponTypeList[typeIdx] or "turbolaser"
            -- Versatz entlang der Schiffe, damit nicht alles aus einem Punkt kommt
            local function Offset(id)
                local info = C.info[id]
                local class = info and C.static and C.static.classes[info.classId]
                local len = (class and class.lengthM or 300) * 0.4
                return {x = (math.random() - 0.5) * len, y = (math.random() - 0.5) * len * 0.4, z = (math.random() - 0.5) * len * 0.2}
            end

            -- Zeitlich verteilt ueber den Takt (0,5 s)
            local delay = math.random() * 0.45
            bolts[#bolts + 1] = {
                from = from, to = to, type = wtype, hit = hit,
                t0 = now + delay, t1 = now + delay + math.max(travel, 0.3),
                ofrom = Offset(from), oto = Offset(to),
                color = TYPE_COLOR[wtype] or FactionColor(from),
                miss = not hit and {x = (math.random() - 0.5) * 2000, y = (math.random() - 0.5) * 2000, z = (math.random() - 0.5) * 1000} or nil,
            }
        end
    end
end)

--------------------------------------------------------------------------------
-- Zeichnen (vom Renderpass aufgerufen)
--------------------------------------------------------------------------------

-- Mitte des Schiffs (eigenes Schiff: Mittelpunkt, Kamera ist darin)
local function ShipPos(view, id)
    if id == view.id then return view.pos end
    local s = view.ships[id]
    if not s then return nil end

    local info = C.info[id]
    return Naval.ShipCenter and Naval.ShipCenter(info and info.classId, s.pos, s.rot) or s.pos
end

-- toRender(pos in Systemmetern) -> Vector (Render-Einheiten) oder nil
function Naval.DrawFX(view, toRender)
    local now = Naval.Now()
    local scale = (C.static and C.static.settings and C.static.settings.render_scale) or 50
    local nearClip = 1500 / scale
    local keep = {}

    for _, b in ipairs(bolts) do
        if now < b.t1 + 0.6 then keep[#keep + 1] = b end

        local fromPos, toPos = ShipPos(view, b.from), ShipPos(view, b.to)
        if fromPos and toPos and now >= b.t0 then
            local a = Naval.V3.Add(fromPos, b.ofrom)
            local z = Naval.V3.Add(toPos, b.oto)
            if b.miss then z = Naval.V3.Add(z, b.miss) end

            local f = (now - b.t0) / (b.t1 - b.t0)

            if f <= 1 then
                -- Bolzen etwa 700 m lang (hoechstens ein Viertel der Strecke)
                local span = math.max(Naval.V3.Dist(a, z), 1)
                local head = Naval.V3.Lerp(a, z, f)
                local tail = Naval.V3.Lerp(a, z, math.max(0, f - math.min(0.25, 700 / span)))
                local h, t = toRender(head), toRender(tail)

                -- Nicht nahe der Kamera zeichnen: Strahlen mit einem Ende hinter
                -- oder dicht an der Kamera verzerrt die Engine (Knick). Erst
                -- ausserhalb der Huelle (1,5 km) sichtbar.
                if h and t and h:Length() > nearClip and t:Length() > nearClip then
                    local width = math.max(h:Length() * 0.01, 0.4)
                    if b.type == "missile" or b.type == "torpedo" then
                        render.SetMaterial(MAT_GLOW)
                        render.DrawSprite(h, width * 5, width * 5, b.color)
                    else
                        render.SetMaterial(MAT_BEAM)
                        render.DrawBeam(t, h, width * 3, 0, 1, Color(b.color.r, b.color.g, b.color.b, 70))
                        render.DrawBeam(t, h, width, 0, 1, b.color)
                    end
                end
            elseif b.hit and not b.flashed then
                b.flashed = true
                flashes[#flashes + 1] = {id = b.to, off = b.oto, t0 = now, t1 = now + 0.5,
                    size = b.type == "torpedo" and 2.2 or (b.type == "missile" and 1.6 or 1),
                    color = b.type == "ion" and Color(160, 210, 255) or Color(255, 200, 140)}
            end
        end
    end
    bolts = keep

    -- Einschlaege
    local keepF = {}
    for _, fl in ipairs(flashes) do
        if now < fl.t1 then
            keepF[#keepF + 1] = fl
            local pos = ShipPos(view, fl.id)
            local p = pos and toRender(Naval.V3.Add(pos, fl.off))
            if p and p:Length() > nearClip then
                local k = 1 - (now - fl.t0) / (fl.t1 - fl.t0)
                local size = math.max(p:Length() * 0.02, 0.6) * fl.size * (0.5 + k)
                render.SetMaterial(MAT_GLOW)
                render.DrawSprite(p, size, size, Color(fl.color.r, fl.color.g, fl.color.b, 255 * k))
            end
        end
    end
    flashes = keepF

    -- Zerstoerte Schiffe: Explosionen fuer ein paar Sekunden
    for id, s in pairs(view.ships or {}) do
        if s.state == "destroyed" and not wrecks[id] then
            wrecks[id] = now
        end
    end

    for id, t0 in pairs(wrecks) do
        local age = now - t0
        local pos = ShipPos(view, id)

        if age > 8 or not pos then
            if age > 60 then wrecks[id] = nil end
        else
            local info = C.info[id]
            local class = info and C.static and C.static.classes[info.classId]
            local len = class and class.lengthM or 300

            -- Feste Zufallswerte je Schiff und Zeitschritt (globales math.random unberuehrt)
            local step = math.floor(age * 6)
            local function R(k) return util.SharedRandom("PD.Naval.Wreck", 0, 1, id * 100000 + step * 10 + k) end

            for k = 1, 3 do
                local off = {x = (R(k) - 0.5) * len, y = (R(k + 3) - 0.5) * len * 0.3, z = (R(k + 6) - 0.5) * len * 0.2}
                local p = toRender(Naval.V3.Add(pos, off))
                if p then
                    local size = math.max(p:Length() * 0.05, 1) * (1 + R(k + 9)) * (1 - age / 10)
                    render.SetMaterial(R(k + 12) < 0.5 and MAT_FLARE or MAT_GLOW)
                    render.DrawSprite(p, size, size, Color(255, 180 + R(k + 15) * 60, 100, 220 * (1 - age / 8)))
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Treffer am eigenen Schiff
--------------------------------------------------------------------------------

local redFlash = 0
local nextSound = 0

hook.Add("PD.Naval.ClientEvent", "PD.Naval.FX", function(kind, data)
    if kind == "hit" then
        local hull = tonumber(data.hull) or 0
        local shield = tonumber(data.shield) or 0
        local total = hull + shield * 0.3

        util.ScreenShake(EyePos(), math.Clamp(total / 40, 0.5, 8), 12, 0.6, 100000)

        if CurTime() > nextSound then
            nextSound = CurTime() + 0.35
            if hull > 0 then
                LocalPlayer():EmitSound("ambient/explosions/explode_" .. math.random(1, 9) .. ".wav", 75, math.random(70, 90), math.Clamp(hull / 150, 0.2, 0.9) * 0.25)
                redFlash = math.max(redFlash, math.Clamp(hull / 300, 0.1, 0.5))
            else
                LocalPlayer():EmitSound("ambient/energy/zap" .. math.random(1, 9) .. ".wav", 70, math.random(60, 80), 0.35)
            end
        end
    elseif kind == "disabled" then
        LocalPlayer():EmitSound("ambient/alarms/klaxon1.wav", 80, 100, 0.8)
        util.ScreenShake(EyePos(), 12, 8, 3, 100000)
        redFlash = 0.7
    elseif kind == "sub_offline" then
        LocalPlayer():EmitSound("ambient/energy/spark" .. math.random(1, 6) .. ".wav", 75, 90, 0.7)
    end
end)

hook.Add("HUDPaint", "PD.Naval.FX", function()
    if redFlash <= 0 then return end
    surface.SetDrawColor(255, 40, 20, redFlash * 120)
    surface.DrawRect(0, 0, ScrW(), ScrH())
    redFlash = math.max(0, redFlash - FrameTime() * 1.5)
end)
