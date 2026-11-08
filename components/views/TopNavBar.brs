' ====================================================================
' Saimo TV para Roku - TopNavBar (BrightScript)
' Barra de navegação superior idêntica ao design do TV Box
' Navegação suave com confirmação explícita (OK / Baixo)
' ====================================================================

sub init()
    m.pillSel = m.top.findNode("pillSel")
    m.pillFoco = m.top.findNode("pillFoco")
    m.clockLabel = m.top.findNode("clockLabel")
    m.clockTimer = m.top.findNode("clockTimer")
    m.clockTimer.observeField("fire", "updateClock")
    m.clockTimer.control = "start"
    updateClock()

    m.itemNames = ["search", "home", "live", "events", "vod", "favorites", "radios", "doacao", "settings"]
    m.tabPositions = [150, 322, 478, 658, 844, 1080, 1284, 1458, 1620]
    m.tabWidths = [168, 152, 176, 182, 232, 200, 170, 158, 64]

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
    alvo = m.focusedIndex
    if alvo < 0 then alvo = 0
    if alvo > 8 then alvo = 8
    atual = m.top.selectedIndex
    temFoco = m.top.hasFocus()

    m.pillSel.translation = [m.tabPositions[atual], 36]
    m.pillSel.width = m.tabWidths[atual]
    m.pillFoco.translation = [m.tabPositions[alvo], 36]
    m.pillFoco.width = m.tabWidths[alvo]
    m.pillFoco.visible = temFoco

    for i = 0 to 8
        cor = "#FFFFFF"
        if temFoco and i = alvo then cor = "#0b0e14"
        m.top.findNode("icon_" + i.ToStr()).blendColor = cor
        rotulo = m.top.findNode("label_" + i.ToStr())
        if rotulo <> invalid then rotulo.color = cor
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
        if m.focusedIndex < 8 then
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
        ' Volta à tela atual sem trocar de aba, como na TV Box.
        m.focusedIndex = m.top.selectedIndex
        updateVisuals()
        m.top.focusDownRequested = true
        return true
    end if

    return false
end function
