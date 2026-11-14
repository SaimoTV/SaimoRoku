' ====================================================================
' Saimo TV - DebridResolveTask (BrightScript)
' Resolve sob demanda um stream torrent (infoHash + fileIdx + sources)
' usando TorBox / Real-Debrid / AllDebrid / Premiumize.
' ====================================================================

sub init()
    m.top.functionName = "executar"
end sub

sub executar()
    info = m.top.streamInfo
    if info = invalid then
        m.top.result = { ok: false, url: "", error: "Dados do stream inválidos." }
        return
    end if
    m.top.result = ResolveTorrentViaDebrid(info)
end sub
