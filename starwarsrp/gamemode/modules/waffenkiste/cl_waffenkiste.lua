PD.WB = PD.WB or {}

local function GetPlayerCheckWeapons(wep)
    local weps = {}
    local id, jobTbl = PD.JOBS.GetJob(LocalPlayer():GetJob())

    if jobTbl.equip[wep] then 
        return true
    end

    return false
end

local function GetWepsByCategory(category)
    local weps = {}
    for k, v in SortedPairs(PD.WB.Weapons) do
        if k == category then
            for wep, _ in SortedPairs(v) do
                if GetPlayerCheckWeapons(wep) then
                    table.insert(weps, wep)
                end
            end
        end
    end
    return weps
end

local function GetWepCategorys()
    local cate = {}
    for k, wep in SortedPairs(PD.WB.Weapons) do
        if #GetWepsByCategory(k) == 0 then
            continue
        end

        if not table.HasValue(cate, k) then
            table.insert(cate, k)
        end
    end
    return cate
end

local function GetPlayerWeapons(ply, wep)
    local weps = {}
    for _, wep in ipairs(ply:GetWeapons()) do
        table.insert(weps, wep:GetClass())
    end
    return weps
end

local activeWeapons = {}

local function GetWepWeights()
    local weights = 0

    for _, wep in pairs(activeWeapons) do
        local weight = PD.WB.GetWeaponWeights(wep)
        weights = weights + weight
    end

    return weights
end

function PD.WB:Menu()
    if IsValid(self.Frame) then
        return
    end

    self.Frame = PD.Frame("Waffenkiste", PD.W(800), PD.H(600), true)

    local leftPnl = PD.Panel("", self.Frame, function(self, w, h)
        draw.DrawText("Ausgerüstete Waffen", "MLIB.25", w/2, 10, Color(255,255,255), TEXT_ALIGN_CENTER)

        if #activeWeapons == 0 then
            draw.DrawText("Nichts ausgewählt", "MLIB.15", 10, 50, Color(255,255,255), TEXT_ALIGN_LEFT)
        else
            for i in #activeWeapons do
                draw.DrawText(activeWeapons[i], "MLIB.15", 10, 10 + i * 25, Color(255,255,255), TEXT_ALIGN_LEFT)
            end
        end

        draw.DrawText("Gewicht: " .. GetWepWeights() .. "/" .. PD.WB.MaxWeigth .. " Kg", "MLIB.25", w/2, h - 35, Color(255,255,255), TEXT_ALIGN_CENTER)
    end)
    leftPnl:Dock(LEFT)
    leftPnl:SetWide(PD.W(250))

    local rightPnl = PD.Panel("", self.Frame)
    rightPnl:Dock(FILL)

    local scrl = PD.Scroll(self.Frame)

    local categorys = GetWepCategorys()

    if #categorys == 0 then
        PD.Label("Keine Waffen verfügbar!", scrl)
        return
    end

    for _, cate in ipairs(categorys) do
        local weps = GetWepsByCategory(cate)
        if #weps == 0 then
            continue
        end

        local catBtn = PD.Button("", scrl, function()
            scrl:Clear()

            for _, wep in ipairs(weps) do
                local btn = PD.Button(wep, scrl, function()
                    scrl:Clear()

                    if GetWepWeights() + PD.WB.GetWeaponWeights(wep) > PD.WB.MaxWeigth then
                        PD.Notify("Du kannst nicht mehr als " .. PD.WB.MaxWeigth .. " Kg tragen!")
                        return
                    end

                    if activeWeapons[cate] then 
                        net.Start("PD.WB:RemoveWeapon")
                            net.WriteString(activeWeapons[cate])
                        net.SendToServer()
                    end

                    if LocalPlayer():HasWeapon(wep) then
                        net.Start("PD.WB:RemoveWeapon")
                            net.WriteString(wep)
                        net.SendToServer()
                        
                        activeWeapons[cate] = nil

                        self.Frame:Remove()
                        return
                    end

                    activeWeapons[cate] = wep

                    net.Start("PD.WB:GiveWeapon")
                        net.WriteString(wep)
                    net.SendToServer()

                    self.Frame:Remove()
                end)
                btn:Dock(TOP)

                if LocalPlayer():HasWeapon(wep) then
                    btn:SetBackColor(Color(0, 255, 0))
                    btn:SetText(wep .. " (Bereits im Besitz)")
                end
            end
        end, function(self, w, h)
            draw.DrawText(cate, "MLIB.25", w/2, 10, Color(255,255,255), TEXT_ALIGN_CENTER)

            if PD.WB.Weigths then 

            end

            draw.DrawText(activeWeapons[cate] or "Nichts ausgewählt", "MLIB.25", w/2, h - 35, Color(255,255,255), TEXT_ALIGN_CENTER)
        end)
        catBtn:Dock(TOP)
        catBtn:SetTall(PD.H(150))
    end
end

