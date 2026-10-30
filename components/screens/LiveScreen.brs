' ====================================================================
' Saimo TV - LiveScreen (BrightScript)
' Zapping instantâneo, decodificação por hardware e bloqueio parental
' ====================================================================

sub init()
    m.liveVideo = m.top.findNode("liveVideo")
    m.bufferingGroup = m.top.findNode("bufferingGroup")
    m.zapHud = m.top.findNode("zapHud")
    m.channelDrawer = m.top.findNode("channelDrawer")
    m.drawerHintGroup = m.top.findNode("drawerHintGroup")
    m.pinModal = m.top.findNode("pinModal")

    m.liveVideo.observeField("state", "onVideoState")
    m.channelDrawer.observeField("channelSelected", "onDrawerSelect")
    m.channelDrawer.observeField("isOpen", "onDrawerOpenChange")
    m.pinModal.observeField("isUnlocked", "onPinUnlocked")
    m.top.observeField("focusedChild", "onFocusedChildChange")

    m.favoriteToast = m.top.findNode("favoriteToast")
    m.favoriteToastText = m.top.findNode("favoriteToastText")
    m.favoriteToastTimer = m.top.findNode("favoriteToastTimer")
    m.favoriteToastTimer.observeField("fire", "onFavoriteToastTimer")

    m.numberBuffer = ""
    m.numberTimer = CreateObject("roSGNode", "Timer")
    m.numberTimer.duration = 1.2
    m.numberTimer.repeat = false
    m.numberTimer.observeField("fire", "onNumberTimerFired")
    m.top.appendChild(m.numberTimer)
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() then
        if m.channelDrawer.isOpen then
            m.channelDrawer.setFocus(true)
        end if
    end if
end sub

sub onFavoriteToastTimer()
    m.favoriteToast.visible = false
end sub

sub showFavoriteToast(channelName as String, isFav as Boolean)
    if isFav then
        m.favoriteToastText.text = "★ " + channelName + " nos Favoritos"
    else
        m.favoriteToastText.text = "☆ " + channelName + " removido dos Favoritos"
    end if
    m.favoriteToast.visible = true
    m.favoriteToastTimer.control = "stop"
    m.favoriteToastTimer.control = "start"
end sub

sub onDrawerOpenChange()
    if m.channelDrawer.isOpen then
        m.drawerHintGroup.visible = false
    else
        m.drawerHintGroup.visible = true
        m.top.setFocus(true)
    end if
end sub

sub onChannelsChange()
    m.channelDrawer.channels = m.top.channels
    if m.top.channels <> invalid and m.top.channels.Count() > 0 then
        playChannel(m.top.currentChannelIndex)
        if m.top.openDrawerOnLoad then
            m.channelDrawer.selectedIndex = m.top.currentChannelIndex
            m.channelDrawer.isOpen = true
            m.channelDrawer.setFocus(true)
            m.top.openDrawerOnLoad = false
        end if
    end if
end sub

sub onEpgChange()
    updateHUDInfo()
end sub

sub onChannelIndexChange()
    playChannel(m.top.currentChannelIndex)
end sub

sub playChannel(index as Integer)
    channels = m.top.channels
    if channels = invalid or channels.Count() = 0 then return
    if index < 0 then index = channels.Count() - 1
    if index >= channels.Count() then index = 0
    if m.top.currentChannelIndex <> index then
        m.top.currentChannelIndex = index
    end if

    ch = channels[index]

    ' Verifica se é canal adulto / protegido
    if ch.category <> invalid and (ch.category = "Adultos" or ch.category = "Adulto") then
        if not m.isParentalUnlocked then
            m.pinModal.isOpen = true
            m.liveVideo.control = "stop"
            return
        end if
    end if

    if ch.variants <> invalid and ch.variants.Count() > 0 then
        variantUrl = ch.variants[0].url

        content = CreateObject("roSGNode", "ContentNode")
        content.url = variantUrl
        content.title = ch.name
        content.streamFormat = "hls"
        content.live = true

        m.bufferingGroup.visible = true
        m.liveVideo.content = content
        m.liveVideo.control = "play"

        updateHUDInfo()
    end if
end sub

sub onPinUnlocked()
    if m.pinModal.isUnlocked then
        m.isParentalUnlocked = true
        playChannel(m.top.currentChannelIndex)
    end if
end sub

sub updateHUDInfo()
    channels = m.top.channels
    if channels = invalid or m.top.currentChannelIndex >= channels.Count() then return
    ch = channels[m.top.currentChannelIndex]

    m.zapHud.channelNumber = ch.number.ToStr()
    m.zapHud.channelName = ch.name
    m.zapHud.channelLogo = ch.logo

    epgMap = m.top.epgMap
    if epgMap <> invalid and epgMap[ch.name] <> invalid then
        programs = epgMap[ch.name]
        for each p in programs
            if p.isCurrent then
                m.zapHud.programTitle = p.title
                dur = p.durationMin
                remMin = p.remainingMin
                pct = 0.5
                if dur > 0 then pct = (dur - remMin) / dur
                m.zapHud.programProgress = pct
                exit for
            end if
        end for
    else
        m.zapHud.programTitle = "Ao Vivo"
        m.zapHud.programProgress = 0.5
    end if
end sub

sub onVideoState()
    state = m.liveVideo.state
    if state = "playing" then
        m.bufferingGroup.visible = false
    else if state = "buffering" then
        m.bufferingGroup.visible = true
    else if state = "error" then
        m.bufferingGroup.visible = false
        tryNextVariant()
    end if
end sub

sub tryNextVariant()
    channels = m.top.channels
    if channels = invalid then return
    ch = channels[m.top.currentChannelIndex]
    if ch <> invalid and ch.variants <> invalid and ch.variants.Count() > 1 then
        content = CreateObject("roSGNode", "ContentNode")
        content.url = ch.variants[1].url
        content.streamFormat = "hls"
        content.live = true
        m.liveVideo.content = content
        m.liveVideo.control = "play"
    end if
end sub

sub onDrawerSelect()
    sel = m.channelDrawer.channelSelected
    if sel <> invalid then
        channels = m.top.channels
        for i = 0 to channels.Count() - 1
            if channels[i].id = sel.id then
                m.top.currentChannelIndex = i
                playChannel(i)
                exit for
            end if
        end for
    end if
end sub

sub onNumberTimerFired()
    if m.numberBuffer <> "" then
        targetNum = Val(m.numberBuffer)
        m.numberBuffer = ""
        channels = m.top.channels
        if channels <> invalid then
            for i = 0 to channels.Count() - 1
                if channels[i].number = targetNum then
                    m.top.currentChannelIndex = i
                    playChannel(i)
                    exit for
                end if
            end for
        end if
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.pinModal.isOpen then return false
    if m.channelDrawer.isOpen then return false

    ' Zapping de canais (Cima/Baixo)
    if key = "up" then
        playChannel(m.top.currentChannelIndex - 1)
        return true
    else if key = "down" then
        playChannel(m.top.currentChannelIndex + 1)
        return true
    else if key = "OK" or key = "left" then
        ' Abre o ChannelDrawer
        m.channelDrawer.selectedIndex = m.top.currentChannelIndex
        m.channelDrawer.isOpen = true
        m.channelDrawer.setFocus(true)
        return true
    end if

    ' Botão * (Options) para favoritar / desfavoritar canal
    if key = "options" then
        channels = m.top.channels
        if channels <> invalid and m.top.currentChannelIndex < channels.Count() then
            ch = channels[m.top.currentChannelIndex]
            ToggleFavoriteChannel(ch.name)
            isFav = IsChannelFavorite(ch.name)
            showFavoriteToast(ch.name, isFav)
            return true
        end if
    end if

    ' Dígitos 0-9
    validDigits = "0123456789"
    if Instr(1, validDigits, key) > 0 then
        m.numberBuffer = m.numberBuffer + key
        m.zapHud.channelNumber = m.numberBuffer
        m.zapHud.channelName = "Sintonizando..."
        m.numberTimer.control = "stop"
        m.numberTimer.control = "start"
        return true
    end if

    return false
end function

sub cleanUp()
    if m.liveVideo <> invalid then
        m.liveVideo.control = "stop"
        m.liveVideo.content = invalid
    end if
    if m.zapHud <> invalid then m.zapHud.visible = false
    if m.channelDrawer <> invalid then m.channelDrawer.isOpen = false
end sub
