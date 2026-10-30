' ====================================================================
' Saimo TV - PlayerOSD (BrightScript)
' ====================================================================

sub init()
    m.osdContainer = m.top.findNode("osdContainer")
    m.titleLabel = m.top.findNode("titleLabel")
    m.subLabel = m.top.findNode("subLabel")
    m.skipIntroBtn = m.top.findNode("skipIntroBtn")
    m.progressBar = m.top.findNode("progressBar")
    m.scrubHead = m.top.findNode("scrubHead")
    m.timeCurrentLabel = m.top.findNode("timeCurrentLabel")
    m.timeRemainingLabel = m.top.findNode("timeRemainingLabel")
    m.btnPlayPause = m.top.findNode("btnPlayPause")
    m.hideTimer = m.top.findNode("hideTimer")
    m.hideTimer.observeField("fire", "hideOSD")
end sub

sub onDataChange()
    m.titleLabel.text = m.top.title
    m.subLabel.text = m.top.subtitle
    m.skipIntroBtn.visible = m.top.isSeries
end sub

sub onStateChange()
    if m.top.isPlaying then
        m.btnPlayPause.text = "⏸ Pausar"
    else
        m.btnPlayPause.text = "▶ Reproduzir"
    end if
end sub

sub onPositionChange()
    pos = m.top.positionSec
    dur = m.top.durationSec
    if dur <= 0 then dur = 1

    pct = pos / dur
    if pct < 0 then pct = 0
    if pct > 1 then pct = 1

    barWidth = Int(1760 * pct)
    m.progressBar.width = barWidth
    m.scrubHead.translation = [barWidth, -4]

    m.timeCurrentLabel.text = FormatSecondsToTime(pos)
    remSec = dur - pos
    if remSec < 0 then remSec = 0
    m.timeRemainingLabel.text = "-" + FormatSecondsToTime(remSec)
end sub

sub onOpenChange()
    isOpen = m.top.isOpen
    m.osdContainer.visible = isOpen
    if isOpen then
        m.hideTimer.control = "stop"
        m.hideTimer.control = "start"
    end if
end sub

sub hideOSD()
    m.top.isOpen = false
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.top.isOpen then
        m.hideTimer.control = "stop"
        m.hideTimer.control = "start"

        if key = "OK" or key = "play" then
            m.top.playPauseRequested = true
            return true
        else if key = "left" or key = "rewind" then
            m.top.seekRequested = -10
            return true
        else if key = "right" or key = "fastforward" then
            m.top.seekRequested = 10
            return true
        else if key = "up" and m.top.isSeries then
            ' Pular abertura
            m.top.skipIntroRequested = true
            return true
        else if key = "back" or key = "down" then
            m.top.isOpen = false
            return true
        end if
    else
        ' Se pressionou qualquer botão de playback com OSD fechado, abre o OSD
        if key = "OK" or key = "up" or key = "down" or key = "left" or key = "right" or key = "play" or key = "rewind" or key = "fastforward" then
            m.top.isOpen = true
            return true
        end if
    end if

    return false
end function
