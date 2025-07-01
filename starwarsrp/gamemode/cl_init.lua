-- 

GM.Version = "1.0.0"
GM.Name = "starwarsrp"
GM.Author = "Progama057 & Deadshot"

DeriveGamemode("sandbox")
DEFINE_BASECLASS("gamemode_sandbox")
GM.Sandbox = BaseClass

-- if GAMEMODE_LOADED then return end
-- GAMEMODE_LOADED = true

include("shared.lua")

local fol = GM.FolderName .. "/gamemode/modules/"
local fileCount = 0

local function LoadFolder(path)
    local files, folders = file.Find(path .. "*", "LUA")

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
        -- print("Entering folder:", path .. folder)
        LoadFolder(path .. folder .. "/")
    end
end

print("Loading modules...")
LoadFolder(fol)
print("Modules loaded.")
print("Total files loaded:", fileCount)

local PLAYER = FindMetaTable("Player")
function PLAYER:Nick()
    return self:GetNWString("rpname") and self:GetNWString("rpname") ~= "" and self:GetNWString("rpname") or "00-0000 Unknown"
end

