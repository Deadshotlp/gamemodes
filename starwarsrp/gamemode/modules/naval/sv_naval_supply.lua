--[[
    Naval - Nachschub (Server, Stufe 4e).

    Ablauf an Bord des Map-Schiffs:
      1. Logistik-Leitstand: Kisten anfordern (Torpedos, Raketen, Ersatzteile,
         Ersatzmaschinen). Geht nur in eigenem Gebiet (Naval.Territory) oder
         mit einem verbuendeten Schiff in der Naehe, nicht im Gefecht, mit
         Sperrzeit zwischen zwei Lieferungen.
      2. Nach supply_delivery_time Sekunden stehen die Kisten
         (pd_naval_nachschub) an der Anlieferung (Ortsmarker supply_drop).
      3. Spieler tragen sie (auch per Fahrzeug, Fahrzeuginventar) zur
         Nachschub-Annahme (Ortsmarker supply_intake). Dort abgestellt wird
         die Kiste verbucht: Munition in die Magazine, Ersatzteile auf die
         Huelle (bis supply_parts_max %), Maschinen in den Hangar.
    KI-Schiffe fuellen in eigenem Gebiet ausserhalb von Gefechten langsam
    selbst auf.

    ship.subs.supply = {eta (os.time), crates = {kind = n}}
    ship.subs.supplyNext = os.time() der naechsten moeglichen Anforderung
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3 = Naval.V3
local S = Naval.State

local CRATE = "pd_naval_nachschub"
local INTAKE_RANGE = 90

-- Kisten duerfen ins Fahrzeuginventar (wie Transportkisten)
PD.VehicalInventory = PD.VehicalInventory or {}
PD.VehicalInventory.ExtraCargo = PD.VehicalInventory.ExtraCargo or {}
PD.VehicalInventory.ExtraCargo[CRATE] = true

local function Setting(key, default)
    return tonumber(Naval.Settings and Naval.Settings[key]) or default
end

-- Hauptschalter (supply_enabled): aus = Munition wird nicht verbraucht,
-- verlorene Maschinen kommen ausserhalb von Gefechten von selbst zurueck,
-- keine Anforderungen
function Naval.SupplyEnabled()
    return Setting("supply_enabled", 1) == 1
end

local function Markers(station)
    local list = {}
    for _, ent in ipairs(ents.FindByClass("pd_naval_console")) do
        if ent:GetStation() == station then list[#list + 1] = ent end
    end
    return list
end

local function NotifyAll(text, col)
    for _, ply in ipairs(player.GetHumans()) do
        PD.Notify("[Logistik] " .. text, col or Color(120, 220, 160), false, ply)
    end
end

--------------------------------------------------------------------------------
-- Bestand
--------------------------------------------------------------------------------

-- Munition je Waffentyp: aktuell, hoechstens, Batterien
local function AmmoOf(ship, weapon)
    local subs, _, cc = Naval.Combat(ship)
    local cur, max, list = 0, 0, {}
    for i, b in ipairs(cc.weapons) do
        if b.type == weapon then
            local m = b.ammo or 50
            local c = subs.ammo[i] or m
            cur, max = cur + c, max + m
            list[#list + 1] = {i = i, cur = c, max = m}
        end
    end
    return cur, max, list
end

local function HullMax(ship)
    return (ship:Class() or {}).hull or 1000
end

local function Craft(ship)
    if not Naval.Hangar then return 0, 0 end
    local h, cap = Naval.Hangar(ship)
    local out = ship.subs.hangarOut or {}
    local ready = (h.fighter or 0) + (h.bomber or 0)
    local max = ((cap.fighter or 0) + (cap.bomber or 0)) * 12
    return ready + (out.fighter or 0) + (out.bomber or 0), max
end

-- Kiste verbuchen. Gibt den Text fuer die Meldung zurueck oder nil (nichts frei).
local function Apply(ship, kind)
    local def = Naval.SupplyKinds[kind]
    if not def then return nil end

    if def.weapon then
        local cur, max, list = AmmoOf(ship, def.weapon)
        if max <= 0 or cur >= max then return nil end
        local left = def.amount
        local subs = ship.subs
        table.sort(list, function(a, b) return a.cur / a.max < b.cur / b.max end)
        for _ = 1, def.amount do
            local added = false
            for _, e in ipairs(list) do
                if left > 0 and e.cur < e.max then
                    e.cur = e.cur + 1
                    subs.ammo[e.i] = e.cur
                    left = left - 1
                    added = true
                end
            end
            if not added or left <= 0 then break end
        end
        return ("%d %s geladen"):format(def.amount - left, def.unit)
    end

    if kind == "parts" then
        local max = HullMax(ship)
        local cap = max * Setting("supply_parts_max", 80) / 100
        local hull = ship.hull or max
        if hull >= cap or ship.state == S.DESTROYED then return nil end
        local add = math.min(max * Setting("supply_parts_hull", 5) / 100, cap - hull)
        ship.hull = hull + add
        return ("Hülle +%d (%d %%)"):format(math.Round(add), math.Round(ship.hull / max * 100))
    end

    if kind == "craft" and Naval.Hangar then
        local total, max = Craft(ship)
        if total >= max then return nil end
        local h, cap = Naval.Hangar(ship)
        local left = math.min(def.amount, max - total)
        local added = left
        -- Erst die Art auffuellen, die mehr fehlt
        for _, k in ipairs({"fighter", "bomber"}) do
            local missing = (cap[k] or 0) * 12 - (h[k] or 0) - ((ship.subs.hangarOut or {})[k] or 0)
            local n = math.min(left, math.max(0, missing))
            h[k] = (h[k] or 0) + n
            left = left - n
        end
        return ("%d Maschinen im Hangar"):format(added - left)
    end
end

--------------------------------------------------------------------------------
-- Anforderung und Anlieferung
--------------------------------------------------------------------------------

local function Friendly(ship)
    if Setting("supply_require_friendly", 1) ~= 1 then return true end
    local terr = Naval.Territory and Naval.Territory[ship.systemId]
    if terr and terr.f == ship.factionId and not terr.c then return true, "eigenes Gebiet" end
    for _, o in pairs(Naval.Ships) do
        if o ~= ship and o.systemId == ship.systemId and o.state == S.NORMAL and not (o.flags and (o.flags.hidden or o.flags.surrendered))
            and Naval.GetRelation(ship.factionId, o.factionId) == Naval.Relation.ALLY and V3.Dist(o.pos, ship.pos) <= 100000 then
            return true, "Versorgung durch " .. o.name
        end
    end
    return false
end

function Naval.SupplyCheck(ship)
    if not Naval.SupplyEnabled() then return false, "Nachschub-System ist abgeschaltet" end
    local subs = ship.subs or {}
    if subs.supply then return false, "Eine Lieferung ist schon unterwegs" end
    if (subs.supplyNext or 0) > os.time() then
        return false, ("Nächste Lieferung in %d min möglich"):format(math.ceil((subs.supplyNext - os.time()) / 60))
    end
    if ship.state ~= S.NORMAL then return false, "Nur im Normalflug" end
    if (ship.lastAttacked or 0) > CurTime() - 60 then return false, "Nicht im Gefecht" end
    local ok, source = Friendly(ship)
    if not ok then return false, "Kein Nachschub hier: eigenes Gebiet oder verbündetes Schiff in 100 km nötig" end
    if #Markers("supply_drop") == 0 then return false, "Keine Anlieferung auf der Map eingerichtet" end
    return true, source
end

-- gift: Lieferung ausserhalb der Anforderung (Szenario), sonst die bestellte
local function Deliver(ship, gift)
    local order = gift or ship.subs.supply
    if not gift then ship.subs.supply = nil end
    ship.dirty = true
    if not order then return end

    local drops = Markers("supply_drop")
    if #drops == 0 then return end
    local n = 0
    for _, kind in ipairs(Naval.SupplyOrder) do
        for _ = 1, order.crates[kind] or 0 do
            local drop = drops[n % #drops + 1]
            local slot = math.floor(n / #drops)
            local crate = ents.Create(CRATE)
            if IsValid(crate) then
                local fwd, right = drop:GetForward(), drop:GetRight()
                crate:SetPos(drop:GetPos() + Vector(0, 0, 20) + right * ((slot % 4) - 1.5) * 45 + fwd * math.floor(slot / 4) * 45)
                crate:SetAngles(Angle(0, drop:GetAngles().y, 0))
                crate:SetKind(kind)
                crate:Spawn()
            end
            n = n + 1
        end
    end

    ship:Log("supply", "", n .. " Nachschubkisten angeliefert")
    NotifyAll(n .. " Nachschubkisten sind an der Anlieferung - zur Nachschub-Annahme bringen")
    Naval.Event(ship, "supply_arrived", {count = n})
end

local function NotifyNear(pos, text, col)
    for _, ply in ipairs(ents.FindInSphere(pos, 600)) do
        if ply:IsPlayer() then PD.Notify("[Logistik] " .. text, col, false, ply) end
    end
end

local function Intake(ship)
    for _, intake in ipairs(Markers("supply_intake")) do
        for _, ent in ipairs(ents.FindInSphere(intake:GetPos(), INTAKE_RANGE)) do
            if ent:GetClass() == CRATE and not IsValid(ent:GetParent()) and not ent.PD_Taken then
                local kind = ent:GetKind()
                local text = Apply(ship, kind)
                if text then
                    ent.PD_Taken = true
                    ent:Remove()
                    ship.dirty = true
                    local def = Naval.SupplyKinds[kind]
                    ship:Log("supply", "", def.name .. ": " .. text)
                    NotifyNear(intake:GetPos(), def.name .. ": " .. text, Color(120, 220, 160))
                elseif (ent.PD_FullNotified or 0) < CurTime() then
                    ent.PD_FullNotified = CurTime() + 20
                    local def = Naval.SupplyKinds[kind]
                    NotifyNear(intake:GetPos(), (def and def.name or "Kiste") .. ": nichts aufzufüllen", Color(255, 200, 80))
                end
            end
        end
    end
end

-- KI-Schiffe in eigenem Gebiet ausserhalb von Gefechten
-- Abgeschaltet: Maschinen kommen bei allen Schiffen ausserhalb von Gefechten zurueck
local function RefillCraft(ship)
    if not Naval.Hangar or ship.state ~= S.NORMAL or (ship.lastAttacked or 0) > CurTime() - 120 then return end
    local h, cap = Naval.Hangar(ship)
    for _, k in ipairs({"fighter", "bomber"}) do
        local max = (cap[k] or 0) * 12 - ((ship.subs.hangarOut or {})[k] or 0)
        if (h[k] or 0) < max then h[k] = math.min(max, (h[k] or 0) + 2) ship.dirty = true end
    end
end

local function NpcResupply(ship)
    if not Naval.SupplyEnabled() then RefillCraft(ship) return end
    if ship:IsPlayerShip() or ship.state ~= S.NORMAL or (ship.lastAttacked or 0) > CurTime() - 120 then return end
    if ship.flags and (ship.flags.surrendered or ship.flags.prisoner or ship.flags.hidden) then return end
    local terr = Naval.Territory and Naval.Territory[ship.systemId]
    if not terr or terr.f ~= ship.factionId then return end
    local rate = Setting("supply_npc_rate", 0.1)
    if rate <= 0 then return end

    local subs, _, cc = Naval.Combat(ship)
    for i, b in ipairs(cc.weapons) do
        local wt = Naval.WeaponTypes[b.type]
        if wt and wt.ammo then
            local m = b.ammo or 50
            subs.ammo[i] = math.min(m, (subs.ammo[i] or m) + math.ceil(m * rate))
        end
    end
    if Naval.Hangar then
        local h, cap = Naval.Hangar(ship)
        for _, k in ipairs({"fighter", "bomber"}) do
            local max = (cap[k] or 0) * 12 - ((subs.hangarOut or {})[k] or 0)
            if (h[k] or 0) < max then h[k] = math.min(max, (h[k] or 0) + 2) end
        end
    end
end

local npcAcc = 0
timer.Create("PD.Naval.Supply", 1, 0, function()
    if not Naval.SimRunning or Naval.Paused then return end
    local ok, err = xpcall(function()
        local ship = Naval.GetMapShip()
        if ship and Naval.Combat then
            Naval.Combat(ship)
            local order = ship.subs.supply
            if order and os.time() >= (order.eta or 0) then Deliver(ship) end
            Intake(ship)
        end

        npcAcc = npcAcc + 1
        if npcAcc >= 60 then
            npcAcc = 0
            for _, s in pairs(Naval.Ships) do
                if Naval.Combat then Naval.Combat(s) end
                NpcResupply(s)
            end
        end
    end, debug.traceback)
    if not ok then ErrorNoHalt("[Naval] Nachschub: " .. tostring(err) .. "\n") end
end)

Naval.SupplyApplyForTest = Apply

-- Kisten sofort an die Anlieferung (Szenarien)
function Naval.SupplyDeliver(ship, crates)
    local clean = {}
    for _, kind in ipairs(Naval.SupplyOrder) do
        local n = math.Clamp(math.floor(tonumber(crates[kind]) or 0), 0, 20)
        if n > 0 then clean[kind] = n end
    end
    if Naval.Combat then Naval.Combat(ship) end
    Deliver(ship, {crates = clean})
end

--------------------------------------------------------------------------------
-- Logistik-Leitstand
--------------------------------------------------------------------------------

Naval.CombatCommands = Naval.CombatCommands or {}
Naval.CombatCommands.logistics = Naval.CombatCommands.logistics or {}
local LC = Naval.CombatCommands.logistics

local function ReadOrder(args)
    local crates, total = {}, 0
    local limit = Setting("supply_max_crates", 8)
    for _, kind in ipairs(Naval.SupplyOrder) do
        local n = math.Clamp(math.floor(tonumber(istable(args.crates) and args.crates[kind]) or 0), 0, limit)
        n = math.min(n, limit - total)
        if n > 0 then crates[kind] = n total = total + n end
    end
    return crates, total
end

LC.order = function(ply, ship, args)
    local crates, total = ReadOrder(args)
    if total <= 0 then PD.Notify("Keine Kisten gewählt", Color(255, 90, 90), false, ply) return end
    local ok, reason = Naval.SupplyCheck(ship)
    if not ok then PD.Notify(reason, Color(255, 90, 90), false, ply) return end

    local delay = Setting("supply_delivery_time", 90)
    ship.subs.supply = {eta = os.time() + delay, crates = crates}
    ship.subs.supplyNext = os.time() + delay + Setting("supply_cooldown", 900)
    ship:Log("supply", ply:Nick(), ("%d Nachschubkisten angefordert (%s), Ankunft in %d s"):format(total, reason or "", delay))
    NotifyAll(("Nachschub angefordert: %d Kisten, Ankunft in %d s"):format(total, delay))
    if PD.LOGS and PD.LOGS.Add then PD.LOGS.Add("Naval", ply:Nick() .. ": Nachschub angefordert (" .. total .. " Kisten)", Color(120, 220, 160)) end
end

-- Spielleitung: sofort liefern (auch ohne Bedingungen)
LC.adminDeliver = function(ply, ship, args)
    if not ply:IsAdmin() then return end
    local crates, total = ReadOrder(args)
    if total <= 0 and not ship.subs.supply then return end
    if total > 0 then ship.subs.supply = {eta = 0, crates = crates} end
    ship.subs.supply.eta = 0
    Deliver(ship)
    if PD.LOGS and PD.LOGS.Add then PD.LOGS.Add("Naval", ply:Nick() .. ": Nachschub sofort geliefert", Color(120, 170, 255)) end
end

LC.adminToggle = function(ply)
    if not ply:IsAdmin() then return end
    local on = not Naval.SupplyEnabled()
    Naval.Settings.supply_enabled = on and 1 or 0
    PD.SQL.Query("REPLACE INTO `pd_naval_settings` (`config_key`, `config_value`) VALUES ('supply_enabled', '" .. (on and 1 or 0) .. "')")
    NotifyAll("Nachschub-System " .. (on and "eingeschaltet - Munition muss nachgeliefert werden" or "abgeschaltet - Munition wird nicht verbraucht"),
        on and Color(120, 220, 160) or Color(240, 200, 90))
    if PD.LOGS and PD.LOGS.Add then PD.LOGS.Add("Naval", ply:Nick() .. ": Nachschub-System " .. (on and "an" or "aus"), Color(120, 170, 255)) end
end

LC.adminCooldown = function(ply, ship)
    if not ply:IsAdmin() then return end
    ship.subs.supplyNext = 0
end

Naval.StatusExtras = Naval.StatusExtras or {}
Naval.StatusExtras.logistics = function(ship)
    if not Naval.Combat then return nil end
    Naval.Combat(ship)
    local subs = ship.subs

    local ammo = {}
    for _, kind in ipairs(Naval.SupplyOrder) do
        local def = Naval.SupplyKinds[kind]
        if def.weapon then
            local cur, max = AmmoOf(ship, def.weapon)
            ammo[kind] = {cur = cur, max = max}
        end
    end
    local craftCur, craftMax = Craft(ship)
    local hullMax = HullMax(ship)

    local ok, reason = Naval.SupplyCheck(ship)
    local onBoard = {}
    for _, ent in ipairs(ents.FindByClass(CRATE)) do
        local k = ent:GetKind()
        onBoard[k] = (onBoard[k] or 0) + 1
    end

    return {
        enabled = Naval.SupplyEnabled() or nil,
        ammo = ammo, craft = {cur = craftCur, max = craftMax},
        hull = math.Round(ship.hull or hullMax), hullMax = hullMax, partsMax = Setting("supply_parts_max", 80),
        delivery = subs.supply and {eta = math.max(0, (subs.supply.eta or 0) - os.time()), crates = subs.supply.crates} or nil,
        cooldown = math.max(0, (subs.supplyNext or 0) - os.time()),
        available = ok or nil, reason = reason, maxCrates = Setting("supply_max_crates", 8),
        onBoard = onBoard, drops = #Markers("supply_drop"), intakes = #Markers("supply_intake"),
    }
end
