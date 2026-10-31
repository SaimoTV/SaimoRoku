' ====================================================================
' Saimo TV - GuideScreen (BrightScript)
' ====================================================================

sub init()
    m.guideChannelList = m.top.findNode("guideChannelList")
    m.selectedChannelHeader = m.top.findNode("selectedChannelHeader")
    m.scheduleList = m.top.findNode("scheduleList")

    m.loadedChannelsCount = 0
    m.allChannels = []
    m.guideRootNode = invalid

    m.guideChannelList.observeField("itemFocused", "onChannelFocused")
    m.guideChannelList.observeField("itemSelected", "onChannelSelected")
    m.scheduleList.observeField("itemSelected", "onScheduleSelected")
    m.top.observeField("focusedChild", "onFocusedChildChange")
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() and not m.guideChannelList.isInFocusChain() and not m.scheduleList.isInFocusChain() then
        if m.guideChannelList <> invalid then m.guideChannelList.setFocus(true)
    end if
end sub

sub onChannelsChange()
    channels = m.top.channels
    if channels = invalid or channels.Count() = 0 then return

    m.allChannels = channels
    m.loadedChannelsCount = 0
    m.guideRootNode = CreateObject("roSGNode", "ContentNode")
    m.guideChannelList.content = m.guideRootNode

    loadMoreChannels(50)
    updateSchedule(0)
end sub

sub loadMoreChannels(count as Integer)
    if m.allChannels = invalid or m.guideRootNode = invalid then return
    total = m.allChannels.Count()
    if m.loadedChannelsCount >= total then return

    endIdx = m.loadedChannelsCount + count
    if endIdx > total then endIdx = total

    for i = m.loadedChannelsCount to endIdx - 1
        ch = m.allChannels[i]
        node = m.guideRootNode.CreateChild("ContentNode")
        node.title = ch.number.ToStr() + "   " + ch.name
    end for

    m.loadedChannelsCount = endIdx
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

    ' Carregamento sob demanda contínuo: quando o usuário rola até 15 canais do fim da lista, carrega mais 40
    if m.allChannels <> invalid and m.loadedChannelsCount < m.allChannels.Count() and idx >= (m.loadedChannelsCount - 15) then
        loadMoreChannels(40)
    end if
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

    if not m.guideChannelList.isInFocusChain() and not m.scheduleList.isInFocusChain() then
        if m.guideChannelList <> invalid then m.guideChannelList.setFocus(true)
    end if

    if key = "up" then
        if m.guideChannelList.isInFocusChain() and m.guideChannelList.itemFocused <= 0 then
            m.top.focusUpRequested = true
            return true
        else if m.scheduleList.isInFocusChain() and m.scheduleList.itemFocused <= 0 then
            m.top.focusUpRequested = true
            return true
        end if
    else if key = "right" and m.guideChannelList.isInFocusChain() then
        if m.scheduleList.content <> invalid and m.scheduleList.content.getChildCount() > 0 then
            m.scheduleList.setFocus(true)
            return true
        end if
    else if key = "left" and m.scheduleList.isInFocusChain() then
        m.guideChannelList.setFocus(true)
        return true
    else if key = "left" and m.guideChannelList.isInFocusChain() then
        return true
    else if key = "back" then
        if m.scheduleList.isInFocusChain() then
            m.guideChannelList.setFocus(true)
            return true
        end if
        return false ' bubbles to MainScene
    end if

    return false
end function
