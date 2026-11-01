' ====================================================================
' Saimo TV para Roku - MainScene (BrightScript)
' Roteador principal de navegação, gerenciador de telas e Saimo Connect
' ====================================================================

sub init()
    m.sceneBg = m.top.findNode("sceneBg")
    m.screensContainer = m.top.findNode("screensContainer")
    m.topNavBar = m.top.findNode("topNavBar")
    m.dataLoader = m.top.findNode("dataLoader")
    m.connectServer = m.top.findNode("connectServer")

    m.topNavBar.observeField("itemSelected", "onTopNavSelected")
    m.topNavBar.observeField("focusDownRequested", "onFocusDownFromNav")
    m.connectServer.observeField("receivedCommand", "onConnectCommand")

    ' Observers do DataLoader
    m.dataLoader.observeField("responseChannels", "onChannelsLoaded")
    m.dataLoader.observeField("responseEpg", "onEpgLoaded")
    m.dataLoader.observeField("responseDestaques", "onDestaquesLoaded")
    m.dataLoader.observeField("responseVodItems", "onVodLoaded")
    m.dataLoader.observeField("responseEvents", "onEventsLoaded")
    m.dataLoader.observeField("responseRadios", "onRadiosLoaded")

    ' Inicia o carregamento de dados em background
    loadAllData()

    ' Inicia o servidor Saimo Connect na porta 8999
    m.connectServer.control = "run"

    ' Pilha de navegação de telas
    m.screenStack = []
    m.currentScreenNode = invalid
    m.currentScreenName = ""

    ' Abre na tela configurada (padrão: "home")
    prefs = LoadPreferences()
    if prefs.abrirEm = "canal" then
        switchScreen("live")
    else
        switchScreen("home")
    end if
end sub

sub loadAllData()
    ' Dispara tarefas assíncronas e armazena referências para evitar garbage collection prematuro
    m.loaders = []

    loader1 = CreateObject("roSGNode", "DataLoaderTask")
    loader1.requestType = "channels"
    loader1.observeField("responseChannels", "onChannelsLoaded")
    loader1.control = "run"
    m.loaders.Push(loader1)

    loader2 = CreateObject("roSGNode", "DataLoaderTask")
    loader2.requestType = "epg"
    loader2.observeField("responseEpg", "onEpgLoaded")
    loader2.control = "run"
    m.loaders.Push(loader2)

    loader3 = CreateObject("roSGNode", "DataLoaderTask")
    loader3.requestType = "destaques"
    loader3.observeField("responseDestaques", "onDestaquesLoaded")
    loader3.observeField("responseVodItems", "onVodLoaded")
    loader3.control = "run"
    m.loaders.Push(loader3)

    loader5 = CreateObject("roSGNode", "DataLoaderTask")
    loader5.requestType = "events"
    loader5.observeField("responseEvents", "onEventsLoaded")
    loader5.control = "run"
    m.loaders.Push(loader5)

    loader6 = CreateObject("roSGNode", "DataLoaderTask")
    loader6.requestType = "radios"
    loader6.observeField("responseRadios", "onRadiosLoaded")
    loader6.control = "run"
    m.loaders.Push(loader6)

    loader7 = CreateObject("roSGNode", "MinhasListasTask")
    loader7.acao = "carregar"
    loader7.observeField("canais", "onMinhasCarregadas")
    loader7.control = "run"
    m.loaders.Push(loader7)
end sub

sub onChannelsLoaded(evt as Object)
    m.canaisCatalogo = evt.getData()
    juntarCanais()
end sub

sub onMinhasCarregadas(evt as Object)
    m.canaisMinhas = evt.getData()
    if m.canaisMinhas <> invalid and m.canaisMinhas.Count() > 0 then juntarCanais()
end sub

sub onListasMudaram(evt as Object)
    dados = evt.getData()
    m.canaisMinhas = dados.canais
    juntarCanais()
end sub

' Os canais das listas do usuário vêm depois do catálogo, em ordem de nome.
sub juntarCanais()
    if m.canaisCatalogo = invalid then return
    ' Mesma ordem de seções da TV Box; o número segue essa ordem.
    todos = []
    secoes = ["TV Aberta", "Filmes e Séries", "Esportes", "Notícias", "Infantil", "Documentários", "Pluto TV", "24 Horas", "Variedades", "Adulto"]
    conhecidas = {}
    for each s in secoes
        conhecidas[s] = true
        for each c in m.canaisCatalogo
            if c.category = s then todos.Push(c)
        end for
    end for
    for each c in m.canaisCatalogo
        if not conhecidas.DoesExist(c.category) then todos.Push(c)
    end for
    for i = 0 to todos.Count() - 1
        todos[i].number = i + 1
    end for
    if m.canaisMinhas <> invalid and m.canaisMinhas.Count() > 0 then
        minhas = []
        minhas.Append(m.canaisMinhas)
        minhas.SortBy("name", "i")
        n = todos.Count()
        for each c in minhas
            n = n + 1
            c.number = n
            c.id = "minha_" + n.ToStr()
            todos.Push(c)
        end for
    end if
    m.cachedChannels = todos
    if m.currentScreenName = "live" and m.currentScreenNode <> invalid then
        m.currentScreenNode.channels = m.cachedChannels
    else if m.currentScreenName = "home" and m.currentScreenNode <> invalid then
        m.currentScreenNode.channels = m.cachedChannels
    else if m.currentScreenName = "favorites" and m.currentScreenNode <> invalid then
        m.currentScreenNode.channels = m.cachedChannels
    else if m.currentScreenName = "search" and m.currentScreenNode <> invalid then
        m.currentScreenNode.channels = m.cachedChannels
    end if
end sub

sub onEpgLoaded(evt as Object)
    m.cachedEpg = evt.getData()
    if m.currentScreenName = "live" and m.currentScreenNode <> invalid then
        m.currentScreenNode.epgMap = m.cachedEpg
    else if m.currentScreenName = "home" and m.currentScreenNode <> invalid then
        m.currentScreenNode.epgMap = m.cachedEpg
    end if
end sub

sub onDestaquesLoaded(evt as Object)
    m.cachedDestaques = evt.getData()
    if m.currentScreenName = "home" and m.currentScreenNode <> invalid then
        m.currentScreenNode.railsData = m.cachedDestaques
        if m.cachedDestaques.Count() > 0 and m.cachedDestaques[0].items.Count() > 0 then
            m.currentScreenNode.featuredItem = m.cachedDestaques[0].items[0]
        end if
    end if
end sub

sub onVodLoaded(evt as Object)
    m.cachedVod = evt.getData()
    if m.currentScreenName = "vod" and m.currentScreenNode <> invalid then
        m.currentScreenNode.vodItems = m.cachedVod
    else if m.currentScreenName = "home" and m.currentScreenNode <> invalid then
        m.currentScreenNode.vodItems = m.cachedVod
    else if m.currentScreenName = "favorites" and m.currentScreenNode <> invalid then
        m.currentScreenNode.vodItems = m.cachedVod
    else if m.currentScreenName = "search" and m.currentScreenNode <> invalid then
        m.currentScreenNode.vodItems = m.cachedVod
    end if
end sub

sub onEventsLoaded(evt as Object)
    m.cachedEvents = evt.getData()
    if m.currentScreenName = "events" and m.currentScreenNode <> invalid then
        m.currentScreenNode.events = m.cachedEvents
    end if
end sub

sub onRadiosLoaded(evt as Object)
    m.cachedRadios = evt.getData()
    if m.currentScreenName = "radios" and m.currentScreenNode <> invalid then
        m.currentScreenNode.radios = m.cachedRadios
    end if
end sub

' ====================================================================
' Gerenciamento e Transição de Telas
' ====================================================================

function screenToNavIndex(name as String) as Integer
    if name = "search" then return 0
    if name = "home" then return 1
    if name = "live" then return 2
    if name = "events" then return 3
    if name = "vod" then return 4
    if name = "favorites" then return 5
    if name = "guide" then return 2
    if name = "radios" then return 6
    if name = "settings" or name = "minhas" then return 7
    return 1
end function

sub switchScreen(screenName as String, params = invalid as Dynamic)
    ' Guarda tela anterior para retorno ao sair do player
    if m.currentScreenName <> "" and m.currentScreenName <> "player" then
        m.previousScreenName = m.currentScreenName
        m.previousScreenParams = m.currentScreenParams
    end if
    m.currentScreenParams = params

    ' Remove tela atual do container se houver e encerra tarefas de vídeo pendentes
    if m.currentScreenNode <> invalid then
        m.currentScreenNode.callFunc("cleanUp")
        m.screensContainer.removeChild(m.currentScreenNode)
        m.currentScreenNode = invalid
    end if

    m.currentScreenName = screenName

    if screenName = "home" then
        node = CreateObject("roSGNode", "HomeScreen")
        if m.cachedChannels <> invalid then node.channels = m.cachedChannels
        if m.cachedEpg <> invalid then node.epgMap = m.cachedEpg
        if m.cachedVod <> invalid then node.vodItems = m.cachedVod
        if m.cachedDestaques <> invalid then
            node.railsData = m.cachedDestaques
            if m.cachedDestaques.Count() > 0 and m.cachedDestaques[0].items.Count() > 0 then
                node.featuredItem = m.cachedDestaques[0].items[0]
            end if
        end if
        node.observeField("itemSelected", "onHomeItemSelected")
        node.observeField("playRequested", "onHomePlayRequested")
        node.observeField("tuneRequested", "onSearchTune")
        node.observeField("focusUpRequested", "onScreenFocusUp")
        m.currentScreenNode = node

    else if screenName = "live" then
        node = CreateObject("roSGNode", "LiveScreen")
        if params <> invalid and params.channelIndex <> invalid then
            node.currentChannelIndex = params.channelIndex
            node.openDrawerOnLoad = false
            node.telaCheia = true
        else
            ' Ao abrir a aba Ao Vivo pelo menu, abre primeiro a lista de canais (drawer)
            node.openDrawerOnLoad = true
        end if
        if m.cachedEpg <> invalid then node.epgMap = m.cachedEpg
        if m.cachedChannels <> invalid then node.channels = m.cachedChannels
        node.observeField("telaCheia", "onRadioTelaCheia")
        node.observeField("guiaRequested", "onAbrirGuia")
        node.observeField("focusUpRequested", "onScreenFocusUp")
        m.currentScreenNode = node

    else if screenName = "vod" then
        node = CreateObject("roSGNode", "VodScreen")
        if m.cachedVod <> invalid then node.vodItems = m.cachedVod
        node.observeField("itemSelected", "onVodItemSelected")
        node.observeField("playRequested", "onHomePlayRequested")
        node.observeField("focusUpRequested", "onScreenFocusUp")
        m.currentScreenNode = node

    else if screenName = "favorites" then
        node = CreateObject("roSGNode", "FavoritesScreen")
        if m.cachedChannels <> invalid then node.channels = m.cachedChannels
        if m.cachedVod <> invalid then node.vodItems = m.cachedVod
        node.observeField("tuneRequested", "onSearchTune")
        node.observeField("itemSelected", "onVodItemSelected")
        node.observeField("focusUpRequested", "onScreenFocusUp")
        m.currentScreenNode = node

    else if screenName = "ficha" then
        node = CreateObject("roSGNode", "FichaScreen")
        if params <> invalid then node.item = params
        node.observeField("playRequested", "onFichaPlayRequested")
        node.observeField("focusUpRequested", "onScreenFocusUp")
        m.currentScreenNode = node

    else if screenName = "player" then
        node = CreateObject("roSGNode", "PlayerScreen")
        if params <> invalid then node.playItem = params
        node.observeField("exitRequested", "onPlayerExit")
        m.currentScreenNode = node

    else if screenName = "guide" then
        node = CreateObject("roSGNode", "GuideScreen")
        if m.cachedChannels <> invalid then node.channels = m.cachedChannels
        if m.cachedEpg <> invalid then node.epgMap = m.cachedEpg
        node.observeField("tuneRequested", "onGuideTune")
        node.observeField("focusUpRequested", "onScreenFocusUp")
        m.currentScreenNode = node

    else if screenName = "events" then
        node = CreateObject("roSGNode", "EventsScreen")
        if m.cachedEvents <> invalid then node.events = m.cachedEvents
        node.observeField("tuneRequested", "onEventTune")
        node.observeField("focusUpRequested", "onScreenFocusUp")
        m.currentScreenNode = node

    else if screenName = "radios" then
        node = CreateObject("roSGNode", "RadiosScreen")
        node.observeField("telaCheia", "onRadioTelaCheia")
        if m.cachedRadios <> invalid then node.radios = m.cachedRadios
        node.observeField("focusUpRequested", "onScreenFocusUp")
        m.currentScreenNode = node

    else if screenName = "search" then
        node = CreateObject("roSGNode", "SearchScreen")
        if m.cachedChannels <> invalid then node.channels = m.cachedChannels
        if m.cachedVod <> invalid then node.vodItems = m.cachedVod
        node.observeField("tuneRequested", "onSearchTune")
        node.observeField("itemSelected", "onSearchVodSelected")
        node.observeField("focusUpRequested", "onScreenFocusUp")
        m.currentScreenNode = node

    else if screenName = "settings" then
        node = CreateObject("roSGNode", "SettingsScreen")
        node.observeField("reloadRequested", "onSettingsReload")
        node.observeField("minhasListasRequested", "onAbrirMinhasListas")
        node.observeField("focusUpRequested", "onScreenFocusUp")
        m.currentScreenNode = node

    else if screenName = "minhas" then
        node = CreateObject("roSGNode", "MinhasListasScreen")
        node.observeField("listasMudaram", "onListasMudaram")
        node.observeField("focusUpRequested", "onScreenFocusUp")
        m.currentScreenNode = node
    end if

    if m.currentScreenNode <> invalid then
        m.screensContainer.appendChild(m.currentScreenNode)
        m.currentScreenNode.setFocus(true)
        if screenName = "minhas" then m.currentScreenNode.callFunc("focar")
    end if

    ' Atualiza visibilidade da barra de navegação (oculta no player de VOD e Live em tela cheia)
    if screenName = "player" then
        m.topNavBar.visible = false
    else if screenName = "live" and m.currentScreenNode.telaCheia then
        m.topNavBar.visible = false
        m.topNavBar.selectedIndex = 2
    else
        m.topNavBar.visible = true
        m.topNavBar.selectedIndex = screenToNavIndex(screenName)
    end if
end sub

' ----- Interações de Telas -----

sub onHomeItemSelected(evt as Object)
    item = evt.getData()
    switchScreen("ficha", item)
end sub

sub onHomePlayRequested(evt as Object)
    item = evt.getData()
    switchScreen("player", item)
end sub

sub onVodItemSelected(evt as Object)
    item = evt.getData()
    switchScreen("ficha", item)
end sub

sub onFichaPlayRequested(evt as Object)
    item = evt.getData()
    switchScreen("player", item)
end sub

sub onPlayerExit()
    if m.previousScreenName <> invalid and m.previousScreenName <> "" and m.previousScreenName <> "player" then
        switchScreen(m.previousScreenName, m.previousScreenParams)
    else
        switchScreen("home")
    end if
end sub

sub onGuideTune(evt as Object)
    ch = evt.getData()
    tuneChannelByName(ch.name)
end sub

sub onEventTune(evt as Object)
    channelName = evt.getData()
    tuneChannelByName(channelName)
end sub

sub onSearchTune(evt as Object)
    ch = evt.getData()
    tuneChannelByName(ch.name)
end sub

sub onSearchVodSelected(evt as Object)
    item = evt.getData()
    switchScreen("ficha", item)
end sub

sub onSettingsReload()
    loadAllData()
end sub

sub tuneChannelByName(channelName as String)
    if m.cachedChannels = invalid then return
    for i = 0 to m.cachedChannels.Count() - 1
        if m.cachedChannels[i].name = channelName then
            switchScreen("live", { channelIndex: i })
            return
        end if
    end for
    ' Se não achou exato, abre no canal 0
    switchScreen("live", { channelIndex: 0 })
end sub

' ----- Top Navigation Bar (TV Box style) -----

sub onTopNavSelected(evt as Object)
    itemKey = evt.getData()
    if m.currentScreenName <> itemKey then
        switchScreen(itemKey)
    end if
    if m.topNavBar <> invalid then m.topNavBar.setFocus(false)
    if m.currentScreenNode <> invalid then
        m.currentScreenNode.setFocus(true)
    end if
end sub

sub onFocusDownFromNav()
    if m.topNavBar <> invalid then m.topNavBar.setFocus(false)
    if m.currentScreenNode <> invalid then
        m.currentScreenNode.setFocus(true)
    end if
end sub

sub onScreenFocusUp()
    if m.topNavBar <> invalid and m.topNavBar.visible then
        m.topNavBar.setFocus(true)
    end if
end sub

' ====================================================================
' Saimo Connect (Controle Remoto via Celular na Porta 8999)
' ====================================================================

sub onRadioTelaCheia(evt as Object)
    m.topNavBar.visible = not evt.getData()
end sub

sub onAbrirGuia()
    switchScreen("guide")
end sub

sub onAbrirMinhasListas()
    switchScreen("minhas")
end sub

sub onConnectCommand(evt as Object)
    cmd = evt.getData()
    if cmd = invalid or cmd.t = invalid then return
    tipo = cmd.t

    if tipo = "tune" and cmd.channel <> invalid then
        tuneChannelByName(cmd.channel)
    else if tipo = "playVod" then
        switchScreen("player", { title: cmd.title, url: cmd.url, isSeries: false })
    else if tipo = "playPause" then
        if m.currentScreenName = "player" and m.currentScreenNode <> invalid then
            ' Dispara toggle play/pause no player
        end if
    else if tipo = "seek" then
        if m.currentScreenName = "player" and m.currentScreenNode <> invalid and cmd.delta <> invalid then
            ' Dispara seek
        end if
    else if tipo = "key" and cmd.code <> invalid then
        handleVirtualKey(cmd.code)
    else if tipo = "text" and cmd.value <> invalid then
        if m.currentScreenName = "minhas" then m.currentScreenNode.textoRecebido = cmd.value
    end if
end sub

sub handleVirtualKey(code as String)
    if code = "up" then
        onKeyEvent("up", true)
    else if code = "down" then
        onKeyEvent("down", true)
    else if code = "left" then
        onKeyEvent("left", true)
    else if code = "right" then
        onKeyEvent("right", true)
    else if code = "ok" then
        onKeyEvent("OK", true)
    else if code = "back" then
        onKeyEvent("back", true)
    end if
end sub

sub onDeepLinkChange()
    ' Trata link externo recebido pelo Roku
    link = m.top.deepLink
    if link <> invalid and link.contentId <> invalid then
        tuneChannelByName(link.contentId)
    end if
end sub

' ====================================================================
' Tratamento de Teclas Globais do Controle Remoto
' ====================================================================

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    ' Se o foco está na barra superior
    if m.topNavBar <> invalid and m.topNavBar.hasFocus() then
        if key = "down" then
            if m.currentScreenNode <> invalid then
                m.currentScreenNode.setFocus(true)
                return true
            end if
        else if key = "back" then
            if m.currentScreenName <> "home" then
                switchScreen("home")
                return true
            end if
        end if
        return false
    end if

    ' Botão Voltar (Back) retorna para Início (como no TV Box)
    if key = "back" then
        if m.currentScreenName = "ficha" then
            if m.previousScreenName <> invalid and m.previousScreenName <> "" and m.previousScreenName <> "ficha" and m.previousScreenName <> "player" then
                switchScreen(m.previousScreenName, m.previousScreenParams)
            else
                switchScreen("home")
            end if
            return true
        else if m.currentScreenName <> "home" and m.currentScreenName <> "player" then
            switchScreen("home")
            return true
        else if m.currentScreenName = "home" and m.topNavBar <> invalid and m.topNavBar.visible then
            m.topNavBar.setFocus(true)
            return true
        end if
    end if

    return false
end function
