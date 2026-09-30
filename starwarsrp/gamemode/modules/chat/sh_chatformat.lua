--[[
    Chat-Formatierung: Farben, Schrift, Animationen und Icons.

    Syntax - Start- und End-Tag, der End-Tag ist der Name ohne Parameter:

        Hallo <color(red)> wie geht es dir <color>
        Hallo <color(255,0,0)> wie geht es dir <color>
        <color(#40a0ff)>Hex<color>          <color(#f80)>kurzes Hex<color>
        <b>fett<b>   <i>kursiv<i>           </color>, </b> ... schliessen ebenfalls
        <anim(wave)>Welle<anim>             <anim(wave,2)>doppelt so schnell<anim>
        <icon(shield)>  oder  :shield:      Icons haben kein End-Tag
        \<  \:  \\                          Zeichen woertlich schreiben

    Unbekannte Tags bleiben woertlich stehen, damit "<3" oder "a<b" nichts
    zerbrechen. Offene Tags schliessen sich am Ende der Nachricht von selbst.

    Die Datei laeuft auf Server und Client. Der Server bereinigt jede Nachricht
    mit Sanitize, bevor sie verschickt wird; der Client zerlegt sie mit Parse in
    Segmente. Beide benutzen denselben Zerleger, dieselben Registries und
    dieselben Grenzen - was die Vorschau beim Tippen anzeigt, kommt auch so an.
]]

PD = PD or {}
PD.Chat = PD.Chat or {}
PD.Chat.Format = PD.Chat.Format or {}

local Format = PD.Chat.Format

--------------------------------------------------------------------------------
-- Grenzen
--------------------------------------------------------------------------------

Format.Limits = {
    MaxLen = 500,         -- Zeichen Rohtext je Nachricht
    MaxTags = 24,         -- geoeffnete Tags je Nachricht
    MaxDepth = 6,         -- gleichzeitig offene Farben und Animationen
    MaxIcons = 6,
    MaxAnimChars = 160,   -- darueber zeichnet der Client statisch (Leistung)
    MinLuminance = 60     -- 0..255; dunklere Farben werden aufgehellt
}

--------------------------------------------------------------------------------
-- Registries
--------------------------------------------------------------------------------

-- Reihenfolge fuer die Hilfe und die Vervollstaendigung.
Format.PaletteOrder = {
    "red", "orange", "yellow", "gold", "green", "cyan", "blue",
    "republic", "jedi", "holo", "purple", "pink", "sith", "white", "grey"
}

Format.Palette = {
    red      = Color(230, 60, 60),
    orange   = Color(240, 150, 50),
    yellow   = Color(240, 210, 60),
    gold     = Color(225, 180, 70),
    green    = Color(80, 200, 90),
    cyan     = Color(80, 210, 230),
    blue     = Color(70, 130, 240),
    republic = Color(70, 135, 225),   -- 501st-Blau, fuer dunklen Grund aufgehellt
    jedi     = Color(90, 160, 255),
    holo     = Color(110, 190, 255),
    purple   = Color(170, 110, 230),
    pink     = Color(235, 120, 180),
    sith     = Color(220, 40, 40),
    white    = Color(255, 255, 255),
    grey     = Color(170, 170, 170)
}

-- Deutsche Namen zeigen auf dieselben Werte.
local PALETTE_ALIASES = {
    rot = "red", gruen = "green", ["grün"] = "green", blau = "blue",
    gelb = "yellow", weiss = "white", ["weiß"] = "white", grau = "grey",
    gray = "grey", lila = "purple", rosa = "pink", tuerkis = "cyan",
    ["türkis"] = "cyan", republik = "republic"
}

for alias, target in pairs(PALETTE_ALIASES) do
    Format.Palette[alias] = Format.Palette[target]
end

Format.AnimationOrder = {"rainbow", "pulse", "wave", "shake", "glitch", "holo", "type"}

Format.Animations = {}

for _, name in ipairs(Format.AnimationOrder) do
    Format.Animations[name] = true
end

Format.AnimationAliases = {
    regenbogen = "rainbow", puls = "pulse", welle = "wave", zittern = "shake",
    stoerung = "glitch", tippen = "type", schreibmaschine = "type"
}

--[[
    Icons. Die Silkicons unter icon16/ liefert GMod selbst aus - jeder Client
    hat sie. Eigene Icons kommen spaeter mit genau einem Aufruf dazu, sobald ein
    Workshop-Addon die Bilddateien verteilt:

        PD.Chat.Format.RegisterIcon("republic", "pd_chat/republic.png")
]]
Format.Icons = Format.Icons or {}
Format.IconOrder = Format.IconOrder or {}

function Format.RegisterIcon(name, path)
    name = string.lower(name)

    if not Format.Icons[name] then
        table.insert(Format.IconOrder, name)
    end

    Format.Icons[name] = {mat = path}
end

local SILKICONS = {
    {"shield", "shield"}, {"star", "star"}, {"medal", "medal_gold_1"},
    {"award", "award_star_gold_1"}, {"rosette", "rosette"}, {"heart", "heart"},
    {"lightning", "lightning"}, {"bomb", "bomb"}, {"error", "error"},
    {"warning", "exclamation"}, {"info", "information"}, {"accept", "accept"},
    {"tick", "tick"}, {"cross", "cross"}, {"bell", "bell"}, {"clock", "clock"},
    {"lock", "lock"}, {"key", "key"}, {"user", "user"}, {"group", "group"},
    {"comment", "comment"}, {"flag", "flag_red"}, {"wrench", "wrench"},
    {"cog", "cog"}, {"map", "map"}, {"compass", "compass"}, {"world", "world"},
    {"house", "house"}, {"sound", "sound"}, {"music", "music"}, {"eye", "eye"},
    {"bug", "bug"}, {"coins", "coins"}, {"car", "car"},
    {"thumbup", "thumb_up"}, {"thumbdown", "thumb_down"},
    {"smile", "emoticon_smile"}, {"grin", "emoticon_grin"},
    {"wink", "emoticon_wink"}, {"sad", "emoticon_unhappy"}
}

for _, entry in ipairs(SILKICONS) do
    Format.RegisterIcon(entry[1], "icon16/" .. entry[2] .. ".png")
end

local KNOWN_TAGS = {color = true, b = true, i = true, anim = true, icon = true}

--------------------------------------------------------------------------------
-- Hilfsfunktionen
--------------------------------------------------------------------------------

--[[
    Auf eine Anzahl Zeichen kuerzen, ohne ein Umlaut-Byte zu zerschneiden.
    Rueckgabe: gekuerzter Text, ob gekuerzt wurde.
]]
local function truncate(text, maxChars)
    local len = utf8.len(text)

    if not len then
        -- Ungueltiges UTF-8: grob nach Bytes, damit trotzdem eine Grenze gilt.
        if #text > maxChars * 4 then
            return string.sub(text, 1, maxChars * 4), true
        end

        return text, false
    end

    if len <= maxChars then return text, false end

    local byte = utf8.offset(text, maxChars + 1)

    return string.sub(text, 1, (byte or #text + 1) - 1), true
end

Format.Truncate = truncate

--[[
    Zu dunkle Farben aufhellen statt ablehnen. Der Chat liegt auf dunklem,
    halbdurchsichtigem Grund; schwarze Schrift waere unsichtbar. Gemischt wird
    Richtung Weiss, genau so weit, bis die Mindesthelligkeit erreicht ist - der
    Farbton bleibt erkennbar.
]]
function Format.Readable(col)
    local r, g, b = col.r, col.g, col.b
    local lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    local min = Format.Limits.MinLuminance

    if lum >= min then return Color(r, g, b, 255) end

    local t = (min - lum) / (255 - lum)

    return Color(
        math.Round(r + (255 - r) * t),
        math.Round(g + (255 - g) * t),
        math.Round(b + (255 - b) * t),
        255
    )
end

local function parseColor(arg)
    arg = string.lower(string.Trim(arg or ""))

    if arg == "" then return nil end

    local named = Format.Palette[arg]

    if named then return Color(named.r, named.g, named.b) end

    local hex = string.match(arg, "^#(%x+)$")

    if hex then
        if #hex == 3 then
            local r, g, b = string.match(hex, "^(%x)(%x)(%x)$")

            return Color(tonumber(r .. r, 16), tonumber(g .. g, 16), tonumber(b .. b, 16))
        elseif #hex == 6 then
            return Color(
                tonumber(string.sub(hex, 1, 2), 16),
                tonumber(string.sub(hex, 3, 4), 16),
                tonumber(string.sub(hex, 5, 6), 16)
            )
        end

        return nil
    end

    local r, g, b = string.match(arg, "^(%d+)%s*,%s*(%d+)%s*,%s*(%d+)$")

    if r then
        r, g, b = tonumber(r), tonumber(g), tonumber(b)

        if r <= 255 and g <= 255 and b <= 255 then
            return Color(r, g, b)
        end
    end

    return nil
end

local function parseAnim(arg)
    arg = string.lower(arg or "")

    local name, speed = string.match(arg, "^%s*(%a+)%s*,%s*([%d%.]+)%s*$")

    if not name then
        name = string.match(arg, "^%s*(%a+)%s*$")
    end

    if not name then return nil end

    name = Format.AnimationAliases[name] or name

    if not Format.Animations[name] then return nil end

    return name, math.Clamp(tonumber(speed) or 1, 0.25, 4)
end

local function colorTag(c)
    return string.format("<color(%d,%d,%d)>", c.r, c.g, c.b)
end

local function animTag(name, speed)
    if speed == 1 then return "<anim(" .. name .. ")>" end

    return string.format("<anim(%s,%g)>", name, speed)
end

-- Fuer Fehlermeldungen: Nutzereingaben kurz halten.
local function short(text)
    text = tostring(text or "")

    if #text > 20 then return string.sub(text, 1, 20) .. "..." end

    return text
end

--------------------------------------------------------------------------------
-- Zerlegen
--------------------------------------------------------------------------------

--[[
    Text in Tokens zerlegen: Text, Tags, Icon-Kurzformen.

    Gearbeitet wird bytweise; Tags bestehen nur aus ASCII, Umlaute landen
    unangetastet im Text. Ein "<" ohne gueltige Tag-Form ist einfach Text.
]]
local function tokenize(text)
    local tokens = {}
    local buffer = {}
    local i, n = 1, #text

    local function flush()
        if #buffer > 0 then
            tokens[#tokens + 1] = {t = "text", s = table.concat(buffer)}
            buffer = {}
        end
    end

    while i <= n do
        local c = string.sub(text, i, i)

        if c == "\\" then
            local nextChar = string.sub(text, i + 1, i + 1)

            if nextChar == "<" or nextChar == ":" or nextChar == "\\" then
                buffer[#buffer + 1] = nextChar
                i = i + 2
            else
                buffer[#buffer + 1] = c
                i = i + 1
            end
        elseif c == "<" then
            local name, arg, closing, stop

            local s, e, nm = string.find(text, "^</(%a+)>", i)

            if s then
                name, closing, stop = nm, true, e
            else
                local ar
                s, e, nm, ar = string.find(text, "^<(%a+)%(([^<>%(%)]*)%)>", i)

                if s then
                    name, arg, stop = nm, ar, e
                else
                    s, e, nm = string.find(text, "^<(%a+)>", i)

                    if s then name, stop = nm, e end
                end
            end

            if name and #name <= 12 and (not arg or #arg <= 40) then
                flush()

                tokens[#tokens + 1] = {
                    t = "tag",
                    name = string.lower(name),
                    arg = arg,
                    closing = closing or false,
                    raw = string.sub(text, i, stop)
                }

                i = stop + 1
            else
                buffer[#buffer + 1] = c
                i = i + 1
            end
        elseif c == ":" then
            local s, e, nm = string.find(text, "^:([%w_]+):", i)

            if s and Format.Icons[string.lower(nm)] then
                flush()

                tokens[#tokens + 1] = {t = "icon", name = string.lower(nm), raw = string.sub(text, i, e)}

                i = e + 1
            else
                buffer[#buffer + 1] = c
                i = i + 1
            end
        else
            local s, e = string.find(text, "^[^\\<:]+", i)

            buffer[#buffer + 1] = string.sub(text, s, e)
            i = e + 1
        end
    end

    flush()

    return tokens
end

Format.Tokenize = tokenize

--[[
    Tokens auswerten.

    Rueckgabe:
      segments  - Liste {kind="text", text, color, bold, italic, anim, animSpeed}
                  oder {kind="icon", name, anim, animSpeed}
      problems  - lesbare Hinweise fuer die Vorschau, ohne Doppelungen
      decisions - je Token: kanonischer Tag-Text, "drop" oder "literal"
      info      - {markup = Anzahl Nicht-Text-Tokens}

    Ein verworfener Oeffner (unbekannte Farbe, Grenze erreicht) wird trotzdem
    als "Phantom" auf den Stapel gelegt. Sonst wuerde sein End-Tag den
    vorherigen, gueltigen Tag schliessen.
]]
local function interpret(tokens, baseColor, useLimits)
    local L = Format.Limits
    local segments, problems, decisions = {}, {}, {}
    local seen = {}

    local function problem(text)
        if not seen[text] then
            seen[text] = true
            problems[#problems + 1] = text
        end
    end

    local colorStack, animStack = {}, {}
    local bold, italic = false, false
    local tagCount, iconCount, depth, markup = 0, 0, 0, 0

    local function topColor()
        for k = #colorStack, 1, -1 do
            if not colorStack[k].phantom then return colorStack[k].color end
        end

        return baseColor
    end

    local function topAnim()
        for k = #animStack, 1, -1 do
            if not animStack[k].phantom then return animStack[k] end
        end

        return nil
    end

    local function pushText(s)
        if s == "" then return end

        local col = topColor()
        local anim = topAnim()
        local animName = anim and anim.name
        local animSpeed = anim and anim.speed
        local last = segments[#segments]

        if last and last.kind == "text" and last.color == col and last.bold == bold
            and last.italic == italic and last.anim == animName and last.animSpeed == animSpeed then
            last.text = last.text .. s
        else
            segments[#segments + 1] = {
                kind = "text", text = s, color = col, bold = bold, italic = italic,
                anim = animName, animSpeed = animSpeed
            }
        end
    end

    local function pushIcon(name)
        local anim = topAnim()

        segments[#segments + 1] = {
            kind = "icon", name = name, anim = anim and anim.name, animSpeed = anim and anim.speed
        }
    end

    local tooManyTags = "Zu viele Tags (höchstens " .. L.MaxTags .. ")"
    local tooDeep = "Zu tief verschachtelt (höchstens " .. L.MaxDepth .. ")"
    local tooManyIcons = "Zu viele Icons (höchstens " .. L.MaxIcons .. ")"

    for index, tok in ipairs(tokens) do
        if tok.t == "text" then
            pushText(tok.s)
        elseif tok.t == "icon" then
            markup = markup + 1

            if useLimits and iconCount >= L.MaxIcons then
                problem(tooManyIcons)
                decisions[index] = "literal"
                pushText(tok.raw)
            else
                iconCount = iconCount + 1
                pushIcon(tok.name)
                decisions[index] = ":" .. tok.name .. ":"
            end
        elseif tok.t == "tag" then
            local name = tok.name

            if KNOWN_TAGS[name] then markup = markup + 1 end

            if name == "color" or name == "anim" then
                local stack = name == "color" and colorStack or animStack

                if tok.closing or tok.arg == nil then
                    local entry = table.remove(stack)

                    if not entry then
                        problem("Schließt nichts: <" .. name .. ">")
                        decisions[index] = "drop"
                    elseif entry.phantom then
                        decisions[index] = "drop"
                    else
                        depth = depth - 1
                        decisions[index] = "<" .. name .. ">"
                    end
                else
                    local entry = {phantom = true}
                    local ok = true

                    if name == "color" then
                        local c = parseColor(tok.arg)

                        if c then
                            entry.color = Format.Readable(c)
                        else
                            problem("Unbekannte Farbe: " .. short(tok.arg))
                            ok = false
                        end
                    else
                        local animName, speed = parseAnim(tok.arg)

                        if animName then
                            entry.name, entry.speed = animName, speed
                        else
                            problem("Unbekannte Animation: " .. short(tok.arg))
                            ok = false
                        end
                    end

                    if ok and useLimits then
                        if tagCount >= L.MaxTags then
                            problem(tooManyTags)
                            ok = false
                        elseif depth >= L.MaxDepth then
                            problem(tooDeep)
                            ok = false
                        end
                    end

                    if ok then
                        entry.phantom = false
                        tagCount = tagCount + 1
                        depth = depth + 1

                        decisions[index] = name == "color"
                            and colorTag(entry.color)
                            or animTag(entry.name, entry.speed)
                    else
                        decisions[index] = "drop"
                    end

                    stack[#stack + 1] = entry
                end
            elseif name == "b" or name == "i" then
                -- Nicht als "name == b and bold or italic": ist bold false,
                -- lieferte das italic zurueck.
                local current

                if name == "b" then current = bold else current = italic end

                local wanted = not current

                if tok.closing then wanted = false end

                if wanted == current then
                    problem("Schließt nichts: </" .. name .. ">")
                    decisions[index] = "drop"
                elseif wanted and useLimits and tagCount >= L.MaxTags then
                    problem(tooManyTags)
                    decisions[index] = "drop"
                else
                    if wanted then tagCount = tagCount + 1 end

                    if name == "b" then bold = wanted else italic = wanted end

                    decisions[index] = tok.closing and ("</" .. name .. ">") or ("<" .. name .. ">")
                end
            elseif name == "icon" then
                local key = tok.arg and string.lower(string.Trim(tok.arg)) or ""

                if not tok.closing and Format.Icons[key] then
                    if useLimits and iconCount >= L.MaxIcons then
                        problem(tooManyIcons)
                        decisions[index] = "literal"
                        pushText(tok.raw)
                    else
                        iconCount = iconCount + 1
                        pushIcon(key)
                        decisions[index] = "<icon(" .. key .. ")>"
                    end
                else
                    if key ~= "" then problem("Unbekanntes Icon: " .. short(key)) end

                    decisions[index] = "literal"
                    pushText(tok.raw)
                end
            else
                -- Kein bekannter Tag: bleibt Text.
                decisions[index] = "literal"
                pushText(tok.raw)
            end
        end
    end

    for _, entry in ipairs(colorStack) do
        if not entry.phantom then
            problem("Nicht geschlossen: <color>")
            break
        end
    end

    for _, entry in ipairs(animStack) do
        if not entry.phantom then
            problem("Nicht geschlossen: <anim>")
            break
        end
    end

    if bold then problem("Nicht geschlossen: <b>") end
    if italic then problem("Nicht geschlossen: <i>") end

    return segments, problems, decisions, {markup = markup}
end

--------------------------------------------------------------------------------
-- Oeffentliche Funktionen
--------------------------------------------------------------------------------

--[[
    Text in Segmente zerlegen.

    opts.limits = true wendet dieselben Grenzen an wie der Server - fuer die
    Vorschau beim Tippen. Empfangene Nachrichten hat der Server schon bereinigt,
    dort bleibt es aus.
]]
function Format.Parse(text, baseColor, opts)
    opts = opts or {}
    text = tostring(text or "")
    baseColor = baseColor or Color(255, 255, 255)

    local cut = false

    if opts.limits then
        text, cut = truncate(text, Format.Limits.MaxLen)
    end

    local segments, problems, _, info = interpret(tokenize(text), baseColor, opts.limits)

    if cut then
        table.insert(problems, 1, "Zu lang - wird nach " .. Format.Limits.MaxLen .. " Zeichen abgeschnitten")
    end

    return segments, problems, info
end

--[[
    Tags woertlich machen. Fuer alles, was nicht formatiert werden darf -
    vor allem Spielernamen: ein Charakter namens "<color(red)>" soll nicht jede
    Zeile einfaerben, in der er steht.
]]
function Format.Escape(text)
    text = string.gsub(tostring(text or ""), "%c", " ")
    text = string.gsub(text, "\\", "\\\\")
    text = string.gsub(text, "<", "\\<")
    text = string.gsub(text, ":", "\\:")

    return text
end

local function escapeText(text)
    text = string.gsub(text, "\\", "\\\\")
    text = string.gsub(text, "<", "\\<")
    text = string.gsub(text, ":", "\\:")

    return text
end

--[[
    Eine Spielernachricht bereinigen, bevor der Server sie verschickt.

    Ergebnis ist wieder Markup - aber nur noch aus dem, was der Zerleger
    verstanden und zugelassen hat: Farben stehen als aufgehelltes RGB, Tags
    ueber den Grenzen sind entfernt, unbekannte Tags und normaler Text sind
    maskiert. Der Client zerlegt damit exakt, was hier entschieden wurde.
]]
function Format.Sanitize(text)
    text = string.gsub(tostring(text or ""), "%c", " ")
    text = truncate(text, Format.Limits.MaxLen)

    local tokens = tokenize(text)
    local _, _, decisions = interpret(tokens, nil, true)
    local out = {}

    for index, tok in ipairs(tokens) do
        local decision = decisions[index]

        if tok.t == "text" then
            out[#out + 1] = escapeText(tok.s)
        elseif decision == "literal" then
            out[#out + 1] = escapeText(tok.raw)
        elseif decision and decision ~= "drop" then
            out[#out + 1] = decision
        end
    end

    return table.concat(out)
end

-- Klartext ohne Tags, fuer Konsole und Logs.
function Format.Strip(text)
    local out = {}

    for _, tok in ipairs(tokenize(tostring(text or ""))) do
        if tok.t == "text" then
            out[#out + 1] = tok.s
        elseif tok.t == "icon" then
            out[#out + 1] = ":" .. tok.name .. ":"
        elseif tok.t == "tag" then
            if tok.name == "icon" and tok.arg then
                out[#out + 1] = ":" .. string.lower(tok.arg) .. ":"
            elseif not KNOWN_TAGS[tok.name] then
                out[#out + 1] = tok.raw
            end
        end
    end

    return table.concat(out)
end

--[[
    Eine Chatzeile zusammensetzen: "[TAG] Name: Text" oder "[TAG] Text".
    Der Name wird maskiert, der Text bereinigt. Die Befehle in sh_chat.lua
    rufen das auf dem Server auf.
]]
function PD.Chat.Compose(tag, ply, text)
    local head = "[" .. tostring(tag) .. "] "
    local body = Format.Sanitize(tostring(text or ""))

    if IsValid(ply) then
        return head .. Format.Escape(ply:Nick()) .. ": " .. body
    end

    return head .. body
end

--------------------------------------------------------------------------------
-- Diagnose
--------------------------------------------------------------------------------

--[[
    Laeuft auch in der Serverkonsole - der Zerleger ist dort genauso vorhanden.
    Im Client prueft der Befehl zusaetzlich, ob jedes Icon ein Material hat.
]]
concommand.Add("pd_chatformat_test", function(ply)
    if SERVER and IsValid(ply) then return end

    local samples = {
        "Hallo <color(255,0,0)> wie geht es dir <color>",
        "Hallo <color(red)> wie geht es dir <color>",
        "<color(#40a0ff)>Hex<color> und <color(#f80)>kurz<color>",
        "<b><color(gold)>Captain<color><b> Rex",
        "Offen <color(red)> bleibt offen",
        "Wörtlich \\<color(red)> bleibt Text",
        "Ich <3 die Republik, a<b gilt",
        ":shield: Schild und :gibtsnicht:",
        "<anim(wave,2)>Welle<anim> <anim(rainbow)>Regenbogen<anim>",
        "<color(0,0,0)>Schwarz<color>",
        "<color(zzz)>kaputt<color> weiter"
    }

    for _, sample in ipairs(samples) do
        print("")
        print("[Chat] Eingabe:    " .. sample)
        print("[Chat] Bereinigt:  " .. Format.Sanitize(sample))

        local segments, problems = Format.Parse(sample, Color(255, 255, 255), {limits = true})

        for _, seg in ipairs(segments) do
            if seg.kind == "icon" then
                print(string.format("         Icon  %-12s anim=%s", seg.name, tostring(seg.anim)))
            else
                local c = seg.color

                print(string.format("         Text  %-30s rgb=%d,%d,%d b=%s i=%s anim=%s",
                    "\"" .. seg.text .. "\"", c.r, c.g, c.b,
                    tostring(seg.bold), tostring(seg.italic), tostring(seg.anim)))
            end
        end

        for _, text in ipairs(problems) do
            print("         Hinweis: " .. text)
        end
    end

    print("")
    print("[Chat] Name maskiert: " .. Format.Escape("<color(red)>Rex:boss"))

    if CLIENT then
        local missing = {}

        for _, name in ipairs(Format.IconOrder) do
            local mat = Material(Format.Icons[name].mat)

            if not mat or mat:IsError() then
                missing[#missing + 1] = name .. " (" .. Format.Icons[name].mat .. ")"
            end
        end

        if #missing == 0 then
            print("[Chat] Alle " .. #Format.IconOrder .. " Icons haben ein Material.")
        else
            print("[Chat] Icons ohne Material: " .. table.concat(missing, ", "))
        end
    end
end)
