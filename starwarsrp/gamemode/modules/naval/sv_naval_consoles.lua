--[[
    Naval - Konsolen auf der Map (Server).

    Positionen in pd_naval_consoles je Map. Beim ersten Start mit den
    Startpositionen aus dem Map-Profil befuellt. Admin-Befehle (Konsole):
      pd_naval_console_add <station>   Konsole dort, wo man hinschaut
      pd_naval_console_remove          angeschaute Konsole entfernen
      pd_naval_console_lock            angeschaute Konsole sperren/entsperren
      pd_naval_console_rotate <grad>   angeschaute Konsole drehen
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local esc = function(value) return PD.SQL.EscapeString(tostring(value == nil and "" or value)) end

local CLASS = "pd_naval_console"

local function SpawnConsole(row)
    local ent = ents.Create(CLASS)
    if not IsValid(ent) then
        Naval.Log("Konsolen-Entity fehlt (Server-Neustart noetig?)")
        return nil
    end

    ent:SetStation(row.station)
    ent:SetLocked(tonumber(row.locked) == 1)
    ent:SetConsoleId(tonumber(row.id) or 0)
    ent:SetPos(Vector(tonumber(row.px), tonumber(row.py), tonumber(row.pz)))
    ent:SetAngles(Angle(tonumber(row.pitch) or 0, tonumber(row.yaw) or 0, tonumber(row.roll) or 0))
    ent:Spawn()
    ent:Activate()

    return ent
end

function Naval.SpawnConsoles()
    for _, ent in ipairs(ents.FindByClass(CLASS)) do ent:Remove() end

    local map = game.GetMap()

    PD.SQL.FetchAll("SELECT * FROM `pd_naval_consoles` WHERE `map` = " .. esc(map), function(rows)
        rows = rows or {}

        if #rows == 0 then
            -- Startpositionen aus dem Profil
            local profile = Naval.GetProfile()
            local pending = #((profile and profile.consoles) or {})
            if pending == 0 then return end

            for _, c in ipairs(profile.consoles) do
                PD.SQL.Query("INSERT INTO `pd_naval_consoles` (`map`, `station`, `px`, `py`, `pz`, `pitch`, `yaw`, `roll`, `locked`, `data`) VALUES ("
                    .. esc(map) .. ", " .. esc(c.station) .. ", " .. c.pos.x .. ", " .. c.pos.y .. ", " .. c.pos.z .. ", "
                    .. c.ang.p .. ", " .. c.ang.y .. ", " .. c.ang.r .. ", 0, '{}')", function()
                    pending = pending - 1
                    if pending == 0 then Naval.SpawnConsoles() end
                end)
            end

            return
        end

        local count = 0
        for _, row in ipairs(rows) do
            if Naval.Stations[row.station] then
                SpawnConsole(row)
                count = count + 1
            else
                -- Station gibt es nicht mehr (z. B. alte Taktik-Konsole/Brueckenanzeige)
                PD.SQL.Query("DELETE FROM `pd_naval_consoles` WHERE `id` = " .. (tonumber(row.id) or 0))
                Naval.Log("Konsole '" .. tostring(row.station) .. "' entfernt (Station gibt es nicht mehr)")
            end
        end
        Naval.Log(count .. " Konsolen aufgestellt")
    end)
end

hook.Add("PD.Naval.SimStarted", "PD.Naval.Consoles", function()
    timer.Simple(3, Naval.SpawnConsoles)
end)

-- Admins duerfen Konsolen mit dem Physgun ausrichten; danach im Admin-Menue
-- (Raumflotte -> Konsolen -> Speichern) die Lage sichern.
hook.Add("PhysgunPickup", "PD.Naval.Consoles", function(ply, ent)
    if IsValid(ent) and ent:GetClass() == CLASS then return ply:IsAdmin() end
end)

hook.Add("PhysgunDrop", "PD.Naval.Consoles", function(_, ent)
    if not IsValid(ent) or ent:GetClass() ~= CLASS then return end
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
end)

-- Aktuelle Lage einer Konsole in die Datenbank
function Naval.SaveConsole(ent)
    local pos, ang = ent:GetPos(), ent:GetAngles()
    PD.SQL.Query(("UPDATE `pd_naval_consoles` SET `px` = %.2f, `py` = %.2f, `pz` = %.2f, `pitch` = %.2f, `yaw` = %.2f, `roll` = %.2f WHERE `id` = %d")
        :format(pos.x, pos.y, pos.z, ang.p, ang.y, ang.r, ent:GetConsoleId()))
end

hook.Add("PostCleanupMap", "PD.Naval.Consoles", function()
    if Naval.SimRunning then timer.Simple(1, Naval.SpawnConsoles) end
end)

--------------------------------------------------------------------------------
-- Admin-Befehle
--------------------------------------------------------------------------------

local function AdminTrace(ply)
    if not IsValid(ply) or not ply:IsAdmin() then return nil end
    return ply:GetEyeTrace()
end

local function LookedConsole(ply)
    local tr = AdminTrace(ply)
    local ent = tr and tr.Entity
    if IsValid(ent) and ent:GetClass() == CLASS then return ent end
end

local function Log(ply, text)
    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("Naval", ply:Nick() .. " (" .. ply:SteamID64() .. "): " .. text, Color(120, 170, 255))
    end
end

concommand.Add("pd_naval_console_add", function(ply, _, args)
    local tr = AdminTrace(ply)
    if not tr then return end

    local station = args[1]
    if not Naval.Stations[station or ""] then
        local list = {}
        for id in SortedPairs(Naval.Stations) do list[#list + 1] = id end
        ply:ChatPrint("[Naval] Station: " .. table.concat(list, ", "))
        return
    end

    local pos = tr.HitPos
    local yaw = math.Round((ply:GetPos() - pos):Angle().y)

    PD.SQL.Query("INSERT INTO `pd_naval_consoles` (`map`, `station`, `px`, `py`, `pz`, `pitch`, `yaw`, `roll`, `locked`, `data`) VALUES ("
        .. esc(game.GetMap()) .. ", " .. esc(station) .. ", " .. pos.x .. ", " .. pos.y .. ", " .. pos.z .. ", 0, " .. yaw .. ", 0, 0, '{}')", function()
        Naval.SpawnConsoles()
        ply:ChatPrint("[Naval] Konsole '" .. station .. "' aufgestellt")
        Log(ply, "Konsole " .. station .. " aufgestellt")
    end)
end)

concommand.Add("pd_naval_console_remove", function(ply)
    local ent = LookedConsole(ply)
    if not ent then return end

    PD.SQL.Query("DELETE FROM `pd_naval_consoles` WHERE `id` = " .. ent:GetConsoleId(), function()
        Naval.SpawnConsoles()
    end)

    ply:ChatPrint("[Naval] Konsole entfernt")
    Log(ply, "Konsole " .. ent:GetStation() .. " entfernt")
end)

concommand.Add("pd_naval_console_lock", function(ply)
    local ent = LookedConsole(ply)
    if not ent then return end

    local locked = not ent:GetLocked()
    ent:SetLocked(locked)
    PD.SQL.Query("UPDATE `pd_naval_consoles` SET `locked` = " .. (locked and 1 or 0) .. " WHERE `id` = " .. ent:GetConsoleId())

    ply:ChatPrint("[Naval] Konsole " .. (locked and "gesperrt" or "entsperrt"))
    Log(ply, "Konsole " .. ent:GetStation() .. (locked and " gesperrt" or " entsperrt"))
end)

concommand.Add("pd_naval_console_rotate", function(ply, _, args)
    local ent = LookedConsole(ply)
    if not ent then return end

    local ang = ent:GetAngles()
    ang.y = ang.y + (tonumber(args[1]) or 15)
    ent:SetAngles(ang)

    PD.SQL.Query("UPDATE `pd_naval_consoles` SET `yaw` = " .. ang.y .. " WHERE `id` = " .. ent:GetConsoleId())
end)
