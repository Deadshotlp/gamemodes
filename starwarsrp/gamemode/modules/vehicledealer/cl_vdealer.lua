PD.VD = PD.VD or {}

local SpwanTable = {}
local VehicleTable = {}

net.Start("PD.VD:Sync")
net.SendToServer()

net.Receive("PD.VD:Sync", function(len, ply)
    SpwanTable = net.ReadTable()
end)

local function VehicleDealerMenu()
    if IsValid(mainframe) then return end

    mainframe = PD.Frame("Vehicle Dealer", PD.W(900), PD.H(600), true)

    local rightPanel = PD.Panel("", mainframe)
    rightPanel:Dock(FILL)
    rightPanel:SetWide(PD.W(200))

    PD.SideTab(mainframe, rightPanel)

    PD.AddSideItem("Spawns", function(pnl)
        local scrl = PD.Scroll(pnl)

        for k, v in SortedPairs(SpwanTable) do
            local lbl = PD.Label(k, scrl)
        end
    end)

    PD.AddSideItem("Fahrzeuge", function(pnl)
        local addBtn = PD.Button("Add Vehicle", pnl, function()
            pnl:Clear()

            local scrl = PD.Scroll(pnl)

            local allVehicles = list.Get("Vehicles")

            local box = PD.ComboBox("Fahrzeug auswählen!", scrl, function()
                
            end)
            box:Dock(TOP)
            box:SetTall(PD.H(50))
            box:SetSearch(true)

            for k, v in pairs(allVehicles) do
                if v.Name and v.Name ~= "" then
                    box:AddChoice(v.Name, k)
                end
            end
        end)
        addBtn:Dock(TOP)
        addBtn:SetTall(PD.H(50))

        local scrl = PD.Scroll(pnl)
    end)

    PD.SelectItem("Fahrzeuge")
end

hook.Add("Tick", "PD.VD:VehicleDealerMenu", function()
    -- VehicleDealerMenu()
end)

if mainframe then
    mainframe:Remove()
end

