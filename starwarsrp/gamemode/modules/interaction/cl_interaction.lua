PD.IA = PD.IA or {}
PD.IA.LastEntity = nil
PD.IA.CurrentBone = {
    index = 0,
    select_time = nil,
    looked_at = false,
    sub_menus = {}
}

local kreis = Material("icons/kreis.png")

local function CheckForSelected(tbl)
    for k,v in pairs(tbl) do
        if v.selected then
            return k
        end
    end
    
    return nil
end

-- Recursively searches for the first item where 'selected' is true.
-- Returns the actual item table if found, otherwise nil.
local function GetSelectedMenuItem(tbl)
    if not tbl then return nil end -- Guard against nil table input

    for key, item in pairs(tbl) do
        if item.selected then
            -- Check if this selected item has sub-menus and if an item is selected within them
            -- Use next(table) to correctly check if a table is empty
            if item.sub_menus and next(item.sub_menus) then
                local deeper_selection = GetSelectedMenuItem(item.sub_menus)
                -- If a selection was found deeper, return that one
                if deeper_selection then
                    return deeper_selection
                end
            end
            -- If no deeper selection, this is the one we want
            return item
        end
    end

    -- No selected item found in this table level
    return nil
end

local function AddChild(tbl, id, name, icon, func)
    local child = {
        name = name or "",
        icon = icon or nil,
        func = func or nil,
        selected = false,
        sub_menus = {},
    }
    tbl[id] = child
end

local function AddSubMenu(tbl1,tbl2) 
    for k, v in pairs(tbl2) do
        AddChild(tbl1.sub_menus, v.id, v.name, v.icon, v.func)
    end
end

local function ResetBoneInfo()
    PD.IA.CurrentBone = {
        index = 0,
        select_time = nil,
        looked_at = false,
        sub_menus =  {}
    }
end

local function DrawSelectedEffect(tbl, index)
    local color = Color(255, 255, 255, 255)

    if tbl[index].selected then
        local sin_wave = math.sin( CurTime() * 5 )
        local alpha = math.Clamp( (sin_wave + 1) * 0.5 * 255, 0, 255 )
        color = Color(255, 0, 0, alpha)
    end

    return color
end

local function DrawSubMenu(tbl, x, y, scale)
    local start_y = y + ((scale / 2) * #tbl + 1)
    local curent_y
    local curent_x = x
    local count = 0
    local mous_x, mous_y = input.GetCursorPos()
    local length = 0

    for k, v in pairs(tbl) do
        curent_x = x
        curent_y = start_y - (scale * count)
        count = count + 1

        local color = DrawSelectedEffect(tbl, k)

        surface.SetDrawColor(color)
        surface.SetTextColor(color)

        if v.icon ~= nil then
            surface.SetMaterial(Material("icons/" .. v.icon .. ".png"))
            surface.DrawTexturedRect(curent_x, curent_y, scale, scale)
            curent_x = curent_x + scale + 5

            length = scale
        end

        surface.SetTextPos( curent_x, curent_y )
        surface.DrawText(v.name)

        local widht, height = surface.GetTextSize(v.name)

        length = length + widht

        if v.selected and v.sub_menus ~= {} then
            DrawSubMenu(v.sub_menus, curent_x + length, curent_y, scale)
        end

        if mous_x >= x and mous_x <= curent_x + widht and mous_y >= curent_y and mous_y <= curent_y + height then
            local result = CheckForSelected(tbl)

            if result ~= nil and result ~= k then
                tbl[result].selected = false
            end
            v.selected = true
        end
    end
end

local function DrawOptions(x, y, bone, index)
    if bone.groups then
        local tbl = {}
        tbl = string.Split(bone.groups, ",")

        for k, v in pairs(tbl) do
            if v == "general" and not PD.IA.CurrentBone.sub_menus["general"] then
                AddChild(PD.IA.CurrentBone.sub_menus, "general", "General Actions")
            elseif v == "medic" and not PD.IA.CurrentBone.sub_menus["medic"] then
                AddChild(PD.IA.CurrentBone.sub_menus, "medic", "Medical Actions", "symbol4")
                AddSubMenu(PD.IA.CurrentBone.sub_menus["medic"], PD.DM.GetInteractions(index))
            end
        end
    end

    for k, v in pairs(bone.additional) do
        AddChild(PD.IA.CurrentBone.sub_menus, v.id, v.name, v.icon, v.func)
    end

    --PrintTable(PD.IA.CurrentBone.sub_menus)

    local scale = 25
    local draw_x = x + 75
    local draw_y = y

    DrawSubMenu(PD.IA.CurrentBone.sub_menus, draw_x, draw_y, scale)
end

hook.Add("PostDrawHUD", "PD.IA.ShowBoons", function()
    if input.IsButtonDown(KEY_RSHIFT) then
        local ply = LocalPlayer()
        local vac1 = ply:GetPos() - Vector(250, 250, 250)
        local vac2 = ply:GetPos() + Vector(250, 250, 250)
        local trace = ply:GetEyeTrace()
        local ent = trace.Entity

        if not ent:IsValid() and not PD.IA.CurrentBone.looked_at then return end
        
        if PD.IA.LastEntity == nil or not PD.IA.LastEntity.ent == ent then
            PD.IA.LastEntity = {}
            net.Start("PD.IA.RequestEntityInformation")
            net.WriteEntity(ply)
            net.WriteEntity(ent)
            net.SendToServer()
        end

        if PD.IA.LastEntity and PD.IA.LastEntity.bones then
            if ply:GetPos():Distance(PD.IA.LastEntity.ent:GetPos()) >= 100 then
                return
            end

            for k, v in pairs(PD.IA.LastEntity.bones) do
                if PD.IA.LastEntity.ent:LookupBone(v["name"]) == nil then continue end

                local mouseX, mouseY = input.GetCursorPos()
                local pos = PD.IA.LastEntity.ent:GetBonePosition(PD.IA.LastEntity.ent:LookupBone(v["name"])):ToScreen()
                local size_x, size_y = 25, 25

                -- Berechne den Mittelpunkt des Bereichs
                local centerX = pos.x
                local centerY = pos.y
                local radius = 25
                local radiusSquared = radius * radius -- Quadrierter Radius für effizienteren Vergleich
                
                -- Berechne die quadrierte Distanz vom Mauszeiger zum Mittelpunkt
                local distanceSquared = (mouseX - centerX)^2 + (mouseY - centerY)^2

                local rotation = 0
                
                -- Prüfe, ob die quadrierte Distanz kleiner oder gleich dem quadrierten Radius ist
                if distanceSquared <= radiusSquared or (not PD.IA.CurrentBone.looked_at or PD.IA.CurrentBone.index == k) then
                    if PD.IA.CurrentBone.index ~= k then
                        PD.IA.CurrentBone.sub_menus = {}
                    end
                
                    DrawOptions(centerX, centerY , v.interactions, k) -- Optionen am Mittelpunkt zeichnen

                    size_x, size_y = 50, 50
                    surface.SetDrawColor(255, 0, 0, 255) -- Rot, wenn im Kreis
                    rotation = (CurTime() * 50) % 360
                
                    PD.IA.CurrentBone.index = k
                    PD.IA.CurrentBone.looked_at = true
                else
                    if PD.IA.CurrentBone.index == k then
                        ResetBoneInfo()
                    end
                    surface.SetDrawColor(0, 255, 255, 255) -- Weiß, wenn außerhalb
                end
                
                surface.SetMaterial(kreis)
                surface.DrawTexturedRectRotated(centerX, centerY, size_x, size_y, rotation)
            end
        else
            ResetBoneInfo()
        end
    elseif PD.IA.CurrentBone and PD.IA.CurrentBone.looked_at then
        -- Find the actual selected menu item data
        local selected_item = GetSelectedMenuItem(PD.IA.CurrentBone.sub_menus)

        -- If an item was selected and it has a function, call it
        if selected_item and selected_item.func then
            selected_item.func(LocalPlayer(), PD.IA.LastEntity.ent, PD.IA.CurrentBone.index)
        end

        ResetBoneInfo()
    elseif PD.IA.LastEntity ~= nil then
        PD.IA.LastEntity = nil
    end
end)

net.Receive("PD.IA.SendEntityInformation", function()
    local tbl = net.ReadTable()
    PD.IA.LastEntity = tbl
end)
