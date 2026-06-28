PD.VehicalInventory = PD.VehicalInventory or {}

PD.VehicalInventory.VehicleNames = {
    ["lvs_sw_transport"] = "Transporter"
}

PD.VehicalInventory.Interactions = {
    ["lvs_sw_transport"] = {
        [1] = {
            id = "open_inventory",
            name = "Öffne Fahrzeug Inventar",
            icon = nil,
            func = function(ply, ent, bone)
                PD.VehicalInventory.OpenInventory(ent)
            end,
            ad = {"static_prop"}
        }
    }
}

local function GetVehicleName(vehicle)
    return PD.VehicalInventory.VehicleNames[vehicle:GetClass()] or vehicle:GetClass()
end

local function CreateCargoRow(parent, index, slotData, vehicle)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:SetTall(PD.H(45))
    row:DockMargin(0, 0, 0, PD.H(5))

    row.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)

        surface.SetDrawColor(slotData and PD.Theme.Colors.AccentGreen or PD.Theme.Colors.AccentGray)
        surface.DrawRect(0, 0, PD.W(3), h)

        local text = slotData and slotData.name or ("Leerer Slot " .. index)
        local color = slotData and PD.Theme.Colors.Text or PD.Theme.Colors.TextMuted

        draw.DrawText(text, "MLIB.16", PD.W(15), h / 2 - PD.H(8), color, TEXT_ALIGN_LEFT)
    end

    if slotData then
        local btn = PD.Button("Entladen", row, function()
            net.Start("PD.VehicalInventory.UnloadEntity")
            net.WriteEntity(vehicle)
            net.WriteUInt(index, 8)
            net.SendToServer()
        end)
        btn:Dock(RIGHT)
        btn:SetWide(PD.W(110))
        btn:DockMargin(0, PD.H(5), PD.W(5), PD.H(5))
        btn:SetAccentColor(PD.Theme.Colors.AccentRed)
    end

    return row
end

local function CreateNearbyRow(parent, entry, vehicle)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:SetTall(PD.H(45))
    row:DockMargin(0, 0, 0, PD.H(5))

    row.Paint = function(self, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)

        surface.SetDrawColor(entry.frozen and PD.Theme.Colors.StatusInactive or PD.Theme.Colors.AccentBlue)
        surface.DrawRect(0, 0, PD.W(3), h)

        local text = entry.name
        if entry.frozen then
            text = text .. " (Eingefroren)"
        end

        draw.DrawText(text, "MLIB.16", PD.W(15), h / 2 - PD.H(8), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
    end

    local btn = PD.Button("Einladen", row, function()
        net.Start("PD.VehicalInventory.LoadEntity")
        net.WriteEntity(vehicle)
        net.WriteEntity(Entity(entry.entindex))
        net.SendToServer()
    end)
    btn:Dock(RIGHT)
    btn:SetWide(PD.W(110))
    btn:DockMargin(0, PD.H(5), PD.W(5), PD.H(5))
    btn:SetDisabled(entry.frozen)

    return row
end

local function RefreshFrame(state)
    local frame = PD.VehicalInventory.Frame
    local vehicle = PD.VehicalInventory.CurrentVehicle

    if not IsValid(frame) or not IsValid(vehicle) then return end

    frame.CargoScroll:Clear()
    for i = 1, state.cargo_slots do
        CreateCargoRow(frame.CargoScroll, i, state.cargo_space[i], vehicle)
    end

    frame.NearbyScroll:Clear()
    if table.IsEmpty(state.nearby) then
        local lbl = vgui.Create("DLabel", frame.NearbyScroll)
        lbl:Dock(TOP)
        lbl:SetTall(PD.H(30))
        lbl:SetText("Keine Objekte in der Nähe")
        lbl:SetTextColor(PD.Theme.Colors.TextMuted)
        lbl:SetFont("MLIB.14")
        lbl:SetContentAlignment(5)
    else
        for _, entry in ipairs(state.nearby) do
            CreateNearbyRow(frame.NearbyScroll, entry, vehicle)
        end
    end
end

function PD.VehicalInventory.OpenInventory(vehicle)
    if not IsValid(vehicle) then return end

    if IsValid(PD.VehicalInventory.Frame) then
        PD.VehicalInventory.Frame:Remove()
    end

    PD.VehicalInventory.CurrentVehicle = vehicle

    local frameWidth = ScrW() / 1.25

    local frame = PD.Frame(GetVehicleName(vehicle) .. " - Inventar", frameWidth, ScrH() / 1.25, true)
    PD.VehicalInventory.Frame = frame

    frame.OnRemove = function()
        if IsValid(PD.VehicalInventory.CurrentVehicle) then
            net.Start("PD.VehicalInventory.EndRequestItems")
            net.WriteEntity(PD.VehicalInventory.CurrentVehicle)
            net.SendToServer()
        end

        PD.VehicalInventory.CurrentVehicle = nil
    end

    local content = frame:GetContentPanel()

    local contentWidth = frameWidth - PD.W(30) -- Frame DockPadding links/rechts

    local leftPnl = vgui.Create("DPanel", content)
    leftPnl:Dock(LEFT)
    leftPnl:SetWide((contentWidth - PD.W(10)) / 2)
    leftPnl:DockMargin(0, 0, PD.W(5), 0)
    leftPnl.Paint = function() end

    PD.Label("Fahrzeug Inventar", leftPnl, {font = "MLIB.20", height = PD.H(35)})
    frame.CargoScroll = PD.Scroll(leftPnl)

    local rightPnl = vgui.Create("DPanel", content)
    rightPnl:Dock(FILL)
    rightPnl.Paint = function() end

    PD.Label("Umgebung (2 Meter)", rightPnl, {font = "MLIB.20", height = PD.H(35)})
    frame.NearbyScroll = PD.Scroll(rightPnl)

    net.Start("PD.VehicalInventory.StartRequestItems")
    net.WriteEntity(vehicle)
    net.SendToServer()
end

net.Receive("PD.VehicalInventory.UpdateRequestItems", function()
    local vehicle = net.ReadEntity()
    local state = net.ReadTable()

    if not IsValid(PD.VehicalInventory.CurrentVehicle) or PD.VehicalInventory.CurrentVehicle ~= vehicle then return end

    RefreshFrame(state)
end)

net.Receive("PD.VehicalInventory.ForceClose", function()
    local vehicle = net.ReadEntity()

    if PD.VehicalInventory.CurrentVehicle ~= vehicle then return end

    if IsValid(PD.VehicalInventory.Frame) then
        PD.VehicalInventory.Frame:Remove()
    end
end)

hook.Add("PD.Interaction.Requested", "PD.VehicalInventory.Interaction.Answer", function(ent_class)
    PD.IA.AddEntityActions(PD.VehicalInventory.Interactions[ent_class], "Fahrzeug Inventar")
end)
