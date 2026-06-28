PD.WB = PD.WB or {}

local function GetWepsByCategory(category)
    local weps = {}
    local JobID, JobTable = LocalPlayer():GetJob()
    local name, subunit = PD.JOBS.GetSubUnit(JobTable.unit)
    local jobWeps = JobTable.equip or {}
    local subunitWeps = subunit.equip or {}

    for _, wep in SortedPairs(subunitWeps) do
        if PD.WB.Weapons[category] and PD.WB.Weapons[category][wep] then
            table.insert(weps, wep)
        end
    end

    --table.Add(jobWeps, subunitWeps)

    for num, wep in SortedPairs(jobWeps) do
        if PD.WB.Weapons[category] and PD.WB.Weapons[category][wep] then
            table.insert(weps, wep)
        end
    end
    
    return weps
end

local function GetWepCategorys()
    local cate = {}
    for k, wep in SortedPairs(PD.WB.Weapons) do
        local weps = GetWepsByCategory(k)

        if table.IsEmpty(weps) then continue end

        cate[k] = weps
    end
    return cate
end

local function GetPlayerWeapons(ply, wep)
    local weps = {}
    local JobName, JobTable = ply:GetJob()
    local name, subunit = PD.JOBS.GetSubUnit(JobTable.unit)

    for _, wep in SortedPairs(JobTable.equip) do
        table.insert(weps, wep)
    end
    for _, wep in SortedPairs(subunit.equip) do
        table.insert(weps, wep)
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

    local leftPnl = PD.Panel(self.Frame)
    leftPnl:Dock(LEFT)
    leftPnl:SetWide(PD.W(250))

    local lbl = PD.Label("Ausgerüstete Waffen", leftPnl, {
        font = "MLIB.25",
        height = PD.H(40),
    })

    local scrl = PD.Scroll(leftPnl)

    local yOffset = PD.H(50)
    for cateName, wep in SortedPairs(activeWeapons) do
        local wepWeight = PD.WB.GetWeaponWeights(wep)
        -- wep = wep:GetPrintName() or wep:GetClass()
        local wepText = wep -- .. " (" .. wepWeight .. " Kg)"
        local btn = PD.Button(wepText, scrl, function()
            net.Start("PD.WB:RemoveWeapon")
                net.WriteString(wep)
            net.SendToServer()

            table.RemoveByValue(activeWeapons[cateName], wep)

            self.Frame:Remove()
        end)
        btn:Dock(TOP)
        btn:SetTall(PD.H(50))
        btn:SetPos(PD.W(10), yOffset)
        btn:SetAccentColor(Color(0, 255, 0))
        yOffset = yOffset + PD.H(110)
    end

    local WeaponWeight = GetWepWeights() .. " / " .. PD.WB.MaxWeigth .. " Kg"

    local lbl = PD.Label(WeaponWeight, leftPnl, {
        font = "MLIB.25",
        height = PD.H(40),
        dock = BOTTOM
    })

    local rightPnl = PD.Panel(self.Frame)
    rightPnl:Dock(FILL)

    local scrl = PD.Scroll(self.Frame)

    local categorys = GetWepCategorys()

    if table.IsEmpty(categorys) then
        PD.Label("Keine Waffen verfügbar!", scrl)
        return
    end

    for cateName, weps in SortedPairs(categorys) do
        local catBtn = PD.Button(cateName, scrl, function()
            scrl:Clear()

            for _, wep in ipairs(weps) do
                -- wep = wep:GetPrintName() or wep:GetClass()
                local activeWep = wep

                if LocalPlayer():HasWeapon(wep) then
                    activeWep = wep .. " (Bereits im Besitz)"
                end

                local btn = PD.Button(activeWep, scrl, function()
                    scrl:Clear()

                    if not activeWeapons[cateName] then
                        activeWeapons[cateName] = {}
                    end

                    if GetWepWeights() + PD.WB.GetWeaponWeights(wep) > PD.WB.MaxWeigth then
                        PD.Popup("Du kannst nicht mehr als " .. PD.WB.MaxWeigth .. " Kg tragen!")
                        return
                    end

                    -- if activeWeapons[cateName] then 
                    --     net.Start("PD.WB:RemoveWeapon")
                    --         net.WriteString(activeWeapons[cateName])
                    --     net.SendToServer()
                    -- end

                    if LocalPlayer():HasWeapon(wep) then
                        net.Start("PD.WB:RemoveWeapon")
                            net.WriteString(wep)
                        net.SendToServer()
                        
                        table.RemoveByValue(activeWeapons[cateName], wep)

                        self.Frame:Remove()
                        return
                    end

                    if PD.WB.CategoryAmount[cateName] and table.Count(activeWeapons[cateName]) >= PD.WB.CategoryAmount[cateName] then
                        PD.Popup("Du kannst nur " .. PD.WB.CategoryAmount[cateName] .. " Waffen aus der Kategorie " .. cateName .. " tragen!")
                        return
                    end

                    table.insert(activeWeapons[cateName], wep)

                    net.Start("PD.WB:GiveWeapon")
                        net.WriteString(wep)
                    net.SendToServer()

                    self.Frame:Remove()
                end)
                btn:Dock(TOP)

                if LocalPlayer():HasWeapon(wep) then
                    btn:SetAccentColor(Color(0, 255, 0))
                end
            end
        end)
        catBtn:Dock(TOP)
        catBtn:SetTall(PD.H(150))
    end
end

concommand.Add("pd_waffenkiste_Prints", function()
    -- Waffen von Spieler
    local jobName, jobTable = LocalPlayer():GetJob()
    PrintTable(jobTable)

    print("Spieler Waffen:")
    PrintTable(GetPlayerWeapons(LocalPlayer()))

    -- print("Waffen Kategorien:")
    -- PrintTable(GetWepCategorys())

    print("Waffen nach Kategorie:")
    for cateName, weps in SortedPairs(GetWepCategorys()) do
        print("Kategorie: " .. cateName)
        PrintTable(GetWepsByCategory(cateName))
    end
end)

for k, v in pairs(player.GetAll()) do
    print(v:SteamID64())
end