GM.Version = "1.0.0"
GM.Name = "starwarsrp"
GM.Author = "Progama057 & Deadshot"

DeriveGamemode("sandbox")
DEFINE_BASECLASS("gamemode_sandbox")
GM.Sandbox = BaseClass

--if GAMEMODE_LOADED then return end
--GAMEMODE_LOADED = true

AddCSLuaFile("shared.lua")
include("shared.lua")

local fol = GM.FolderName .. "/gamemode/modules/"
local fileCount = 0
local globalStartTime = SysTime()

local function LoadFolder(path)
    local folderStartTime = SysTime()
    local files, folders = file.Find(path .. "*", "LUA")

    -- print("Loading folder:", path)

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
    end

    for _, folder in SortedPairs(folders) do
        LoadFolder(path .. folder .. "/")
    end

    print(string.format("Finished loading folder: %s | Time taken: %.6f sec", path, SysTime() - folderStartTime))
end

print("Loading modules...")
LoadFolder(fol)
print(string.format("Modules loaded. Total files: %d | Total time: %.6f sec", fileCount, SysTime() - globalStartTime))

-- hook.Run("PostPDLoaded")

local PLAYER = FindMetaTable("Player")
function PLAYER:Nick()
   return self:GetNWString("rpname") and self:GetNWString("rpname") ~= "" and self:GetNWString("rpname") or "Unknown"
end