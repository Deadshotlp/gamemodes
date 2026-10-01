--[[
    Clientseite der ArcCW-Anpassungen.

    Den Schaden rechnet der Server aus - hier geht es nur darum, dass die
    Anzeige stimmt. ArcCW liest fuer das Waffenmenue und die Statistikleiste
    dieselben Felder aus der Waffentabelle, und die kaemen ohne diese Datei aus
    der unveraenderten Addon-Datei. Der Spieler saehe dann 50 Schaden, waehrend
    er in Wirklichkeit 35 macht.
]]

net.Receive("PD.ACW:Sync", function()
    local weapons_ = net.ReadTable()
    local atts = net.ReadTable()

    if istable(weapons_) then
        PD.ACW.Overrides = {}

        for class, values in pairs(weapons_) do
            if not istable(values) then continue end

            PD.ACW.Overrides[class] = values

            -- Clientseitig gibt es keinen Schnappschuss der Ausgangswerte,
            -- deshalb werden die Werte direkt gesetzt statt ueber Refresh.
            local stored = weapons.GetStored(class)

            if istable(stored) then
                PD.ACW.ApplyTo(stored, values)
            end

            for _, wep in ipairs(ents.FindByClass(class)) do
                if IsValid(wep) then
                    PD.ACW.ApplyTo(wep:GetTable(), values)
                end
            end
        end
    end

    if istable(atts) then
        PD.ACW.AttOverrides = {}

        local registry = PD.ACW.AttachmentRegistry()

        for id, values in pairs(atts) do
            if not istable(values) then continue end

            PD.ACW.AttOverrides[id] = values

            if registry and istable(registry[id]) then
                PD.ACW.ApplyToAtt(registry[id], values)
            end
        end
    end

    -- Die Sperrliste. Ohne sie bot das Aufsatzmenue beim Client gesperrte
    -- Aufsaetze an, weil nur der Server von der Sperre wusste. Ein aelterer
    -- Server schickt sie nicht mit - dann wird nicht ueber das Ende gelesen.
    if (net.BytesLeft() or 0) > 0 then
        local blocks = net.ReadTable()

        if istable(blocks) then
            PD.ACW.Blocked = blocks
        end
    end

    PD.ACW.ApplyBlocks()
end)

--------------------------------------------------------------------------------
-- Grappling Hook: Abspringen mit der Use-Taste statt T
--------------------------------------------------------------------------------

--[[
    Der Grappling Hook (Special Forces Pack) fragt fuer "Jump off" fest
    input.IsKeyDown(KEY_T) ab. Hier wird sein Think-Hook - gleicher Name,
    damit er ersetzt statt verdoppelt wird - durch eine Fassung mit der
    Use-Taste ersetzt (IN_USE, also was der Spieler auf +use gebunden hat).
    Die Serverseite (ArcCW_KrakenGrapple_JumpOff) bleibt unveraendert.

    Das Addon legt seinen Hook beim Laden der Aufsaetze an, also nach dem
    Gamemode. Deshalb nach InitPostEntity bzw. beim Lua-Refresh sofort.
]]
local function grappleHookEnt(wep)
    return wep:GetNWEntity("ArcCWKrakenGrappleHook")
end

local function installGrappleUseKey()
    local lastUse = false
    local nextSend = 0

    hook.Add("Think", "ArcCW_KrakenGrapple_TKey", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then lastUse = false return end

        local wep = lp:GetActiveWeapon()
        local valid = IsValid(wep) and wep.ArcCW and wep:GetInUBGL()
        local pressed = lp:KeyDown(IN_USE)

        if valid and pressed and not lastUse and CurTime() >= nextSend then
            local hk = grappleHookEnt(wep)

            if IsValid(hk) and hk.GetHasHit and hk:GetHasHit() then
                net.Start("ArcCW_KrakenGrapple_JumpOff")
                net.SendToServer()
                nextSend = CurTime() + 0.25
            end
        end

        lastUse = pressed
    end)
end

hook.Add("InitPostEntity", "PD.ACW.GrappleUseKey", installGrappleUseKey)
timer.Simple(0, installGrappleUseKey)

-- Hinweis im Grapple-HUD: "T  -  Jump off" zeigt die tatsaechliche Use-Taste.
-- Nur die beiden exakten Texte des Addons werden ersetzt.
PD.ACW.RealDrawText = PD.ACW.RealDrawText or draw.DrawText
local realDrawText = PD.ACW.RealDrawText

local jumpHints = {
    ["T  -  Jump off"] = "  -  Abspringen",
    ["T  -  Jump off (when above)"] = "  -  Abspringen (wenn darüber)",
}

draw.DrawText = function(text, ...)
    local suffix = jumpHints[text]

    if suffix then
        local key = string.upper(input.LookupBinding("+use") or "E")
        text = key .. suffix
    end

    return realDrawText(text, ...)
end

--------------------------------------------------------------------------------
-- Grappling Hook: Seil schwarz und vom Lauf der Waffe
--------------------------------------------------------------------------------

--[[
    Das Addon zeichnet das Seil an zwei Stellen:
      * eigene Sicht: lokales DrawRope, per PostDrawOpaqueRenderables-Hook
        "ArcCW_KrakenGrapple_Client_<EntIndex>"
      * andere Spieler / Third Person: ENT:Draw von arccw_kraken_ubgl_hook
    Beide suchen am Modell den Anhangspunkt "muzzle", finden ihn bei unseren
    Waffen nicht und fallen auf die Schussposition zurueck - das Seil kam
    dadurch aus dem Kopf.

    Hier wird ArcCWs eigene Muendung genommen (GetTracerOrigin; im UGL-Modus
    die des Aufsatzes). Das Addon-Material cable/physbeam ist additiv und
    laesst sich nicht schwarz faerben, deshalb ein deckendes Farbmaterial.
]]
local ROPE_COLOR = Color(0, 0, 0, 255)
local ROPE_WIDTH = 1.5

local function ropeOrigin(wep)
    local ok, pos = pcall(wep.GetTracerOrigin, wep)

    if ok and isvector(pos) then return pos end

    return wep:GetPos()
end

local function followTarget(hk)
    local target = hk:GetTargetEnt()
    if not IsValid(target) then return end

    local bpos, bang = target:GetBonePosition(hk:GetFollowBone())
    local npos, nang = hk:GetFollowOffset(), hk:GetFollowAngle()

    if npos and nang and bpos and bang then
        npos = Vector(npos)
        npos:Rotate(nang)
        hk:SetPos(bpos + npos)
        hk:SetAngles(nang + bang)
    end
end

local function drawRope(hk, wep)
    render.SetColorMaterial()
    render.DrawBeam(hk:GetPos(), ropeOrigin(wep), ROPE_WIDTH, 0, 1, ROPE_COLOR)
end

--[[
    Der Haken zeichnet sein Modell und das Seil - fuer alle Sichten.

    ENT:Draw laeuft nur, solange das Entity im Bild ist. Damit das Seil nicht
    mit dem Haken verschwindet, umfassen die Render-Bounds des Hakens das
    ganze Seil bis zur Muendung (PD.ACW.GrappleRopeBounds): ausgeblendet wird
    erst, wenn auch vom Seil nichts mehr zu sehen ist.

    (Ein eigener zentraler PostDrawOpaqueRenderables-Hook zeichnete gar nichts
    - vermutlich bricht dort ein anderer Hook die Kette mit einem
    Rueckgabewert ab. Dieser Weg haengt an keiner Hook-Reihenfolge.)
]]
local function hookEntDraw(self)
    followTarget(self)
    self:DrawModel()

    local wep = self:GetWep()

    if IsValid(wep) and IsValid(wep:GetOwner()) then
        drawRope(self, wep)
    end
end

hook.Remove("PostDrawOpaqueRenderables", "PD.ACW.GrappleRopes")

-- Der Seil-Hook des Addons (eigene Sicht) wird durch diesen leeren ersetzt:
-- das Seil zeichnet der Haken selbst, sonst laege es doppelt.
local function ownRopeDraw()
end

local BOUNDS_PAD = Vector(16, 16, 16)

hook.Add("Think", "PD.ACW.GrappleRopeBounds", function()
    for _, hk in ipairs(ents.FindByClass("arccw_kraken_ubgl_hook")) do
        local wep = hk:GetWep()

        if IsValid(wep) and IsValid(wep:GetOwner()) then
            local a, b = hk:GetPos(), ropeOrigin(wep)
            local mins = Vector(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z)) - BOUNDS_PAD
            local maxs = Vector(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z)) + BOUNDS_PAD

            hk:SetRenderBoundsWS(mins, maxs)
        end
    end
end)

local function installGrappleRope()
    local stored = scripted_ents.GetStored("arccw_kraken_ubgl_hook")
    if stored and istable(stored.t) then
        stored.t.Draw = hookEntDraw
    end

    for _, ent in ipairs(ents.FindByClass("arccw_kraken_ubgl_hook")) do
        ent.Draw = hookEntDraw
    end

    local original = PD.ACW.GrappleClientThinkOriginal or _G.ArcCWKrakenGrappleClientThink
    if not isfunction(original) then return end

    PD.ACW.GrappleClientThinkOriginal = original

    _G.ArcCWKrakenGrappleClientThink = function(wep)
        original(wep)

        if wep._ArcCWKrakenGrappleClientHooks then
            if not wep.PD_RopeHook then
                -- Gleicher Name wie im Addon: ersetzt dessen Seil-Zeichnung.
                hook.Add("PostDrawOpaqueRenderables", "ArcCW_KrakenGrapple_Client_" .. wep:EntIndex(), function()
                    ownRopeDraw(wep)
                end)

                wep.PD_RopeHook = true
            end
        else
            wep.PD_RopeHook = nil
        end
    end
end

hook.Add("InitPostEntity", "PD.ACW.GrappleRope", installGrappleRope)
timer.Simple(0, installGrappleRope)
