PD.Char = PD.Char or {}

PD.Char.Background = "mario/void_logo.png" -- Hintergrund Bild
PD.Char.Discord = "" -- Discord Link
PD.Char.Kollektion = "" -- Kollektion Link
PD.Char.MaxChars = 5 -- Maximale Anzahl an Charakteren
PD.Char.DefaultJob = "" -- Default Job

PD.Char.UserGroupChar = {
    ["user"] = 2,
    ["projekt"] = 5,
    ["Developer"] = 5,
    ["teamleitung"] = 4,
    ["moderator"] = 3,
    ["supporter"] = 3,
    ["eventler"] = 3,
    ["superadmin"] = 5
}

PD.Char.OpenMenuBind = KEY_F6 -- Charaktermenü öffnen
PD.Char.OpenAdminMenuBind = KEY_F7 -- Adminmenü öffnen

PD.Char.OpenAdminMenuTeam = { -- Welche Teams können das Adminmenü öffnen
    ["admin"] = true,
    ["superadmin"] = true
}

PD.Char.MinName = 3 -- Minimale Länge des Namens
PD.Char.MaxName = 20 -- Maximale Länge des Namens

PD.Char.NameBlacklist = { -- Blacklist für Namen
    [""] = true 
}

PD.Char.NotAllowedNumbers = { -- Nicht erlaubt CT / CC Nummern
    [""] = true
}

PD.Config:AddSetting("Character", "Hintergrundbild", "string", "mario/void_logo.png")
PD.Config:AddSetting("Character", "Discord Link", "string", "")
PD.Config:AddSetting("Character", "Kollektion Link", "string", "")
PD.Config:AddSetting("Character", "Maximale Anzahl an Charakteren", "number", 5)
PD.Config:AddSetting("Character", "Default Job", "string", "")
PD.Config:AddSetting("Character", "Minimale Namenslänge", "number", 3)
PD.Config:AddSetting("Character", "Maximale Namenslänge", "number", 20)
PD.Config:AddSetting("Character", "Name Blacklist", "table", {"Hitler", "Mario1"}, "list")

function FindJobIDByName(jobName)
    for jobID, jobData in pairs(PD.JOBS.GetJob()) do
        if jobData.name == jobName then
            return jobID
        end
    end
    return nil
end

function FindJobNameByID(jobID)
    if PD.JOBS.GetJob()[jobID] then
        return PD.JOBS.GetJob()[jobID].name
    end
    return nil
end

function FindPlayerbyID(id)
    for k, v in pairs(player.GetAll()) do
        if v:SteamID64() == id then
            return v
        end
    end
    return nil
end

function FindPlayerbyCharID(id)
    for k, v in pairs(player.GetAll()) do
        if v:GetCharacterID() == id then
            return v
        end
    end
    return nil
end

function FindPlayerCharbyName(name,tbl)
    for k,v in pairs(tbl) do
        if v.name == name then
            return k
        end
    end

    -- print(name)
    -- PrintTable(tbl)

    return nil
end