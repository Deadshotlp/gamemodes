-- Commands by Progama057

util.AddNetworkString("CMD_Verlosung")
util.AddNetworkString("CommandsSend")
util.AddNetworkString("CMD_Decode")

local types = {
    "akt",
    "me",
    "git",
    "it",
    "id",
    "makt",
    "takt",
    "rok",
    "funk",
    "vfunk",
    "decode",
    "hacken",
    "forschen",
    "scan",
    "looc",
    "flip",
    "roll",
    "eakt",
    "efunk"
}

local nontext = {
    ["a"] = "@",
    ["b"] = "#",
    ["c"] = "$",
    ["d"] = "%",
    ["e"] = "&",
    ["f"] = "*",
    ["g"] = "+",
    ["h"] = "=",
    ["i"] = "!",
    ["j"] = "?",
    ["k"] = "/",
    ["l"] = "(",
    ["m"] = ")",
    ["n"] = "-",
    ["o"] = "_",
    ["p"] = ";",
    ["q"] = ":",
    ["r"] = ",",
    ["s"] = ".",
    ["t"] = "<",
    ["u"] = ">",
    ["v"] = "|",
    ["w"] = "{",
    ["x"] = "}",
    ["y"] = "[",
    ["z"] = "]",
    ["ä"] = "~",
    ["ü"] = "^",
    ["ö"] = "`",
    ["1"] = "a",
    ["2"] = "b",
    ["3"] = "c",
    ["4"] = "d",
    ["5"] = "e",
    ["6"] = "f",
    ["7"] = "g",
    ["8"] = "h",
    ["9"] = "i",
    [","] = "j",
    ["."] = "k",
    ["-"] = "l",
    ["_"] = "m",
    [":"] = "n",
    [";"] = "o",
    ["#"] = "p",
    ["'"] = "q",
    ["*"] = "r",
    ["+"] = "s",
    ["!"] = "t",
    ["?"] = "u",
    ["/"] = "v",
    ["("] = "w",
    [")"] = "x",
    ["="] = "y",
    ["&"] = "z",
    ["%"] = "ä",
    ["$"] = "ü",
    ["§"] = "ö",
    ["@"] = "1",
    ["<"] = "2",
    [">"] = "3",
    ["|"] = "4",
    ["{"] = "5",
    ["}"] = "6",
    ["["] = "7",
    ["]"] = "8",
    ["~"] = "9",
    ["°"] = "_"
}

local function TextCode(text)
    local code = ""
    for i = 1, #text do
        local char = string.sub(string.lower(text), i, i)

        if char == " " then
            code = code.." "
            continue
        end
        
        newchar = nontext[char] or char
        
        code = code..newchar
    end

    return code
end

local function Decode(code)
    local text = ""
    for i = 1, #code do
        local char = string.sub(string.lower(code), i, i)

        if char == " " then
            text = text.." "
            continue
        end

        for k, v in pairs(nontext) do
            if v == char then
                newchar = k
            end
        end

        text = text..newchar
    end

    return text
end

local function AutoComplitePlayerName(name)
    local plys = player.GetAll()
    local plys2 = nil

    for k, v in pairs(plys) do
        if string.find(string.lower(v:Name()), string.lower(name)) then
            plys2 = v
            break
        end
    end

    return plys2
end

net.Receive("CMD_Decode", function(len, ply)
    local code = net.ReadString()
    local decode = Decode(code)
    print("Decode: "..decode)


    ply:ChatPrint("Decode: "..decode)
end)

hook.Add("PlayerSay","Progama057Commands",function(ply,text)
    local args = string.Split(text, " ")
	local cmd = string.lower(args[1])
    local txt = string.sub(text, #args[1] + 2)

    for k, v in SortedPairs(PD.Commands.Table) do
        if (cmd == "!" .. v.command) then
            if not v.admin then
                if not CONFIG:GetConfig("commands_adminteam")[ply:GetUserGroup()] or CONFIG:GetConfig("commands_adminjobs")[team.GetName(ply:Team())] then
                    ply:ChatPrint("Du hast keine Rechte für diesen Command!")
                    return ""
                end
            end

            net.Start("CommandsSend")
                net.WriteTable({typ = v.command, ply = ply})
            net.Send(ply)

            return ""
        end
    end

    if (cmd == "/verlosung") then
        if CONFIG:GetConfig("commands_adminteam")[ply:GetUserGroup()] or CONFIG:GetConfig("commands_adminjobs")[team.GetName(ply:Team())] then
            local gewinner = math.random(1,#player.GetAll())
            local gply = nil

            for k,v in pairs(player.GetAll()) do
                if k == gewinner then
                    gply = v
                end
            end

            net.Start("CMD_Verlosung")
                net.WriteEntity(gply)
                net.WriteEntity(ply)
                net.WriteString(txt)
            net.Broadcast()
        else
            ply:ChatPrint("Du hast keine Rechte für diesen Command!")
        end
        
        return ""
    elseif (cmd == "/status") then
        if !args[2] then ply:ChatPrint("*** Du hast keinen Status angegeben.") return end
        -- if #args[2] > 1 then ply:ChatPrint("*** Status Ungültig!!") return end

        ply:ChatPrint("*** Dein Status wurde auf "..string.upper(args[2]).." gesetzt.")

        ply:SetNWString("StatusCode", string.lower(args[2]))

        return ""
    elseif (cmd == "/leitstelle") then
        local plyCategory = PD.JOBS.GetJob(ply:GetJob()).category

		for k, v in pairs(player.GetAll()) do
			if PD.JOBS.GetJob(v:GetJob()).category == plyCategory then
				ply:ChatPrint(v:Name() .. " | " .. string.upper(v:GetNWString("StatusCode", "N/A")))
			end
		end

        return ""
    end

    for k, v in pairs(types) do
        local tbl = {}
        if (cmd == "/"..v) then
            if v == "rok " then
                if not CONFIG:GetConfig("commands_adminteam")[ply:GetUserGroup()] or CONFIG:GetConfig("commands_adminjobs")[team.GetName(ply:Team())] then
                    ply:ChatPrint("Du hast keine Rechte für diesen Command!")
                    return ""
                end
            end

            if v == "vfunk" then 
                txt = string.sub(text, #args[1] + #args[2] + 2)
                local codetxt = TextCode(txt)

                tbl.vtext = codetxt

                local ply2 = AutoComplitePlayerName(args[2])
                if ply2 then
                    tbl.ply2 = ply2
                end
            elseif v == "funk" then
                txt = string.sub(text, #args[1] + #args[2] + 2)

                local ply2 = AutoComplitePlayerName(args[2])
                if ply2 then
                    tbl.ply2 = ply2
                end
            elseif v == "roll" then
                local roll = math.random(1, 100)

                tbl.roll = roll
            elseif v == "flip" then
                local flip = math.random(1, 2)

                tbl.flip = flip
            elseif v == "efunk" then
                txt = string.sub(text, #args[1] + #args[2] + 2)

                -- for k, e in pairs(RPExtraTeams) do
                --     if string.lower(e.category) == string.lower(args[2]) then
                --         tbl.category = e.category
                --     end 
                -- end
            end

            tbl.typ = v
            tbl.text = txt
            tbl.ply = ply

            net.Start("CommandsSend")
                net.WriteTable(tbl)
            net.Broadcast()

            return ""
        end
    end
end)


