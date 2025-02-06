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

function PD.DataPad.AddEntry(category, name, data)
    if not PD.DataPad.Table[category] then return end

    PD.DataPad.Table[category][name] = data
end

function PD.DataPad.GetEntry(category, name)
    if not PD.DataPad.Table[category] then return end

    if name then
        return PD.DataPad.Table[category][name]
    end

    return PD.DataPad.Table[category]
end

function PD.DataPad.CheckEntry(category, name)
    if not PD.DataPad.Table[category] then return print("NIcht gefunden") end

    return PD.DataPad.Table[category][name] and true or false
end

if CLIENT then 
    concommand.Add("print_getEntry", function()
        PrintTable(PD.DataPad.GetEntry("Akten"))
    end)

    concommand.Add("print_datapadtable", function()
        PrintTable(PD.DataPad.Table)
    end)
end