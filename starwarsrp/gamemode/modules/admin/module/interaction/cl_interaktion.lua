PD.IA = PD.IA or {}
PD.IA.Objects = PD.IA.Objects or nil

net.Receive("PD.IA.SendInteractionTbl", function()
    PD.IA.Objects = net.ReadTable()

    if PD.IA.Objects == nil then
        PD.IA.Objects = {}
    end
end)

local request = false

local function save_ia_tbl()
    net.Start("PD.IA.SaveInteractionTbl")
    net.WriteTable(PD.IA.Objects)
    net.SendToServer()

    request = false
end

local function checkObjects()
    if PD.IA.Objects == nil then
        if not request then
            request = true
            net.Start("PD.IA.RequestInteractionTbl")
            net.SendToServer()
        end

        timer.Simple(1, function()

        end)
    end
end

local function getAllEntitys()
    local tbl = {}

    for className, entTable in pairs(scripted_ents.GetList()) do
        if not table.HasValue(tbl, className) then
            tbl[className] = entTable
        end
    end

    return tbl
end

local function sortByBase(tbl)
    -- print(1)

    -- PrintTable(tbl)
    local sorted_tbl = {
        ["Test"] = {}
    }

    for index, tbl in pairs(tbl) do
        -- print(2)

        local className = index
        local entTable = tbl

        if table.HasValue(tbl, entTable["Base"]) then
            -- print(3)
            if not table.HasValue(sorted_tbl, entTable["Base"]) then
                -- print(4)
                PrintTable(tbl[entTable["Base"]])

                sorted_tbl[entTable["Base"]] = tbl[entTable["Base"]]
                -- sorted_tbl[entTable["Base"]]["subclass"] = {}
                -- PrintTable(sorted_tbl)
            end

        end
    end

    PrintTable(sorted_tbl)

    return sorted_tbl
end

-- Einfachere Variante mit Timer (empfohlen für GMod)
function PD.IA.AdminInterface(base)

    checkObjects()

    timer.Simple(1, function()

    end)

    local x = getAllEntitys()

    -- PrintTable(x)

    local sorted_ent_tbl = sortByBase(x)

    PrintTable(sorted_ent_tbl)
end
-- 392
