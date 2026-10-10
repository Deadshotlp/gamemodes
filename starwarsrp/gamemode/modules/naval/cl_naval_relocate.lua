--[[
    Naval - Umstationieren (Client, Stufe 4f): Konsole "Umstationierung".
    Auf dem Schiff: Maps des Planeten im Orbit waehlen und freigeben; auf der
    Planeten-Map: Rueckflug freigeben. Zustand per PD.Naval.RelocateState
    (sv_naval_relocate.lua), auch ohne laufende Simulation.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local state = {}

net.Receive("PD.Naval.RelocateState", function()
    state = util.JSONToTable(net.ReadString()) or {}
end)

local function Send(action, id)
    net.Start("PD.Naval.Relocate")
    net.WriteString(action)
    net.WriteUInt(id or 0, 32)
    net.SendToServer()
end

Naval.RelocateSend = Send
function Naval.RelocateGetState() return state end

local function OpenRelocation(console)
    local UI = Naval.UI
    local COL = UI.COL
    local frame = UI.Frame("UMSTATIONIERUNG", 900, 600)
    frame.Console = console
    state = {}
    Send("state")

    local head = vgui.Create("DPanel", frame)
    head:SetPos(20, 55)
    head:SetSize(frame:GetWide() - 40, 130)
    head.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL.panel)
        local a = state.armed
        if a then
            if a.countdown then
                draw.SimpleText(("MAPWECHSEL IN %d s"):format(a.countdown), "MLIB.22", 14, 14, COL.warn)
            else
                draw.SimpleText((a.back and "Rückflug zum Schiff" or ("Umstationierung nach " .. a.name)) .. " freigegeben", "MLIB.18", 14, 12, COL.ok)
                draw.SimpleText(("Noch %d:%02d min. Mit einem Fahrzeug (Spieler an Bord) an den Rand der Map fliegen%s.")
                    :format(math.floor(a.remaining / 60), a.remaining % 60, a.back and "" or " - auf der Seite, hinter der der Planet liegt"),
                    "MLIB.14", 14, 42, COL.text)
                draw.SimpleText("Beim Mapwechsel gehen alle Spieler mit.", "MLIB.14", 14, 64, COL.dim)
            end
        elseif state.mode == "ship" and state.body then
            draw.SimpleText("Im Orbit: " .. state.body, "MLIB.18", 14, 12, COL.accent)
            draw.SimpleText("Landezone wählen und freigeben. Danach mit einem Schiff in Richtung des Planeten aus der Map fliegen.", "MLIB.14", 14, 42, COL.text)
        elseif state.mode == "planet" and state.back then
            draw.SimpleText("Auf " .. (state.back.body or "dem Planeten"), "MLIB.18", 14, 12, COL.accent)
            draw.SimpleText("Rückflug zum Schiff freigeben, dann mit einem Schiff an den Rand der Map fliegen.", "MLIB.14", 14, 42, COL.text)
        else
            draw.SimpleText(state.reason or "Lade ...", "MLIB.14", 14, 14, COL.dim)
        end
    end

    local cancel = UI.Button(head, "Freigabe abbrechen", function() Send("cancel") end, function() return COL.bad end)
    cancel:SetPos(head:GetWide() - 234, 86) cancel:SetSize(220, 32)

    local back = UI.Button(head, "Rückflug freigeben", function()
        Derma_Query("Rückflug zum Schiff freigeben? Beim Mapwechsel gehen alle Spieler mit.", "Umstationierung",
            "Freigeben", function() Send("arm") end, "Abbrechen")
    end, function() return COL.ok end)
    back:SetPos(14, 86) back:SetSize(260, 32)

    local list = vgui.Create("DScrollPanel", frame)
    list:SetPos(20, 195)
    list:SetSize(frame:GetWide() - 40, frame:GetTall() - 215)

    local rows = {}
    for i = 1, 12 do
        local row = list:Add("DPanel")
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 6)
        row:SetTall(62)
        row.Paint = function(s, w, h)
            local m = s.Entry
            if not m then return end
            draw.RoundedBox(0, 0, 0, w, h, COL.panel)
            draw.SimpleText(m.name, "MLIB.18", 12, 6, m.exists and COL.text or COL.dim)
            draw.SimpleText(m.description ~= "" and m.description or m.map, "MLIB.12", 12, 32, COL.dim)
            if not m.exists then draw.SimpleText("Map fehlt auf dem Server", "MLIB.12", w - 220, 8, COL.bad) end
        end
        local go = UI.Button(row, "Umstationieren", function()
            local m = row.Entry
            if not m then return end
            Derma_Query("Umstationierung nach " .. m.name .. " freigeben? Beim Mapwechsel gehen alle Spieler mit.", "Umstationierung",
                "Freigeben", function() Send("arm", m.id) end, "Abbrechen")
        end, function() return COL.accent end)
        go:SetSize(190, 34)
        go:SetPos(list:GetWide() - 210, 14)
        row.Go = go
        rows[i] = row
    end

    local nextPoll = 0
    local baseThink = frame.Think
    frame.Think = function(s)
        if baseThink then baseThink(s) end
        if not IsValid(s) then return end
        if CurTime() > nextPoll then
            nextPoll = CurTime() + 1
            net.Start("PD.Naval.RelocateState")
            net.SendToServer()
        end
        local maps = state.maps or {}
        for i, row in ipairs(rows) do
            row.Entry = maps[i]
            row:SetVisible(maps[i] ~= nil)
            row.Go.Disabled = state.armed ~= nil or not (maps[i] and maps[i].exists)
        end
        cancel:SetVisible(state.armed ~= nil and not state.armed.countdown)
        back:SetVisible(state.mode == "planet" and state.armed == nil)
    end
end

Naval.StationUI = Naval.StationUI or {}
Naval.StationUI.relocation = OpenRelocation
