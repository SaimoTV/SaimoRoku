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
    t = m.top.findNode("focoTimer")
    t.observeField("fire", "aplicarFoco")
    t.control = "start"
    agora = CreateObject("roDateTime")
    m.top.findNode("relogio").text = horaDe(agora.AsSeconds())
end sub

sub aplicarFoco()
    m.guideChannelList.setFocus(true)
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
        node.title = ch.name
        if ch.logo <> invalid then node.hdPosterUrl = ch.logo
        prog = ""
        pct = 0.0
        lista = invalid
        if m.top.epgMap <> invalid then lista = m.top.epgMap[ch.name]
        if lista <> invalid and lista.Count() > 0 then
            prog = lista[0].title
            pct = progressoDe(lista[0])
        end if
        node.addFields({ numero: ch.number.ToStr(), grupoTexto: UCase(ch.category), programa: prog, progresso: pct })
    end for

    m.loadedChannelsCount = endIdx
end sub

function horaDe(seg as Integer) as String
    d = CreateObject("roDateTime")
    d.FromSeconds(seg)
    d.ToLocalTime()
    h = d.GetHours().ToStr()
    if Len(h) < 2 then h = "0" + h
    mi = d.GetMinutes().ToStr()
    if Len(mi) < 2 then mi = "0" + mi
    return h + ":" + mi
end function

function progressoDe(p as Object) as Float
    agora = CreateObject("roDateTime").AsSeconds()
    if agora < p.startSec or agora >= p.stopSec or p.stopSec <= p.startSec then return 0.0
    return (agora - p.startSec) / (p.stopSec - p.startSec)
end function

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
    m.selectedChannelHeader.text = ch.number.ToStr() + "  " + ch.name

    epgMap = m.top.epgMap
    root = CreateObject("roSGNode", "ContentNode")
    if epgMap <> invalid and epgMap[ch.name] <> invalid then
        for each p in epgMap[ch.name]
            node = root.CreateChild("ContentNode")
            node.title = p.title
            node.description = p.durationMin.ToStr() + " min"
            node.addFields({ hora: horaDe(p.startSec), progresso: progressoDe(p) })
        end for
    end if
    if root.getChildCount() = 0 then
        node = root.CreateChild("ContentNode")
        node.title = "Sem programação para este canal"
        node.addFields({ hora: "", progresso: 0.0 })
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

    if key = "right" and m.guideChannelList.isInFocusChain() then
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
        m.top.voltarRequested = true
        return true
    end if

    return false
end function
