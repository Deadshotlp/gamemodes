-- 

GM.Version = "1.0.0"
GM.Name = "starwarsrp"
GM.Author = "Progama057 & Deadshot"

if GM.ModulesLoaded then return end
GM.ModulesLoaded = true

DeriveGamemode("sandbox")
DEFINE_BASECLASS("gamemode_sandbox")
GM.Sandbox = BaseClass

include("shared.lua")

local fol = GM.FolderName .. "/gamemode/modules/"
local fileCount = 0

local function LoadFolder(path)
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

        -- print("Found file:", path .. File)
        fileCount = fileCount + 1

        if string.StartWith(File, "sh_") then
            AddCSLuaFile(path .. File)
            include(path .. File)
        elseif string.StartWith(File, "cl_") then
            AddCSLuaFile(path .. File)
            if CLIENT then
                include(path .. File)
            end
        end
    end

    for _, folder in SortedPairs(folders) do
        if not string.StartWith(folder, "_") then
            LoadFolder(path .. folder .. "/")
        end
    end
end

if not file.IsDir("modules", "DATA") then
        file.CreateDir("modules")
end

-- print("Loading modules...")
LoadFolder(fol)
-- print("Modules loaded.")
-- print("Total files loaded:", fileCount)

local PLAYER = FindMetaTable("Player")
function PLAYER:Nick()
    return self:GetNWString("rpname") and self:GetNWString("rpname") ~= "" and self:GetNWString("rpname") or "00-0000 Unknown"
end