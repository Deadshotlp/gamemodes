

timer.Simple(1, function()
    RunConsoleCommand("cl_drawhud", "0")
end)

hook.Add("PreRender", "JOaGPU", function()
    -- if not system.HasFocus() then
    --     if LocalPlayer():IsAdmin() then
    --         return
    --     end

    --     -- cam.Start2D()
    --     --     draw.RoundedBox(0, 0, 0, ScrW(), ScrH(), Color(0, 0, 0, 255))
    --     --     draw.DrawText("Hm, scheit so als hättest du dein Spiel nicht mehr aktiv!", "MLIB.50", ScrW() / 2, ScrH() / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER)
    --     -- cam.End2D()

    --     return true
    -- end
end)

local videourl = ""
local VideoStart = 0
local VideoEnde = 0

local function ExtractVideoID(url)
    local videoID = string.match(url, "v=([%w_-]+)") -- Extrahiere die ID nach 'v='
    return videoID
end

net.Receive("PD.OpenYoutube", function()
    videourl = net.ReadString()
    -- VideoStart = net.ReadInt(32)
    -- VideoEnde = net.ReadInt(32)

    local videoID = ExtractVideoID(videourl)
    if videoID then
        YoutubeVideo(videourl)
    else
        print("[Fehler] Ungültige YouTube-URL: " .. videourl)
    end
end)

function YoutubeVideo(url)
    if IsValid(frame) then
        return
    end

    frame = PD.Frame("[E] Zum überspringen", ScrW(), ScrH(), true)

    local html = vgui.Create("DHTML", frame)
    html:SetSize(ScrW(), ScrH())
    html:Dock(FILL)

    html:SetHTML([[
        <html>
        <body style="margin:0; overflow:hidden; background-color:black;">
            <script src="https://www.youtube.com/iframe_api"></script>
            <div id="player"></div>
            <script>
                var player;
                function onYouTubeIframeAPIReady() {
                    player = new YT.Player('player', {
                        height: '100%',
                        width: '100%',
                        videoId: ']] .. ExtractVideoID(url) .. [[',
                        playerVars: { 'autoplay': 1, 'controls': 0, 'start': ]] .. VideoStart .. [[, 'end': ]] ..
                     VideoEnde .. [[},
                        events: {
                            'onStateChange': onPlayerStateChange
                        }
                    });
                }

                function onPlayerStateChange(event) {
                    if (event.data === YT.PlayerState.ENDED) {
                        console.log("Video beendet");
                        if (typeof gmod !== 'undefined') {
                            gmod.postMessage('closeFrame');
                        }
                    }
                }
            </script>
        </body>
        </html>
    ]])

    function html:ConsoleMessage(msg)
        if msg == "closeFrame" then
            frame:Remove()
        end
    end

    frame.OnKeyCodePressed = function(self, key)
        if key == KEY_ESCAPE then
            self:Remove()
        end
    end
end

hook.Add("Think", "PD.YoutubeSkip", function()
    if frame then
        if input.IsKeyDown(KEY_E) then
            frame:Remove()
        end
    end
end)

local longtext = [[
Bevor du den Server betrittst, musst du diese Regeln lesen und bestätigen. Verstöße können zu Kicks, Bans oder permanentem Ausschluss führen.

1. Roleplay (RP) Verhalten
Du spielst deinen Charakter immersiv – kein Metagaming oder Powergaming.

FailRP (z.B. unrealistisches Verhalten deines Charakters) ist verboten.

RP-Tod: Du vergisst alles, was passierte.

2. Kommunikation
Voice & Chat dienen dem RP – kein OOC im IC!

Respektiere andere Spieler, kein Trolling oder Beleidigungen.

Rassismus, Sexismus und andere diskriminierende Inhalte sind sofort bannwürdig.

3. Verbotenes Verhalten
Kein RDM (Random Deathmatch) oder VDM (Fahrzeuge als Waffe ohne RP).

Kein Cheating, Exploiting oder Bugusing.

Werbung für andere Server, Discords oder Communities ist untersagt.

4. Fraktionsverhalten
Befehle der Vorgesetzten sind zu befolgen – Befehlsverweigerung kann Ingame-Strafen haben.

Eigenmächtiges Handeln außerhalb deines Rangs/Jobs ist untersagt.

Klassen- oder Ausrüstungsregeln deiner Einheit müssen eingehalten werden.

5. Allgemeines Verhalten
Kein Spammen, Griefen oder Belästigen anderer Spieler.

Du brauchst ein funktionierendes Mikrofon und solltest im Voicechat klar verständlich sein.

Ich habe die Regeln gelesen, verstanden und akzeptiere sie.
]]

local function RulePopup()
    if IsValid(frame) then
        return
    end

    frame = PD.Frame("📜 Server-Regeln – Galactic Liberation", PD.W(600), PD.H(800), true, function(self, w, h)
        -- draw.DrawText(longtext, "MLIB.20", PD.W(10), PD.H(10), Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end)

    local scrl = PD.Scroll(frame)

    local pnl = PD.Panel("", scrl, function(self, w, h)
        -- draw.DrawText(longtext, "MLIB.20", PD.W(10), PD.H(10), Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        local longText = markup.Parse("<font=MLIB.20>" .. longtext, self:GetWide() - PD.W(20))
        longText:Draw(PD.W(10), PD.H(10), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end)
    surface.SetFont("MLIB.20")
    local w, h = surface.GetTextSize(longtext)
    pnl:SetTall(PD.H(h + 20))

    local accept = PD.Button("Akzeptieren", frame, function()
        frame:Remove()

        file.Write("pd_rules.json", "1")
    end)
    accept:Dock(BOTTOM)
    accept:SetTall(PD.H(50))
    accept:SetRadius(20)
    accept:SetHoverColor(Color(0, 255, 0))

    local decline = PD.Button("Ablehnen", frame, function()
        net.Start("PD.RuleDecline")
        net.SendToServer()
    end)
    decline:Dock(BOTTOM)
    decline:SetTall(PD.H(50))
    decline:SetRadius(20)
    decline:SetHoverColor(Color(255, 0, 0))
end

hook.Add("InitPostEntity", "PD.RulePopup", function()
    if not file.Exists("pd_rules.json", "DATA") then
        --RulePopup()
    end
end)

local function DeveloperMenu()
    if IsValid(frame) then
        return
    end

    frame = PD.Frame("Developer Menu", PD.W(600), PD.H(800), true)

    local checkPlayerView = PD.SimpleCheck(frame, "Developer Settings", true, function(val)
        PD.Developer = val
    end)

    local checkPlayerView = PD.SimpleCheck(frame, "Player View", false, function(val)
        PD.DeveloperView = val
    end)

    local checkPlayerView = PD.SimpleCheck(frame, "Developer Information", true, function(val)
        PD.DeveloperInfo = val
    end)
end

hook.Add("DrawDeathNotice", "NoDeathNOtice", function()
    return 0, 0
end)

hook.Add("Initialize", "NoDeathNOtice", function()
    GM = GM or GAMEMODE
    function GM:AddDeathNotice()
        return
    end
end)

function notification.AddLegacy()
    return
end

local function color_interpolieren(baseColor, count)
    local white = Color(255, 255, 255)
    local black = Color(0, 0, 0)
    local colors = {white, baseColor, black}

    local upStep = {(white.r - baseColor.r) / count, (white.g - baseColor.g) / count, (white.b - baseColor.b) / count}
    local downStep = {baseColor.r / count, baseColor.g / count, baseColor.b / count}

    for i = 1, count do
        local color
        colors["Base+" .. i] = Color(baseColor.r + upStep[1] * i, baseColor.g + upStep[2] * i,
            baseColor.b + upStep[3] * i)
        colors["Base-" .. i] = Color(baseColor.r + downStep[1] * (i - count / 2),
            baseColor.g + downStep[2] * (i - count / 2), baseColor.b + downStep[3] * (i - count / 2))
    end

    return colors
end
