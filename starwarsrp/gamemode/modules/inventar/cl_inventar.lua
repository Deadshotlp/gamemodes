-- Vollständiger Inventarcode mit Drag & Drop, Stack-Merge, Tooltips,
-- Armor-/Weapon-Slots, Kategorieprüfung und Rückverschiebung

PD.INV = PD.INV or {}

local Player_Table = {
    ["Inv"] = {
        ["ITEM_XYZ"] = {
            id = "ITEM_XYZ",
            name = "Item XYZ",
            size = 3,
            model = "models/props_c17/oildrum001.mdl",
            slot_pos = {x = 1, y = 1},
            amount = 4,
            type = "item",
        },
        ["ITEM_SMALL"] = {
            id = "ITEM_SMALL",
            name = "Item Small",
            size = 1,
            model = "models/props_junk/PopCan01a.mdl",
            slot_pos = {x = 5, y = 2},
            amount = 2,
            type = "weapon",
        }
    },
    ["InvArmor"] = {},
    ["InvWeapon"] = {}
}

function PD.INV:Menu()
    if IsValid(frame) then frame:Remove() end

    frame = PD.Frame("Inventar", PD.W(1200), PD.H(700), true)

    local InvPanel = PD.Panel("", frame)
    InvPanel:Dock(RIGHT)
    InvPanel:SetWide(PD.W(600))

    local InvArmor = PD.Panel("", frame)
    InvArmor:Dock(TOP)
    InvArmor:SetTall(PD.H(250))

    local InvWeapon = PD.Panel("", frame)
    InvWeapon:Dock(FILL)

    -- Slot-Grundfunktionen
    local gridW, gridH = 12, 13
    local slotSize = PD.H(50)
    local padding = 0

    InvPanel.Slots = {}
    InvPanel.OccupiedSlots = {}

    function InvPanel:OccupySlots(x, y, sizeX, sizeY, panel)
        for dx = 0, sizeX - 1 do
            for dy = 0, sizeY - 1 do
                self.OccupiedSlots[(x + dx) .. "_" .. (y + dy)] = panel
            end
        end
    end

    function InvPanel:ClearSlots(panel)
        for k, v in pairs(self.OccupiedSlots) do
            if v == panel then self.OccupiedSlots[k] = nil end
        end
    end

    function InvPanel:IsAreaFree(x, y, sizeX, sizeY)
        for dx = 0, sizeX - 1 do
            for dy = 0, sizeY - 1 do
                if self.OccupiedSlots[(x + dx) .. "_" .. (y + dy)] then return false end
            end
        end
        return true
    end

    -- Gitter zeichnen
    for y = 1, gridH do
        for x = 1, gridW do
            local slot = PD.Panel("", InvPanel)
            slot:SetSize(slotSize, slotSize)
            slot:SetPos((x - 1) * (slotSize + padding), (y - 1) * (slotSize + padding))
            slot:Dock(NODOCK)
            slot.Paint = function(self, w, h)
                surface.SetDrawColor(self:IsHovered() and 255 or 50, 50, 50, 100)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(100, 100, 100, 180)
                surface.DrawOutlinedRect(0, 0, w, h)
            end
            InvPanel.Slots[y] = InvPanel.Slots[y] or {}
            InvPanel.Slots[y][x] = slot
        end
    end

    -- Slot mit Label erstellen
    local function CreateLabeledSlot(parent, labelText, x, y, w, h, acceptedTypes)
        local container = vgui.Create("DPanel", parent)
        container:SetSize(w, h + 20)
        container:SetPos(x, y)
        container.Paint = nil

        local label = vgui.Create("DLabel", container)
        label:SetText(labelText)
        label:SetFont("DermaDefaultBold")
        label:SetColor(color_white)
        label:SizeToContents()
        label:SetPos((w - label:GetWide()) / 2, 0)

        local slot = PD.Panel("", container)
        slot:SetSize(w, h)
        slot:SetPos(0, 20)
        slot.AcceptedTypes = acceptedTypes or {"all"}
        slot.Item = nil
        slot.Paint = function(self, w, h)
            surface.SetDrawColor(self:IsHovered() and 255 or 50, 50, 50, 100)
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(100, 100, 100, 180)
            surface.DrawOutlinedRect(0, 0, w, h)
        end

        return slot
    end

    -- Armor-Slots erstellen
    local armorSlotSize = PD.H(50)
    local armorSlotData = {
        { name = "Kopf",    x = 0, y = 0 },
        { name = "Körper",  x = 80, y = 0 },
        { name = "Beine",   x = 160, y = 0 },
        { name = "Rücken",  x = 240, y = 0 },
    }

    for _, data in ipairs(armorSlotData) do
        CreateLabeledSlot(InvArmor, data.name, data.x, data.y, armorSlotSize, armorSlotSize, {"armor"})
    end

    -- Weapon-Slots gruppiert
    local weaponSlotSize = PD.H(50)
    local weaponSlotGroups = {
        { label = "Primär", slots = { { name = "1", x = 0 }, { name = "2", x = 50 }, { name = "3", x = 100 } }, y = 0, types = {"weapon"} },
        { label = "Sekundär", slots = { { name = "Sek", x = 0 } }, y = 90, types = {"weapon"} },
        { label = "Pistole", slots = { { name = "Pistole", x = 0, w = 120 } }, y = 180, types = {"weapon"} },
        { label = "Granaten", slots = { { name = "G1", x = 0 }, { name = "G2", x = 80 } }, y = 270, types = {"grenade", "ammo"} }
    }

    for _, group in ipairs(weaponSlotGroups) do
        for _, s in ipairs(group.slots) do
            CreateLabeledSlot(InvWeapon, s.name, s.x, group.y, weaponSlotSize, weaponSlotSize, group.types)
        end
    end

    -- Items erzeugen
    for id, itemData in pairs(Player_Table["Inv"]) do
        local size = itemData.size or 1
        local pos = itemData.slot_pos or {x = 1, y = 1}
        itemData.id = id
        local icon = vgui.Create("DModelPanel", InvPanel)
        icon:SetSize(slotSize * size, slotSize)
        icon:SetPos((pos.x - 1) * (slotSize + padding), (pos.y - 1) * (slotSize + padding))
        icon:SetModel(itemData.model)
        icon:SetFOV(35)
        icon:SetCamPos(Vector(30, 20, 20))
        icon:SetLookAt(Vector(0, 0, 0))
        icon.ItemData = itemData
        icon.SlotPos = pos

        -- Tooltip
        icon:SetTooltip("Name: " .. itemData.name .. "\nAnzahl: " .. itemData.amount)

        -- Anzahl anzeigen
        function icon:PaintOver(w, h)
            surface.SetDrawColor(255, 255, 255, 10)
            surface.DrawOutlinedRect(0, 0, w, h)
            if self.ItemData.amount > 1 then
                draw.SimpleText(tostring(self.ItemData.amount), "DermaDefault", w - 4, h - 2, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
            end
        end

        -- Rechtsklick: Stapel teilen
        icon.OnMousePressed = function(self, code)
            if code == MOUSE_RIGHT and self.ItemData.amount > 1 then
                local menu = DermaMenu()
                menu:AddOption("Stapel teilen", function() PD.INV:SplitStack(self) end)
                menu:Open()
            elseif code == MOUSE_LEFT then
                self:MouseCapture(true)
                self.Dragging = true
                self.DragOffset = self:ScreenToLocal(gui.MouseX(), gui.MouseY())
                InvPanel:ClearSlots(self)
            end
        end

        -- Drag
        icon.Think = function(self)
            if self.Dragging then
                local mx, my = gui.MouseX(), gui.MouseY()
                local lx, ly = self:GetParent():ScreenToLocal(mx, my)
                self:SetPos(lx - self.DragOffset, ly - self.DragOffset)
            end
        end

        -- Drop
        icon.OnMouseReleased = function(self)
            if not self.Dragging then return end
            self:MouseCapture(false)
            self.Dragging = false

            local lx, ly = self:GetPos()
            local newX = math.floor(lx / (slotSize + padding)) + 1
            local newY = math.floor(ly / (slotSize + padding)) + 1

            -- Merge-Check
            for _, other in pairs(InvPanel:GetChildren()) do
                if other ~= self and other.ItemData and other.ItemData.name == self.ItemData.name then
                    if math.abs(other:GetX() - self:GetX()) < slotSize and math.abs(other:GetY() - self:GetY()) < slotSize then
                        other.ItemData.amount = other.ItemData.amount + self.ItemData.amount
                        self:Remove()
                        surface.PlaySound("buttons/button5.wav")
                        return
                    end
                end
            end

            -- Drop auf Equipment Slot?
            local dropTarget = vgui.GetHoveredPanel()
            if dropTarget and dropTarget.AcceptedTypes and table.HasValue(dropTarget.AcceptedTypes, self.ItemData.type or "item") then
                dropTarget.Item = self
                self:SetParent(dropTarget)
                self:SetPos(0, 0)
                surface.PlaySound("buttons/button15.wav")
                return
            end

            -- Drop ins Grid prüfen
            if newX < 1 or newY < 1 or newX + size - 1 > gridW or newY > gridH then
                self:SetPos((self.SlotPos.x - 1) * (slotSize + padding), (self.SlotPos.y - 1) * (slotSize + padding))
                InvPanel:OccupySlots(self.SlotPos.x, self.SlotPos.y, size, 1, self)
                surface.PlaySound("buttons/button10.wav")
                return
            end

            if InvPanel:IsAreaFree(newX, newY, size, 1) then
                self:SetPos((newX - 1) * (slotSize + padding), (newY - 1) * (slotSize + padding))
                self.SlotPos = {x = newX, y = newY}
                InvPanel:OccupySlots(newX, newY, size, 1, self)
                surface.PlaySound("buttons/button15.wav")
            else
                self:SetPos((self.SlotPos.x - 1) * (slotSize + padding), (self.SlotPos.y - 1) * (slotSize + padding))
                InvPanel:OccupySlots(self.SlotPos.x, self.SlotPos.y, size, 1, self)
                surface.PlaySound("buttons/button10.wav")
            end
        end

        InvPanel:OccupySlots(pos.x, pos.y, size, 1, icon)
    end
end

-- Stapel teilen Funktion
function PD.INV:SplitStack(itemPanel)
    if IsValid(self.SplitFrame) then self.SplitFrame:Remove() end
    local maxAmount = itemPanel.ItemData.amount
    local amountToSplit = 1
    local frame = vgui.Create("DFrame")
    self.SplitFrame = frame
    frame:SetTitle("Stapel teilen")
    frame:SetSize(200, 100)
    frame:Center()
    frame:MakePopup()

    local label = vgui.Create("DLabel", frame)
    label:SetText("Anzahl: " .. amountToSplit)
    label:SetPos(20, 35)
    label:SizeToContents()

    frame.OnMouseWheeled = function(_, delta)
        amountToSplit = math.Clamp(amountToSplit + delta, 1, maxAmount - 1)
        label:SetText("Anzahl: " .. amountToSplit)
        label:SizeToContents()
    end

    local button = vgui.Create("DButton", frame)
    button:SetText("Aufteilen")
    button:SetSize(160, 25)
    button:SetPos(20, 60)
    button.DoClick = function()
        itemPanel.ItemData.amount = itemPanel.ItemData.amount - amountToSplit
        local newItemData = table.Copy(itemPanel.ItemData)
        newItemData.amount = amountToSplit
        local newID = "ITEM_" .. math.random(1000, 9999)
        Player_Table["Inv"][newID] = newItemData
        frame:Close()
        PD.INV:Menu()
    end
end

if frame then frame:Remove() end

-- PD.INV:Menu()
