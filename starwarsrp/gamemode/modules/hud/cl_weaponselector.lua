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
-- 	return (LocalPlayer():IsValid() and LocalPlayer():Alive() and (not LocalPlayer():InVehicle() or LocalPlayer():GetAllowWeaponsInVehicle())) and not LocalPlayer():KeyDown(IN_ATTACK)
-- end

-- function TimerStuff()
--     timer.Remove( "autoclose" )
--     timer.Create( "autoclose", 3, 1, CloseSelector )
-- end

-- function weaponName(wep)
-- 	if not IsValid(wep) then return "NO NAME" end
  
-- 	local name = language.GetPhrase(wep:GetPrintName())

-- 	return name
-- end

-- local function DrawWeaponHUD()
	
--     local w = ScrW()
--     local h = ScrH()

-- 	local distance = w / 2 - 275

--     local tWeapons = tCache[iCurSlot]

--     for _ = 1, MAX_SLOTS do 
--         if _ ~= iCurSlot then
--             if _ > iCurSlot then 
--                 draw.RoundedBox( 0, 50 * _ + 150 + distance, 85, 50, 30, Color(0,0,0,175) )
--                 draw.SimpleText(_, "CreditsText", 50 * _ + 175 + distance, 100, Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
--             elseif _ < iCurSlot then 
--                 draw.RoundedBox( 0, 50 * _ + distance, 85, 50, 30, Color(0,0,0,175) )
--                 draw.SimpleText(_, "CreditsText", 50 * _ + 25 + distance, 100, Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
--             end
--         else
-- 			draw.RoundedBox( 0, 100 * _  - 50 * _ + distance, 85, 200, 30, Color(0,0,0,230) )
-- 			draw.SimpleText(_, "CreditsText", 50 * _ + 25 + distance, 100, Color(255,255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
--             draw.RoundedBox( 0, 100 * _  - 50 * _ + distance, 115, 200, 30 * tCacheLength[iCurSlot], Color(0,0,0,175) )
--             draw.RoundedBox( 0, 100 * _ - 50 * _ + distance, 30 * iCurPos + 85, 200, 30, Color(0,0,0,255) )

-- 			surface.SetDrawColor( 255, 255, 255, 255 )
-- 			surface.DrawLine( 100 * _  - 50 * _ + distance, 115, 100 * _  - 50 * _ + 200 + distance, 115 )
-- 			surface.DrawLine( 100 * _  - 50 * _ + distance, 84, 100 * _  - 50 * _ + 200 + distance, 84 )
-- 			surface.DrawLine( 100 * _  - 50 * _ + 199 + distance, 85, 100 * _  - 50 * _ + 199 + distance, 115 )
-- 			surface.DrawLine( 100 * _  - 50 * _ + distance, 85, 100 * _  - 50 * _ + distance, 115 )
-- 		end
--     end

--     for i = 1, tCacheLength[iCurSlot] do
-- 		draw.SimpleText(weaponName(tWeapons[i]), "CreditsText", 100 * iCurSlot - 50 * iCurSlot + 5 + distance, 30 * i + 100, Color(255,255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
-- 	end
-- end

-- for i = 1, MAX_SLOTS do
-- 	tCache[i] = {}
-- 	tCacheLength[i] = 0
-- end

-- local tonumber = tonumber
-- local RealTime = RealTime
-- local hook_Add = hook.Add
-- local math_floor = math.floor
-- local string_sub = string.sub
-- local LocalPlayer = LocalPlayer
-- local string_lower = string.lower

-- hook_Add("HUDShouldDraw", "WeaponSelector", function(sName)
-- 	if (sName == "CHudWeaponSelection") then
-- 		return false
-- 	end
-- end)

-- local function PrecacheWeps()
-- 	for i = 1, MAX_SLOTS do
-- 		for j = 1, tCacheLength[i] do
-- 			tCache[i][j] = nil
-- 		end

-- 		tCacheLength[i] = 0
-- 	end

-- 	flNextPrecache = RealTime() + CACHE_TIME

-- 	local tWeapons = LocalPlayer():GetWeapons()
-- 	iWeaponCount = #tWeapons

-- 	if (iWeaponCount == 0) then
-- 		iCurSlot = 0
-- 		iCurPos = 1
-- 	else
-- 		for i = 1, iWeaponCount do
-- 			local pWeapon = tWeapons[i]

-- 			local iSlot = pWeapon:GetSlot() + 1

-- 			if (iSlot <= MAX_SLOTS) then
-- 				local iLen = tCacheLength[iSlot] + 1
-- 				tCacheLength[iSlot] = iLen
-- 				tCache[iSlot][iLen] = pWeapon
-- 			end
-- 		end
-- 	end

-- 	if (iCurSlot ~= 0) then
-- 		local iLen = tCacheLength[iCurSlot]

-- 		if (iLen == 0) then
-- 			iCurSlot = 0
-- 			iCurPos = 1
-- 		elseif (iCurPos > iLen) then
-- 			iCurPos = iLen
-- 		end
-- 	end
-- end

-- local function CheckBounds()
-- 	if (iCurSlot < 0 or iCurSlot > MAX_SLOTS) then
-- 		iCurSlot = 0
-- 	else
-- 		iCurSlot = math_floor(iCurSlot)
-- 	end

-- 	if (iCurPos < 1) then
-- 		iCurPos = 1
-- 	else
-- 		iCurPos = math_floor(iCurPos)
-- 	end

-- 	if (iWeaponCount < 0) then
-- 		iWeaponCount = 0
-- 	else
-- 		iWeaponCount = math_floor(iWeaponCount)
-- 	end
-- end

-- local cl_drawhud = GetConVar("cl_drawhud")

-- hook_Add("HUDPaint", "WeaponSelector", function()
    
--     if (not cl_drawhud:GetBool()) then
-- 		return
-- 	end

-- 	CheckBounds()

-- 	if (iCurSlot == 0) then
-- 		return
-- 	end

-- 	local pPlayer = LocalPlayer()

-- 	if CanUseSelector() then
-- 		if (flNextPrecache <= RealTime()) then
-- 			PrecacheWeps()
-- 		end

-- 		if (iCurSlot ~= 0) then
-- 			DrawWeaponHUD()
-- 		end
-- 	else
-- 		iCurSlot = 0
-- 		iCurPos = 1
--     end
    
-- end)

-- hook_Add("PlayerBindPress", "WeaponSelector", function(pPlayer, sBind, bPressed)
-- 	if not CanUseSelector() then return end 
-- 	sBind = string_lower(sBind)

-- 	if (sBind == "lastinv") then
-- 		if (bPressed) then
-- 			local pLastWeapon = LocalPlayer():GetPreviousWeapon()

-- 			if (pLastWeapon:IsWeapon()) then
-- 				input.SelectWeapon(pLastWeapon)
-- 			end
-- 		end

-- 		--return true
-- 	end

-- 	if (sBind == "cancelselect") then
-- 		if (bPressed and iCurSlot ~= 0) then
-- 			iCurSlot = 0
-- 			iCurPos = 1

-- 			flSelectTime = RealTime()
-- 			LocalPlayer():EmitSound(CANCEL_SOUND)
-- 		end

-- 		--return true
-- 	end

--     if (sBind == "invprev") then
--         TimerStuff()
-- 		if (not bPressed) then
-- 			--return true
-- 		end

-- 		CheckBounds()
-- 		PrecacheWeps()

-- 		if (iWeaponCount == 0) then
-- 			--return true
-- 		end

-- 		local bLoop = iCurSlot == 0

-- 		if (bLoop) then
-- 			local pActiveWeapon = LocalPlayer():GetActiveWeapon()

-- 			if (pActiveWeapon:IsValid()) then
-- 				local iSlot = pActiveWeapon:GetSlot() + 1
-- 				local tSlotCache = tCache[iSlot]

-- 				if (tSlotCache[1] ~= pActiveWeapon) then
-- 					iCurSlot = iSlot
-- 					iCurPos = 1

-- 					for i = 2, tCacheLength[iSlot] do
-- 						if (tSlotCache[i] == pActiveWeapon) then
-- 							iCurPos = i - 1

-- 							break
-- 						end
-- 					end

-- 					flSelectTime = RealTime()
-- 					LocalPlayer():EmitSound(MOVE_SOUND)

-- 					--return true
-- 				end

-- 				iCurSlot = iSlot
-- 			end
-- 		end

-- 		if (bLoop or iCurPos == 1) then
-- 			repeat
-- 				if (iCurSlot <= 1) then
-- 					iCurSlot = MAX_SLOTS
-- 				else
-- 					iCurSlot = iCurSlot - 1
-- 				end
-- 			until(tCacheLength[iCurSlot] ~= 0)

-- 			iCurPos = tCacheLength[iCurSlot]
-- 		else
-- 			iCurPos = iCurPos - 1
-- 		end

-- 		flSelectTime = RealTime()
-- 		LocalPlayer():EmitSound(MOVE_SOUND)

-- 		--return true
-- 	end

--     if (sBind == "invnext") then
--         TimerStuff()
-- 		if (not bPressed) then
-- 			--return true
-- 		end

-- 		CheckBounds()
-- 		PrecacheWeps()

-- 		if (iWeaponCount == 0) then
-- 			--return true
-- 		end

-- 		local bLoop = iCurSlot == 0

-- 		if (bLoop) then
-- 			local pActiveWeapon = LocalPlayer():GetActiveWeapon()

-- 			if (pActiveWeapon:IsValid()) then
-- 				local iSlot = pActiveWeapon:GetSlot() + 1
-- 				local iLen = tCacheLength[iSlot]
-- 				local tSlotCache = tCache[iSlot]

-- 				if (tSlotCache[iLen] ~= pActiveWeapon) then
-- 					iCurSlot = iSlot
-- 					iCurPos = 1

-- 					for i = 1, iLen - 1 do
-- 						if (tSlotCache[i] == pActiveWeapon) then
-- 							iCurPos = i + 1

-- 							break
-- 						end
-- 					end

-- 					flSelectTime = RealTime()
-- 					LocalPlayer():EmitSound(MOVE_SOUND)

-- 					--return true
-- 				end

-- 				iCurSlot = iSlot
-- 			end
-- 		end

-- 		if (bLoop or iCurPos == tCacheLength[iCurSlot]) then
-- 			repeat
-- 				if (iCurSlot == MAX_SLOTS) then
-- 					iCurSlot = 1
-- 				else
-- 					iCurSlot = iCurSlot + 1
-- 				end
-- 			until(tCacheLength[iCurSlot] ~= 0)

-- 			iCurPos = 1
-- 		else
-- 			iCurPos = iCurPos + 1
-- 		end

-- 		flSelectTime = RealTime()
-- 		LocalPlayer():EmitSound(MOVE_SOUND)

-- 		--return true
-- 	end

-- 	if (string_sub(sBind, 1, 4) == "slot") then
-- 		local iSlot = tonumber(string_sub(sBind, 5))
-- 		if (iSlot == nil) then
-- 			return
-- 		end

-- 		if (not bPressed) then
-- 			--return true
-- 		end

-- 		CheckBounds()
-- 		PrecacheWeps()

-- 		if (iWeaponCount == 0) then
-- 			LocalPlayer():EmitSound(MOVE_SOUND)

-- 			--return true
-- 		end

-- 		if (iSlot <= MAX_SLOTS) then
-- 			if (iSlot == iCurSlot) then
-- 				if (iCurPos == tCacheLength[iCurSlot]) then
-- 					iCurPos = 1
-- 				else
-- 					iCurPos = iCurPos + 1
-- 				end
-- 			elseif (tCacheLength[iSlot] ~= 0) then
-- 				iCurSlot = iSlot
-- 				iCurPos = 1
-- 			end

-- 			flSelectTime = RealTime()
-- 			LocalPlayer():EmitSound(MOVE_SOUND)
-- 		end

-- 		--return true
--     end

-- 	if (iCurSlot ~= 0) then
-- 		if (sBind == "+attack") then
-- 			local pWeapon = tCache[iCurSlot][iCurPos]
-- 			iCurSlot = 0
-- 			iCurPos = 1

-- 			if (pWeapon:IsValid() and pWeapon ~= LocalPlayer():GetActiveWeapon()) then
-- 				input.SelectWeapon(pWeapon)
-- 			end

-- 			flSelectTime = RealTime()
-- 			LocalPlayer():EmitSound(SELECT_SOUND)

-- 			return true
-- 		end

-- 		if (sBind == "+attack2") then
-- 			flSelectTime = RealTime()
-- 			LocalPlayer():EmitSound(CANCEL_SOUND)

-- 			iCurSlot = 0
-- 			iCurPos = 1

-- 			return true
-- 		end
-- 	end
-- end)