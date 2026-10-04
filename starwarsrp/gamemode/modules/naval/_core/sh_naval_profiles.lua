--[[
    Naval - Map-Profile.

    Ein Profil beschreibt eine Map als Schiff: wie Map-Koordinaten zum
    Schiffskoerper stehen, welche Klasse das Schiff hat, wo Konsolen
    standardmaessig stehen und welche Map-eigenen Bedienelemente stoeren.
    Das sind Fakten ueber die Map-Geometrie, deshalb im Code statt im Panel.

    Werte mit "MESSEN" sind vorlaeufig und werden auf der Map mit
    pd_naval_mapfacts bzw. im Spiel bestimmt (Prototyp P3).
]]

PD.Naval = PD.Naval or {}
PD.Naval.Profiles = PD.Naval.Profiles or {}

PD.Naval.Profiles["rp_venator_extensive_v1_4"] = {
    key = "venator_extensive",
    classId = "venator",
    defaultName = "Venator",
    factionId = "republik",

    -- Mittelpunkt des Schiffs in Map-Koordinaten (MESSEN)
    shipOriginMap = Vector(0, 0, 0),

    -- Drehung Map -> Schiffskoerper: der Bug der Venator zeigt in der Map
    -- nicht entlang +x. Wert aus SWU (shipOffsetRotation), im Spiel pruefen.
    mapToBody = Angle(0, 90, 0),

    -- Meter pro Map-Einheit fuer die Parallaxe (wo im Schiff man steht).
    -- nil = keine Parallaxe. MESSEN: Venator ~1137 m / Laenge in Units.
    metersPerUnit = nil,

    -- Map-eigene Hyperraum-Logik (pd_naval_mapfacts): beim Start leerer
    -- Raum, bei Spruengen der originale Tunnel-Effekt der Map.
    mapRelays = {
        start = "desti_relay_space",
        jump = "hyperjump_relay",
        exit = "hyperexit_relay",
    },
    lockMapControls = {"hypertunnel_move2", "hyper_button_relay"},

    -- Aus SWU, nur fuer Pruefungen der Skybox
    skyboxReference = Vector(0, 0, 15500),

    disableSWU = true,
    disableFog = true,
    disableSun = true,

    -- Map-eigene Hyperraum-Knoepfe/Hebel (aus SWU blockPos): werden entfernt,
    -- damit sie nicht an unserem Hyperantrieb vorbei schalten.
    blockMapControls = {
        Vector(-5565, -4544, 1113),
        Vector(-5315, -3456, 1099),
    },

    hyperspace = {
        tunnel = "models/kingpommes/starwars/venator/hypertunnel.mdl",
        stars = "models/kingpommes/starwars/venator/lightspeed_stars.mdl",
    },

    -- Startpositionen der Konsolen (aus den SWU-Positionen), werden beim
    -- ersten Start in pd_naval_consoles uebernommen und sind danach mit dem
    -- Konsolen-Tool verschiebbar.
    consoles = {
        {station = "helm", pos = Vector(-7176, -3725, 1016), ang = Angle(0, -20, 0)},
        {station = "navcomputer", pos = Vector(-7272, -4552, 1088), ang = Angle(0, 0, 0)},
        {station = "hyperdrive", pos = Vector(-6711, -3725, 1016), ang = Angle(0, -160, 0)},
        {station = "bridgescreen", pos = Vector(-7120, -4552, 1160), ang = Angle(90, 0, 0)},
    },
}

--[[
    Hauptschalter. Solange er aus ist, verhaelt sich jede Map wie bisher:
    kein Naval-Betrieb, SWU bleibt aktiv. Erst einschalten, wenn Simulation,
    Darstellung und Konsolen fertig sind (Stufe 1) - sonst fehlt auf der
    Venator jede Steuerung. Wirkt nach Mapwechsel/Neustart vollstaendig.
]]
PD.Naval.ActiveConVar = CreateConVar("pd_naval_active", "0", FCVAR_ARCHIVE + FCVAR_REPLICATED,
    "Naval-System auf Maps mit Profil aktivieren (1) - schaltet dort SWU ab")

-- Profil der aktuellen Map (oder nil, auch wenn der Schalter aus ist)
function PD.Naval.GetProfile()
    if not PD.Naval.ActiveConVar:GetBool() then return nil end

    return PD.Naval.Profiles[game.GetMap()]
end

function PD.Naval.IsNavalMap()
    return PD.Naval.GetProfile() ~= nil
end

--------------------------------------------------------------------------------
-- Map-Fakten auslesen (Prototyp P3)
--------------------------------------------------------------------------------

if SERVER then
    local INTERESTING = {
        "sky_camera", "env_sun", "env_fog_controller", "env_skypaint",
        "shadow_control", "light_environment", "logic_relay", "func_button",
        "momentary_rot_button", "func_door", "func_movelinear", "info_player_start",
    }

    concommand.Add("pd_naval_mapfacts", function(ply)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end

        print("[Naval] Map-Fakten fuer " .. game.GetMap())

        local wmin, wmax = game.GetWorld():GetModelBounds()
        print(("  Welt-Grenzen: %s  bis  %s"):format(tostring(wmin), tostring(wmax)))

        for _, class in ipairs(INTERESTING) do
            local list = ents.FindByClass(class)

            if #list > 0 then
                print(("  %s: %d"):format(class, #list))

                for i, ent in ipairs(list) do
                    if i > 25 then
                        print("    ...")
                        break
                    end

                    local kv = ent:GetKeyValues()
                    local extra = ""

                    if class == "sky_camera" then
                        extra = " scale=" .. tostring(kv.scale)
                    elseif class == "env_sun" then
                        extra = " size=" .. tostring(kv.size) .. " overlaysize=" .. tostring(kv.overlaysize)
                    end

                    print(("    #%d %s pos=%s ang=%s%s"):format(ent:EntIndex(), ent:GetName() ~= "" and ("'" .. ent:GetName() .. "'") or "",
                        tostring(ent:GetPos()), tostring(ent:GetAngles()), extra))
                end
            end
        end

        local profile = PD.Naval.GetProfile()
        print("  Naval-Profil: " .. (profile and profile.key or "keins"))
    end)
end
