' ====================================================================
' Saimo TV para Roku - TopNavBar (BrightScript)
' Barra de navegação superior idêntica ao design do TV Box
' Navegação suave com confirmação explícita (OK / Baixo)
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
    m.tabPositions = [250, 365, 470, 600, 730, 900, 1055, 1175]
    m.tabWidths = [110, 100, 125, 125, 165, 150, 115, 115]

    m.focusedIndex = 1
    m.top.observeField("focusedChild", "onFocusedChildChange")
    updateVisuals()
end sub

sub onFocusedChildChange()
    if m.top.hasFocus() then
        m.focusedIndex = m.top.selectedIndex
    end if
    updateVisuals()
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
    m.focusedIndex = m.top.selectedIndex
    updateVisuals()
end sub

sub updateVisuals()
    targetIdx = m.focusedIndex
    if targetIdx < 0 then targetIdx = 0
    if targetIdx > 7 then targetIdx = 7

    xPos = m.tabPositions[targetIdx]
    tWidth = m.tabWidths[targetIdx]

    m.tabPill.translation = [xPos, 14]
    m.tabPill.width = tWidth
    m.tabBorder.translation = [xPos, 57]
    m.tabBorder.width = tWidth

    hasRealFocus = m.top.hasFocus()
    if hasRealFocus then
        m.tabPill.color = "#4FE3D0"
        m.tabBorder.color = "#FFFFFF"
    else
        m.tabPill.color = "#162032"
        m.tabBorder.color = "#4FE3D0"
    end if

    activeScreenIdx = m.top.selectedIndex

    for i = 0 to 7
        labelNode = m.top.findNode("label_" + i.ToStr())
        if labelNode <> invalid then
            if i = targetIdx and hasRealFocus then
                labelNode.color = "#0b0e14"
            else if i = activeScreenIdx then
                labelNode.color = "#4FE3D0"
            else
                labelNode.color = "#94a3b8"
            end if
        end if
    end for
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "left" then
        if m.focusedIndex > 0 then
            m.focusedIndex = m.focusedIndex - 1
            updateVisuals()
            return true
        end if
    else if key = "right" then
        if m.focusedIndex < 7 then
            m.focusedIndex = m.focusedIndex + 1
            updateVisuals()
            return true
        end if
    else if key = "OK" then
        ' CONFIRMAÇÃO OBRIGATÓRIA: Só abre a tela quando o usuário apertar OK!
        m.top.selectedIndex = m.focusedIndex
        m.top.itemSelected = m.itemNames[m.focusedIndex]
        m.top.focusDownRequested = true
        return true
    else if key = "down" then
        ' Seta para baixo confirma e entra na tela focada
        m.top.selectedIndex = m.focusedIndex
        m.top.itemSelected = m.itemNames[m.focusedIndex]
        m.top.focusDownRequested = true
        return true
    end if

    return false
end function
