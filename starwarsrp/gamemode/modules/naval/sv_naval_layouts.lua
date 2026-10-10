--[[
    Naval - Flaechen auf den Konsolenmodellen (Server).

    Fuer die beiden Konsolenmodelle legen Admins an den Demo-Konsolen
    (Stationen demo_large / demo_medium) Flaechen fest, die spaeter per 3D2D
    Knoepfe oder Anzeigen tragen. Gespeichert je Modell in
    pd_naval_console_layouts, an alle Spieler verteilt (PD.Naval.Layouts).

    Flaeche: {id, kind = button|display, label, pos = {x, y, z}, ang = {p, y, r}
    (beides relativ zum Konsolen-Entity), w, h (Einheiten), color = {r, g, b}}
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local esc = function(value) return PD.SQL.EscapeString(tostring(value == nil and "" or value)) end

util.AddNetworkString("PD.Naval.Layouts")
util.AddNetworkString("PD.Naval.LayoutSave")

Naval.Layouts = Naval.Layouts or {}

local MAX_AREAS = 60

local CREATE = [[CREATE TABLE IF NOT EXISTS `pd_naval_console_layouts` (
    `model` VARCHAR(255) NOT NULL,
    `data` MEDIUMTEXT NOT NULL,
    `updated_at` BIGINT NOT NULL DEFAULT 0,
    `updated_by` VARCHAR(64) NOT NULL DEFAULT '',
    PRIMARY KEY (`model`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

local function Send(target)
    local data = util.Compress(util.TableToJSON(Naval.Layouts) or "{}") or ""
    net.Start("PD.Naval.Layouts")
    net.WriteUInt(#data, 32)
    net.WriteData(data, #data)
    if target then net.Send(target) else net.Broadcast() end
end

function Naval.LoadLayouts()
    PD.SQL.Query(CREATE, function()
        PD.SQL.FetchAll("SELECT `model`, `data` FROM `pd_naval_console_layouts`", function(rows)
            local list = {}
            for _, row in ipairs(rows or {}) do
                local t = util.JSONToTable(row.data or "")
                if istable(t) then list[row.model] = t end
            end
            Naval.Layouts = list
            Send()
        end)
    end)
end

hook.Add("PD.Naval.Ready", "PD.Naval.Layouts", Naval.LoadLayouts)
if Naval.Ready then Naval.LoadLayouts() end

hook.Add("PlayerInitialSpawn", "PD.Naval.Layouts", function(ply)
    timer.Simple(8, function() if IsValid(ply) then Send(ply) end end)
end)

-- Werte aus dem Editor pruefen
local function Num(v, lo, hi, default)
    v = tonumber(v)
    if not v or v ~= v then return default end
    return math.Clamp(v, lo, hi)
end

local function Clean(areas)
    local out = {}
    for i = 1, math.min(#areas, MAX_AREAS) do
        local a = areas[i]
        if istable(a) then
            local p, g, c = istable(a.pos) and a.pos or {}, istable(a.ang) and a.ang or {}, istable(a.color) and a.color or {}
            out[#out + 1] = {
                id = string.sub(tostring(a.id or ("flaeche" .. i)), 1, 32),
                kind = a.kind == "button" and "button" or "display",
                label = string.sub(tostring(a.label or ""), 1, 64),
                pos = {x = Num(p.x, -200, 200, 0), y = Num(p.y, -200, 200, 0), z = Num(p.z, -200, 200, 0)},
                ang = {p = Num(g.p, -360, 360, 0), y = Num(g.y, -360, 360, 0), r = Num(g.r, -360, 360, 0)},
                w = Num(a.w, 0.5, 200, 10), h = Num(a.h, 0.5, 200, 6),
                color = {Num(c[1], 0, 255, 90), Num(c[2], 0, 255, 170), Num(c[3], 0, 255, 255)},
            }
        end
    end
    return out
end

net.Receive("PD.Naval.LayoutSave", function(_, ply)
    if not ply:IsAdmin() then return end
    if (ply.PD_NavalLayoutNext or 0) > CurTime() then return end
    ply.PD_NavalLayoutNext = CurTime() + 1

    local model = string.lower(net.ReadString())
    local len = net.ReadUInt(32)
    if len > 200000 then return end
    local areas = util.JSONToTable(util.Decompress(net.ReadData(len)) or "") or {}

    -- Nur Modelle, die eine Naval-Station benutzt
    local known = false
    for _, def in pairs(Naval.Stations) do
        if def.model and string.lower(def.model) == model then known = true break end
    end
    if not known then return end

    local clean = Clean(areas)
    Naval.Layouts[model] = clean
    PD.SQL.Query("REPLACE INTO `pd_naval_console_layouts` (`model`, `data`, `updated_at`, `updated_by`) VALUES ("
        .. esc(model) .. ", " .. esc(util.TableToJSON(clean)) .. ", " .. os.time() .. ", " .. esc(ply:Nick()) .. ")")
    Send()

    if Naval.Feedback then Naval.Feedback(ply, #clean .. " Flächen für " .. string.GetFileFromFilename(model) .. " gespeichert", true) end
    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("Naval", ply:Nick() .. ": Konsolen-Flächen gespeichert (" .. string.GetFileFromFilename(model) .. ", " .. #clean .. ")", Color(120, 170, 255))
    end
end)
