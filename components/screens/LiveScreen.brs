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
    m.canais = []
    m.inicioTimer = m.top.findNode("inicioTimer")
    m.inicioTimer.observeField("fire", "onInicio")
    m.indiceAtual = -1
    m.pedemProxy = {
        "proxy-embedtv.embedtvproxy.workers.dev": true,
        "embedtvproxy.workers.dev": true
    }
    m.ancora = m.top.findNode("ancora")
    m.vigiaTimer = m.top.findNode("vigiaTimer")
    m.vigiaTimer.observeField("fire", "onVigia")
    m.zapTimer = m.top.findNode("zapTimer")
    m.zapTimer.observeField("fire", "onZap")
    m.holdTimer = m.top.findNode("holdTimer")
    m.holdTimer.observeField("fire", "onHold")
    m.sonoTimer = m.top.findNode("sonoTimer")
    m.sonoTimer.observeField("fire", "onSono")
    m.channelDrawer.observeField("menuRequested", "onDrawerMenu")
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

' Cada canal aberto custa rede e decodificador: passando vários seguidos, só o
' último abre de fato. A barra mostra o canal na hora.
sub zapear(passo as Integer)
    total = m.canais.Count()
    if total = 0 then return
    if m.alvoZap = invalid then m.alvoZap = m.top.currentChannelIndex
    m.alvoZap = (m.alvoZap + passo + total) mod total
    ch = m.canais[m.alvoZap]
    m.zapHud.channelNumber = ch.number.ToStr()
    m.zapHud.channelName = ch.name
    m.zapHud.channelLogo = ch.logo
    m.zapTimer.control = "stop"
    m.zapTimer.control = "start"
end sub

sub onZap()
    alvo = m.alvoZap
    m.alvoZap = invalid
    if alvo <> invalid then playChannel(alvo)
end sub

sub onDrawerMenu()
    abrirMenu(m.channelDrawer.menuRequested)
end sub

sub onDrawerFontes()
    abrirFontes(m.channelDrawer.fontesRequested)
end sub

' Painel com as fontes do canal: "Fonte N · qualidade", nunca o endereço.
sub abrirFontes(ch as Object)
    m.modoPainel = "fontes"
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
    if m.channelDrawer.isOpen then m.channelDrawer.setFocus(true) else m.ancora.setFocus(true)
end sub

' Segurar OK (ou *): tudo o que se pode fazer com o canal, como na TV Box.
sub abrirMenu(ch as Object)
    m.modoPainel = "menu"
    m.canalFontes = ch
    fav = "Favoritar"
    if IsChannelFavorite(ch.name) then fav = "Tirar dos favoritos"
    m.acoes = [
        { id: "canais", titulo: "Canais" },
        { id: "guia", titulo: "Guia de programação" }
    ]
    if m.canalAnterior <> invalid then m.acoes.Push({ id: "anterior", titulo: "Voltar para " + m.canalAnterior })
    m.acoes.Push({ id: "favorito", titulo: fav })
    m.acoes.Push({ id: "audio", titulo: "Áudio e legenda" })
    if ch.variants.Count() > 1 then m.acoes.Push({ id: "fontes", titulo: "Trocar fonte", detalhe: ch.variants.Count().ToStr() + " fontes" })
    m.acoes.Push({ id: "timer", titulo: "Timer de sono" })
    mostrarPainel(ch.name, "", m.acoes)
end sub

sub mostrarPainel(titulo as String, ajuda as String, opcoes as Object)
    m.painelFontes.titulo = titulo
    m.painelFontes.ajuda = ajuda
    m.painelFontes.opcoes = opcoes
    m.liveVideo.translation = [32, 262]
    m.liveVideo.width = 988
    m.liveVideo.height = 556
    m.painelFontes.aberto = true
    m.top.telaCheia = true
end sub

sub onHold()
    m.holdUsado = true
    channels = m.canais
    if channels <> invalid and m.top.currentChannelIndex < channels.Count() then abrirMenu(channels[m.top.currentChannelIndex])
end sub

sub onSono()
    m.liveVideo.control = "stop"
    m.top.sairRequested = true
end sub

sub executarMenu(i as Integer)
    a = m.acoes[i]
    ch = m.canalFontes
    if a.id = "canais" then
        m.painelFontes.aberto = false
        m.channelDrawer.selectedIndex = m.top.currentChannelIndex
        m.channelDrawer.isOpen = true
        m.channelDrawer.setFocus(true)
    else if a.id = "guia" then
        m.painelFontes.aberto = false
        m.top.guiaRequested = true
    else if a.id = "anterior" then
        m.painelFontes.aberto = false
        channels = m.canais
        for c = 0 to channels.Count() - 1
            if channels[c].name = m.canalAnterior then
                playChannel(c)
                exit for
            end if
        end for
    else if a.id = "favorito" then
        ToggleFavoriteChannel(ch.name)
        showFavoriteToast(ch.name, IsChannelFavorite(ch.name))
        m.painelFontes.aberto = false
    else if a.id = "fontes" then
        abrirFontes(ch)
    else if a.id = "audio" then
        m.modoPainel = "audio"
        m.faixas = []
        lista = []
        faixas = m.liveVideo.availableAudioTracks
        if faixas <> invalid then
            for f = 0 to faixas.Count() - 1
                t = faixas[f]
                nome = "Áudio " + (f + 1).ToStr()
                if t.Language <> invalid and t.Language <> "" then nome = "Áudio: " + t.Language
                lista.Push({ titulo: nome })
                m.faixas.Push({ tipo: "audio", valor: t.Track })
            end for
        end if
        legendas = m.liveVideo.availableSubtitleTracks
        if legendas <> invalid then
            for f = 0 to legendas.Count() - 1
                t = legendas[f]
                nome = "Legenda " + (f + 1).ToStr()
                if t.Language <> invalid and t.Language <> "" then nome = "Legenda: " + t.Language
                lista.Push({ titulo: nome })
                m.faixas.Push({ tipo: "legenda", valor: t.TrackName })
            end for
        end if
        lista.Push({ titulo: "Sem legenda" })
        m.faixas.Push({ tipo: "legenda", valor: "" })
        mostrarPainel("Áudio e legenda", "", lista)
    else if a.id = "timer" then
        m.modoPainel = "timer"
        m.minutos = [0, 30, 60, 90, 120]
        lista = [{ titulo: "Desligado" }]
        for each q in [30, 60, 90, 120]
            lista.Push({ titulo: q.ToStr() + " minutos" })
        end for
        mostrarPainel("Timer de sono", "", lista)
    end if
end sub

sub onFonteEscolhida()
    i = m.painelFontes.escolhido
    if m.modoPainel = "menu" then
        executarMenu(i)
        return
    else if m.modoPainel = "timer" then
        m.painelFontes.aberto = false
        m.sonoTimer.control = "stop"
        if m.minutos[i] > 0 then
            m.sonoTimer.duration = m.minutos[i] * 60
            m.sonoTimer.control = "start"
        end if
        return
    else if m.modoPainel = "audio" then
        f = m.faixas[i]
        m.painelFontes.aberto = false
        if f.tipo = "audio" then
            m.liveVideo.audioTrack = f.valor
        else if f.valor = "" then
            m.liveVideo.globalCaptionMode = "Off"
        else
            m.liveVideo.globalCaptionMode = "On"
            m.liveVideo.subtitleTrack = f.valor
        end if
        return
    end if
    ch = m.canalFontes
    m.painelFontes.aberto = false
    if i >= ch.variants.Count() then
        m.top.guiaRequested = true
        return
    end if
    channels = m.canais
    for c = 0 to channels.Count() - 1
        if channels[c].name = ch.name then
            m.indiceAtual = c
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
    ' A barra do canal não aparece por cima do painel.
    m.zapHud.visible = not m.channelDrawer.isOpen
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
        ' A lista escondida ficava com o foco: comia as setas e o OK trocava de canal.
        m.ancora.setFocus(true)
    end if
end sub

' A árvore vem pronta e por referência: aqui só se monta a lista de ponteiros
' para o zapping, na ordem dos números.
sub onArvore()
    arvore = m.top.arvore
    if arvore = invalid then return
    total = 0
    for i = 0 to arvore.getChildCount() - 1
        total = total + arvore.getChild(i).getChildCount()
    end for
    nos = CreateObject("roArray", total, true)
    for i = 0 to arvore.getChildCount() - 1
        secao = arvore.getChild(i)
        for j = 0 to secao.getChildCount() - 1
            c = secao.getChild(j)
            nos[c.number - 1] = c
        end for
    end for
    m.canais = nos
    m.channelDrawer.selectedIndex = m.top.currentChannelIndex
    m.channelDrawer.arvore = arvore
    if m.iniciado = true then
        updateHUDInfo()
        return
    end if
    if nos.Count() > 0 then
        m.iniciado = true
        if m.top.openDrawerOnLoad then
            m.channelDrawer.isOpen = true
            m.channelDrawer.setFocus(true)
            m.zapHud.visible = false
            m.top.openDrawerOnLoad = false
        end if
        ' O painel aparece antes: o vídeo entra no quadro seguinte.
        m.inicioTimer.control = "start"
    end if
end sub

sub onInicio()
    playChannel(m.top.currentChannelIndex)
end sub

sub onChannelIndexChange()
    ' Quem já está trocando de canal grava o índice antes: sem isto, o canal abria duas vezes.
    if m.top.currentChannelIndex <> m.indiceAtual then playChannel(m.top.currentChannelIndex)
end sub

sub playChannel(index as Integer)
    channels = m.canais
    if channels = invalid or channels.Count() = 0 then return
    if index < 0 then index = channels.Count() - 1
    if index >= channels.Count() then index = 0
    m.indiceAtual = index
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

    if m.ultimoCanal <> invalid and m.ultimoCanal <> ch.name then m.canalAnterior = m.ultimoCanal
    m.ultimoCanal = ch.name
    m.currentVariantIndex = 0
    m.tryingProxy = false
    playCurrentVariant()
    updateHUDInfo()
end sub

sub playCurrentVariant()
    channels = m.canais
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

    ' O Roku fala direto com a fonte: manda Referer e User-Agent, e o formato vai
    ' declarado abaixo, então .txt toca sem proxy. Cada segmento pelo proxy custa
    ' tempo e pedidos na Cloudflare: ele fica só como segunda tentativa.
    servidor = rawUrl.Split("/")[2]
    if m.pedemProxy.DoesExist(servidor) or InStr(1, rawUrl, "embedtvproxy.workers.dev") > 0 then m.tryingProxy = true
    if m.tryingProxy then
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
    m.servidorAtual = servidor
    ' Fonte que não abre nem dá erro não pode prender o canal.
    m.vigiaTimer.control = "stop"
    m.vigiaTimer.control = "start"
end sub

sub onVigia()
    if m.liveVideo.state <> "playing" then tryNextVariant()
end sub

sub onPinUnlocked()
    if m.pinModal.isUnlocked then
        m.isParentalUnlocked = true
        playChannel(m.top.currentChannelIndex)
    end if
end sub

sub updateHUDInfo()
    channels = m.canais
    if channels = invalid or m.top.currentChannelIndex >= channels.Count() then return
    ch = channels[m.top.currentChannelIndex]

    m.zapHud.channelNumber = ch.number.ToStr()
    m.zapHud.channelName = ch.name
    m.zapHud.channelLogo = ch.logo

    if ch.programa <> "" then
        m.zapHud.programTitle = ch.programa
        agora = CreateObject("roDateTime").AsSeconds()
        pct = 0.5
        if ch.fim > ch.ini then pct = (agora - ch.ini) / (ch.fim - ch.ini)
        m.zapHud.programProgress = pct
        m.zapHud.linhaHora = "faltam " + Int((ch.fim - agora) / 60).ToStr() + " min"
    else
        m.zapHud.programTitle = "Ao Vivo"
        m.zapHud.programProgress = 0.5
    end if
end sub

sub onVideoState()
    state = m.liveVideo.state
    if state = "playing" then
        m.bufferingGroup.visible = false
        m.vigiaTimer.control = "stop"
        ' Só pelo proxy abriu: os próximos canais deste servidor vão direto a ele.
        if m.tryingProxy and m.servidorAtual <> invalid then m.pedemProxy[m.servidorAtual] = true
    else if state = "buffering" then
        m.bufferingGroup.visible = true
    else if state = "error" then
        m.bufferingGroup.visible = false
        tryNextVariant()
    end if
end sub

sub tryNextVariant()
    channels = m.canais
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
        channels = m.canais
        for i = 0 to channels.Count() - 1
            if channels[i].name = sel.name then
                if i <> m.top.currentChannelIndex then playChannel(i)
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
        channels = m.canais
        if channels <> invalid then
            for i = 0 to channels.Count() - 1
                if channels[i].number = targetNum then
                    playChannel(i)
                    exit for
                end if
            end for
        end if
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    ' OK curto mostra a barra do canal; segurado, abre o menu.
    if key = "OK" and not press then
        if m.okSolto = true then
            m.okSolto = false
            m.holdTimer.control = "stop"
            if not m.holdUsado then m.zapHud.callFunc("alternar")
            return true
        end if
        return false
    end if
    if not press then return false

    if m.pinModal.isOpen then return false
    if m.channelDrawer.isOpen then return false
    if m.painelFontes.aberto then return false

    if key = "right" then
        channels = m.canais
        if channels <> invalid and m.top.currentChannelIndex < channels.Count() then abrirFontes(channels[m.top.currentChannelIndex])
        return true
    end if

    ' Zapping de canais (Cima/Baixo)
    if key = "up" then
        zapear(-1)
        return true
    else if key = "down" then
        zapear(1)
        return true
    else if key = "OK" then
        m.holdUsado = false
        m.okSolto = true
        m.holdTimer.control = "start"
        return true
    else if key = "left" or key = "back" then
        ' Abre o painel de canais
        m.channelDrawer.selectedIndex = m.top.currentChannelIndex
        m.channelDrawer.isOpen = true
        m.channelDrawer.setFocus(true)
        return true
    end if

    if key = "options" then
        onHold()
        return true
    end if

    ' Botão Replay ou Play para favoritar / desfavoritar canal
    if key = "replay" or key = "play" then
        channels = m.canais
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
        m.vigiaTimer.control = "stop"
        m.liveVideo.control = "stop"
        m.liveVideo.content = invalid
    end if
    if m.zapHud <> invalid then m.zapHud.visible = false
    if m.channelDrawer <> invalid then m.channelDrawer.isOpen = false
end sub
