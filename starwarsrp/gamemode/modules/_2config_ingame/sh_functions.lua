PD.Config = PD.Config or {}
PD.Config.Table = {}

function PD.Config:AddSetting(addon, settingName, settingType, default)
    self.Table[addon] = self.Table[addon] or {}

    if self.Table[addon][settingName] then return end

    self.Table[addon][settingName] = {
        type = settingType,
        default = default
    }
end

function PD.Config:GetSetting(addon, settingName)
    if self.Table[addon] and self.Table[addon][settingName] then
        return self.Table[addon][settingName]
    else
        print("Einstellung nicht gefunden: " .. addon .. " - " .. settingName)
        return nil
    end
end