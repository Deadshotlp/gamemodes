--

local mouse = false
hook.Add("PlayerButtonDown", "PD.GamemodeHUD", function(ply, key)
    if not IsFirstTimePredicted() then return end
   
    if key == KEY_G and mouse then
        gui.EnableScreenClicker(false)
        mouse = false
    elseif key == KEY_G and not mouse then
        gui.EnableScreenClicker(true)
        mouse = true
    end
end)

timer.Simple(1, function()
    RunConsoleCommand("cl_drawhud", "0")
end)

hook.Add("PreRender", "JOaGPU", function()
    -- if not system.HasFocus() then

    --     cam.Start2D()

    --     draw.RoundedBox(0,0,0,ScrW(),ScrH(),Color(0,0,0,255))

    --     draw.DrawText("Hm, scheit so als hättest du dein Spiel nicht mehr aktiv!", "MLIB.50", ScrW() / 2, ScrH() / 2, Color(255,255,255), TEXT_ALIGN_CENTER)

    --     cam.End2D()
    
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
    if IsValid(frame) then return end

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
                        playerVars: { 'autoplay': 1, 'controls': 0, 'start': ]] .. VideoStart .. [[, 'end': ]] .. VideoEnde .. [[},
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

local function RulePopup()
    if IsValid(frame) then return end

    frame = PD.Frame("Regeln", PD.W(600), PD.H(800), false)

    local lbl = PD.Label("Regeln", frame)

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
        RulePopup()
    end
end)

local function DeveloperMenu()
    if IsValid(frame) then return end

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

function notification.AddLegacy() return end

