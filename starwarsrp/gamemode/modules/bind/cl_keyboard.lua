--[[
    Tastaturbild fuer das Belegungsmenue.

    Zeigt, welche Taste belegt ist und womit - farblich getrennt nach unseren
    eigenen Binds und denen, die GMod selbst vergibt. Die dritte Farbe ist die
    wichtigste: sie markiert Tasten, auf denen beides liegt. Genau die sind der
    Grund, warum ein Bind sich "manchmal komisch" verhaelt.

    Die Belegung der Engine kommt aus input.LookupKeyBinding, unsere aus
    PD.Binds.List. Nichts davon wird zwischengespeichert - beim Oeffnen des
    Menues einmal einsammeln reicht, und so ist die Anzeige nie veraltet.
]]

PD = PD or {}
PD.Binds = PD.Binds or {}

local COL_FREE   = Color( 38,  44,  52)
local COL_OURS   = Color( 58, 124, 205)
local COL_GMOD   = Color(104, 114, 126)
local COL_BOTH   = Color(198, 126,  40)
local COL_EDGE   = Color(  0,   0,   0, 90)
local COL_LABEL  = Color(232, 238, 245)
local COL_LABEL_DIM = Color(150, 158, 168)

--------------------------------------------------------------------------------
-- Aufbau
--------------------------------------------------------------------------------

local LAYOUT = {}

local function put(x, y, w, key, label)
    table.insert(LAYOUT, {x = x, y = y, w = w, key = key, label = label})

    return x + w
end

--[[
    Eine Reihe setzen. Ein Eintrag ist {Tastencode, Beschriftung, Breite};
    steht false statt eines Codes, bleibt an der Stelle eine Luecke - so sitzen
    Pfeilblock und Enter-Ueberhang dort, wo sie auf einer echten Tastatur sind.
]]
local function row(y, x, entries)
    for _, e in ipairs(entries) do
        local w = e[3] or 1

        if e[1] == false then
            x = x + w
        else
            x = put(x, y, w, e[1], e[2])
        end
    end
end

row(0, 0, {
    {KEY_ESCAPE, "ESC"}, {false, "", 0.5},
    {KEY_F1, "F1"}, {KEY_F2, "F2"}, {KEY_F3, "F3"}, {KEY_F4, "F4"}, {false, "", 0.5},
    {KEY_F5, "F5"}, {KEY_F6, "F6"}, {KEY_F7, "F7"}, {KEY_F8, "F8"}, {false, "", 0.5},
    {KEY_F9, "F9"}, {KEY_F10, "F10"}, {KEY_F11, "F11"}, {KEY_F12, "F12"}
})

row(1.3, 0, {
    {KEY_BACKQUOTE, "^"},
    {KEY_1, "1"}, {KEY_2, "2"}, {KEY_3, "3"}, {KEY_4, "4"}, {KEY_5, "5"},
    {KEY_6, "6"}, {KEY_7, "7"}, {KEY_8, "8"}, {KEY_9, "9"}, {KEY_0, "0"},
    {KEY_MINUS, "ss"}, {KEY_EQUAL, "'"},
    {KEY_BACKSPACE, "Backspace", 2}
})

row(2.3, 0, {
    {KEY_TAB, "Tab", 1.5},
    {KEY_Q, "Q"}, {KEY_W, "W"}, {KEY_E, "E"}, {KEY_R, "R"}, {KEY_T, "T"},
    {KEY_Z, "Z"}, {KEY_U, "U"}, {KEY_I, "I"}, {KEY_O, "O"}, {KEY_P, "P"},
    {KEY_LBRACKET, "Ue"}, {KEY_RBRACKET, "+"},
    {KEY_ENTER, "Enter", 1.5}
})

row(3.3, 0, {
    {KEY_CAPSLOCK, "Feststell", 1.75},
    {KEY_A, "A"}, {KEY_S, "S"}, {KEY_D, "D"}, {KEY_F, "F"}, {KEY_G, "G"},
    {KEY_H, "H"}, {KEY_J, "J"}, {KEY_K, "K"}, {KEY_L, "L"},
    {KEY_SEMICOLON, "Oe"}, {KEY_APOSTROPHE, "Ae"},
    {KEY_BACKSLASH, "#", 1.25}
})

row(4.3, 0, {
    {KEY_LSHIFT, "Umschalt", 2.25},
    {KEY_Y, "Y"}, {KEY_X, "X"}, {KEY_C, "C"}, {KEY_V, "V"}, {KEY_B, "B"},
    {KEY_N, "N"}, {KEY_M, "M"},
    {KEY_COMMA, ","}, {KEY_PERIOD, "."}, {KEY_SLASH, "-"},
    {KEY_RSHIFT, "Umschalt", 2.75}
})

row(5.3, 0, {
    {KEY_LCONTROL, "Strg", 1.75},
    {KEY_LWIN, "Win", 1.25},
    {KEY_LALT, "Alt", 1.5},
    {KEY_SPACE, "Leertaste", 6.25},
    {KEY_RALT, "Alt Gr", 1.5},
    {KEY_APP, "Menue", 1.25},
    {KEY_RCONTROL, "Strg", 1.5}
})

-- Navigationsblock
row(1.3, 15.5, {{KEY_INSERT, "Einfg"}, {KEY_HOME, "Pos1"}, {KEY_PAGEUP, "Bild auf"}})
row(2.3, 15.5, {{KEY_DELETE, "Entf"}, {KEY_END, "Ende"}, {KEY_PAGEDOWN, "Bild ab"}})
row(4.3, 15.5, {{false, "", 1}, {KEY_UP, "hoch"}})
row(5.3, 15.5, {{KEY_LEFT, "links"}, {KEY_DOWN, "runter"}, {KEY_RIGHT, "rechts"}})

-- Maus. Gehoert dazu: der Binder nimmt Maustasten genauso an wie Tasten.
row(6.9, 0, {
    {MOUSE_LEFT, "Maus links", 1.75},
    {MOUSE_RIGHT, "Maus rechts", 1.75},
    {MOUSE_MIDDLE, "Maus Mitte", 1.75},
    {MOUSE_4, "Maus 4", 1.5},
    {MOUSE_5, "Maus 5", 1.5},
    {MOUSE_WHEEL_UP, "Rad hoch", 1.75},
    {MOUSE_WHEEL_DOWN, "Rad runter", 1.75}
})

local GRID_W = 18.5
local GRID_H = 7.9

--------------------------------------------------------------------------------
-- Belegung einsammeln
--------------------------------------------------------------------------------

--[[
    Was liegt auf welcher Taste?

    Rueckgabe ist eine Tabelle Tastencode -> {ours = {...}, gmod = "befehl"}.
    Unsere Binds koennen mehrfach auf derselben Taste liegen: PD.Binds nimmt
    beim Belegen keine Ruecksicht darauf, und FindBindToKey liefert dann nur
    den ersten. Auch das soll hier sichtbar werden.
]]
local function collect()
    local map = {}

    local function slot(key)
        map[key] = map[key] or {ours = {}}

        return map[key]
    end

    for id, bind in pairs(PD.Binds.List or {}) do
        local key = bind.Key

        if key and key ~= KEY_NONE then
            table.insert(slot(key).ours, {id = id, bind = bind})
        end
    end

    for _, entry in ipairs(LAYOUT) do
        local cmd = input.LookupKeyBinding(entry.key)

        if cmd and cmd ~= "" then
            slot(entry.key).gmod = cmd
        end
    end

    for _, entry in pairs(map) do
        table.sort(entry.ours, function(a, b)
            return (a.bind.Name or a.id) < (b.bind.Name or b.id)
        end)
    end

    return map
end

--------------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------------

local function keyColor(slot)
    if not slot then return COL_FREE end

    local ours = #slot.ours > 0
    local gmod = slot.gmod ~= nil

    if ours and gmod then return COL_BOTH end
    if ours then return COL_OURS end
    if gmod then return COL_GMOD end

    return COL_FREE
end

local function legend(x, y, col, text)
    surface.SetDrawColor(col)
    surface.DrawRect(x, y, PD.W(14), PD.H(14))

    surface.SetDrawColor(COL_EDGE)
    surface.DrawOutlinedRect(x, y, PD.W(14), PD.H(14), 1)

    draw.SimpleText(text, "MLIB.12", x + PD.W(20), y + PD.H(7),
        PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

    surface.SetFont("MLIB.12")
    local tw = surface.GetTextSize(text)

    return x + PD.W(34) + tw
end

--[[
    Der Hinweiskasten unter dem Mauszeiger.

    Wird als Letztes gezeichnet, damit er ueber den Tasten liegt, und kippt an
    der rechten und unteren Kante nach innen statt aus dem Panel zu laufen.
]]
local function drawTooltip(panel, mx, my, entry, slot)
    local lines = {}

    table.insert(lines, {text = entry.label .. "  (" ..
        (input.GetKeyName(entry.key) or "?") .. ")", font = "MLIB.16",
        col = PD.Theme.Colors.Text})

    if slot and #slot.ours > 0 then
        for _, o in ipairs(slot.ours) do
            table.insert(lines, {text = (o.bind.Name or o.id) ..
                "  -  " .. (o.bind.Category or "Allgemein"),
                font = "MLIB.12", col = COL_OURS})
        end
    end

    if slot and slot.gmod then
        table.insert(lines, {text = "GMod: " .. slot.gmod,
            font = "MLIB.12", col = COL_GMOD})
    end

    if not slot or (#slot.ours == 0 and not slot.gmod) then
        table.insert(lines, {text = "Nicht belegt", font = "MLIB.12",
            col = PD.Theme.Colors.TextMuted})
    end

    if slot and #slot.ours > 1 then
        table.insert(lines, {text = #slot.ours .. " eigene Binds - nur der "
            .. "erste wird ausgeloest", font = "MLIB.12", col = COL_BOTH})
    elseif slot and #slot.ours > 0 and slot.gmod then
        table.insert(lines, {text = "Ueberschneidung: beides feuert",
            font = "MLIB.12", col = COL_BOTH})
    end

    local pad = PD.W(8)
    local lh = PD.H(17)
    local w = 0

    for _, l in ipairs(lines) do
        surface.SetFont(l.font)
        w = math.max(w, surface.GetTextSize(l.text))
    end

    local bw = w + pad * 2
    local bh = #lines * lh + pad * 2 - PD.H(3)

    local bx = mx + PD.W(14)
    local by = my + PD.H(14)

    if bx + bw > panel:GetWide() then bx = mx - bw - PD.W(8) end
    if by + bh > panel:GetTall() then by = my - bh - PD.H(8) end

    draw.RoundedBox(0, bx, by, bw, bh, PD.Theme.Colors.BackgroundDark)

    surface.SetDrawColor(PD.Theme.Colors.AccentGray)
    surface.DrawOutlinedRect(bx, by, bw, bh, 1)

    for i, l in ipairs(lines) do
        draw.SimpleText(l.text, l.font, bx + pad, by + pad + (i - 1) * lh,
            l.col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
end

--[[
    Baut das Tastaturbild in ein vorhandenes Panel.

    Die Belegung wird beim Erzeugen einmal eingesammelt und ueber Refresh
    aufgefrischt - das Menue ruft das nach jeder Aenderung auf.
]]
function PD.Binds:Keyboard(parent)
    -- Ueber parent:Add und nicht vgui.Create: PD.Frame haengt seine Kinder in
    -- den Inhaltsbereich unter der Titelleiste. vgui.Create ginge daran vorbei.
    local panel = parent:Add("DPanel")
    panel:SetMouseInputEnabled(true)

    panel.Map = collect()

    function panel:Refresh()
        self.Map = collect()
    end

    panel.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)

        local legendH = PD.H(24)
        local pad = PD.W(10)

        local unit = math.min(
            (w - pad * 2) / GRID_W,
            (h - pad * 2 - legendH) / GRID_H
        )

        if unit <= 0 then return end

        local ox = (w - unit * GRID_W) / 2
        local oy = pad

        local gap = math.max(1, unit * 0.06)
        local hovered, hoveredSlot

        local mx, my = self:CursorPos()
        local inside = self:IsHovered()

        for _, entry in ipairs(LAYOUT) do
            local kx = ox + entry.x * unit
            local ky = oy + entry.y * unit
            local kw = entry.w * unit - gap
            local kh = unit - gap

            local slot = self.Map[entry.key]
            local col = keyColor(slot)

            local isHover = inside
                and mx >= kx and mx <= kx + kw
                and my >= ky and my <= ky + kh

            if isHover then
                hovered, hoveredSlot = entry, slot

                col = Color(
                    math.min(col.r + 40, 255),
                    math.min(col.g + 40, 255),
                    math.min(col.b + 40, 255)
                )
            end

            draw.RoundedBox(0, kx, ky, kw, kh, col)

            surface.SetDrawColor(COL_EDGE)
            surface.DrawOutlinedRect(kx, ky, kw, kh, 1)

            -- Lange Beschriftungen brauchen die kleinere Schrift, sonst laufen
            -- sie ueber den Tastenrand hinaus.
            local font = (#entry.label > 3 or kw < unit) and "MLIB.10" or "MLIB.14"
            local textCol = (slot and (#slot.ours > 0 or slot.gmod))
                and COL_LABEL or COL_LABEL_DIM

            draw.SimpleText(entry.label, font, kx + kw / 2, ky + kh / 2,
                textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local lx = ox
        local ly = oy + GRID_H * unit + PD.H(4)

        lx = legend(lx, ly, COL_OURS, "Eigener Bind")
        lx = legend(lx, ly, COL_GMOD, "GMod-Standard")
        lx = legend(lx, ly, COL_BOTH, "Beides - Ueberschneidung")
        legend(lx, ly, COL_FREE, "Frei")

        if hovered then
            drawTooltip(self, mx, my, hovered, hoveredSlot)
        end
    end

    return panel
end

--------------------------------------------------------------------------------
-- Eigenes Fenster
--------------------------------------------------------------------------------

--[[
    Das Tastaturbild als eigenes Fenster rechts neben dem Belegungsfenster.

    Beide zusammen sind breiter als das Belegungsfenster allein, deshalb wird
    das Ankerfenster mit verschoben: sonst stuende das Paar aus der Mitte
    heraus und die Tastatur haenge halb ausserhalb des Bildschirms. Passt die
    volle Breite nicht, schrumpft das Tastaturfenster - verschoben wird es
    nicht, denn "rechts daneben" ist der Sinn der Sache.
]]
function PD.Binds:KeyboardWindow(anchor)
    if IsValid(self.keyboardFrame) then
        self.keyboardFrame:Remove()
    end

    local gap = PD.W(12)
    local kw, kh = PD.W(760), PD.H(400)

    local aw = IsValid(anchor) and anchor:GetWide() or 0
    local ah = IsValid(anchor) and anchor:GetTall() or 0

    kw = math.min(kw, ScrW() - aw - gap - PD.W(20))

    if kw < PD.W(320) then
        -- Zu wenig Platz fuer eine lesbare Tastatur. Lieber gar keine als eine
        -- mit unleserlichen Tasten.
        return nil
    end

    local frame = PD.Frame("Tastatur", kw, kh, true)

    local keyboard = PD.Binds:Keyboard(frame)
    keyboard:Dock(FILL)
    keyboard:DockMargin(PD.W(5), PD.H(5), PD.W(5), PD.H(5))

    if IsValid(anchor) then
        local _, ay = anchor:GetPos()
        local x = math.max(0, (ScrW() - (aw + gap + kw)) * 0.5)

        -- Senkrecht an der Oberkante ausrichten, aber nicht unten hinausragen.
        local y = math.Clamp(ay, 0, math.max(0, ScrH() - kh))

        anchor:SetPos(x, ay)
        frame:SetPos(x + aw + gap, y)

        --[[
            Die Eingabe gehoert zurueck ans Belegungsfenster: PD.Frame ruft
            MakePopup auf, das neue Fenster haette sonst den Fokus und der
            Binder darunter reagierte nicht auf den ersten Klick.
        ]]
        anchor:MakePopup()

        -- Mit dem Belegungsfenster wieder zu. Vorhandenes OnRemove nicht
        -- ueberschreiben, sondern davorhaengen.
        local previous = anchor.OnRemove

        anchor.OnRemove = function(pnl)
            if isfunction(previous) then previous(pnl) end

            if IsValid(PD.Binds.keyboardFrame) then
                PD.Binds.keyboardFrame:Remove()
            end
        end
    end

    self.keyboardFrame = frame

    return frame
end
