--

local Spawns = {}
local showSpawns = false

net.Receive("PDPlayerSpanwMenuOpen", function()
    Spawns = net.ReadTable()

    PlayerSpawnMenu()
end)

function PlayerSpawnMenu()
    if IsValid(base) then return end

    base = PD.Frame("Player Spawn Menu", PD.W(600), PD.H(600), true)

    local scrl = PD.Scroll(base)

    local Units = PD.JOBS.GetUnit(false, true)
    local unitTbl = {}

    for k, v in SortedPairs(Units) do
        local btn = PD.SimpleCheck(scrl, k, false, function(val)
            if val then 
                unitTbl[k] = {
                    pos = LocalPlayer():GetPos(),
                    ang = LocalPlayer():GetAngles()
                }
            else
                unitTbl[k] = nil
            end
        end)
        btn:Dock(TOP)
    end

    local deleteBtn = PD.Button("Spawns Löschen", base, function()
        unitTbl = {}

        net.Start("PDDeltePlayerSpawns")
        net.SendToServer()
    end)
    deleteBtn:Dock(BOTTOM)
    deleteBtn:SetTall(PD.H(50))

    local showBtn = PD.Button("Spawns Anzeigen", base, function()
        showSpawns = not showSpawns
    end)
    showBtn:Dock(BOTTOM)
    showBtn:SetTall(PD.H(50))

    local setBtn = PD.Button("Spawn Setzten", base, function()
        net.Start("PDPlayerSpawnSet")
        net.WriteTable(unitTbl)
        net.SendToServer()
    end)
    setBtn:Dock(BOTTOM)
    setBtn:SetTall(PD.H(50))
end

hook.Add("HUDPaint", "PlayerSpawnShow", function()
    if not showSpawns then return end
    if not LocalPlayer():IsAdmin() then return end

    for k, v in pairs(Spawns) do
        local pos = v.pos
        local ang = v.ang

        local pos = pos:ToScreen()
        local text = "Spawn: " .. k
        surface.SetFont("MLIB.20")
        local w, h = surface.GetTextSize(text)

        draw.RoundedBox(0, pos.x - w / 2 - PD.W(10), pos.y - PD.H(25), w + PD.W(20), PD.H(50), Color(0, 0, 0, 200))
        draw.SimpleText(text, "MLIB.20", pos.x, pos.y, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

hook.Add("Tick", "plss", function()
    -- PlayerSpawnMenu()
end)

if base then base:Remove() end

