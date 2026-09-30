--[[
    Renderer fuer formatierten Chat.

    Aus den Segmenten von PD.Chat.Format.Parse wird ein Layout: Zeilen aus
    positionierten Stuecken, umbrochen an Wortgrenzen - auch dort, wo innerhalb
    eines Wortes die Farbe wechselt. Das Layout wird je Nachricht, Breite und
    Schriftgroesse gecacht; der geschlossene Chat bricht damit nicht mehr jeden
    Frame neu um.

    Gezeichnet wird ueber die surface-Funktionen statt draw.SimpleText, damit im
    HUD pro Frame keine Color-Tabellen entstehen. Nur animierte Stuecke gehen
    Zeichen fuer Zeichen - alles andere am Stueck.
]]

PD = PD or {}
PD.Chat = PD.Chat or {}
PD.Chat.Render = PD.Chat.Render or {}

local Render = PD.Chat.Render

local FONT_MIN, FONT_MAX = 10, 24
local WHITE = Color(255, 255, 255)
local TIMESTAMP_COLOR = Color(150, 150, 150)

--------------------------------------------------------------------------------
-- Schriften
--------------------------------------------------------------------------------

--[[
    Fett und kursiv nur fuer die Groessen, die der Chat anbietet (10 bis 24).
    Gleiche Familie und gleiche PD.H-Skalierung wie MLIB in _1base/cl_fonts.lua,
    damit fetter und normaler Text dieselbe Hoehe haben.
]]
for n = FONT_MIN, FONT_MAX do
    surface.CreateFont("MLIB_CHAT_B." .. n, {font = "Roboto Regular", size = PD.H(n), weight = 700})
    surface.CreateFont("MLIB_CHAT_I." .. n, {font = "Roboto Regular", size = PD.H(n), weight = 100, italic = true})
    surface.CreateFont("MLIB_CHAT_BI." .. n, {font = "Roboto Regular", size = PD.H(n), weight = 700, italic = true})
end

local function clampSize(size)
    return math.Clamp(math.Round(tonumber(size) or 15), FONT_MIN, FONT_MAX)
end

local function fontFor(size, bold, italic)
    size = clampSize(size)

    if bold and italic then return "MLIB_CHAT_BI." .. size end
    if bold then return "MLIB_CHAT_B." .. size end
    if italic then return "MLIB_CHAT_I." .. size end

    return "MLIB." .. size
end

Render.FontFor = fontFor

function Render.LineHeight(size)
    return PD.H(clampSize(size) + 3)
end

function Render.AnimationsEnabled()
    return not (PD.Chat.Config and PD.Chat.Config.animations == false)
end

--------------------------------------------------------------------------------
-- Messen
--------------------------------------------------------------------------------

local function textWidth(font, text)
    surface.SetFont(font)

    return (surface.GetTextSize(text))
end

local glyphWidths = {}

local function glyphWidth(font, ch)
    local key = font .. "\0" .. ch
    local w = glyphWidths[key]

    if not w then
        surface.SetFont(font)
        w = surface.GetTextSize(ch)
        glyphWidths[key] = w
    end

    return w
end

local function splitChars(text)
    local out = {}

    local ok = pcall(function()
        for _, code in utf8.codes(text) do
            out[#out + 1] = utf8.char(code)
        end
    end)

    if not ok then
        out = {}

        for k = 1, #text do
            out[k] = string.sub(text, k, k)
        end
    end

    return out
end

local function charCount(text)
    return utf8.len(text) or #text
end

--------------------------------------------------------------------------------
-- Icons
--------------------------------------------------------------------------------

local materials = {}

--[[
    Material je Icon, einmal geladen. Ein Icon ohne gueltiges Material liefert
    nil - das Layout setzt dann den Kurznamen als Text, statt ein Schachbrett
    zu zeichnen.
]]
function Render.IconMaterial(name)
    local entry = PD.Chat.Format.Icons[name]

    if not entry then return nil end

    local cached = materials[name]

    if cached == nil then
        local mat = Material(entry.mat, "smooth mips")

        cached = (mat and not mat:IsError()) and mat or false
        materials[name] = cached
    end

    return cached or nil
end

--------------------------------------------------------------------------------
-- Layout
--------------------------------------------------------------------------------

--[[
    Segmente auf eine Breite umbrechen.

    Rueckgabe: {lines = {{pieces, width}, ...}, lineH, height}
    Ein Stueck: {kind, text, font, color, anim, animSpeed, x, w, ci, si}
      ci - Zeichenindex innerhalb der Nachricht (Phase der Animation)
      si - Zeichenindex innerhalb des Segments (Schreibmaschine)

    Ein Wort, das breiter ist als die Zeile - ein Link etwa -, wird Zeichen fuer
    Zeichen gebrochen, statt rechts abgeschnitten zu werden.
]]
function Render.LayoutSegments(segments, maxWidth, size)
    local lineH = Render.LineHeight(size)
    local iconSize = math.floor(lineH * 0.8)
    local lines = {}
    local line = {pieces = {}, width = 0}
    local charIndex = 0

    maxWidth = math.max(maxWidth or 0, PD.W(20))

    local function newLine()
        lines[#lines + 1] = line
        line = {pieces = {}, width = 0}
    end

    local function addText(str, font, seg, w, segStart)
        local last = line.pieces[#line.pieces]

        if last and last.kind == "text" and last.seg == seg then
            last.text = last.text .. str
            last.w = last.w + w
            last.chars = nil
        else
            line.pieces[#line.pieces + 1] = {
                kind = "text", text = str, font = font, color = seg.color or WHITE,
                anim = seg.anim, animSpeed = seg.animSpeed, seg = seg,
                x = line.width, w = w, ci = charIndex, si = charIndex - segStart
            }
        end

        line.width = line.width + w
        charIndex = charIndex + charCount(str)
    end

    for _, seg in ipairs(segments) do
        local segStart = charIndex

        if seg.kind == "icon" and not Render.IconMaterial(seg.name) then
            seg = {kind = "text", text = ":" .. seg.name .. ":", color = WHITE, anim = seg.anim, animSpeed = seg.animSpeed}
        end

        if seg.kind == "icon" then
            local w = iconSize + PD.W(2)

            if line.width > 0 and line.width + w > maxWidth then newLine() end

            line.pieces[#line.pieces + 1] = {
                kind = "icon", name = seg.name, size = iconSize,
                anim = seg.anim, animSpeed = seg.animSpeed,
                x = line.width, w = w, ci = charIndex, si = 0
            }

            line.width = line.width + w
            charIndex = charIndex + 1
        else
            local font = fontFor(size, seg.bold, seg.italic)
            local text = seg.text or ""
            local pos = 1

            while pos <= #text do
                local s, e = string.find(text, "^%s+", pos)
                local isSpace = s ~= nil

                if not isSpace then
                    s, e = string.find(text, "^%S+", pos)
                end

                local run = string.sub(text, s, e)
                pos = e + 1

                if isSpace then
                    if string.find(run, "\n", 1, true) then
                        newLine()
                    elseif line.width > 0 then
                        local w = textWidth(font, run)

                        if line.width + w <= maxWidth then
                            addText(run, font, seg, w, segStart)
                        else
                            -- Leerraum am Umbruch faellt weg.
                            newLine()
                        end
                    end
                else
                    local w = textWidth(font, run)

                    if line.width > 0 and line.width + w > maxWidth then newLine() end

                    if w <= maxWidth then
                        addText(run, font, seg, w, segStart)
                    else
                        for _, ch in ipairs(splitChars(run)) do
                            local cw = glyphWidth(font, ch)

                            if line.width > 0 and line.width + cw > maxWidth then newLine() end

                            addText(ch, font, seg, cw, segStart)
                        end
                    end
                end
            end
        end
    end

    if #line.pieces > 0 or #lines == 0 then
        lines[#lines + 1] = line
    end

    return {lines = lines, lineH = lineH, height = #lines * lineH}
end

--[[
    Segmente einer Nachricht, einmal zerlegt und am Nachrichtenobjekt behalten.
    Nachrichten aus chat.AddText und Engine-Meldungen bringen ihre Segmente
    schon mit und laufen nie durch den Markup-Zerleger.
]]
function Render.Segments(msg)
    if not msg.segments then
        local command = msg.key and PD.Chat.Command and PD.Chat.Command.Flat[msg.key]
        local base = command and command.color or WHITE

        msg.segments = PD.Chat.Format.Parse(msg.text or "", base)
    end

    return msg.segments
end

local layoutCache = setmetatable({}, {__mode = "k"})

function Render.Layout(msg, width, size, showTimestamps)
    size = clampSize(size)
    showTimestamps = showTimestamps and true or false

    local cached = layoutCache[msg]

    if cached and cached.width == width and cached.size == size and cached.ts == showTimestamps then
        return cached.layout
    end

    local segments = Render.Segments(msg)

    if showTimestamps and msg.time then
        local withTime = {{kind = "text", text = os.date("[%H:%M:%S] ", msg.time), color = TIMESTAMP_COLOR}}

        for _, seg in ipairs(segments) do
            withTime[#withTime + 1] = seg
        end

        segments = withTime
    end

    local layout = Render.LayoutSegments(segments, width, size)

    layoutCache[msg] = {width = width, size = size, ts = showTimestamps, layout = layout}

    return layout
end

--------------------------------------------------------------------------------
-- Zeichnen
--------------------------------------------------------------------------------

-- Pseudozufall, der fuer dieselbe Eingabe immer dasselbe liefert.
local function hash(n)
    local x = math.sin(n * 12.9898) * 43758.5453

    return x - math.floor(x)
end

-- HSV -> RGB ohne Color-Tabelle, fuer den Regenbogen je Zeichen je Frame.
local function hsv(h, s, v)
    local c = v * s
    local hp = (h % 360) / 60
    local x = c * (1 - math.abs(hp % 2 - 1))
    local r, g, b = 0, 0, 0

    if hp < 1 then r, g, b = c, x, 0
    elseif hp < 2 then r, g, b = x, c, 0
    elseif hp < 3 then r, g, b = 0, c, x
    elseif hp < 4 then r, g, b = 0, x, c
    elseif hp < 5 then r, g, b = x, 0, c
    else r, g, b = c, 0, x end

    local m = v - c

    return (r + m) * 255, (g + m) * 255, (b + m) * 255
end

--[[
    Wirkung einer Animation fuer ein Zeichen oder Icon.
    Rueckgabe: r, g, b, a, Versatz x, Versatz y, sichtbar
]]
local function animate(anim, speed, ci, si, r, g, b, lineH, now, age)
    local t = now * (speed or 1)
    local a, ox, oy = 255, 0, 0

    if anim == "rainbow" then
        r, g, b = hsv(t * 90 + ci * 14, 0.6, 1)
    elseif anim == "pulse" then
        a = 255 * (0.45 + 0.55 * (0.5 + 0.5 * math.sin(t * 4)))
    elseif anim == "wave" then
        oy = math.sin(t * 6 + ci * 0.55) * lineH * 0.14
    elseif anim == "shake" then
        local step = math.floor(t * 20)

        ox = (hash(step + ci * 7.1) - 0.5) * 2.4
        oy = (hash(step * 1.7 + ci * 3.3) - 0.5) * 2.4
    elseif anim == "glitch" then
        local step = math.floor(t * 9)

        if hash(step + ci * 5.3) > 0.9 then
            ox = (hash(step * 3.1 + ci) - 0.5) * 6

            if hash(step + ci) > 0.5 then
                r, g, b = 90, 230, 255
            else
                r, g, b = 255, 70, 160
            end
        end
    elseif anim == "holo" then
        r = r + (110 - r) * 0.35
        g = g + (190 - g) * 0.35
        b = b + (255 - b) * 0.35
        a = 255 * (0.78 + 0.22 * math.sin(t * 18 + ci * 0.4))

        if hash(math.floor(t * 12)) > 0.94 then a = a * 0.35 end
    elseif anim == "type" then
        if si >= age * 28 * (speed or 1) then
            return r, g, b, 0, 0, 0, false
        end
    end

    return r, g, b, a, ox, oy, true
end

local function drawIcon(p, px, py, lineH, alphaMul, anim, now, age)
    local mat = Render.IconMaterial(p.name)

    if not mat then return end

    local a, ox, oy, visible = 255, 0, 0, true

    if anim then
        local _
        _, _, _, a, ox, oy, visible = animate(anim, p.animSpeed, p.ci, p.si, 255, 255, 255, lineH, now, age)
    end

    if not visible then return end

    surface.SetMaterial(mat)
    surface.SetDrawColor(255, 255, 255, a * alphaMul)
    surface.DrawTexturedRect(px + PD.W(1) + ox, py + (lineH - p.size) * 0.5 + oy, p.size, p.size)
end

local function drawAnimated(p, px, py, lineH, alphaMul, anim, now, age, budget)
    local chars = p.chars

    if not chars then
        chars = splitChars(p.text)
        p.chars = chars
    end

    local c = p.color
    local cx = px

    for k, ch in ipairs(chars) do
        local w = glyphWidth(p.font, ch)

        surface.SetFont(p.font)

        if budget <= 0 then
            surface.SetTextColor(c.r, c.g, c.b, 255 * alphaMul)
            surface.SetTextPos(cx, py)
            surface.DrawText(ch)
        else
            budget = budget - 1

            local r, g, b, a, ox, oy, visible = animate(anim, p.animSpeed, p.ci + k, p.si + k - 1,
                c.r, c.g, c.b, lineH, now, age)

            if visible then
                surface.SetTextColor(r, g, b, a * alphaMul)
                surface.SetTextPos(cx + ox, py + oy)
                surface.DrawText(ch)
            end
        end

        cx = cx + w
    end

    return budget
end

--[[
    Ein Layout zeichnen.

    alphaMul blendet die ganze Nachricht aus (geschlossener Chat). msg liefert
    den Empfangszeitpunkt fuer die Schreibmaschine; ohne msg gilt die Nachricht
    als laengst vollstaendig.
]]
function Render.Draw(layout, x, y, alphaMul, msg)
    alphaMul = alphaMul or 1

    local animationsOn = Render.AnimationsEnabled()
    local now = RealTime()
    local age = (msg and msg.rt) and (now - msg.rt) or math.huge
    local budget = PD.Chat.Format.Limits.MaxAnimChars
    local lineH = layout.lineH

    for li, line in ipairs(layout.lines) do
        local ly = y + (li - 1) * lineH

        for _, p in ipairs(line.pieces) do
            local anim = animationsOn and p.anim or nil

            if p.kind == "icon" then
                drawIcon(p, x + p.x, ly, lineH, alphaMul, anim, now, age)
            elseif anim and budget > 0 then
                budget = drawAnimated(p, x + p.x, ly, lineH, alphaMul, anim, now, age, budget)
            else
                local c = p.color

                surface.SetFont(p.font)
                surface.SetTextColor(c.r, c.g, c.b, 255 * alphaMul)
                surface.SetTextPos(x + p.x, ly)
                surface.DrawText(p.text)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Messung
--------------------------------------------------------------------------------

--[[
    Zeichenzeit fuer 20 animierte Nachrichten, gemittelt ueber 120 Frames.
    Gezeichnet wird ausserhalb des Bildes - die Draw-Aufrufe laufen trotzdem,
    die Zahl ist also ehrlich.
]]
concommand.Add("pd_chatformat_bench", function()
    local samples = {}

    for k = 1, 20 do
        samples[k] = {
            text = "<anim(rainbow)>Regenbogen " .. k .. "<anim> <anim(wave)>Welle mit etwas mehr Text<anim> :shield:",
            key = "looc", time = os.time(), rt = RealTime()
        }
    end

    local width = (PD.Chat.Config.w or PD.W(250)) - PD.W(30)
    local size = PD.Chat.Config.fontSize or 15
    local frames, total = 0, 0

    hook.Add("HUDPaint", "PD.Chat.Bench", function()
        local start = SysTime()

        for _, msg in ipairs(samples) do
            Render.Draw(Render.Layout(msg, width, size, false), -ScrW(), 0, 1, msg)
        end

        total = total + (SysTime() - start)
        frames = frames + 1

        if frames >= 120 then
            hook.Remove("HUDPaint", "PD.Chat.Bench")

            print(string.format("[Chat] 20 animierte Nachrichten: %.3f ms je Frame (Mittel über %d Frames)",
                total / frames * 1000, frames))
        end
    end)
end)
