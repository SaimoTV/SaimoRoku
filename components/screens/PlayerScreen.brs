' ====================================================================
' Saimo TV - PlayerScreen (BrightScript)
' Player nativo de VOD, controle de progresso e auto-skip
' ====================================================================

sub init()
    m.videoPlayer = m.top.findNode("videoPlayer")
    m.bufferingGroup = m.top.findNode("bufferingGroup")
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

    m.playerOsd.title = item.title
    if item.isSeries then
        m.playerOsd.subtitle = "Temporada 1 • " + item.episodeTitle
        m.playerOsd.isSeries = true
    else
        m.playerOsd.subtitle = "Filme • Full HD"
        m.playerOsd.isSeries = false
    end if

    ' Constrói a URL do stream a partir da base
    prefs = LoadPreferences()
    baseUrl = prefs.urlFilmes
    streamUrl = baseUrl + "stream/" + item.title + ".m3u8"
    if item.url <> invalid and item.url <> "" then streamUrl = item.url

    content = CreateObject("roSGNode", "ContentNode")
    content.url = streamUrl
    content.title = item.title
    content.streamFormat = "hls"

    ' Aplica resume se fornecido
    if item.resumePos <> invalid and item.resumePos > 0 then
        content.playStart = item.resumePos
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
        m.playerOsd.isPlaying = true
    else if state = "paused" then
        m.playerOsd.isPlaying = false
    else if state = "buffering" then
        m.bufferingGroup.visible = true
    else if state = "finished" then
        ' Fim do vídeo: conclui e fecha
        saveCurrentProgress()
        m.top.exitRequested = true
    else if state = "error" then
        m.bufferingGroup.visible = false
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
    ' Pula abertura (+85 segundos)
    newPos = m.videoPlayer.position + 85
    if newPos > m.videoPlayer.duration then newPos = m.videoPlayer.duration
    m.videoPlayer.seek = newPos
end sub

sub saveCurrentProgress()
    if m.top.playItem = invalid then return
    pos = Int(m.videoPlayer.position)
    dur = Int(m.videoPlayer.duration)
    if dur > 60 then
        SaveVODProgress(m.top.playItem.title, pos, dur)
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
