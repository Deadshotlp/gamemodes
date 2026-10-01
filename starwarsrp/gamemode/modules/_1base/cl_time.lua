Mario = Mario or {}

function Mario.FormatTime( Time, oneFormat )
	local TimeTable = {}
	TimeTable.Hours = math.floor(Time / 3600)
	TimeTable.Minutes = math.floor((Time / 60) % (3600 / 60))
	TimeTable.Seconds = math.floor(Time % 60)
	oneFormat = oneFormat or false
	if TimeTable.Hours > 0 then
		local formattedTime = ""
		if oneFormat then
			formattedTime = "%Hh:Mm"
		else
			formattedTime = "%Hh:%Mm:%Ss"
		end
		formattedTime = string.Replace(formattedTime,"%H",TimeTable.Hours)
		formattedTime = string.Replace(formattedTime,"%M",TimeTable.Minutes)
		formattedTime = string.Replace(formattedTime,"%S",TimeTable.Seconds)
        return formattedTime
	elseif TimeTable.Minutes > 0 then
		local formattedTime = ""
		if oneFormat then
			formattedTime = "%Mm"
		else
			formattedTime = "%Mm:%Ss"
		end
		formattedTime = string.Replace(formattedTime,"%M",TimeTable.Minutes)
		formattedTime = string.Replace(formattedTime,"%S",TimeTable.Seconds)
		return formattedTime
	else
		local formattedTime = "%Ss"
		formattedTime = string.Replace(formattedTime,"%S",TimeTable.Seconds)
		return formattedTime
	end
end

GameUpTime = GameUpTime or RealTime()
ServerUptime = 0
UptimeOffset = 0
net.Receive("SendUptime", function(  ) 
	ServerUptime = net.ReadUInt(22) or 0
	UptimeOffset = RealTime()
end)

Time_1 = function() return 
    Mario.FormatTime(ServerUptime + RealTime() - UptimeOffset) 
end

Mario_SpielZeit = function() return 
    Mario.FormatTime( RealTime() - GameUpTime ) 
end