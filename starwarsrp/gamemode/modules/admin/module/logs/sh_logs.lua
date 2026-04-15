PD.LOGS = PD.LOGS or {}

-- PD.LOGS.Tbl = {
--     {
--         text = "Test",
--         color = Color(255,255,255),
--         time = os.time(),
--         date = os.date("%d.%m.%Y")
--     }
-- }

function PD.LOGS.Add(typ, text, color)
    if CLIENT then
        net.Start("PD.LOGS.Addcl")
            net.WriteString(typ)
            net.WriteString(text)
            net.WriteColor(color)
        net.SendToServer()
    end

    if SERVER then
        table.insert(PD.LOGS.Tbl, {
            typ = typ,
            text = text,
            color = color,
            time = os.time(),
            date = os.date("%d.%m.%Y")
        })
    
        net.Start("PD.LOGS.Add")
            net.WriteTable(PD.LOGS.Tbl)
        net.Broadcast()
    end
end

function PD.LOGS.GetTbl()
    return PD.LOGS.Tbl
end

