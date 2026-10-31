' ====================================================================
' Saimo TV para Roku - TopNavBar (BrightScript)
' Barra de navegação superior idêntica ao design do TV Box
' ====================================================================

sub init()
    m.tabPill = m.top.findNode("tabPill")
    m.tabBorder = m.top.findNode("tabBorder")
    m.clockLabel = m.top.findNode("clockLabel")
    m.clockTimer = m.top.findNode("clockTimer")
    m.clockTimer.observeField("fire", "updateClock")
    m.clockTimer.control = "start"
    updateClock()

    m.itemNames = ["search", "home", "live", "events", "vod", "favorites", "radios", "settings"]
    m.tabWidth = 140
    m.top.observeField("focusedChild", "onFocusedChildChange")
    updateVisuals(1)
end sub

sub onFocusedChildChange()
    updateVisuals(m.top.selectedIndex)
end sub

sub updateClock()
    date = CreateObject("roDateTime")
    date.ToLocalTime()
    hrs = date.GetHours().ToStr()
    if Len(hrs) < 2 then hrs = "0" + hrs
    mins = date.GetMinutes().ToStr()
    if Len(mins) < 2 then mins = "0" + mins
    m.clockLabel.text = hrs + ":" + mins
end sub

sub onIndexChange()
    updateVisuals(m.top.selectedIndex)
end sub

sub updateVisuals(index as Integer)
    if index < 0 then index = 0
    if index > 7 then index = 7

    xPos = 270 + (index * m.tabWidth)
    m.tabPill.translation = [xPos, 14]
    m.tabBorder.translation = [xPos, 57]

    hasRealFocus = m.top.hasFocus()
    if hasRealFocus then
        m.tabPill.color = "#4FE3D0"
        m.tabBorder.color = "#FFFFFF"
    else
        m.tabPill.color = "#1a2436"
        m.tabBorder.color = "#4FE3D0"
    end if

    for i = 0 to 7
        labelNode = m.top.findNode("label_" + i.ToStr())
        if labelNode <> invalid then
            if i = index then
                if hasRealFocus then
                    labelNode.color = "#0b0e14"
                else
                    labelNode.color = "#4FE3D0"
                end if
            else
                labelNode.color = "#94a3b8"
            end if
        end if
    end for
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "left" then
        if m.top.selectedIndex > 0 then
            m.top.selectedIndex = m.top.selectedIndex - 1
            m.top.itemSelected = m.itemNames[m.top.selectedIndex]
            return true
        end if
    else if key = "right" then
        if m.top.selectedIndex < 7 then
            m.top.selectedIndex = m.top.selectedIndex + 1
            m.top.itemSelected = m.itemNames[m.top.selectedIndex]
            return true
        end if
    else if key = "down" then
        m.top.focusDownRequested = true
        return true
    else if key = "OK" then
        m.top.itemSelected = m.itemNames[m.top.selectedIndex]
        m.top.focusDownRequested = true
        return true
    end if

    return false
end function
