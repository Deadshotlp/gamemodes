PD.DataPad = PD.DataPad or {}
PD.DataPad.Table = PD.DataPad.Table or {}

function PD.DataPad.AddCategory(name)
    if PD.DataPad.Table[name] then return end

    PD.DataPad.Table[name] = {}
end

function PD.DataPad.GetCategory(name)
    if not name then return PD.DataPad.Table end

    if not PD.DataPad.Table[name] then return {} end

    return PD.DataPad.Table[name]
end

function PD.DataPad.AddSubCategory(category, name)
    if not PD.DataPad.Table[category] then return end
    if PD.DataPad.Table[category][name] then return end

    PD.DataPad.Table[category][name] = {}
end

function PD.DataPad.GetSubCategory(category, name)
    if not PD.DataPad.Table[category] then return {} end

    if not PD.DataPad.Table[category][name] then return {} end

    return PD.DataPad.Table[category][name]
end

function PD.DataPad.AddEntry(category, subcategory, name, data)
    if not PD.DataPad.Table[category] then return end
    if not PD.DataPad.Table[category][subcategory] and subcategory then return end
    if not name or not data then return end

    if PD.DataPad.Table[category][subcategory] then
        PD.DataPad.Table[category][subcategory][name] = {}
        PD.DataPad.Table[category][subcategory][name] = data
    end
end

function PD.DataPad.GetEntry(category, subcategory, name)
    if not PD.DataPad.Table[category] then return nil end

    if subcategory then
        if not PD.DataPad.Table[category][subcategory] then return nil end
        return PD.DataPad.Table[category][subcategory][name]
    else
        return PD.DataPad.Table[category][name]
    end
end

function PD.DataPad.GetTable()
    return PD.DataPad.Table
end

if CLIENT then PrintTable(PD.DataPad.Table) end