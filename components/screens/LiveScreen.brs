' ====================================================================
' Saimo TV - LiveScreen (BrightScript)
' Zapping instantâneo, decodificação por hardware e bloqueio parental
' ====================================================================

sub init()
    m.liveVideo = m.top.findNode("liveVideo")
    m.bufferingGroup = m.top.findNode("bufferingGroup")
    m.zapHud = m.top.findNode("zapHud")
    m.channelDrawer = m.top.findNode("channelDrawer")
    m.pinModal = m.top.findNode("pinModal")

    m.liveVideo.observeField("state", "onVideoState")
    m.channelDrawer.observeField("channelSelected", "onDrawerSelect")
    m.channelDrawer.observeField("isOpen", "onDrawerOpenChange")
    m.channelDrawer.observeField("focusUpRequested", "onDrawerUp")
    m.channelDrawer.observeField("fontesRequested", "onDrawerFontes")
    m.painelFontes = m.top.findNode("painelFontes")
    m.painelFontes.observeField("escolhido", "onFonteEscolhida")
    m.painelFontes.observeField("aberto", "onFontesAberto")
    m.pinModal.observeField("isUnlocked", "onPinUnlocked")
    m.top.observeField("focusedChild", "onFocusedChildChange")

    m.favoriteToast = m.top.findNode("favoriteToast")
    m.favoriteToastText = m.top.findNode("favoriteToastText")
    m.favoriteToastTimer = m.top.findNode("favoriteToastTimer")
    m.favoriteToastTimer.observeField("fire", "onFavoriteToastTimer")

    m.currentVariantIndex = 0
    m.tryingProxy = false

    m.numberBuffer = ""
    m.numberTimer = CreateObject("roSGNode", "Timer")
    m.numberTimer.duration = 1.2
    m.numberTimer.repeat = false
    m.numberTimer.observeField("fire", "onNumberTimerFired")
    m.top.appendChild(m.numberTimer)
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() and not m.painelFontes.aberto then
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
        m.favoriteToastText.text = "[-] " + channelName + " removido dos Favoritos"
    end if
    m.favoriteToast.visible = true
    m.favoriteToastTimer.control = "stop"
    m.favoriteToastTimer.control = "start"
end sub

sub onDrawerFontes()
    abrirFontes(m.channelDrawer.fontesRequested)
end sub

' Painel com as fontes do canal: "Fonte N · qualidade", nunca o endereço.
sub abrirFontes(ch as Object)
    m.canalFontes = ch
    opcoes = []
    for i = 0 to ch.variants.Count() - 1
        o = { titulo: "Fonte " + (i + 1).ToStr() }
        q = ch.variants[i].quality
        if q <> invalid and q <> "Auto" then o.detalhe = q
        opcoes.Push(o)
    end for
    opcoes.Push({ titulo: "Guia de programação", detalhe: "Ver a grade dos canais" })
    m.painelFontes.titulo = "Fontes  ·  " + ch.name
    m.painelFontes.ajuda = "Se a imagem travar, tente outra fonte. Se ela também cair, o app troca sozinho."
    m.liveVideo.translation = [32, 262]
    m.liveVideo.width = 988
    m.liveVideo.height = 556
    m.painelFontes.opcoes = opcoes
    m.painelFontes.aberto = true
    m.top.telaCheia = true
end sub

sub onFontesAberto()
    if m.painelFontes.aberto then return
    m.top.telaCheia = not m.channelDrawer.isOpen
    if m.channelDrawer.isOpen then
        m.liveVideo.translation = [896, 130]
    else
        m.liveVideo.translation = [0, 0]
        m.liveVideo.width = 1920
        m.liveVideo.height = 1080
    end if
    if m.channelDrawer.isOpen then m.channelDrawer.setFocus(true) else m.top.setFocus(true)
end sub

sub onFonteEscolhida()
    i = m.painelFontes.escolhido
    ch = m.canalFontes
    m.painelFontes.aberto = false
    if i >= ch.variants.Count() then
        m.top.guiaRequested = true
        return
    end if
    channels = m.top.channels
    for c = 0 to channels.Count() - 1
        if channels[c].name = ch.name then
            m.top.currentChannelIndex = c
            exit for
        end if
    end for
    m.currentVariantIndex = i
    m.tryingProxy = false
    playCurrentVariant()
    if m.channelDrawer.isOpen then m.channelDrawer.isOpen = false
end sub

sub onDrawerUp()
    m.top.focusUpRequested = true
end sub

sub onDrawerOpenChange()
    if m.channelDrawer.isOpen then
        m.top.telaCheia = false
        m.liveVideo.translation = [896, 130]
        m.liveVideo.width = 988
        m.liveVideo.height = 556
        m.bufferingGroup.translation = [1240, 400]
    else
        m.top.telaCheia = true
        m.liveVideo.translation = [0, 0]
        m.liveVideo.width = 1920
        m.liveVideo.height = 1080
        m.bufferingGroup.translation = [840, 500]
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
    m.channelDrawer.epgMap = m.top.epgMap
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

    m.currentVariantIndex = 0
    m.tryingProxy = false
    playCurrentVariant()
    updateHUDInfo()
end sub

sub playCurrentVariant()
    channels = m.top.channels
    if channels = invalid or m.top.currentChannelIndex >= channels.Count() then return
    ch = channels[m.top.currentChannelIndex]
    if ch.variants = invalid or ch.variants.Count() = 0 then return

    if m.currentVariantIndex >= ch.variants.Count() then
        ' Todas as fontes foram esgotadas
        m.bufferingGroup.visible = false
        m.zapHud.channelName = ch.name + " (Sem sinal)"
        return
    end if

    v = ch.variants[m.currentVariantIndex]
    rawUrl = v.url
    if rawUrl = invalid or rawUrl = "" then
        tryNextVariant()
        return
    end if

    playUrl = rawUrl
    hasReferer = (v.referer <> invalid and v.referer <> "")
    isTxt = (Instr(1, LCase(rawUrl), ".txt") > 0)

    ' Se está no modo proxy, ou se a fonte obrigatoriamente precisa de proxy
    if m.tryingProxy or hasReferer or isTxt then
        ut = CreateObject("roUrlTransfer")
        playUrl = "https://saimo-tv.pages.dev/api/proxy?url=" + ut.Escape(rawUrl)
        if hasReferer then playUrl = playUrl + "&referer=" + ut.Escape(v.referer)
        if v.userAgent <> invalid and v.userAgent <> "" then playUrl = playUrl + "&ua=" + ut.Escape(v.userAgent)
    end if

    content = CreateObject("roSGNode", "ContentNode")
    content.url = playUrl
    content.title = ch.name
    content.streamFormat = "hls"
    content.live = true
    content.HttpSendClientHeaders = true

    headers = []
    if hasReferer then headers.Push("Referer: " + v.referer)
    if v.userAgent <> invalid and v.userAgent <> "" then headers.Push("User-Agent: " + v.userAgent)
    if headers.Count() > 0 then content.HttpHeaders = headers

    m.bufferingGroup.visible = true
    m.liveVideo.content = content
    m.liveVideo.control = "play"
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
                m.zapHud.linhaHora = "faltam " + remMin.ToStr() + " min"
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
    if channels = invalid or m.top.currentChannelIndex >= channels.Count() then return
    ch = channels[m.top.currentChannelIndex]
    if ch.variants = invalid then return

    ' Se ainda não tentou a fonte atual via proxy, tenta via proxy antes de avançar para a próxima fonte
    if not m.tryingProxy then
        m.tryingProxy = true
        playCurrentVariant()
        return
    end if

    ' Avança para a próxima fonte da lista
    m.currentVariantIndex = m.currentVariantIndex + 1
    m.tryingProxy = false
    playCurrentVariant()
end sub

sub onDrawerSelect()
    sel = m.channelDrawer.channelSelected
    if sel <> invalid then
        channels = m.top.channels
        for i = 0 to channels.Count() - 1
            if channels[i].id = sel.id then
                if i <> m.top.currentChannelIndex then
                    m.top.currentChannelIndex = i
                    playChannel(i)
                end if
                m.channelDrawer.isOpen = false
                exit for
            end if
        end for
    end if
end sub

sub onNumberTimerFired()
    if m.numberBuffer <> "" then
        targetNum = Val(m.numberBuffer)
        m.currentVariantIndex = 0
    m.tryingProxy = false

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
    if m.painelFontes.aberto then return false

    if key = "right" then
        channels = m.top.channels
        if channels <> invalid and m.top.currentChannelIndex < channels.Count() then abrirFontes(channels[m.top.currentChannelIndex])
        return true
    end if

    ' Zapping de canais (Cima/Baixo)
    if key = "up" then
        playChannel(m.top.currentChannelIndex - 1)
        return true
    else if key = "down" then
        playChannel(m.top.currentChannelIndex + 1)
        return true
    else if key = "OK" then
        m.zapHud.callFunc("alternar")
        return true
    else if key = "left" or key = "back" then
        ' Abre o painel de canais
        m.channelDrawer.selectedIndex = m.top.currentChannelIndex
        m.channelDrawer.isOpen = true
        m.channelDrawer.setFocus(true)
        return true
    end if

    ' Botão Replay, Play ou * para favoritar / desfavoritar canal
    if key = "replay" or key = "play" or key = "options" then
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
