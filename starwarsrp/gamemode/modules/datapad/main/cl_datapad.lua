PD.DataPad = PD.DataPad or {}

PD.DataPad.History = PD.DataPad.History or {}

function PD.DataPad:Menu(category, subcategory, entry)
    if IsValid(mainFrame) then return end

    mainFrame = PD.Frame("Datapad", PD.W(700), PD.H(900), true)

    mainFrame.OnClose = function()
        PD.DataPad.History = {}
    end

    local pnl = PD.Panel("", mainFrame)
    pnl:Dock(FILL)

    if #PD.DataPad.History > 0 then
        local backBtn = PD.Button("Zurück", pnl, function()
            local last = table.remove(PD.DataPad.History)
            if last then
                DataPadMenu(last.category, last.subcategory, last.entry)
            else
                DataPadMenu()
            end
        end)
        backBtn:Dock(BOTTOM)
        backBtn:SetTall(PD.H(40))
    end

    local scrl = PD.Scroll(pnl)

    -- === EINTRAG anzeigen ===
    if category and subcategory and entry then
        PD.DataPad.GetEntry(category, subcategory, entry)(pnl)
        return
    end

    -- === EINTRAGSLISTE (Subkategorie) anzeigen ===
    if category and subcategory then
        local data = PD.DataPad.GetSubCategory(category, subcategory)
        local x, y = PD.W(10), PD.H(10)
        for entryName, entryFunc in SortedPairs(data) do
            local entryBtn = PD.Button(entryName, scrl, function()
                table.insert(PD.DataPad.History, {category = category, subcategory = subcategory})
                DataPadMenu(category, subcategory, entryName)
            end)
            entryBtn:SetPos(x, y)
            entryBtn:SetSize(PD.W(150), PD.H(150))
            entryBtn:SetRadius(20)
            entryBtn:DockMargin(0, 0, 0, PD.H(10))

            x = x + PD.W(150) + PD.W(10)
            if x + PD.W(150) > PD.W(700) then
                x = 0
                y = y + PD.H(50) + PD.H(10)
            end
        end
        return
    end

    -- === SUBKATEGORIEN anzeigen ===
    if category then
        local data = PD.DataPad.GetCategory(category)
        local x, y = PD.W(10), PD.H(10)
        for subcatName, subData in SortedPairs(data) do
            local subcategoryBtn = PD.Button(subcatName, scrl, function()
                table.insert(PD.DataPad.History, {category = category})
                DataPadMenu(category, subcatName)
            end)
            subcategoryBtn:SetPos(x, y)
            subcategoryBtn:SetSize(PD.W(150), PD.H(150))
            subcategoryBtn:SetRadius(20)
            subcategoryBtn:DockMargin(0, 0, 0, PD.H(10))

            x = x + PD.W(150) + PD.W(10)
            if x + PD.W(150) > PD.W(700) then
                x = 0
                y = y + PD.H(50) + PD.H(10)
            end
        end
        return
    end


    if table.Count(PD.DataPad.History) > 0 then return end
    -- === KATEGORIEN-ÜBERSICHT ===
    local x, y = PD.W(10), PD.H(10)
    for catName, catData in SortedPairs(PD.DataPad.GetTable()) do
        local catBtn = PD.Button(catName, scrl, function()
            table.insert(PD.DataPad.History, {})
            DataPadMenu(catName)
        end)
        catBtn:SetPos(x, y)
        catBtn:SetSize(PD.W(150), PD.H(150))
        catBtn:SetRadius(20)
        catBtn:DockMargin(0, 0, 0, PD.H(10))

        x = x + PD.W(150) + PD.W(10)
        if x + PD.W(150) > PD.W(700) then
            x = 0
            y = y + PD.H(50) + PD.H(10)
        end
    end
end

function DataPadMenu(category, subcategory, entry)
    if IsValid(mainFrame) then
        mainFrame:Remove()
    end

    PD.DataPad:Menu(category, subcategory, entry)
end


hook.Add("Tick", "PD.DataPad:Menu", function()
    -- PD.DataPad:Menu()
end)

if mainFrame then
    mainFrame:Remove()
end

