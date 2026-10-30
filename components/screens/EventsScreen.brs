' ====================================================================
' Saimo TV - EventsScreen (BrightScript)
' ====================================================================

sub init()
    m.eventsList = m.top.findNode("eventsList")
    m.eventsList.observeField("itemSelected", "onEventSelected")
end sub

sub onEventsChange()
    events = m.top.events
    if events = invalid then return

    root = CreateObject("roSGNode", "ContentNode")
    for each ev in events
        node = root.CreateChild("ContentNode")
        scoreStr = ""
        if ev.score <> invalid and ev.score <> "" then scoreStr = "  [" + ev.score + "]"
        node.title = ev.timeStr + "  •  " + ev.homeTeam + scoreStr + "  x  " + ev.awayTeam + "   (" + ev.league + ")   ▶ " + ev.channelName
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
