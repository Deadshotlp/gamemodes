--[[
    Konsolenausgaben rund um das Web-Panel (pd_reload, Heartbeat, Lade-
    meldungen von Waffenkiste, Fortbildung, ArcCW, Assets).

    Standardmaessig stumm. Zum Mitlesen - etwa wenn das Panel eine Rueckmeldung
    aus der Konsole braucht - pd_remote_verbose 1 setzen (server.cfg oder
    Konsole).
]]
local verbose = CreateConVar("pd_remote_verbose", "0", FCVAR_ARCHIVE, "Konsolenausgaben des Web-Panels anzeigen (1) oder unterdruecken (0)")

function PD.RemoteLog(text)
    if verbose:GetBool() then
        print(text)
    end
end
