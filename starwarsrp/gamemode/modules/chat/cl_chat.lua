PD.Chat = PD.Chat or {}
PD.Chat.MSG = PD.Chat.MSG or {}

PD.Chat.Config = PD.Chat.Config or {
    MaxMessages = 50,
    y = ScrH() - PD.H(350),
    x = PD.W(50),
    w = PD.W(250),
    h = PD.H(300),
    showTimestamps = false,
    showInThirdPerson = false,
    fontSize = 15,
    animations = true
}

PD.Chat.ConfigFile = "pd_chat_config"

PD.Chat.RecentMessages = PD.Chat.RecentMessages or {}

local PROBLEM_COLOR = Color(235, 90, 90)

local function chatFontSize()
    return math.Clamp(math.Round(PD.Chat.Config.fontSize or 15), 10, 24)
end

local function load_chat_config()
    if not file.IsDir("modules/" .. PD.Chat.ConfigFile, "DATA") then
        file.CreateDir("modules/" .. PD.Chat.ConfigFile)
    end

    if file.Exists("modules/" .. PD.Chat.ConfigFile .. "/" .. "config" .. ".json", "DATA") then
        PD.Chat.Config = util.JSONToTable(file.Read("modules/" .. PD.Chat.ConfigFile .. "/" .. "config" .. ".json", "DATA"))
    end
end

local function save_chat_config()
    if not file.IsDir("modules/" .. PD.Chat.ConfigFile, "DATA") then
        file.CreateDir("modules/" .. PD.Chat.ConfigFile)
    end

    file.Write("modules/" .. PD.Chat.ConfigFile .. "/" .. "config" .. ".json", util.TableToJSON(PD.Chat.Config, true))
end

--[[
    Ans Ende des Verlaufs springen.

    ScrollToChild direkt nach dem Anlegen eines Labels fand immer Position 0:
    angedockte Kinder bekommen ihre Lage erst beim naechsten Layout. Deshalb
    sprang das Fenster beim Oeffnen nach oben statt nach unten.

    Hier wird gewartet und zweimal nachgezogen - erst strecken sich die Zeilen
    auf ihre Hoehe, dann kennt die Leinwand ihre Gesamthoehe. SetScroll klemmt
    selbst auf das Maximum, math.huge landet also genau am Ende.
]]
local function scrollToBottom(scrollPanel)
    local function step()
        if not IsValid(scrollPanel) then return end

        scrollPanel:InvalidateLayout(true)
        scrollPanel:GetVBar():SetScroll(math.huge)
    end

    timer.Simple(0, step)
    timer.Simple(0.05, step)
end

--[[
    Chatverlauf im geoeffneten Fenster.

    Jede Nachricht ist ein eigenes Panel, das ueber PD.Chat.Render mehrfarbig,
    mit Icons und Animationen zeichnet. Umbrochen wird in PerformLayout an der
    Breite, die das Panel tatsaechlich bekommt - nicht an einer geschaetzten.
]]
local function populateChat(scrollPanel)
    scrollPanel:Clear()

    local size = chatFontSize()
    local showTimestamps = PD.Chat.Config.showTimestamps

    for _, msg in ipairs(PD.Chat.MSG) do
        local line = scrollPanel:Add("DPanel")
        line:Dock(TOP)
        line:DockMargin(PD.W(5), PD.H(1), PD.W(5), PD.H(1))
        line:SetTall(PD.Chat.Render.LineHeight(size))

        -- Sonst faengt die Zeile das Mausrad ab und die Liste scrollt nicht.
        line:SetMouseInputEnabled(false)

        line.PerformLayout = function(self, w)
            if w < PD.W(20) then return end

            local layout = PD.Chat.Render.Layout(msg, w, size, showTimestamps)

            if self:GetTall() ~= layout.height then
                self:SetTall(layout.height)
            end
        end

        line.Paint = function(self, w)
            if w < PD.W(20) then return end

            PD.Chat.Render.Draw(PD.Chat.Render.Layout(msg, w, size, showTimestamps), 0, 0, 1, msg)
        end
    end

    scrollToBottom(scrollPanel)
end

--------------------------------------------------------------------------------
-- Nachrichten annehmen
--------------------------------------------------------------------------------

local function pushMessage(entry)
    entry.time = os.time()
    entry.rt = RealTime()

    table.insert(PD.Chat.MSG, entry)

    local max = tonumber(PD.Chat.Config.MaxMessages) or 50

    while #PD.Chat.MSG > max do
        table.remove(PD.Chat.MSG, 1)
    end

    if IsValid(ChatMainFrame) and IsValid(ChatMainFrame.scrollPanel) then
        populateChat(ChatMainFrame.scrollPanel)
    end
end

-- Vom Server: Markup, schon bereinigt.
function PD.Chat:AddMSG(text, key)
    pushMessage({text = text, key = key})
end

-- Klartext ohne Markup, etwa Engine-Meldungen.
function PD.Chat:AddPlain(text, color)
    pushMessage({segments = {{kind = "text", text = tostring(text or ""), color = color or Color(255, 255, 255)}}})
end

--[[
    Argumente wie bei chat.AddText: Farben gelten fuer alles danach, Spieler
    erscheinen mit Namen in Teamfarbe. Text wird bewusst nicht als Markup
    gelesen - ein Addon, das "<" schreibt, meint "<".
]]
function PD.Chat:AddRichText(...)
    local segments = {}
    local color = Color(255, 255, 255)

    for index = 1, select("#", ...) do
        local value = select(index, ...)

        if IsColor(value) or (istable(value) and isnumber(value.r) and isnumber(value.g) and isnumber(value.b)) then
            color = Color(value.r, value.g, value.b, 255)
        elseif isentity(value) and IsValid(value) and value:IsPlayer() then
            segments[#segments + 1] = {kind = "text", text = value:Nick(), color = team.GetColor(value:Team())}
        elseif value ~= nil then
            segments[#segments + 1] = {kind = "text", text = tostring(value), color = color}
        end
    end

    if #segments > 0 then
        pushMessage({segments = segments})
    end
end

--[[
    chat.AddText in den eigenen Chat umleiten.

    Defcon, Warnsystem, Decode, Kennenlernen, Squad, Sprache und Faction
    schreiben ueber chat.AddText. Der Standard-Chat ist ausgeblendet (siehe
    HUDShouldDraw unten) - ohne diese Umleitung hat diese Meldungen nie jemand
    gesehen.

    Das Original wird einmal gesichert, damit ein Lua-Refresh nicht die eigene
    Umleitung als "Original" wegspeichert und sich selbst aufruft. Es laeuft
    weiter mit, damit die Meldungen auch in der Konsole stehen. Ein Fehler in
    der Umleitung darf chat.AddText fuer alle anderen nicht kaputt machen.
]]
PD.Chat.OriginalAddText = PD.Chat.OriginalAddText or chat.AddText

function chat.AddText(...)
    local ok, err = pcall(PD.Chat.AddRichText, PD.Chat, ...)

    if not ok then
        ErrorNoHalt("[Chat] chat.AddText-Umleitung: " .. tostring(err) .. "\n")
    end

    return PD.Chat.OriginalAddText(...)
end

--[[
    Standardzeile "Name: Text" des Basis-Gamemodes abschalten.

    GM:OnPlayerChat schreibt jede Spielernachricht per chat.AddText. Seit der
    Umleitung oben landet das im eigenen Chat - zusaetzlich zur formatierten
    Nachricht vom Server ([LOOC], [OOC] ...), also doppelt. Spielernachrichten
    kommen ausschliesslich ueber PD.Chat.SendMSG, die Standardzeile wird nicht
    gebraucht. Der Hook selbst laeuft weiter (siehe KEY_ENTER), damit Addons,
    die auf OnPlayerChat hoeren, nichts verpassen.
]]
local gm = GM or GAMEMODE

if gm then
    function gm:OnPlayerChat()
        return true
    end
end

--------------------------------------------------------------------------------
-- Einstellungen und Hilfe
--------------------------------------------------------------------------------

local ChatCommandHelp = {
    {cmd = "/ooc <Text>  (auch: //<Text>)", desc = "Globaler Out-of-Character Chat", color = Color(255, 255, 255), example = "/ooc Hallo zusammen!", result = "[OOC] DeinName: Hallo zusammen!"},
    {cmd = "/looc <Text>  (Standard ohne Prefix)", desc = "Lokaler Out-of-Character Chat", color = Color(255, 255, 255), example = "/looc kurze Frage", result = "[LOOC] DeinName: kurze Frage"},
    {cmd = "/me <Text>", desc = "Lokale Aktion / Emote", color = Color(255, 255, 255), example = "/me nickt zustimmend", result = "[ME] DeinName: nickt zustimmend"},
    {cmd = "/akt <Text>", desc = "Aktion (lokal)", color = Color(255, 0, 0), example = "/akt zieht die Waffe", result = "[AKT] DeinName: zieht die Waffe"},
    {cmd = "/makt <Text>", desc = "Medizinische Aktion", color = Color(125, 125, 0), example = "/makt verbindet die Wunde", result = "[MAKT] DeinName: verbindet die Wunde"},
    {cmd = "/eakt <Text>", desc = "Event-Aktion", color = Color(0, 255, 0), example = "/eakt lässt Trümmer herabfallen", result = "[EAKT] DeinName: lässt Trümmer herabfallen"},
    {cmd = "/fakt <Text>", desc = "FC-Aktion", color = Color(0, 255, 0), example = "/fakt ruft Verstärkung", result = "[FAKT] DeinName: ruft Verstärkung"},
    {cmd = "/it <Text>", desc = "Lokale Interaktion (ohne Namen)", color = Color(255, 0, 0), example = "/it Ein Knacken ist zu hören", result = "[***] Ein Knacken ist zu hören"},
    {cmd = "/git <Text>", desc = "Globale Interaktion (ohne Namen)", color = Color(255, 255, 255), example = "/git Der Boden erzittert", result = "[***] Der Boden erzittert"},
    {cmd = "/roll <Text>", desc = "Würfeln / Zufallswert", color = Color(0, 255, 0), example = "/roll 1-100", result = "[ROLL] DeinName: 1-100"},
    {cmd = "@<Text>", desc = "Admin-Chat", color = Color(255, 0, 0), example = "@Bitte einmal aufs Postfach schauen", result = "[ADMIN] DeinName: Bitte einmal aufs Postfach schauen"},
}

local FormatExamples = {
    {note = "Farbe aus der Palette", code = "Hallo <color(red)> wie geht es dir <color>"},
    {note = "Farbe als RGB", code = "Hallo <color(255,0,0)> wie geht es dir <color>"},
    {note = "Farbe als Hex", code = "<color(#40a0ff)>Hex<color> oder kurz <color(#f80)>so<color>"},
    {note = "Schrift", code = "<b>fett<b>, <i>kursiv<i>, <b><i>beides<i><b>"},
    {note = "Verschachtelt", code = "<b><color(gold)>Captain<color><b> Rex"},
    {note = "Animation", code = "<anim(rainbow)>Regenbogen<anim>  <anim(pulse)>Puls<anim>"},
    {note = "Animation mit Tempo", code = "<anim(wave)>Welle<anim>  <anim(wave,2)>doppelt so schnell<anim>"},
    {note = "Animation", code = "<anim(shake)>Zittern<anim>  <anim(glitch)>Störung<anim>"},
    {note = "Animation", code = "<anim(holo)>Holo-Funkspruch<anim>  <anim(type)>Schreibmaschine<anim>"},
    {note = "Icons", code = ":shield: :star: :medal: oder <icon(bell)>"},
    {note = "Tag wörtlich schreiben", code = "\\<color(red)> bleibt Text"}
}

local function wrappedLabel(text, parent, color, font)
    local label = PD.Label(text, parent, {dock = TOP, color = color or PD.Theme.Colors.TextDim, font = font or "MLIB.13"})

    label:SetWrap(true)
    label:SetAutoStretchVertical(true)
    label:SetContentAlignment(7)

    return label
end

local function helpBox(scroll)
    local box = scroll:Add("DPanel")
    box:Dock(TOP)
    box:DockMargin(PD.W(5), PD.H(3), PD.W(5), PD.H(3))
    box:SetTall(PD.H(50))

    return box
end

-- Raster fuer Farbfelder und Icons: Spaltenzahl aus der Breite.
local function gridLayout(box, count)
    box.PerformLayout = function(self, w)
        local cols = math.max(1, math.floor((w - PD.W(20)) / PD.W(105)))
        local rows = math.ceil(count / cols)
        local tall = PD.H(26) + rows * PD.H(20) + PD.H(6)

        self.cols = cols

        if self:GetTall() ~= tall then self:SetTall(tall) end
    end
end

local function populateChatSettingsTab(panel)
    panel:Clear()

    PD.Checkbox(panel, "Zeitstempel anzeigen", PD.Chat.Config.showTimestamps, function(value)
        PD.Chat.Config.showTimestamps = value
        save_chat_config()

        if IsValid(ChatMainFrame) and IsValid(ChatMainFrame.scrollPanel) then
            populateChat(ChatMainFrame.scrollPanel)
        end
    end)

    PD.Checkbox(panel, "Chat in Third Person anzeigen", PD.Chat.Config.showInThirdPerson, function(value)
        PD.Chat.Config.showInThirdPerson = value
        save_chat_config()

        if IsValid(ChatMainFrame) and IsValid(ChatMainFrame.scrollPanel) then
            populateChat(ChatMainFrame.scrollPanel)
        end
    end)

    -- Aus heisst: animierter Text wird still gezeichnet. Fuer schwaechere
    -- Rechner und fuer alle, die flackernde Schrift nicht vertragen.
    PD.Checkbox(panel, "Animationen anzeigen", PD.Chat.Config.animations ~= false, function(value)
        PD.Chat.Config.animations = value
        save_chat_config()
    end)

    PD.Slider(panel, "Schriftgröße", 10, 24, PD.Chat.Config.fontSize or 15, function(value)
        PD.Chat.Config.fontSize = math.Round(value)
        save_chat_config()

        if IsValid(ChatMainFrame) and IsValid(ChatMainFrame.scrollPanel) then
            populateChat(ChatMainFrame.scrollPanel)
        end
    end)
end

local function populateChatHelpTab(panel)
    panel:Clear()

    local scroll = PD.Scroll(panel)

    wrappedLabel("Farben, Schrift und Animationen stehen zwischen Start- und End-Tag. Der End-Tag ist der Name ohne Klammer. Icons brauchen keinen End-Tag. Tab vervollständigt beim Tippen, über dem Eingabefeld siehst du vorab, wie die Nachricht ankommt.", scroll)

    for _, example in ipairs(FormatExamples) do
        example.segments = example.segments or PD.Chat.Format.Parse(example.code, Color(255, 255, 255))
        example.fake = example.fake or {rt = RealTime()}

        local box = helpBox(scroll)

        box.PerformLayout = function(self, w)
            self.layout = PD.Chat.Render.LayoutSegments(example.segments, w - PD.W(20), 14)

            local tall = PD.H(40) + self.layout.height

            if self:GetTall() ~= tall then self:SetTall(tall) end
        end

        box.Paint = function(self, w, h)
            draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
            draw.SimpleText(example.note, "MLIB.11", PD.W(10), PD.H(3), PD.Theme.Colors.TextMuted)
            draw.SimpleText(example.code, "MLIB.12", PD.W(10), PD.H(17), PD.Theme.Colors.TextDim)

            if self.layout then
                -- Die Schreibmaschine laeuft in der Hilfe alle vier Sekunden neu.
                local now = RealTime()
                example.fake.rt = now - (now % 4)

                PD.Chat.Render.Draw(self.layout, PD.W(10), PD.H(34), 1, example.fake)
            end
        end
    end

    local palette = helpBox(scroll)
    gridLayout(palette, #PD.Chat.Format.PaletteOrder)

    palette.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
        draw.SimpleText("Farben   <color(name)>", "MLIB.12", PD.W(10), PD.H(5), PD.Theme.Colors.TextDim)

        local cols = self.cols or 3

        for k, name in ipairs(PD.Chat.Format.PaletteOrder) do
            local c = PD.Chat.Format.Palette[name]
            local x = PD.W(10) + ((k - 1) % cols) * PD.W(105)
            local y = PD.H(26) + math.floor((k - 1) / cols) * PD.H(20)

            surface.SetDrawColor(c.r, c.g, c.b, 255)
            surface.DrawRect(x, y + PD.H(3), PD.H(12), PD.H(12))

            draw.SimpleText(name, "MLIB.12", x + PD.H(17), y + PD.H(2), c)
        end
    end

    local icons = helpBox(scroll)
    gridLayout(icons, #PD.Chat.Format.IconOrder)

    icons.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
        draw.SimpleText("Icons   :name:  oder  <icon(name)>", "MLIB.12", PD.W(10), PD.H(5), PD.Theme.Colors.TextDim)

        local cols = self.cols or 3

        for k, name in ipairs(PD.Chat.Format.IconOrder) do
            local x = PD.W(10) + ((k - 1) % cols) * PD.W(105)
            local y = PD.H(26) + math.floor((k - 1) / cols) * PD.H(20)
            local mat = PD.Chat.Render.IconMaterial(name)

            if mat then
                surface.SetMaterial(mat)
                surface.SetDrawColor(255, 255, 255, 255)
                surface.DrawTexturedRect(x, y + PD.H(2), PD.H(14), PD.H(14))
            end

            draw.SimpleText(":" .. name .. ":", "MLIB.12", x + PD.H(18), y + PD.H(2),
                mat and PD.Theme.Colors.Text or PD.Theme.Colors.TextMuted)
        end
    end

    wrappedLabel("Befehle: Nachrichten werden anhand des verwendeten Prefixes eingefärbt und mit einem Tag versehen.", scroll)

    for _, entry in ipairs(ChatCommandHelp) do
        PD.Panel(scroll, {dock = TOP, height = PD.H(72), hideBox = false, accentTop = false}, function(self, w, h)
            draw.DrawText(entry.cmd, "MLIB.15", PD.W(10), PD.H(6), entry.color, TEXT_ALIGN_LEFT)
            draw.DrawText(entry.desc, "MLIB.12", PD.W(10), PD.H(27), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
            draw.DrawText(entry.result, "MLIB.12", PD.W(10), PD.H(46), entry.color, TEXT_ALIGN_LEFT)
        end)
    end
end

function PD.Chat:OpenSettings()
    if IsValid(ChatSettingsFrame) then
        ChatSettingsFrame:Remove()
    end

    ChatSettingsFrame = PD.Frame("Chat-Einstellungen", PD.W(460), PD.H(460), true)
    ChatSettingsFrame:SetDraggable(true)
    ChatSettingsFrame:Center()

    local content = ChatSettingsFrame:GetContentPanel()

    local tabBar = vgui.Create("DPanel", content)
    tabBar:Dock(TOP)
    tabBar:SetTall(PD.H(36))
    tabBar:DockMargin(0, 0, 0, PD.H(5))
    tabBar.Paint = function() end

    local pagePanel = vgui.Create("DPanel", content)
    pagePanel:Dock(FILL)
    pagePanel.Paint = function() end

    local tabs = {}

    local function CreateTab(name, id, populate)
        local tabBtn = tabBar:Add("DButton")
        tabBtn:SetText("")
        tabBtn:Dock(LEFT)
        tabBtn:SetWide(PD.W(200))
        tabBtn:DockMargin(0, 0, PD.W(4), 0)
        tabBtn._active = false
        tabBtn._hover = 0

        tabBtn.Paint = function(self, w, h)
            self._hover = Lerp(FrameTime() * 10, self._hover, self:IsHovered() and 1 or 0)

            local base = PD.Theme.Colors.BackgroundLight
            local bg = self._active and base or Color(base.r, base.g, base.b, 60 * self._hover)
            draw.RoundedBox(0, 0, 0, w, h, bg)

            if self._active then
                surface.SetDrawColor(PD.Theme.Colors.AccentRed)
                surface.DrawRect(0, h - PD.H(3), w, PD.H(3))
            end

            local textColor = self._active and PD.Theme.Colors.Text or PD.Theme.Colors.TextDim
            draw.DrawText(name, "MLIB.14", w / 2, h / 2 - PD.H(7), textColor, TEXT_ALIGN_CENTER)
        end

        tabBtn.OnCursorEntered = function()
            surface.PlaySound("UI/buttonrollover.wav")
        end

        tabBtn.DoClick = function()
            surface.PlaySound("UI/buttonclick.wav")

            for _, t in pairs(tabs) do
                t._active = false
            end

            tabBtn._active = true
            populate(pagePanel)
        end

        tabs[id] = tabBtn
        return tabBtn
    end

    local settingsTab = CreateTab("Einstellungen", "settings", populateChatSettingsTab)
    CreateTab("Formatierung & Befehle", "help", populateChatHelpTab)

    settingsTab.DoClick()
end

--------------------------------------------------------------------------------
-- Vorschau und Vervollstaendigung
--------------------------------------------------------------------------------

--[[
    Befehlsprefix abtrennen, damit die Vorschau nur den Text zeigt - in der
    Farbe des Befehls, die er beim Empfaenger auch haben wird.
]]
local function splitCommand(text)
    local flat = PD.Chat.Command and PD.Chat.Command.Flat or {}
    local prefix = string.sub(text, 1, 1)

    if prefix == "@" then
        return string.sub(text, 2), flat.admin and flat.admin.color
    end

    local group = PD.Chat.Command and PD.Chat.Command.List[prefix]

    if group then
        local typed, rest = string.match(string.sub(text, 2), "^(%S*)%s?(.*)$")

        if typed then
            local command = group[typed]

            if not command then
                for name, entry in pairs(group) do
                    if string.lower(name) == string.lower(typed) then
                        command = entry
                        break
                    end
                end
            end

            if command then return rest or "", command.color end
        end
    end

    return text, flat.looc and flat.looc.color
end

local TAG_COMPLETIONS = {"<color(", "<anim(", "<icon(", "<b>", "<i>", "<color>", "<anim>"}

local function startsWith(value, prefix)
    return string.sub(value, 1, #prefix) == prefix
end

--[[
    Kandidaten fuer die Stelle vor dem Cursor.
    Rueckgabe: Byte-Position, ab der ersetzt wird, und die Liste der Ersetzungen.
]]
local function completionsFor(before)
    local Format = PD.Chat.Format
    local list = {}

    local start, word = string.match(before, "()<color%(([%w#]*)$")

    if start then
        for _, name in ipairs(Format.PaletteOrder) do
            if startsWith(name, string.lower(word)) then list[#list + 1] = "<color(" .. name .. ")>" end
        end

        return start, list
    end

    start, word = string.match(before, "()<anim%((%a*)$")

    if start then
        for _, name in ipairs(Format.AnimationOrder) do
            if startsWith(name, string.lower(word)) then list[#list + 1] = "<anim(" .. name .. ")>" end
        end

        return start, list
    end

    start, word = string.match(before, "()<icon%(([%w_]*)$")

    if start then
        for _, name in ipairs(Format.IconOrder) do
            if startsWith(name, string.lower(word)) then list[#list + 1] = "<icon(" .. name .. ")>" end
        end

        return start, list
    end

    start, word = string.match(before, "():([%w_]*)$")

    if start then
        for _, name in ipairs(Format.IconOrder) do
            if startsWith(name, string.lower(word)) then list[#list + 1] = ":" .. name .. ":" end
        end

        return start, list
    end

    start, word = string.match(before, "()<(%a*)$")

    if start then
        for _, tag in ipairs(TAG_COMPLETIONS) do
            if startsWith(tag, "<" .. string.lower(word)) then list[#list + 1] = tag end
        end

        return start, list
    end

    return nil
end

-- Der Cursor von DTextEntry zaehlt Zeichen, Lua-Strings zaehlen Bytes.
local function byteOffset(text, chars)
    local ok, offset = pcall(utf8.offset, text, chars + 1)

    if ok and offset then return offset - 1 end

    return #text
end

--------------------------------------------------------------------------------
-- Chatfenster
--------------------------------------------------------------------------------

function PD.Chat:Open()
    if IsValid(ChatMainFrame) then
        ChatMainFrame:Remove()
    end

    ChatMainFrame = PD.Frame("Chat", PD.Chat.Config.w, PD.Chat.Config.h, true, {onClose = function()
        local x, y = ChatMainFrame:GetPos()
        local w, h = ChatMainFrame:GetSize()

        PD.Chat.Config.x = x
        PD.Chat.Config.y = y
        PD.Chat.Config.w = w
        PD.Chat.Config.h = h

        save_chat_config()
    end})
    ChatMainFrame:SetDraggable(true)
    ChatMainFrame:SetSizable(true)
    ChatMainFrame:SetPos(PD.Chat.Config.x, PD.Chat.Config.y)

    local settingsBtn = vgui.Create("DButton", ChatMainFrame)
    settingsBtn:SetSize(PD.W(30), PD.H(30))
    settingsBtn:SetPos(PD.W(8), PD.H(8))
    settingsBtn:SetText("")
    settingsBtn._hover = 0

    settingsBtn.Paint = function(self, bw, bh)
        local hover = self:IsHovered()
        self._hover = Lerp(FrameTime() * 10, self._hover, hover and 1 or 0)

        local bgAlpha = 50 + self._hover * 150
        local col = PD.LerpColor(PD.Theme.Colors.AccentGray, PD.Theme.Colors.AccentRed, self._hover)

        draw.RoundedBox(0, 0, 0, bw, bh, Color(col.r, col.g, col.b, bgAlpha))
        draw.DrawText("⚙", "MLIB.20", bw / 2, bh / 2 - PD.H(11), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
    end

    settingsBtn.DoClick = function()
        surface.PlaySound("UI/buttonclick.wav")
        PD.Chat:OpenSettings()
    end

    settingsBtn.OnCursorEntered = function()
        surface.PlaySound("UI/buttonrollover.wav")
    end

    ChatMainFrame.SettingsButton = settingsBtn

    ChatMainFrame.OnSizeChanged = function( newWidth, newHeight )
        local x, y = ChatMainFrame:GetPos()
        local w, h = ChatMainFrame:GetSize()

        PD.Chat.Config.x = x
        PD.Chat.Config.y = y
        PD.Chat.Config.w = w
        PD.Chat.Config.h = h

        ChatMainFrame:GetContentPanel():Clear()
        ChatMainFrame.CloseButton:SetPos( ChatMainFrame:GetWide() - PD.W(40), PD.H(8))
        ChatMainFrame.SettingsButton:SetPos( PD.W(8), PD.H(8))
        drawChatComponens()
        save_chat_config()
    end

    function drawChatComponens()
        local content = ChatMainFrame:GetContentPanel()

        local textEntry = PD.TextEntry(content, "Write your message...", "", function() end, {dock = BOTTOM})

        -- Tab soll vervollstaendigen, nicht den Fokus weiterreichen.
        if textEntry.SetTabbingDisabled then
            textEntry:SetTabbingDisabled(true)
        end

        --[[
            Vorschau ueber dem Eingabefeld. Sie erscheint nur, wenn die Eingabe
            Formatierung enthaelt oder etwas nicht stimmt - fuer normalen Text
            bleibt sie zu und nimmt keinen Platz weg.
        ]]
        local preview = content:Add("DPanel")
        preview:Dock(BOTTOM)
        preview:DockMargin(PD.W(5), 0, PD.W(5), 0)
        preview:SetTall(0)
        preview:SetMouseInputEnabled(false)
        preview.problems = {}
        preview.fake = {rt = RealTime()}

        preview.Paint = function(self, w, h)
            if h <= 0 then return end

            draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)

            local y = PD.H(3)

            if self.layout then
                PD.Chat.Render.Draw(self.layout, PD.W(6), y, 1, self.fake)
                y = y + self.layout.height
            end

            for _, text in ipairs(self.problems) do
                draw.SimpleText(text, "MLIB.12", PD.W(6), y, PROBLEM_COLOR)
                y = y + PD.H(15)
            end
        end

        local lastText
        local completion

        local function updatePreview(text)
            local body, base = splitCommand(text)
            local segments, problems, info = PD.Chat.Format.Parse(body, base, {limits = true})

            if text == "" or (info.markup == 0 and #problems == 0) then
                preview.layout = nil
                preview.problems = {}

                if preview:GetTall() ~= 0 then preview:SetTall(0) end

                return
            end

            local width = preview:GetWide() - PD.W(12)

            if width < PD.W(40) then
                width = ChatMainFrame:GetWide() - PD.W(40)
            end

            preview.layout = PD.Chat.Render.LayoutSegments(segments, width, chatFontSize())
            preview.problems = problems
            preview.fake.rt = RealTime()

            local tall = PD.H(6) + preview.layout.height + #problems * PD.H(15)

            if preview:GetTall() ~= tall then
                preview:SetTall(tall)

                if IsValid(ChatMainFrame.scrollPanel) then
                    scrollToBottom(ChatMainFrame.scrollPanel)
                end
            end
        end

        --[[
            Vervollstaendigen an der Cursorposition. Wiederholtes Tab ohne
            Tippen dazwischen blaettert durch die Kandidaten.
        ]]
        local function completeAtCaret(entry)
            local text = entry:GetValue() or ""
            local caretByte = byteOffset(text, entry:GetCaretPos())

            if completion and completion.text == text and completion.caret == caretByte then
                completion.index = completion.index % #completion.list + 1
            else
                local before = string.sub(text, 1, caretByte)
                local start, list = completionsFor(before)

                if not start or #list == 0 then
                    completion = nil
                    return
                end

                completion = {
                    list = list,
                    index = 1,
                    prefix = string.sub(before, 1, start - 1),
                    after = string.sub(text, caretByte + 1)
                }
            end

            local newBefore = completion.prefix .. completion.list[completion.index]
            local newText = newBefore .. completion.after

            entry:SetText(newText)
            entry:SetCaretPos(utf8.len(newBefore) or #newBefore)

            completion.text = newText
            completion.caret = #newBefore

            lastText = newText
            updatePreview(newText)
        end

        --[[
            Tab ueber die Tastenflanke im Think statt ueber OnKeyCodeTyped:
            VGUI verschiebt bei Tab den Fokus, bevor das Eingabefeld die Taste
            sieht. Dieselbe Falle wie beim frueheren Systemterminal.
        ]]
        local baseThink = textEntry.Think
        local tabDown, wasFocused = false, false

        textEntry.Think = function(self)
            if isfunction(baseThink) then baseThink(self) end

            local text = self:GetValue() or ""

            if text ~= lastText then
                lastText = text
                completion = nil
                updatePreview(text)
            end

            local focused = self:HasFocus()
            local down = input.IsKeyDown(KEY_TAB)

            if down and not tabDown and (focused or wasFocused) then
                completeAtCaret(self)
                self:RequestFocus()
            end

            tabDown = down
            wasFocused = focused
        end

        local lastMsgIndex = #PD.Chat.RecentMessages

        textEntry.OnKeyCodeTyped = function(self, key)
            if key == KEY_UP then
                local lastMessage = PD.Chat.RecentMessages[lastMsgIndex]
                if lastMessage then
                    self:SetText(lastMessage)
                    self:SetCaretPos(#lastMessage)
                end

                lastMsgIndex = lastMsgIndex - 1
            elseif key == KEY_DOWN then
                self:SetText("")
                lastMsgIndex = #PD.Chat.RecentMessages
            elseif key == KEY_ENTER then
                local text = string.Trim(self:GetValue() or "")
                if not table.HasValue(PD.Chat.RecentMessages, text) then
                    table.insert(PD.Chat.RecentMessages, text)
                end
                PD.Chat.HandleMessage(text)
                hook.Run("OnPlayerChat", LocalPlayer(), text, false, not LocalPlayer():Alive())

                ChatMainFrame:Close()
            end
        end
        textEntry:RequestFocus()

        local scrollPanel = PD.Scroll(content)
        scrollPanel:Dock(FILL)

        ChatMainFrame.scrollPanel = scrollPanel
        populateChat(scrollPanel)
    end

    drawChatComponens()
end

function PD.Chat.HandleMessage(text)
    net.Start("PD.Chat.SendMSG")
        net.WriteString(text)
    net.SendToServer()
end

net.Receive("PD.Chat.SendMSG", function()
    local text = net.ReadString()
    local key = net.ReadString()

    PD.Chat:AddMSG(text, key)
end)

local messageBinds = {
    ["messagemode"] = true,
    ["messagemode2"] = true,
    ["say"] = true,
    ["say_team"] = true
}

hook.Add("ChatText", "PD.Chat.HandleChatText", function(index, name, text, type)
    if type == "joinleave" then
        return
    end

    -- Engine-Meldungen enthalten Spielernamen - als Klartext, nie als Markup.
    PD.Chat:AddPlain(text)

    return true
end)

hook.Add("PlayerBindPress", "PD.Chat.DisableBind", function(ply, bind, pressed)
    if not pressed or not messageBinds[bind] then return end

    PD.Chat:Open()

    return true
end)

hook.Add("HUDShouldDraw", "PD.Chat.HideNormalChat", function(name)
    if name == "CHudChat" then return false end
end)

hook.Add("OnPauseMenuShow", "PD.Chat.CloseOnPauseMenuShow", function()
    if IsValid(ChatMainFrame) then
        ChatMainFrame:Remove()
    end

    if IsValid(ChatSettingsFrame) then
        ChatSettingsFrame:Remove()
    end
end)

load_chat_config()

-- Abstand zwischen zwei Nachrichten im geschlossenen Chat, in Zeilenhoehen.
local MSG_GAP = 0.3

--[[
    Geschlossener Chat: die Nachrichten der letzten 60 Sekunden, neueste unten,
    langsam ausblendend. Das Layout kommt aus dem Cache des Renderers - vorher
    wurde hier jede Nachricht in jedem Frame neu umbrochen.
]]
AddSmoothElement(PD.Chat.Config.x, PD.Chat.Config.y, PD.Chat.Config.w, PD.Chat.Config.h, function(smoothX, smoothY)
    if PD.FOV.thirdPerson and not PD.Chat.Config.showInThirdPerson then return end
    if IsValid(ChatMainFrame) then return end
    if not PD.Chat.Render or not PD.Chat.Render.Layout then return end

    local now = os.time()
    local size = chatFontSize()
    local lineH = PD.Chat.Render.LineHeight(size)
    local width = PD.Chat.Config.w - PD.W(30)
    local showTimestamps = PD.Chat.Config.showTimestamps
    local x = PD.Chat.Config.x + PD.W(10)
    local bottom = PD.Chat.Config.y + PD.Chat.Config.h

    local pos = 0

    -- Von der neuesten Nachricht rueckwaerts; die Liste ist chronologisch, die
    -- erste zu alte Nachricht beendet also die Suche.
    for i = #PD.Chat.MSG, 1, -1 do
        local msg = PD.Chat.MSG[i]
        local timeSince = now - msg.time

        if timeSince >= 60 then break end

        local alpha = math.Clamp(1 - timeSince / 60, 0, 1)

        if alpha > 0 then
            local layout = PD.Chat.Render.Layout(msg, width, size, showTimestamps)
            local count = #layout.lines

            PD.Chat.Render.Draw(layout, x, bottom - (pos + count - 1) * lineH, alpha, msg)

            pos = pos + count + MSG_GAP
        end
    end
end)
