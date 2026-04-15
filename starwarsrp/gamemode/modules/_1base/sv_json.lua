PD.JSON = PD.JSON or {}

function PD.JSON.Create(dir) -- Ordner Name z.b "defcon"
    if file.IsDir(dir, "DATA") then return end

    file.CreateDir(dir)
    print("Created directory: " .. dir)
end

function PD.JSON.Write(dir, data)
    -- if not PD.JSON.Exists(dir) then
    --     PD.JSON.Create(dir)
    -- end

    file.Write(dir, util.TableToJSON(data, true))
end

function PD.JSON.Read(dir)
    if PD.JSON.Exists(dir) then
        return util.JSONToTable(file.Read(dir, "DATA"))
    end

    return {}
end

function PD.JSON.Exists(dir)
    return file.Exists(dir, "DATA")
end

function PD.JSON.Delete(dir)
    file.Delete(dir)
end

 