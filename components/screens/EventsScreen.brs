' ====================================================================
' Saimo TV - EventsScreen (BrightScript)
' ====================================================================

sub init()
    m.eventsList = m.top.findNode("eventsList")
    m.eventsList.observeField("itemSelected", "onEventSelected")
    m.top.observeField("focused", "onFocusChange")
end sub

sub onFocusChange()
    if m.top.hasFocus() and m.eventsList <> invalid then
        m.eventsList.setFocus(true)
    end if
end sub

sub onEventsChange()
    events = m.top.events
    if events = invalid then return

    root = CreateObject("roSGNode", "ContentNode")
    for each ev in events
        node = root.CreateChild("ContentNode")
        scoreStr = ""
        if ev.score <> invalid and ev.score <> "" then scoreStr = "  [" + ev.score + "]"
        node.title = ev.timeStr + "  •  " + ev.homeTeam + scoreStr + "  x  " + ev.awayTeam + "   (" + ev.league + ")   • Canal: " + ev.channelName
        node.addFields({ channelName: ev.channelName })
    end for

    m.eventsList.content = root
end sub

sub onEventSelected()
    idx = m.eventsList.itemSelected
    root = m.eventsList.content
    if root <> invalid and idx < root.getChildCount() then
        node = root.getChild(idx)
        if node <> invalid and node.channelName <> invalid then
            m.top.tuneRequested = node.channelName
        end if
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "left" and m.eventsList.hasFocus() then
        return false ' Bubbles to MainScene to open sidebar
    end if

    return false
end function
