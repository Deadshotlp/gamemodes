PD.LANG = PD.LANG or {}

print("Loading Language Module...")

PD.LANG.List = PD.LANG.List or {
    ["EN"] = {
        Name = "English"
    },
    ["DE"] = {
        Name = "Deutsch"
    }
}

function PD.LANG.AddLanguage(name, code)
    PD.LANG.List[code] = {
        Name = name
    }
end

function PD.LANG.SetLanguage(code)
    if PD.LANG.List[code] then
        PD.Config.tbl.language.Current = code or PD.Config.tbl.language.Default
    end
end

function PD.LANG.Menu(base)
    if not IsValid(base) then
        return
    end

    local scrl = PD.Scroll(base)

    for k, v in SortedPairs(PD.LANG.List) do
        local langBtn = PD.Button(v.Name, scrl, function()
            PD.LANG.SetLanguage(k)
        end)
        langBtn:Dock(TOP)
        langBtn:SetTall(PD.H(50))
    end
end

function PD.LANG.Load()
    PD.LANG.SetLanguage(PD.Config.tbl.language.Current)

    local cur = PD.Config.tbl.language.Current

    for k, v in pairs(PD.LANG.List) do
        if k == cur then

            LANG = PD.LANG[k]

            chat.AddText(LANG.LANGUAGE_LOADED)
        end
    end
end

hook.Add("PD.Config.LoadModule", "PD.language", function()
    if not PD.Config.tbl.language or not istable(PD.Config.tbl.language) then
        PD.Config.tbl.language = {}
        PD.Config.tbl.language.Default = "DE"
        PD.Config.tbl.language.Current = "DE"
    end

    PD.LANG.Load()

    -- PrintTable(LANG)

    PD.Config:AddModule(LANG.ESC_CONFIG_LANGUAGE, function(base)
        PD.LANG.Menu(base)
    end)
end)
