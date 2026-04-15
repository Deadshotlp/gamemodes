WarningSystem = WarningSystem or {}
WarningSystem.Config = WarningSystem.Config or {}

-- Default Configuration
WarningSystem.Config.Defaults = {
    -- Warn Settings
    MaxWarns = 3,
    WarnDecayEnabled = true,
    WarnDecayTime = 604800, -- 7 days in seconds

    -- Ban Settings
    AutoBanEnabled = true,
    BanDuration = 86400, -- 24 hours in seconds

    -- Permissions
    AdminFlags = {
        ["superadmin"] = true,
        ["admin"] = true
    }
}

-- Current active configuration (server-controlled)
WarningSystem.Config.Current = table.Copy(WarningSystem.Config.Defaults)

function WarningSystem.Config:Get(key)
    return self.Current[key] or self.Defaults[key]
end

function WarningSystem.Config:Set(key, value)
    self.Current[key] = value
    if SERVER then
        self:Save()
        self:SyncToClients()
    end
end

if SERVER then
    function WarningSystem.Config:Save()
        local data = util.TableToJSON(self.Current)
        file.Write("warningsystem_config.txt", data)
    end

    function WarningSystem.Config:Load()
        if file.Exists("warningsystem_config.txt", "DATA") then
            local data = file.Read("warningsystem_config.txt", "DATA")
            local loaded = util.JSONToTable(data)
            if loaded then
                self.Current = table.Merge(table.Copy(self.Defaults), loaded)
            end
        end
    end

    function WarningSystem.Config:SyncToClients(ply)
        net.Start("WarningSystem_ConfigSync")
        net.WriteTable(self.Current)
        if ply then
            net.Send(ply)
        else
            net.Broadcast()
        end
    end

    net.Receive("WarningSystem_ConfigUpdate", function(len, ply)
        if not WarningSystem:HasPermission(ply) then return end

        local key = net.ReadString()
        local valueType = net.ReadString()
        local value

        if valueType == "number" then
            value = net.ReadFloat()
        elseif valueType == "bool" then
            value = net.ReadBool()
        elseif valueType == "string" then
            value = net.ReadString()
        elseif valueType == "table" then
            value = net.ReadTable()
        end

        WarningSystem.Config:Set(key, value)
    end)
else
    net.Receive("WarningSystem_ConfigSync", function()
        WarningSystem.Config.Current = net.ReadTable()
    end)
end

function WarningSystem:HasPermission(ply)
    if not IsValid(ply) then return false end

    local usergroup = ply:GetUserGroup()
    return WarningSystem.Config.Current.AdminFlags[usergroup] == true
end
