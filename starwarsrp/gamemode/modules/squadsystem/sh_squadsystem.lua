PD.SQUAD = PD.SQUAD or {}
PD.SQUAD.rolle_list = PD.SQUAD.rolle_list or {
    [1] = {
        name = "Attack",
        icon = nil,
        color = Color(255, 215, 0),
    },
    [2] = {
        name = "Defense",
        icon = nil,
        color = Color(255, 215, 0),
    },
    [3] = {
        name = "Support",
        icon = nil,
        color = Color(255, 215, 0),
    },
    [4] = {
        name = "Recon",
        icon = nil,
        color = Color(255, 215, 0),
    },
    [5] = {
        name = "Medical",
        icon = nil,
        color = Color(255, 215, 0),
    },
    [6] = {
        name = "Engineering",
        icon = nil,
        color = Color(255, 215, 0),
    }
}

PD.SQUAD.rank_list = PD.SQUAD.rank_list or {
    [1] = {
        name = "Leader",
        icon = nil,
        color = Color(255, 215, 0),
    },
    [2] = {
        name = "Co-Leader",
        icon = nil,
        color = Color(255, 215, 0),
    },
    [3] = {
        name = "Member",
        icon = nil,
        color = Color(255, 255, 255), 
    },
    [4] = {
        name = "Medic",
        icon = nil,
        color = Color(255, 0, 0),
    },
    [5] = {
        name = "EOD",
        icon = nil,
        color = Color(255, 255, 0),
    }
}

PD.SQUAD.name_list = PD.SQUAD.name_list or {
    "Alpha Squad",
    "Bravo Squad",
    "Charlie Squad",
    "Delta Squad",
    "Echo Squad",
    "Foxtrot Squad",
    "Gamma Squad",
    "Hotel Squad",
    "India Squad",
    "Juliet Squad",
    "Kilo Squad",
    "Lima Squad",
    "Mike Squad",
    "November Squad",
    "Oscar Squad",
    "Papa Squad",
    "Quebec Squad",
    "Romeo Squad",
    "Sierra Squad",
    "Tango Squad",
    "Uniform Squad",
    "Victor Squad",
    "Whiskey Squad",
    "X-ray Squad",
    "Yankee Squad",
    "Zulu Squad"
}

if CLIENT then
    net.Start("PD.SQUAD.UpdateSquad")
    net.WriteString("squad_background")
    net.WriteEntity(LocalPlayer())
    net.SendToServer()
end