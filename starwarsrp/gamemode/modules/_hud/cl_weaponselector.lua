-- Weaponselector

local selectedWeapon = 1
local weaponList = {}
local switchDelay = 0.2
local lastSwitchTime = 0

local function WeaponSelectorMenu()
    if IsValid(WeaponSelectorFrame) then WeaponSelectorFrame:Remove() end

    -- selectedWeapon = table.KeyFromValue(LocalPlayer():GetWeapons(), LocalPlayer():GetActiveWeapon())
    
    WeaponSelectorFrame = PD.Frame("Weapon Selector", PD.W(250), PD.H(400), false, function (self, w, h) end, true)
    WeaponSelectorFrame:SetPos(PD.W(10), ScrH() / 2 - PD.H(200))
    
    weaponList = LocalPlayer():GetWeapons()
    for i, wep in ipairs(weaponList) do
        local weplbl = PD.Label(wep:GetPrintName() .. " | " .. i , WeaponSelectorFrame)
        
        if i == selectedWeapon then
            weplbl.Paint = function(self, w, h)
                draw.RoundedBox(5, 0, 0, w, h, Color(255, 255, 255, 100))
            end
        end
    end
end

local function CloseFrame()
    if IsValid(WeaponSelectorFrame) then
        timer.Remove("WeaponSelectorCloseTimer")
        timer.Create("WeaponSelectorCloseTimer", 2, 1, function()
            if IsValid(WeaponSelectorFrame) then
                WeaponSelectorFrame:MoveTo(PD.W(10) - PD.W(300), ScrH() / 2 - PD.H(200), 0.5, 0, -1, function()
                    WeaponSelectorFrame:Remove()
                end)
            end
        end)
    end
end

hook.Add("PlayerBindPress", "WeaponSelector_ThinkPD", function(ply, bind, pressed)
    if not IsValid(ply) then return end
    
    if bind == "invprev" then
        if CurTime() - lastSwitchTime < switchDelay then return true end
        lastSwitchTime = CurTime()

        weaponList = ply:GetWeapons()

        selectedWeapon = selectedWeapon - 1
        if selectedWeapon < 1 then selectedWeapon = #weaponList end

        WeaponSelectorMenu()

        net.Start("PD.WeaponSelector:SelectWeapon")
            net.WriteInt(selectedWeapon, 32)
            net.WriteEntity(ply)
        net.SendToServer()

        CloseFrame()

        return true
    elseif bind == "invnext" then
        if CurTime() - lastSwitchTime < switchDelay then return true end
        lastSwitchTime = CurTime()

        weaponList = ply:GetWeapons()

        selectedWeapon = selectedWeapon + 1
        if selectedWeapon > #weaponList then selectedWeapon = 1 end

        WeaponSelectorMenu()

        net.Start("PD.WeaponSelector:SelectWeapon")
            net.WriteInt(selectedWeapon, 32)
            net.WriteEntity(ply)
        net.SendToServer()

        CloseFrame()

        return true
    end
end)

-- local MAX_SLOTS = 6
-- local CACHE_TIME = 1 
-- local MOVE_SOUND = "Player.WeaponSelectionMoveSlot" 
-- local SELECT_SOUND = "Player.WeaponSelected"
-- local CANCEL_SOUND = ""

-- local iCurSlot = 0
-- local iCurPos = 1
-- local flNextPrecache = 0
-- local flSelectTime = 0
-- local iWeaponCount = 0

-- local tCache = {}
-- local tCacheLength = {}

-- function CloseSelector()
--     iCurSlot = 0
--     iCurPos = 1
-- end

-- function CanUseSelector()
--     local ply = LocalPlayer()
--     if not IsValid(ply) then return false end
--     return ply:Alive() and (not ply:InVehicle() or ply:GetAllowWeaponsInVehicle()) and not ply:KeyDown(IN_ATTACK)
-- end

-- function TimerStuff()
--     timer.Remove("autoclose")
--     if iCurSlot ~= 0 then
--         timer.Create("autoclose", 3, 1, CloseSelector)
--     end
-- end

-- function weaponName(wep)
--     if not IsValid(wep) then return "NO NAME" end
--     return language.GetPhrase(wep:GetPrintName())
-- end

-- local function DrawWeaponHUD()
--     if not tCache[iCurSlot] then return end  -- Fix: Prüft, ob Slot gültig ist
    
--     local w, h = ScrW(), ScrH()
--     local distance = w / 2 - 275
--     local tWeapons = tCache[iCurSlot]
--     local len = tCacheLength[iCurSlot] or 0  -- Fix: Sicherstellen, dass kein nil-Zugriff erfolgt
    
--     for _ = 1, MAX_SLOTS do 
--         if _ ~= iCurSlot then
--             draw.RoundedBox(0, 50 * _ + distance, 85, 50, 30, Color(0,0,0,175))
--             draw.SimpleText(_, "MLIB.20", 50 * _ + 25 + distance, 100, Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
--         else
--             draw.RoundedBox(0, 100 * _ - 50 * _ + distance, 85, 200, 30, Color(0,0,0,230))
--             draw.RoundedBox(0, 100 * _ - 50 * _ + distance, 115, 200, 30 * len, Color(0,0,0,175))
--             draw.RoundedBox(0, 100 * _ - 50 * _ + distance, 30 * iCurPos + 85, 200, 30, Color(0,0,0,255))
--         end
--     end

--     for i = 1, len do
--         draw.SimpleText(weaponName(tWeapons[i]), "MLIB.20", 100 * iCurSlot - 50 * iCurSlot + 5 + distance, PD.H(200) * i + PD.H(100), Color(255,255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
--     end
-- end

-- for i = 1, MAX_SLOTS do
--     tCache[i] = {}
--     tCacheLength[i] = 0
-- end

-- local function PrecacheWeps()
--     for i = 1, MAX_SLOTS do
--         tCache[i] = {}
--         tCacheLength[i] = 0
--     end

--     flNextPrecache = RealTime() + CACHE_TIME
--     local ply = LocalPlayer()
--     if not IsValid(ply) then return end

--     local tWeapons = ply:GetWeapons()
--     iWeaponCount = #tWeapons

--     if iWeaponCount == 0 then
--         iCurSlot, iCurPos = 0, 1
--     else
--         for _, pWeapon in ipairs(tWeapons) do
--             if IsValid(pWeapon) then
--                 local iSlot = pWeapon:GetSlot() + 1
--                 if iSlot <= MAX_SLOTS then
--                     local iLen = tCacheLength[iSlot] + 1
--                     tCacheLength[iSlot] = iLen
--                     tCache[iSlot][iLen] = pWeapon
--                 end
--             end
--         end
--     end

--     if iCurSlot ~= 0 and (tCacheLength[iCurSlot] or 0) == 0 then
--         iCurSlot, iCurPos = 0, 1
--     elseif iCurPos > (tCacheLength[iCurSlot] or 0) then
--         iCurPos = tCacheLength[iCurSlot]
--     end
-- end

-- hook.Add("HUDShouldDraw", "WeaponSelector", function(sName)
--     if sName == "CHudWeaponSelection" then return false end
-- end)

-- hook.Add("HUDPaint", "WeaponSelector", function()
--     if not GetConVar("cl_drawhud"):GetBool() then return end
--     if iCurSlot == 0 then return end

--     local ply = LocalPlayer()
--     if not IsValid(ply) then return end
    
--     if CanUseSelector() then
--         if flNextPrecache <= RealTime() then
--             PrecacheWeps()
--         end
--         DrawWeaponHUD()
--     else
--         CloseSelector()
--     end
-- end)

-- hook.Add("PlayerBindPress", "WeaponSelector", function(pPlayer, sBind, bPressed)
--     if not CanUseSelector() then return end 
--     sBind = string.lower(sBind)

--     if sBind == "lastinv" and bPressed then
--         local pLastWeapon = pPlayer:GetPreviousWeapon()
--         if IsValid(pLastWeapon) then
--             input.SelectWeapon(pLastWeapon)
--         end
--         return true
--     end

--     if sBind == "cancelselect" and bPressed and iCurSlot ~= 0 then
--         CloseSelector()
--         pPlayer:EmitSound(CANCEL_SOUND)
--         return true
--     end

--     if sBind == "invnext" or sBind == "invprev" then
--         TimerStuff()
--         PrecacheWeps()
--         if iWeaponCount == 0 then return true end
        
--         local direction = (sBind == "invnext") and 1 or -1
--         repeat
--             iCurSlot = ((iCurSlot + direction - 1) % MAX_SLOTS) + 1
--         until tCacheLength[iCurSlot] > 0
        
--         iCurPos = (direction == 1) and 1 or tCacheLength[iCurSlot]
--         pPlayer:EmitSound(MOVE_SOUND)
--         return true
--     end

--     if string.sub(sBind, 1, 4) == "slot" then
--         local iSlot = tonumber(string.sub(sBind, 5))
--         if not iSlot or iSlot > MAX_SLOTS then return true end

--         PrecacheWeps()
--         if tCacheLength[iSlot] > 0 then
--             iCurSlot, iCurPos = iSlot, 1
--             pPlayer:EmitSound(MOVE_SOUND)
--         end
--         return true
--     end

--     if iCurSlot ~= 0 and (sBind == "+attack" or sBind == "+attack2") then
--         local pWeapon = tCache[iCurSlot][iCurPos]
--         if sBind == "+attack" and IsValid(pWeapon) then
--             input.SelectWeapon(pWeapon)
--             pPlayer:EmitSound(SELECT_SOUND)
--         else
--             pPlayer:EmitSound(CANCEL_SOUND)
--         end
--         CloseSelector()
--         return true
--     end
-- end)
