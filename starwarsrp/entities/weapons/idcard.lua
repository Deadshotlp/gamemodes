
if SERVER then
    AddCSLuaFile()
end

SWEP.PrintName = 'ID Card'
SWEP.Author = 'PD - Gamemode'
SWEP.Purpose = ''
SWEP.Spawnable = true
SWEP.Category = 'PD - Gamemode'
SWEP.ViewModel = 'models/weapons/c_medkit.mdl'
SWEP.WorldModel = ''
SWEP.AnimPrefix = 'rpg'
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = 'none'
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = 'none'
SWEP.DrawCrosshair = false
SWEP.Slot = 5

function SWEP:Initialize()
    self:SetHoldType('normal')
    self.range = 100

    self.ownerPos = Vector(0, 0, 0)
    self.ownerAim = Vector(0, 0, 0)
end

function SWEP:Think()
end

local showCard = false
local click = false

function SWEP:PrimaryAttack()
    if click then return end
    click = true

    showCard = not showCard

    local owner = self:GetOwner()

    if IsValid(owner) and SERVER then
        local tr = owner:GetEyeTrace()

        -- Wer angeschaut wird, bekommt den Ausweis eingeblendet.
        if IsValid(tr.Entity) and tr.Entity:IsPlayer() then
            net.Start("PD.IDCards:CheckID")
                net.WriteEntity(owner)
            net.Send(tr.Entity)
        end
    end

    timer.Simple(0.2, function()
        click = false
    end)
end

function SWEP:SecondaryAttack()
end

if SERVER then
    return
end

--[[
    Der Dienstausweis als HUD-Element.

    Frueher lag der Ausweis als Bild auf Imgur und wurde ueber PD.DrawImgur
    gezeichnet. Beides gibt es nicht mehr: das Bild ist verschwunden und
    PD.DrawImgur ist im Gamemode nirgends definiert. Deshalb wird der Ausweis
    hier komplett aus surface- und draw-Aufrufen gebaut - nichts haengt mehr an
    einer fremden Quelle.

    Die Zeichenfunktion haengt unter PD.IDCards.DrawCard, damit das Modul
    id_cards denselben Ausweis benutzen kann, wenn ihn jemand vorzeigt.
]]

PD = PD or {}
PD.IDCards = PD.IDCards or {}

-- Masse in der 1920x1080-Referenz, siehe PD.W und PD.H.
local CARD_W, CARD_H = 300, 170

-- Aufschrift der Kopfleiste. Hier aendern, wenn die Fraktion wechselt.
local CARD_TITLE = "GALAKTISCHE REPUBLIK"

--[[
    Die Kopfleiste hat die Farbe des Jobs, und die kann alles sein - bei Jobs
    ohne eigene Farbe ist sie weiss. Heller Grund braucht dunkle Schrift, sonst
    steht der Titel unsichtbar auf sich selbst.
]]
local function headerText(accent)
    local luminance = (accent.r * 0.299 + accent.g * 0.587 + accent.b * 0.114) / 255

    if luminance > 0.6 then
        return Color(15, 15, 20)
    end

    return PD.Theme.Colors.TextHighlight
end

-- Der eigene Ausweis sitzt tiefer als der vorgezeigte, damit sich beide nie
-- ueberdecken, wenn man seinen eigenen zeigt und gleichzeitig einen sieht.
local ANCHOR_OWN = 0.75

--[[
    Farben kommen ueber net.WriteTable herein und verlieren dabei ihre
    Metatabelle - IsColor sagt dann nein, obwohl r, g und b da sind.
]]
local function toColor(value, fallback)
    if IsColor(value) then return value end

    if istable(value) and value.r and value.g and value.b then
        return Color(value.r, value.g, value.b, value.a or 255)
    end

    return fallback
end

--[[
    Text kuerzen, damit lange Einheiten- oder Dienstgradnamen nicht ueber den
    Rand des Ausweises hinauslaufen.
]]
local function fit(text, font, maxWidth)
    surface.SetFont(font)

    if (surface.GetTextSize(text)) <= maxWidth then
        return text
    end

    while string.len(text) > 1 do
        text = string.sub(text, 1, string.len(text) - 1)

        if (surface.GetTextSize(text .. "...")) <= maxWidth then
            return text .. "..."
        end
    end

    return text
end

-- rpname steht als "00-0000 Vorname Nachname" im Netzwerk, siehe sv_char.lua.
local function cardData(ply)
    local jobID, jobTbl = ply:GetJob()

    if not istable(jobTbl) then
        jobTbl = {}
    end

    local rpName = ply:GetNWString("rpname", "")

    if rpName == "" then
        rpName = ply:Nick()
    end

    local id, name = string.match(rpName, "^(%S+)%s+(.+)$")

    return {
        id = id or "--------",
        name = name or rpName,
        unit = jobTbl.unit or "Ohne Einheit",
        rank = jobTbl.name or jobID or "Unbekannt",
        color = toColor(jobTbl.color, PD.Theme.Colors.AccentRed)
    }
end

--[[
    Zeichnet den Dienstausweis eines Spielers.

        PD.IDCards.DrawCard(x, y, breite, hoehe, spieler)

    Alle Masse sind Pixel, damit der Ausweis auch in einem Panel benutzt werden
    kann und nicht nur im HUD.
]]
function PD.IDCards.DrawCard(x, y, w, h, ply)
    if not PD.Theme then return end
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local colors = PD.Theme.Colors
    local data = cardData(ply)
    local accent = data.color

    local headH = h * 0.2
    local pad = w * 0.06
    local inner = w - pad * 2

    draw.RoundedBox(0, x, y, w, h, colors.Background)

    -- Kopfleiste in der Farbe des Jobs
    surface.SetDrawColor(accent)
    surface.DrawRect(x, y, w, headH)

    draw.SimpleText(fit(CARD_TITLE, "MLIB.14", inner), "MLIB.14", x + w / 2, y + headH / 2,
        headerText(accent), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- Rahmen und Ecken wie im uebrigen UI
    surface.SetDrawColor(accent)
    surface.DrawOutlinedRect(x, y, w, h, PD.BorderWidth.Normal)
    PD.DrawCorners(x, y, w, h, colors.AccentGray)

    -- Zwei Zeilen unterhalb der Kopfleiste, gleichmaessig im Rest verteilt.
    local bodyY = y + headH
    local bodyH = h - headH
    local valueOffset = bodyH * 0.16

    local function field(fx, fy, label, value, maxWidth, align)
        draw.SimpleText(label, "MLIB.11", fx, fy, colors.TextMuted, align, TEXT_ALIGN_TOP)
        draw.SimpleText(fit(value, "MLIB.16", maxWidth), "MLIB.16", fx, fy + valueOffset,
            colors.Text, align, TEXT_ALIGN_TOP)
    end

    local left = x + pad
    local right = x + w - pad

    -- Die Kennung hat feste Laenge (00-0000) und steht deshalb in einer eigenen
    -- schmalen Spalte links, der Name bekommt den Rest der Zeile.
    local idWidth = inner * 0.34
    local nameX = left + inner * 0.38

    local row1 = bodyY + bodyH * 0.16
    local row2 = bodyY + bodyH * 0.58
    local half = inner * 0.46

    field(left, row1, "KENNUNG", data.id, idWidth, TEXT_ALIGN_LEFT)
    field(nameX, row1, "NAME", data.name, x + w - pad - nameX, TEXT_ALIGN_LEFT)

    field(left, row2, "EINHEIT", data.unit, half, TEXT_ALIGN_LEFT)
    field(right, row2, "DIENSTGRAD", data.rank, half, TEXT_ALIGN_RIGHT)
end

function SWEP:DrawHUD()
    if not PD.Theme then return end

    local owner = self:GetOwner()
    if not IsValid(owner) then return end
    if IsValid(owner:GetVehicle()) then return end

    draw.SimpleText("ID Karte mit Linksklick zeigen", "MLIB.20", ScrW() / 2,
        ScrH() - PD.H(130), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    if not showCard then return end

    local w, h = PD.W(CARD_W), PD.H(CARD_H)

    PD.IDCards.DrawCard(ScrW() - w - PD.W(20), ScrH() * ANCHOR_OWN - h / 2, w, h, owner)
end

function SWEP:PreDrawViewModel()
    return true
end
