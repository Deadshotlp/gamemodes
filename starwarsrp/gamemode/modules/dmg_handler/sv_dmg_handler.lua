PD.DH = PD.DH or {}
PD.Armor = PD.Armor or {}

-- Eine Source-Einheit ist ein Zoll.
local EINHEITEN_JE_METER = 39.37

--[[
    Der alte Fallschaden-Hook, ausdruecklich abgeraeumt.

    hook.Add("GetFallDamage", "RealisticDamage", ...) stand frueher in dieser
    Datei und gab speed/10 zurueck. Ihn aus der Datei zu loeschen reicht nicht:
    ein Lua-Refresh laedt die Datei neu, entfernt aber keine Hooks, die beim
    vorigen Durchlauf registriert wurden. Der Hook blieb also im laufenden
    Server bestehen und hat weiter Schaden beigesteuert - bei 668 Einheiten pro
    Sekunde rund 67, zusaetzlich zu unseren eigenen gut 22.
]]
hook.Remove("GetFallDamage", "RealisticDamage")

--[[
    Bezugsschwerkraft fuer die Umrechnung Geschwindigkeit -> Hoehe.

    Bewusst fest und nicht aus sv_gravity: eine Verletzung haengt daran, wie
    hart man aufschlaegt, nicht daran, wie weit man dafuer fallen musste. Mit
    der gelesenen Schwerkraft wuerde derselbe Aufprall auf einer Karte mit
    halber Schwerkraft doppelt so weh tun - und genau das laesst sich im Spiel
    nicht erklaeren.

    Die Kurve unten ist damit in Metern beschrieben, meint aber feste
    Aufprallgeschwindigkeiten: 5 m sind 486 Einheiten pro Sekunde, 25 m sind
    1087. Bei geringerer Schwerkraft faellt man einfach weiter, bis man sie
    erreicht.
]]
local BEZUGSSCHWERKRAFT = 600

--[[
    Fallschaden ueber der Fallhoehe, in Metern.

    Stuetzpunkte, zwischen denen PD.LinearInterpolation geradlinig vermittelt.
    Wer die Kurve biegen will, setzt Punkte dazwischen - etwa {x = 15, y = 35},
    damit mittlere Stuerze glimpflicher ausgehen und der Anstieg erst zum Ende
    hin steil wird. Die Reihenfolge ist egal, die Funktion sortiert selbst.
]]
PD.DH.FallKurve = {
    {x = 5,  y = 0},
    {x = 10,  y = 25},
    {x = 15,  y = 50},
    {x = 20,  y = 75},
    {x = 25, y = 100}
}

--------------------------------------------------------------------------------
-- Fallschaden
--------------------------------------------------------------------------------

--[[
    Aufprallgeschwindigkeit in Fallhoehe umrechnen.

    h = v^2 / (2g), danach von Einheiten in Meter, mit der Bezugsschwerkraft
    von oben.
]]
local function fallHeight(speed)
    return (speed * speed) / (2 * BEZUGSSCHWERKRAFT) / EINHEITEN_JE_METER
end

function PD.DH.FallHeight(speed)
    return fallHeight(speed)
end

--[[
    Schaden zu einer Aufprallgeschwindigkeit.

    PD.LinearInterpolation gibt ausserhalb der Stuetzpunkte 0 zurueck. Unterhalb
    ist das genau richtig - unter fuenf Metern soll nichts passieren. Oberhalb
    waere es das Gegenteil von dem, was gemeint ist: ein Sturz aus dreissig
    Metern taete dann gar nicht weh. Deshalb wird die Hoehe vorher auf den
    obersten Stuetzpunkt geklemmt.
]]
function PD.DH.FallDamage(speed)
    local kurve = PD.DH.FallKurve

    if not istable(kurve) or #kurve < 2 then return 0 end
    if not isfunction(PD.LinearInterpolation) then return 0 end

    local hoehe = fallHeight(speed)

    local unten, oben = math.huge, -math.huge

    for _, punkt in ipairs(kurve) do
        unten = math.min(unten, punkt.x)
        oben  = math.max(oben, punkt.x)
    end

    if hoehe < unten then return 0 end

    return math.Clamp(PD.LinearInterpolation(math.min(hoehe, oben), kurve), 0, 100)
end

--[[
    Der Fallschaden der Engine wird abgeschaltet, wir rechnen selbst.

    Source ruft GetFallDamage erst ab seiner eigenen Untergrenze auf - rund 580
    Einheiten pro Sekunde, bei Standardschwerkraft also etwa sieben Meter. Eine
    Schwelle bei fuenf Metern liesse sich dort gar nicht unterbringen, weil der
    Aufruf nie kaeme. Deshalb haengt die Rechnung an OnPlayerHitGround, das bei
    jeder Landung feuert, und die Engine steuert nichts mehr bei.
]]
hook.Add("GetFallDamage", "PD.DH.NoEngineFallDamage", function()
    return 0
end)

hook.Add("OnPlayerHitGround", "PD.DH.FallDamage", function(ply, inWater, onFloater, speed)
    if not IsValid(ply) or not ply:Alive() then return end

    -- Wasser faengt den Sturz ab.
    if inWater then return end

    local damage = PD.DH.FallDamage(speed)

    if damage <= 0 then return end

    local dmg = DamageInfo()
    dmg:SetDamage(damage)
    dmg:SetDamageType(DMG_FALL)
    dmg:SetAttacker(game.GetWorld())
    dmg:SetInflictor(game.GetWorld())

    --[[
        Kennzeichnen, damit die Pruefung unten unseren eigenen Fallschaden von
        fremdem unterscheiden kann. TakeDamageInfo laeuft sofort durch, die
        Markierung steht also genau waehrend dieses einen Ereignisses.
    ]]
    ply.PD_OwnFallDamage = true
    ply:TakeDamageInfo(dmg)
    ply.PD_OwnFallDamage = nil
end)

--------------------------------------------------------------------------------
-- Schadensverarbeitung
--------------------------------------------------------------------------------

hook.Add("EntityTakeDamage", "PD.DamageHandler", function(target, dmg_object)
    if target:IsPlayer() and target:HasGodMode() then return true end

    --[[
        Fallschaden kommt ausschliesslich aus OnPlayerHitGround weiter oben.

        Alles andere wird verworfen: die Engine selbst, ein Addon, oder ein
        alter Hook, der nach einem Lua-Refresh noch registriert ist. Ohne diese
        Sperre summiert sich beides stillschweigend, und der Sturz kostet mehr
        als in der Kurve steht - genau das ist passiert.

        Die Ruestung bleibt aussen vor: sie schuetzt vor Beschuss, nicht vor dem
        Boden. Sonst kaeme der Sturz aus 25 Metern je nach Ruestungswert mit 70
        oder 80 Schaden an und waere ueberlebbar.
    ]]
    if dmg_object:IsFallDamage() then
        if target:IsPlayer() and not target.PD_OwnFallDamage then
            return true
        end

        return
    end

    local dmg = dmg_object:GetDamage()
    local attacker = dmg_object:GetAttacker()
    local model = tostring(target:GetModel() or "Keine ahnung auf jeden fall kein model i guess!")

    for _, i in pairs(PD.Armor.Data) do
        if i.Model == model then
            dmg_object:ScaleDamage(i.ArmorValue / 100)
        end
    end
end)

--------------------------------------------------------------------------------
-- Diagnose
--------------------------------------------------------------------------------

concommand.Add("pd_falldamage_table", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end

    local function say(text)
        if IsValid(ply) then
            ply:PrintMessage(HUD_PRINTCONSOLE, text)
        else
            print(text)
        end
    end

    local gravity = GetConVar("sv_gravity")
    local live = gravity and gravity:GetFloat() or -1

    say("[Fallschaden] Bezugsschwerkraft " .. BEZUGSSCHWERKRAFT
        .. ", sv_gravity auf dem Server " .. live)
    say("[Fallschaden] Stuetzpunkte:")

    for _, punkt in ipairs(PD.DH.FallKurve) do
        say(string.format("   %5.1f m  ->  %5.1f Schaden", punkt.x, punkt.y))
    end

    say("[Fallschaden] Verlauf:")

    for hoehe = 0, 30, 2.5 do
        -- Rueckwaerts gerechnet: welche Geschwindigkeit kaeme aus dieser Hoehe an?
        local speed = math.sqrt(2 * BEZUGSSCHWERKRAFT * hoehe * EINHEITEN_JE_METER)

        say(string.format("   %5.1f m  ->  %5.1f Schaden   (%4.0f Einheiten/s)",
            hoehe, PD.DH.FallDamage(speed), speed))
    end
end)
