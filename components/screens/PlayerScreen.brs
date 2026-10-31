' ====================================================================
' Saimo TV - PlayerScreen (BrightScript)
' Player nativo de VOD, controle de progresso, fallbacks e proxy
' ====================================================================

sub init()
    m.videoPlayer = m.top.findNode("videoPlayer")
    m.bufferingGroup = m.top.findNode("bufferingGroup")
    m.errorGroup = m.top.findNode("errorGroup")
    m.errorLabel = m.top.findNode("errorLabel")
    m.playerOsd = m.top.findNode("playerOsd")
    m.progressTimer = m.top.findNode("progressTimer")

    m.candidateUrls = []
    m.candidateIdx = 0
    m.tryingProxy = false
    m.resumePos = 0

    m.videoPlayer.observeField("state", "onVideoState")
    m.videoPlayer.observeField("position", "onVideoPosition")
    m.videoPlayer.observeField("duration", "onVideoDuration")
    m.progressTimer.observeField("fire", "saveCurrentProgress")

    m.playerOsd.observeField("playPauseRequested", "onOsdPlayPause")
    m.playerOsd.observeField("seekRequested", "onOsdSeek")
    m.playerOsd.observeField("skipIntroRequested", "onOsdSkipIntro")
end sub

sub onPlayItemChange()
    item = m.top.playItem
    if item = invalid then return

    m.errorGroup.visible = false
    m.bufferingGroup.visible = true

    m.playerOsd.title = item.title
    if item.isSeries then
        epTitle = "Episódio 1"
        if item.episodeTitle <> invalid and item.episodeTitle <> "" then
            epTitle = item.episodeTitle
        else if item.episode <> invalid then
            epTitle = "Episódio " + item.episode.ToStr()
        end if
        seasonNum = 1
        if item.season <> invalid and item.season > 0 then seasonNum = item.season
        m.playerOsd.subtitle = "Temporada " + seasonNum.ToStr() + " • " + epTitle
        m.playerOsd.isSeries = true
    else
        m.playerOsd.subtitle = "Filme • Full HD"
        m.playerOsd.isSeries = false
    end if

    m.candidateUrls = []
    m.candidateIdx = 0
    m.tryingProxy = false
    m.resumePos = 0
    if item.resumePos <> invalid then m.resumePos = item.resumePos

    ' Se já tem URL direta, toca imediatamente
    if item.url <> invalid and item.url <> "" then
        m.candidateUrls = [item.url]
        playCandidate(0, false)
    else
        ' Resolve a URL usando StreamResolverTask
        m.resolverTask = CreateObject("roSGNode", "StreamResolverTask")
        m.resolverTask.requestItem = item
        m.resolverTask.observeField("resolvedItem", "onStreamResolved")
        m.resolverTask.control = "run"
    end if
end sub

sub onStreamResolved(evt as Object)
    resolved = evt.getData()
    if resolved <> invalid and resolved.candidateUrls <> invalid and resolved.candidateUrls.Count() > 0 then
        m.candidateUrls = resolved.candidateUrls
        m.candidateIdx = 0
        m.tryingProxy = false
        if resolved.resumePos <> invalid then m.resumePos = resolved.resumePos
        playCandidate(0, false)
    else if resolved <> invalid and resolved.url <> invalid and resolved.url <> "" then
        m.candidateUrls = [resolved.url]
        m.candidateIdx = 0
        m.tryingProxy = false
        if resolved.resumePos <> invalid then m.resumePos = resolved.resumePos
        playCandidate(0, false)
    else
        m.bufferingGroup.visible = false
        m.errorLabel.text = "Vídeo indisponível no momento"
        m.errorGroup.visible = true
    end if
end sub

sub playCandidate(idx as Integer, useProxy as Boolean)
    if m.candidateUrls = invalid or idx >= m.candidateUrls.Count() then
        m.bufferingGroup.visible = false
        m.errorLabel.text = "Vídeo indisponível no momento"
        m.errorGroup.visible = true
        return
    end if

    rawUrl = m.candidateUrls[idx]
    if rawUrl = invalid or rawUrl = "" then
        tryNextCandidate()
        return
    end if

    playUrl = rawUrl
    isTxt = (Instr(1, LCase(rawUrl), ".txt") > 0)

    ' Se está no modo proxy ou é .txt e ainda não está com api/proxy
    if (useProxy or isTxt) and Instr(1, playUrl, "api/proxy") = 0 then
        ut = CreateObject("roUrlTransfer")
        playUrl = "https://saimo-tv.pages.dev/api/proxy?url=" + ut.Escape(rawUrl)
    end if

    startPlayback(playUrl, m.resumePos)
end sub

sub tryNextCandidate()
    if m.candidateUrls = invalid or m.candidateUrls.Count() = 0 then
        m.bufferingGroup.visible = false
        m.errorLabel.text = "Falha ao reproduzir o vídeo"
        m.errorGroup.visible = true
        return
    end if

    currentUrl = m.candidateUrls[m.candidateIdx]

    ' 1. Tenta a fonte atual via proxy da Cloudflare se ainda não tentou
    if not m.tryingProxy and Instr(1, currentUrl, "api/proxy") = 0 then
        m.tryingProxy = true
        playCandidate(m.candidateIdx, true)
        return
    end if

    ' 2. Se o proxy da fonte atual também falhou, avança para a próxima fonte direta
    m.candidateIdx = m.candidateIdx + 1
    m.tryingProxy = false

    if m.candidateIdx < m.candidateUrls.Count() then
        playCandidate(m.candidateIdx, false)
    else
        ' Esgotou todos os candidatos
        m.bufferingGroup.visible = false
        m.errorLabel.text = "Vídeo indisponível no momento"
        m.errorGroup.visible = true
    end if
end sub

sub startPlayback(streamUrl as String, resumePos as Dynamic)
    content = CreateObject("roSGNode", "ContentNode")
    content.url = streamUrl
    content.title = m.playerOsd.title
    
    headers = ["User-Agent: SaimoTV/2.6.0 (RokuOS)", "Accept: */*"]
    if Instr(1, LCase(streamUrl), "embedplayer2.xyz") > 0 then
        headers.Push("Referer: https://embedplayer2.xyz/")
    end if
    content.HttpHeaders = headers

    lowerUrl = LCase(streamUrl)
    if Instr(1, lowerUrl, ".m3u8") > 0 or Instr(1, lowerUrl, "master.txt") > 0 or Instr(1, lowerUrl, "/hls/") > 0 or Instr(1, lowerUrl, "api/proxy") > 0 then
        content.streamFormat = "hls"
    else if Instr(1, lowerUrl, ".mkv") > 0 then
        content.streamFormat = "mkv"
    else
        content.streamFormat = "mp4"
    end if

    if resumePos <> invalid and resumePos > 0 then
        content.playStart = resumePos
    end if

    m.bufferingGroup.visible = true
    m.videoPlayer.content = content
    m.videoPlayer.control = "play"
    m.progressTimer.control = "start"
    m.playerOsd.isOpen = true
end sub

sub onVideoState()
    state = m.videoPlayer.state
    if state = "playing" then
        m.bufferingGroup.visible = false
        m.errorGroup.visible = false
        m.playerOsd.isPlaying = true
    else if state = "paused" then
        m.playerOsd.isPlaying = false
    else if state = "buffering" then
        m.bufferingGroup.visible = true
    else if state = "finished" then
        videoPos = m.videoPlayer.position
        if videoPos > 10 then
            saveCurrentProgress()
            item = m.top.playItem
            if item <> invalid and item.isSeries and item.episode <> invalid then
                ' Auto-avançar para o próximo episódio
                nextEp = item.episode + 1
                item.episode = nextEp
                item.resumePos = 0
                item.episodeTitle = "Episódio " + nextEp.ToStr()
                item.url = "" ' Limpa URL direta para que StreamResolverTask resolva o próximo episódio
                m.top.playItem = item
                onPlayItemChange()
            else
                m.top.exitRequested = true
            end if
        else
            ' Vídeo finalizou sem sequer começar -> falha de stream
            m.bufferingGroup.visible = false
            tryNextCandidate()
        end if
    else if state = "error" then
        m.bufferingGroup.visible = false
        tryNextCandidate()
    end if
end sub

sub onVideoPosition()
    m.playerOsd.positionSec = Int(m.videoPlayer.position)
end sub

sub onVideoDuration()
    m.playerOsd.durationSec = Int(m.videoPlayer.duration)
end sub

sub onOsdPlayPause()
    if m.videoPlayer.state = "playing" then
        m.videoPlayer.control = "pause"
    else
        m.videoPlayer.control = "resume"
    end if
end sub

sub onOsdSeek()
    delta = m.playerOsd.seekRequested
    newPos = m.videoPlayer.position + delta
    if newPos < 0 then newPos = 0
    if newPos > m.videoPlayer.duration then newPos = m.videoPlayer.duration
    m.videoPlayer.seek = newPos
end sub

sub onOsdSkipIntro()
    newPos = m.videoPlayer.position + 85
    if newPos > m.videoPlayer.duration then newPos = m.videoPlayer.duration
    m.videoPlayer.seek = newPos
end sub

sub saveCurrentProgress()
    if m.top.playItem = invalid then return
    currentPos = Int(m.videoPlayer.position)
    dur = Int(m.videoPlayer.duration)
    if dur > 60 then
        item = m.top.playItem
        season = 0
        episode = 0
        epTitle = ""
        url = ""
        if item.season <> invalid then season = item.season
        if item.episode <> invalid then episode = item.episode
        if item.episodeTitle <> invalid then epTitle = item.episodeTitle
        if item.url <> invalid then url = item.url
        SaveVODProgress(item.title, currentPos, dur, season, episode, epTitle, url)
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back" then
        saveCurrentProgress()
        m.videoPlayer.control = "stop"
        m.progressTimer.control = "stop"
        m.top.exitRequested = true
        return true
    end if

    return false
end function

sub cleanUp()
    saveCurrentProgress()
    if m.videoPlayer <> invalid then
        m.videoPlayer.control = "stop"
        m.videoPlayer.content = invalid
    end if
    if m.progressTimer <> invalid then
        m.progressTimer.control = "stop"
    end if
end sub
