--
function PD.IsBetween(value, min, max)
    return value >= min and value <= max
end

function PD.deepTablesEqual(t1, t2)
    -- Prüfe ob beide nil sind
    if t1 == nil or t2 == nil then
        return false
    end

    -- Prüfe ob beide keine Tabellen sind
    if type(t1) ~= "table" or type(t2) ~= "table" then
        return t1 == t2
    end

    -- Prüfe Array-Teil
    if #t1 ~= #t2 then
        return false
    end
    for i = 1, #t1 do
        if not t1[i] == nil and not t2[i] == nil and not deepTablesEqual(t1[i], t2[i]) then -- Rekursiver Aufruf!
            return false
        end
    end

    -- Prüfe Hash-Teil (benannte Schlüssel)
    for k, v in pairs(t1) do
        if type(k) ~= "number" or k > #t1 or k < 1 then
            if not deepTablesEqual(v, t2[k]) then
                return false
            end
        end
    end

    for k, v in pairs(t2) do
        if type(k) ~= "number" or k > #t2 or k < 1 then
            if t1[k] == nil then
                return false
            end
        end
    end

    return true
end

function PD.CheckUnitAccess(ply, unit)
    if not IsValid(ply) then return false end
    if not unit then return false end

    local jobName, jobTable = ply:GetJob()
    local subunitName, subunitTable = PD.JOBS.GetSubUnit(jobTable.unit, false)

    if subunitTable.unit and subunitTable.unit ~= unit then
        return false
    end

    return true
end

function PD.CheckSubUnitAccess(ply, unit)
    if not IsValid(ply) then return false end
    if not unit then return false end

    local jobName, jobTable = ply:GetJob()
    if jobTable.unit and jobTable.unit ~= unit then
        return false
    end

    return true
end