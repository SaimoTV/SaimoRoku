' ====================================================================
' Saimo TV - GuideScreen (BrightScript)
' ====================================================================

sub init()
    m.guideChannelList = m.top.findNode("guideChannelList")
    m.selectedChannelHeader = m.top.findNode("selectedChannelHeader")
    m.scheduleList = m.top.findNode("scheduleList")

    m.guideChannelList.observeField("itemFocused", "onChannelFocused")
    m.guideChannelList.observeField("itemSelected", "onChannelSelected")
    m.scheduleList.observeField("itemSelected", "onScheduleSelected")
    m.top.observeField("focused", "onFocusChange")
end sub

sub onFocusChange()
    if m.top.hasFocus() and m.guideChannelList <> invalid then
        m.guideChannelList.setFocus(true)
    end if
end sub

sub onChannelsChange()
    channels = m.top.channels
    if channels = invalid or channels.Count() = 0 then return

    root = CreateObject("roSGNode", "ContentNode")
    for each ch in channels
        node = root.CreateChild("ContentNode")
        node.title = ch.number.ToStr() + "   " + ch.name
    end for
    m.guideChannelList.content = root
    updateSchedule(0)
end sub

sub onEpgChange()
    idx = m.guideChannelList.itemFocused
    if idx < 0 then idx = 0
    updateSchedule(idx)
end sub

sub onChannelFocused()
    idx = m.guideChannelList.itemFocused
    if idx < 0 then idx = 0
    updateSchedule(idx)
end sub

sub updateSchedule(idx as Integer)
    channels = m.top.channels
    if channels = invalid or channels.Count() = 0 then return
    if idx < 0 then idx = 0
    if idx >= channels.Count() then idx = channels.Count() - 1

    ch = channels[idx]
    m.selectedChannelHeader.text = "PROGRAMAÇÃO • " + UCase(ch.name)

    epgMap = m.top.epgMap
    root = CreateObject("roSGNode", "ContentNode")

    if epgMap <> invalid and epgMap[ch.name] <> invalid and epgMap[ch.name].Count() > 0 then
        for each p in epgMap[ch.name]
            node = root.CreateChild("ContentNode")
            timeStr = ""
            if p.isCurrent then
                timeStr = "[NO AR] "
            end if
            node.title = timeStr + p.title + " (" + p.durationMin.ToStr() + " min)"
        end for
    else
        node = root.CreateChild("ContentNode")
        node.title = "[NO AR] Transmissão Contínua Ao Vivo"
    end if

    m.scheduleList.content = root
end sub

sub onChannelSelected()
    idx = m.guideChannelList.itemSelected
    if m.top.channels <> invalid and idx >= 0 and idx < m.top.channels.Count() then
        m.top.tuneRequested = m.top.channels[idx]
    end if
end sub

sub onScheduleSelected()
    onChannelSelected()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "right" and m.guideChannelList.hasFocus() then
        if m.scheduleList.content <> invalid and m.scheduleList.content.getChildCount() > 0 then
            m.scheduleList.setFocus(true)
            return true
        end if
    else if key = "left" and m.scheduleList.hasFocus() then
        m.guideChannelList.setFocus(true)
        return true
    else if key = "left" and m.guideChannelList.hasFocus() then
        return false ' bubbles to MainScene to open sidebar
    end if

    return false
end function
