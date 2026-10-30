' ====================================================================
' Saimo TV - ZapHUD (BrightScript)
' ====================================================================

sub init()
    m.hudContainer = m.top.findNode("hudContainer")
    m.numLabel = m.top.findNode("numLabel")
    m.logoPoster = m.top.findNode("logoPoster")
    m.nameLabel = m.top.findNode("nameLabel")
    m.progLabel = m.top.findNode("progLabel")
    m.progBar = m.top.findNode("progBar")
    m.hideTimer = m.top.findNode("hideTimer")
    m.hideTimer.observeField("fire", "hideHUD")
end sub

sub onDataChange()
    m.numLabel.text = m.top.channelNumber
    m.nameLabel.text = m.top.channelName
    if m.top.channelLogo <> "" then
        m.logoPoster.uri = m.top.channelLogo
    end if
    if m.top.programTitle <> "" then
        m.progLabel.text = m.top.programTitle
    else
        m.progLabel.text = "Programação não disponível"
    end if

    pct = m.top.programProgress
    if pct < 0 then pct = 0
    if pct > 1 then pct = 1
    m.progBar.width = Int(1200 * pct)

    showHUD()
end sub

sub showHUD()
    m.hudContainer.visible = true
    m.hideTimer.control = "stop"
    m.hideTimer.control = "start"
end sub

sub hideHUD()
    m.hudContainer.visible = false
end sub
