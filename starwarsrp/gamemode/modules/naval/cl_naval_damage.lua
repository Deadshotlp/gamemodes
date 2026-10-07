--[[
    Naval - Schaeden an Bord (Client): Funken, Rauch und Feuer an den
    Schadenspunkten, Hinweis "E halten" mit Fortschritt beim Reparieren.
    Daten: PD.Naval.Incidents (sv_naval_damagecontrol.lua).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval

local KINDS = {"sparks", "smoke", "fire"}
local FX_RANGE = 3000
local REPAIR_RANGE = 110

local incidents = {}
local emitter

local function StopSound(inc)
    if inc.sound then inc.sound:Stop() inc.sound = nil end
end

net.Receive("PD.Naval.Incidents", function()
    local count = net.ReadUInt(8)
    local fresh = {}

    for _ = 1, count do
        local id = net.ReadUInt(16)
        local ent = net.ReadEntity()
        local kind = KINDS[net.ReadUInt(2)] or "sparks"
        local progress = net.ReadFloat()

        local inc = incidents[id] or {id = id, nextFx = 0}
        inc.ent, inc.kind, inc.progress = ent, kind, progress
        fresh[id] = inc
    end

    for id, inc in pairs(incidents) do
        if not fresh[id] then StopSound(inc) end
    end
    incidents = fresh
    Naval.OldIncidents = incidents
end)

local LOOP = {fire = "ambient/fire/fire_small_loop2.wav", smoke = "ambient/gas/steam_loop1.wav"}

local function Effects(inc, pos, now)
    if not emitter then emitter = ParticleEmitter(pos) end
    if not emitter then return end
    emitter:SetPos(pos)

    if inc.kind == "sparks" then
        if now >= inc.nextFx then
            inc.nextFx = now + math.Rand(0.25, 1.4)
            local data = EffectData()
            data:SetOrigin(pos)
            data:SetNormal(VectorRand():GetNormalized())
            data:SetMagnitude(2)
            data:SetScale(1)
            data:SetRadius(3)
            util.Effect("Sparks", data)
            sound.Play("ambient/energy/spark" .. math.random(1, 6) .. ".wav", pos, 65, math.random(90, 110), 0.6)
        end
        return
    end

    -- Rauch (auch ueber Feuer)
    if now >= inc.nextFx then
        inc.nextFx = now + (inc.kind == "fire" and 0.06 or 0.12)

        local p = emitter:Add("particle/smokesprites_000" .. math.random(1, 9), pos + VectorRand() * 6)
        if p then
            p:SetVelocity(Vector(math.Rand(-10, 10), math.Rand(-10, 10), math.Rand(25, 50)))
            p:SetDieTime(math.Rand(2.5, 4))
            p:SetStartAlpha(inc.kind == "fire" and 120 or 90)
            p:SetEndAlpha(0)
            p:SetStartSize(math.Rand(8, 14))
            p:SetEndSize(math.Rand(40, 60))
            p:SetRoll(math.Rand(0, 360))
            p:SetRollDelta(math.Rand(-0.5, 0.5))
            local g = inc.kind == "fire" and 40 or 90
            p:SetColor(g, g, g)
            p:SetAirResistance(40)
            p:SetGravity(Vector(0, 0, 8))
        end

        if inc.kind == "fire" then
            for _ = 1, 2 do
                local f = emitter:Add("particles/flamelet" .. math.random(1, 5), pos + VectorRand() * 10)
                if f then
                    f:SetVelocity(Vector(math.Rand(-6, 6), math.Rand(-6, 6), math.Rand(30, 60)))
                    f:SetDieTime(math.Rand(0.4, 0.8))
                    f:SetStartAlpha(230)
                    f:SetEndAlpha(0)
                    f:SetStartSize(math.Rand(10, 16))
                    f:SetEndSize(math.Rand(2, 5))
                    f:SetRoll(math.Rand(0, 360))
                    f:SetColor(255, math.random(150, 220), 120)
                end
            end
        end
    end

    if inc.kind == "fire" then
        local light = DynamicLight(inc.ent:EntIndex() + 9000)
        if light then
            light.pos = pos + Vector(0, 0, 10)
            light.r, light.g, light.b = 255, 130, 50
            light.brightness = 2 + math.sin(now * 17) * 0.4
            light.decay = 1000
            light.size = 220
            light.dietime = now + 0.2
        end
    end
end

hook.Add("Think", "PD.Naval.DamageFX", function()
    if Naval.ClientShutdown or not next(incidents) then return end

    local eye = EyePos()
    local now = CurTime()

    for _, inc in pairs(incidents) do
        if IsValid(inc.ent) then
            local pos = inc.ent:GetPos() + Vector(0, 0, 12)
            local near = eye:DistToSqr(pos) < FX_RANGE * FX_RANGE

            if near then
                Effects(inc, pos, now)

                local loop = LOOP[inc.kind]
                if loop and not inc.sound then
                    inc.sound = CreateSound(inc.ent, loop)
                    inc.sound:PlayEx(0.5, 100)
                end
            else
                StopSound(inc)
            end
        end
    end
end)

-- Hinweis beim Hinschauen: am Schadensort (3D2D) statt auf dem Bildschirm
surface.CreateFont("PD.Naval.Damage3D2D", {font = "Roboto", size = 40, weight = 700, extended = true})

hook.Add("PostDrawTranslucentRenderables", "PD.Naval.DamageHint", function(depth, sky)
    if depth or sky or Naval.ClientShutdown then return end
    if not next(incidents) then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    local eye, aim = ply:EyePos(), ply:GetAimVector()
    local best, bestD
    for _, inc in pairs(incidents) do
        if IsValid(inc.ent) then
            local to = inc.ent:GetPos() + Vector(0, 0, 12) - eye
            local d = to:Length()
            if d < REPAIR_RANGE and (d < 40 or aim:Dot(to:GetNormalized()) > 0.6) and (not bestD or d < bestD) then
                best, bestD = inc, d
            end
        end
    end
    if not best then return end

    local kind = Naval.IncidentKinds[best.kind] or {}
    local w = 360
    local ang = Angle(0, ply:EyeAngles().y - 90, 90)
    cam.Start3D2D(best.ent:GetPos() + Vector(0, 0, 40), ang, 0.1)
        draw.RoundedBox(4, -w / 2, 0, w, 64, Color(14, 18, 24, 220))
        draw.SimpleText((kind.name or "Schaden") .. " - E halten", "PD.Naval.Damage3D2D", 0, 6, Color(225, 230, 240), TEXT_ALIGN_CENTER)
        draw.RoundedBox(0, -w / 2 + 12, 48, w - 24, 8, Color(40, 46, 56))
        draw.RoundedBox(0, -w / 2 + 12, 48, (w - 24) * math.Clamp(best.progress or 0, 0, 1), 8, Color(90, 210, 130))
    cam.End3D2D()
end)

-- Beim Verlassen der Map: Emitter abschliessen, Toene stoppen
hook.Add("ShutDown", "PD.Naval.DamageFX", function()
    Naval.ClientShutdown = true
    for _, inc in pairs(incidents) do StopSound(inc) end
    incidents = {}
    if emitter then
        pcall(emitter.Finish, emitter)
        emitter = nil
    end
end)

-- Beim Lua-Refresh keine Endlos-Geraeusche liegen lassen
for _, inc in pairs(Naval.OldIncidents or {}) do StopSound(inc) end
Naval.OldIncidents = incidents
