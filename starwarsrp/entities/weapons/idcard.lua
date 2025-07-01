
if SERVER then
    AddCSLuaFile()
end

SWEP.PrintName = 'ID Card'
SWEP.Author = 'PD - Gamemode'
SWEP.Purpose = ''
SWEP.Spawnable = true
SWEP.Category = 'PD - Gamemode'
SWEP.ViewModel = 'models/weapons/c_medkit.mdl'
SWEP.WorldModel = ''
SWEP.AnimPrefix = 'rpg'
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = 'none'
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = 'none'
SWEP.DrawCrosshair = false

function SWEP:Initialize()
    self:SetHoldType('normal')
    self.range = 100

    self.ownerPos = Vector(0, 0, 0)
    self.ownerAim = Vector(0, 0, 0)
end

function SWEP:Think()
end

local showCard = false
local click = false
function SWEP:PrimaryAttack()
    if click then return end
    click = true

    showCard = !showCard

    local tr = self.Owner:GetEyeTrace()
    if tr.Entity and tr.Entity:IsPlayer() then
        if CLIENT then
            -- net.Start('PD.IDCards:CheckID')
            -- net.WriteEntity(tr.Entity)
            -- net.SendToServer()

            -- hook.Add("HUDPaint", "IDCard", function()
            --     if IsValid(showEntity) then
            --         PD.DrawImgur(w() - PD.W(310), h() / 2 - PD.H(75), PD.W(300), PD.H(150), "N9FDPCL")
            
            --         local jobName, jobTable = showEntity:GetJob()
            --         draw.SimpleText(showEntity:Nick(), "MLIB.17", w() - PD.W(190), h() / 2 - PG.H(5), PD.UI.Colors["Text"], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            --         draw.SimpleText(jobTable.unit .. " | " .. jobName, "MLIB.17", w() - PD.W(190), h() / 2 + PG.H(50), PD.UI.Colors["Text"], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            
            --     end
            -- end)
        end

        if SERVER then
            net.Start("PD.IDCards:CheckID")
                net.WriteEntity(self.Owner)
            net.Send(tr.Entity)
        end
    end

    timer.Simple(0.2, function()
        click = false
    end)
end

function SWEP:SecondaryAttack()
   
end

if SERVER then
    return 
end

local w, h = ScrW, ScrH
function SWEP:DrawHUD()
    if IsValid(self.Owner:GetVehicle()) then return end

    draw.SimpleText("ID Karte mit Links-click rausholen", "MLIB.20", w() / 2, h() - PG.H(120), PD.UI.Colors["Text"], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    if !showCard then return end

    PD.DrawImgur(w() - PD.W(310), h() / 2 - PD.H(75), PD.W(300), PD.H(150), "N9FDPCL")

    local jobName, jobTable = self.Owner:GetJob()
    draw.SimpleText(self.Owner:Nick(), "MLIB.17", w() - PD.W(190), h() / 2 - PG.H(5), PD.UI.Colors["Text"], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText(jobTable.unit .. " | " .. jobName, "MLIB.17", w() - PD.W(190), h() / 2 + PG.H(50), PD.UI.Colors["Text"], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

function SWEP:PreDrawViewModel()
    return true
end