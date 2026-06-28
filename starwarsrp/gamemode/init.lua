GM.Version = "1.0.0"
GM.Name = "starwarsrp"
GM.Author = "Progama057 & Deadshot"

if GM.ModulesLoaded then return end
GM.ModulesLoaded = true

DeriveGamemode("sandbox")
DEFINE_BASECLASS("gamemode_sandbox")
GM.Sandbox = BaseClass

AddCSLuaFile("shared.lua")
include("shared.lua")

PD.Equip = {
    ["ID"] = "idcard",
    ["Hands"] = "mhands"
}

PD.Admin = PD.Admin or {}

PD.Admin.Ranks = {
    ["superadmin"] = 99,
    ["admin"] = 50,
    ["projektleitung"] = 10,
    ["teamleitung"] = 8,
    ["moderator"] = 4,
    ["supporter"] = 2,
}

PD.Admin.Equip = {
    ["PhysGun"] = "weapon_physgun",
    ["ToolGun"] = "gmod_tool"
}

PD.Admin.PayDayPercent = {
    ["superadmin"] = 5,
    ["admin"] = 2,
    ["projektleitung"] = 2,
    ["teamleitung"] = 2,
    ["moderator"] = 2,
    ["supporter"] = 2,
    ["user"] = 1
}

PD.Admin.Slots = {
    ["superadmin"] = 5,
    ["admin"] = 4,
    ["projektleitung"] = 4,
    ["teamleitung"] = 4,
    ["moderator"] = 3,
    ["supporter"] = 3,
    ["user"] = 2
}

local fol = GM.FolderName .. "/gamemode/modules/"
local fileCount = 0
local globalStartTime = SysTime()

local function LoadFolder(path)
    local folderStartTime = SysTime()
    local files, folders = file.Find(path .. "*", "LUA")

    -- print("Loading folder:", path)
    for _, folder in SortedPairs(folders) do
        if string.StartWith(folder, "!old") then continue end

        if string.StartWith(folder, "_") then
            LoadFolder(path .. folder .. "/")
        end
    end

    for _, File in SortedPairs(files) do
        if string.GetExtensionFromFilename(File) ~= "lua" then continue end

        fileCount = fileCount + 1

        if string.StartWith(File, "sh_") then
            AddCSLuaFile(path .. File)
            include(path .. File)
        elseif string.StartWith(File, "sv_") then
            if SERVER then
                include(path .. File)
            end
        elseif string.StartWith(File, "cl_") then
            AddCSLuaFile(path .. File)
            if CLIENT then
                include(path .. File)
            end
        end
        -- print("Loaded file:", path .. File)
    end

    for _, folder in SortedPairs(folders) do
        if not string.StartWith(folder, "_") then
            LoadFolder(path .. folder .. "/")
        end
    end

    -- print(string.format("Finished loading folder: %s | Time taken: %.6f sec", path, SysTime() - folderStartTime))
end

print("Loading modules...")
LoadFolder(fol)
print(string.format("Modules loaded. Total files: %d | Total time: %.6f sec", fileCount, SysTime() - globalStartTime))

-- hook.Run("PostPDLoaded")

local PLAYER = FindMetaTable("Player")
function PLAYER:Nick()
   return self:GetNWString("rpname") and self:GetNWString("rpname") ~= "" and self:GetNWString("rpname") or "Unknown"
end

function LoadFolderInfo(baseFolder)
    local totalFiles = 0
    local totalFolders = 0
    local totalLines = 0
    local totalChars = 0
    local mostLinesFile = ""
    local mostLinesCount = 0
    local folderStats = {}

    -- Hilfsfunktion: Gibt den Modulnamen zurück (erste + zweite Ordnerebene)
    local function GetModulePath(path)
        local relPath = string.gsub(path, "^" .. baseFolder .. "/?", "")
        local parts = {}
        for part in string.gmatch(relPath, "[^/]+") do
            table.insert(parts, part)
            if #parts == 2 then break end
        end
        return table.concat(parts, "/")
    end

    -- Rekursive Funktion zum Durchsuchen des Verzeichnisses
    local function ProcessFolder(folderPath)
        local files, dirs = file.Find(folderPath .. "/*", "LUA")

        -- Modulname aus Pfad extrahieren
        local moduleName = GetModulePath(folderPath)
        folderStats[moduleName] = folderStats[moduleName] or { lines = 0, chars = 0 }

        -- Verarbeite Dateien
        for _, fileName in ipairs(files) do
            totalFiles = totalFiles + 1
            local fullPath = folderPath .. "/" .. fileName

            if file.Exists(fullPath, "LUA") then
                local content = file.Read(fullPath, "LUA")
                local lineCount = select(2, string.gsub(content, "\n", "")) + 1
                local charCount = #content

                totalLines = totalLines + lineCount
                totalChars = totalChars + charCount

                folderStats[moduleName].lines = folderStats[moduleName].lines + lineCount
                folderStats[moduleName].chars = folderStats[moduleName].chars + charCount

                if lineCount > mostLinesCount then
                    mostLinesCount = lineCount
                    mostLinesFile = fullPath
                end
            end
        end

        -- Verarbeite Unterordner
        for _, dirName in ipairs(dirs) do
            totalFolders = totalFolders + 1
            ProcessFolder(folderPath .. "/" .. dirName)
        end
    end

    -- Startverzeichnis prüfen
    if not file.IsDir(baseFolder, "LUA") then
        print("Ordner existiert nicht: " .. baseFolder)
        return
    end

    ProcessFolder(baseFolder)

    -- Top 3 Module nach Zeilenzahl sortieren
    local topModules = {}
    for name, stats in pairs(folderStats) do
        table.insert(topModules, { name = name, lines = stats.lines, chars = stats.chars })
    end
    table.sort(topModules, function(a, b) return a.lines > b.lines end)

    local top3 = {}
    for i = 1, math.min(3, #topModules) do
        table.insert(top3, topModules[i])
    end

    -- Rückgabe
    return {
        ordner = totalFolders,
        dateien = totalFiles,
        zeilen = totalLines,
        zeichen = totalChars,
        dateiMitMeistenZeilen = mostLinesFile,
        zeilenInDerDatei = mostLinesCount,
        topModule = top3
    }
end

-- Beispielaufruf
-- local info = LoadFolderInfo(fol)
-- PrintTable(info)

-- print("Vor dem Patch:")
-- print("CPath:", package.cpath)
-- print("Path: ", package.path)

-- -- Setze Suchpfade
-- package.cpath = "lua/bin/?.dll"
-- package.path  = "lua/includes/modules/?.lua"

-- print("Nach dem Patch:")
-- print("CPath:", package.cpath)
-- print("Path: ", package.path)

-- -- Lanes laden
-- local lanes = require("lanes")
-- print("Lanes:", lanes)

-- print(file.Exists("includes/modules/lanes.lua", "LUA"))