PD.LOGS = PD.LOGS or {}
util.AddNetworkString("PD.LOGS.Addcl")
util.AddNetworkString("PD.LOGS.Add")
util.AddNetworkString("PD.LOGS.Append")
util.AddNetworkString("PD.LOGS.Sync")

-- Eintraege dieser Sitzung. Haengt an PD.LOGS, damit ein Lua-Refresh sie
-- nicht verwirft. unsaved zeigt auf den ersten noch nicht geschriebenen.
PD.LOGS.Tbl = PD.LOGS.Tbl or {}
PD.LOGS.unsaved = PD.LOGS.unsaved or 1

local LOG_DIR = "modules/logs/"
local SAVE_INTERVAL = 300       -- Sekunden zwischen zwei Speicherungen
local KEEP_IN_MEMORY = 2000     -- aeltere, bereits gespeicherte Eintraege fallen aus dem Speicher
local SYNC_LIMIT = 500          -- so viele Eintraege bekommt ein Admin beim Oeffnen
local SYNC_COOLDOWN = 3

local function Admins()
    local list = {}

    for _, ply in ipairs(player.GetAll()) do
        if PD.LOGS.CanSee(ply) then
            list[#list + 1] = ply
        end
    end

    return list
end

function PD.LOGS.Insert(typ, text, color)
    local now = os.time()
    local entry = {
        typ = typ,
        text = text,
        color = color,
        time = now,
        date = os.date("%H:%M:%S - %d.%m.%Y", now)
    }

    table.insert(PD.LOGS.Tbl, entry)

    local admins = Admins()
    if #admins == 0 then return end

    net.Start("PD.LOGS.Append")
        net.WriteString(entry.typ)
        net.WriteString(entry.text)
        net.WriteColor(entry.color)
        net.WriteString(entry.date)
    net.Send(admins)
end

--[[
    Noch nicht gespeicherte Eintraege an die Tagesdatei anhaengen.

    Frueher wurde nur beim ShutDown geschrieben - ein Absturz verlor alles
    seit dem Start. Jetzt alle SAVE_INTERVAL Sekunden und beim ShutDown.
    Jeder Eintrag landet in der Datei seines eigenen Tages.
]]
function PD.LOGS.Save()
    local tbl = PD.LOGS.Tbl
    local from = PD.LOGS.unsaved
    if from > #tbl then return end

    PD.JSON.Create("modules/logs")

    local byDay = {}
    for i = from, #tbl do
        local e = tbl[i]
        local day = os.date("%d.%m.%Y", e.time or os.time())
        byDay[day] = byDay[day] or {}
        table.insert(byDay[day], e)
    end

    for day, entries in pairs(byDay) do
        local path = LOG_DIR .. day .. ".json"
        local old = PD.JSON.Read(path)
        if not istable(old) then old = {} end

        for _, e in ipairs(entries) do
            table.insert(old, e)
        end

        PD.JSON.Write(path, old)
    end

    PD.LOGS.unsaved = #tbl + 1

    -- Gespeicherte, alte Eintraege aus dem Speicher nehmen.
    local overflow = #tbl - KEEP_IN_MEMORY
    if overflow > 0 then
        local trimmed = {}
        for i = overflow + 1, #tbl do
            trimmed[#trimmed + 1] = tbl[i]
        end

        PD.LOGS.Tbl = trimmed
        PD.LOGS.unsaved = #trimmed + 1
    end
end

net.Receive("PD.LOGS.Addcl", function(len, ply)
    if not PD.LOGS.CanSee(ply) then return end

    local typ = string.sub(net.ReadString(), 1, 64)
    local text = string.sub(net.ReadString(), 1, 1024)
    local color = net.ReadColor()

    PD.LOGS.Insert(typ, text, color)
end)

net.Receive("PD.LOGS.Sync", function(len, ply)
    if not PD.LOGS.CanSee(ply) then return end

    local now = CurTime()
    if (ply.PD_LogsSyncNext or 0) > now then return end
    ply.PD_LogsSyncNext = now + SYNC_COOLDOWN

    local tbl = PD.LOGS.Tbl
    local out = {}

    for i = math.max(1, #tbl - SYNC_LIMIT + 1), #tbl do
        out[#out + 1] = tbl[i]
    end

    local data = util.Compress(util.TableToJSON(out)) or ""

    net.Start("PD.LOGS.Add")
        net.WriteUInt(#data, 32)
        net.WriteData(data, #data)
    net.Send(ply)
end)

timer.Simple(1, function()
    PD.JSON.Create("modules/logs")
end)

timer.Create("PD.LOGS.AutoSave", SAVE_INTERVAL, 0, function()
    PD.LOGS.Save()
end)

hook.Add("ShutDown", "SaveLogs", function()
    PD.LOGS.Save()
end)
