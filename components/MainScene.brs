' ====================================================================
' Saimo TV para Roku - MainScene (BrightScript)
' Roteador principal de navegação, gerenciador de telas e Saimo Connect
' ====================================================================

sub init()
    m.sceneBg = m.top.findNode("sceneBg")
    m.screensContainer = m.top.findNode("screensContainer")
    m.sidebarMenu = m.top.findNode("sidebarMenu")
    m.dataLoader = m.top.findNode("dataLoader")
    m.connectServer = m.top.findNode("connectServer")

    m.sidebarMenu.observeField("itemSelected", "onSidebarSelected")
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

    ' Foco inicial no menu lateral para navegação instantânea e visível
    m.sidebarMenu.visible = true
    m.sidebarMenu.isExpanded = true
    m.sidebarMenu.setFocus(true)
end sub

sub loadAllData()
    ' Dispara tarefas assíncronas
    loader1 = CreateObject("roSGNode", "DataLoaderTask")
    loader1.requestType = "channels"
    loader1.observeField("responseChannels", "onChannelsLoaded")
    loader1.control = "run"

    loader2 = CreateObject("roSGNode", "DataLoaderTask")
    loader2.requestType = "epg"
    loader2.observeField("responseEpg", "onEpgLoaded")
    loader2.control = "run"

    loader3 = CreateObject("roSGNode", "DataLoaderTask")
    loader3.requestType = "destaques"
    loader3.observeField("responseDestaques", "onDestaquesLoaded")
    loader3.observeField("responseVodItems", "onVodLoaded")
    loader3.control = "run"

    loader5 = CreateObject("roSGNode", "DataLoaderTask")
    loader5.requestType = "events"
    loader5.observeField("responseEvents", "onEventsLoaded")
    loader5.control = "run"

    loader6 = CreateObject("roSGNode", "DataLoaderTask")
    loader6.requestType = "radios"
    loader6.observeField("responseRadios", "onRadiosLoaded")
    loader6.control = "run"
end sub

sub onChannelsLoaded(evt as Object)
    m.cachedChannels = evt.getData()
    if m.currentScreenName = "live" and m.currentScreenNode <> invalid then
        m.currentScreenNode.channels = m.cachedChannels
    else if m.currentScreenName = "guide" and m.currentScreenNode <> invalid then
        m.currentScreenNode.channels = m.cachedChannels
    else if m.currentScreenName = "search" and m.currentScreenNode <> invalid then
        m.currentScreenNode.channels = m.cachedChannels
    end if
end sub

sub onEpgLoaded(evt as Object)
    m.cachedEpg = evt.getData()
    if m.currentScreenName = "live" and m.currentScreenNode <> invalid then
        m.currentScreenNode.epgMap = m.cachedEpg
    else if m.currentScreenName = "guide" and m.currentScreenNode <> invalid then
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

sub switchScreen(screenName as String, params = invalid as Dynamic)
    ' Remove tela atual do container se houver
    if m.currentScreenNode <> invalid then
        m.screensContainer.removeChild(m.currentScreenNode)
        m.currentScreenNode = invalid
    end if

    m.currentScreenName = screenName

    if screenName = "home" then
        node = CreateObject("roSGNode", "HomeScreen")
        if m.cachedDestaques <> invalid then
            node.railsData = m.cachedDestaques
            if m.cachedDestaques.Count() > 0 and m.cachedDestaques[0].items.Count() > 0 then
                node.featuredItem = m.cachedDestaques[0].items[0]
            end if
        end if
        node.observeField("itemSelected", "onHomeItemSelected")
        node.observeField("playRequested", "onHomePlayRequested")
        m.currentScreenNode = node
        m.sidebarMenu.selectedIndex = 0

    else if screenName = "live" then
        node = CreateObject("roSGNode", "LiveScreen")
        if m.cachedChannels <> invalid then node.channels = m.cachedChannels
        if m.cachedEpg <> invalid then node.epgMap = m.cachedEpg
        if params <> invalid and params.channelIndex <> invalid then
            node.currentChannelIndex = params.channelIndex
        end if
        m.currentScreenNode = node
        m.sidebarMenu.selectedIndex = 1

    else if screenName = "vod" then
        node = CreateObject("roSGNode", "VodScreen")
        if m.cachedVod <> invalid then node.vodItems = m.cachedVod
        node.observeField("itemSelected", "onVodItemSelected")
        m.currentScreenNode = node
        m.sidebarMenu.selectedIndex = 2

    else if screenName = "ficha" then
        node = CreateObject("roSGNode", "FichaScreen")
        if params <> invalid then node.item = params
        node.observeField("playRequested", "onFichaPlayRequested")
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
        m.currentScreenNode = node
        m.sidebarMenu.selectedIndex = 3

    else if screenName = "events" then
        node = CreateObject("roSGNode", "EventsScreen")
        if m.cachedEvents <> invalid then node.events = m.cachedEvents
        node.observeField("tuneRequested", "onEventTune")
        m.currentScreenNode = node
        m.sidebarMenu.selectedIndex = 4

    else if screenName = "radios" then
        node = CreateObject("roSGNode", "RadiosScreen")
        if m.cachedRadios <> invalid then node.radios = m.cachedRadios
        m.currentScreenNode = node
        m.sidebarMenu.selectedIndex = 5

    else if screenName = "search" then
        node = CreateObject("roSGNode", "SearchScreen")
        if m.cachedChannels <> invalid then node.channels = m.cachedChannels
        if m.cachedVod <> invalid then node.vodItems = m.cachedVod
        node.observeField("tuneRequested", "onSearchTune")
        node.observeField("itemSelected", "onSearchVodSelected")
        m.currentScreenNode = node
        m.sidebarMenu.selectedIndex = 6

    else if screenName = "settings" then
        node = CreateObject("roSGNode", "SettingsScreen")
        node.observeField("reloadRequested", "onSettingsReload")
        m.currentScreenNode = node
        m.sidebarMenu.selectedIndex = 7
    end if

    if m.currentScreenNode <> invalid then
        m.screensContainer.appendChild(m.currentScreenNode)
        m.currentScreenNode.setFocus(true)
    end if

    ' Atualiza visibilidade da barra lateral (oculta no player de VOD e Live em tela cheia)
    if screenName = "player" or (screenName = "live" and not m.sidebarMenu.isExpanded) then
        m.sidebarMenu.visible = false
    else
        m.sidebarMenu.visible = true
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
    switchScreen("home")
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

' ----- Sidebar Menu -----

sub onSidebarSelected(evt as Object)
    itemKey = evt.getData()
    m.sidebarMenu.isExpanded = false
    if m.currentScreenName <> itemKey then
        switchScreen(itemKey)
    end if
    if m.currentScreenNode <> invalid then
        m.currentScreenNode.setFocus(true)
    end if
end sub

' ====================================================================
' Saimo Connect (Controle Remoto via Celular na Porta 8999)
' ====================================================================

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

    ' Se a barra lateral está expandida
    if m.sidebarMenu.isExpanded then
        if key = "right" then
            m.sidebarMenu.isExpanded = false
            if m.currentScreenNode <> invalid then m.currentScreenNode.setFocus(true)
            return true
        else if key = "back" then
            m.sidebarMenu.isExpanded = false
            if m.currentScreenNode <> invalid then m.currentScreenNode.setFocus(true)
            return true
        end if
        return false
    end if

    ' Se o usuário pressiona "left" e não está em Player de vídeo
    if key = "left" and m.currentScreenName <> "player" then
        m.sidebarMenu.visible = true
        m.sidebarMenu.isExpanded = true
        m.sidebarMenu.setFocus(true)
        return true
    end if

    ' Botão Voltar (Back)
    if key = "back" then
        if m.currentScreenName <> "home" then
            switchScreen("home")
            if m.currentScreenNode <> invalid then m.currentScreenNode.setFocus(true)
            return true
        else if not m.sidebarMenu.isExpanded then
            m.sidebarMenu.visible = true
            m.sidebarMenu.isExpanded = true
            m.sidebarMenu.setFocus(true)
            return true
        end if
    end if

    return false
end function
