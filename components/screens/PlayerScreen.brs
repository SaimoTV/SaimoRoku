' ====================================================================
' Saimo TV - PlayerScreen (BrightScript)
' Player nativo de VOD, controle de progresso e auto-skip
' ====================================================================

sub init()
    m.videoPlayer = m.top.findNode("videoPlayer")
    m.bufferingGroup = m.top.findNode("bufferingGroup")
    m.errorGroup = m.top.findNode("errorGroup")
    m.errorLabel = m.top.findNode("errorLabel")
    m.playerOsd = m.top.findNode("playerOsd")
    m.progressTimer = m.top.findNode("progressTimer")

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
        if item.episodeTitle <> invalid then epTitle = item.episodeTitle
        m.playerOsd.subtitle = "Temporada 1 • " + epTitle
        m.playerOsd.isSeries = true
    else
        m.playerOsd.subtitle = "Filme • Full HD"
        m.playerOsd.isSeries = false
    end if

    ' Se já tem URL direta, toca imediatamente
    if item.url <> invalid and item.url <> "" then
        startPlayback(item.url, item.resumePos)
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
    if resolved <> invalid and resolved.url <> invalid and resolved.url <> "" then
        startPlayback(resolved.url, resolved.resumePos)
    else
        m.bufferingGroup.visible = false
        m.errorLabel.text = "Vídeo indisponível no momento"
        m.errorGroup.visible = true
    end if
end sub

sub startPlayback(streamUrl as String, resumePos as Dynamic)
    content = CreateObject("roSGNode", "ContentNode")
    content.url = streamUrl
    content.title = m.playerOsd.title

    if Instr(1, streamUrl, ".m3u8") > 0 or Instr(1, streamUrl, "api/stream") > 0 then
        content.streamFormat = "hls"
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
        saveCurrentProgress()
        m.top.exitRequested = true
    else if state = "error" then
        m.bufferingGroup.visible = false
        m.errorLabel.text = "Falha ao reproduzir o vídeo"
        m.errorGroup.visible = true
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
        SaveVODProgress(m.top.playItem.title, currentPos, dur)
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
