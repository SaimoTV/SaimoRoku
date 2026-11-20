' ====================================================================
' Saimo TV para Roku - MainScene (BrightScript)
' Roteador principal de navegação, gerenciador de telas e Saimo Connect
' ====================================================================

sub init()
    iniciarConta()
    m.sceneBg = m.top.findNode("sceneBg")
    m.screensContainer = m.top.findNode("screensContainer")
    m.topNavBar = m.top.findNode("topNavBar")
    m.dataLoader = m.top.findNode("dataLoader")
    m.connectServer = m.top.findNode("connectServer")
    m.veuBrilho = m.top.findNode("veuBrilho")
    m.voltaDoBrilho = m.top.findNode("voltaDoBrilho")
    m.voltaDoBrilho.observeField("state", "onVoltaDoBrilho")
    m.focoAntesDoEscuro = invalid
    salvo = GetRegistry().Read("brilho_app")
    if salvo <> invalid and salvo <> "" then m.top.brilho = salvo.ToInt()

    m.topNavBar.observeField("itemSelected", "onTopNavSelected")
    m.topNavBar.observeField("focusDownRequested", "onFocusDownFromNav")
    m.connectServer.observeField("receivedCommand", "onConnectCommand")
    m.connectServer.observeField("addonsUpdated", "onConnectAddonsUpdated")

    m.localDestaques = []
    m.localVod = []
    m.addonRails = []
    m.addonVodItems = []
    m.addonCatalogTask = invalid
    m.addonSyncTask = invalid
    m.pendingDeepLinkId = invalid

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

    ' Sem conta e sem ter escolhido "entrar sem login": primeiro as boas-vindas.
    if not ContaLogado() and GetRegistry().Read("boas_vindas_feito") <> "1" then
        abrirBoasVindas()
    else
        partidaNormal()
    end if
end sub

sub partidaNormal()
    ' Com 2 ou mais perfis, a partida pergunta quem está assistindo.
    e = PerfisEstado()
    if e.perguntar = true and e.lista.Count() >= 2 then
        abrirPerfis(true, "escolher")
    else
        ' Abre na tela configurada (padrão: "home")
        prefs = LoadPreferences()
        if prefs.abrirEm = "canal" then
            switchScreen("live")
        else
            switchScreen("home")
        end if
    end if
end sub

sub abrirBoasVindas()
    m.telaBoasVindas = CreateObject("roSGNode", "BoasVindasScreen")
    m.telaBoasVindas.observeField("entrarConta", "onBoasVindasEntrar")
    m.telaBoasVindas.observeField("semLogin", "onBoasVindasSemLogin")
    m.topNavBar.visible = false
    m.top.appendChild(m.telaBoasVindas)
    m.telaBoasVindas.setFocus(true)
end sub

sub fecharBoasVindas()
    if m.telaBoasVindas <> invalid then
        m.top.removeChild(m.telaBoasVindas)
        m.telaBoasVindas = invalid
    end if
    m.topNavBar.visible = true
end sub

sub onBoasVindasSemLogin()
    reg = GetRegistry()
    reg.Write("boas_vindas_feito", "1")
    reg.Flush()
    fecharBoasVindas()
    partidaNormal()
end sub

' Vai para os Ajustes, que abrem a Conta Saimo (QR ou e-mail e senha).
sub onBoasVindasEntrar()
    fecharBoasVindas()
    switchScreen("settings")
    if m.currentScreenNode <> invalid then m.currentScreenNode.abrirConta = true
end sub

sub loadAllData()
    ' Cancela tarefas de um reload anterior: sem isso, respostas antigas
    ' chegam depois e sobrescrevem os dados novos na TV.
    pararLoaders()
    m.loaders = []
    prefs = LoadPreferences()

    loader1 = CreateObject("roSGNode", "DataLoaderTask")
    loader1.requestType = "channels"
    loader1.requestUrl = prefs.urlCanais
    loader1.observeField("responseChannels", "onChannelsLoaded")
    loader1.control = "run"
    m.loaders.Push(loader1)

    loader2 = CreateObject("roSGNode", "DataLoaderTask")
    loader2.requestType = "epg"
    loader2.requestUrl = prefs.urlCanais
    loader2.observeField("responseEpg", "onEpgLoaded")
    loader2.control = "run"
    m.loaders.Push(loader2)

    loader3 = CreateObject("roSGNode", "DataLoaderTask")
    loader3.requestType = "destaques"
    loader3.requestUrl = prefs.urlFilmes
    loader3.observeField("responseDestaques", "onDestaquesLoaded")
    loader3.observeField("responseVodItems", "onVodLoaded")
    loader3.control = "run"
    m.loaders.Push(loader3)

    loader5 = CreateObject("roSGNode", "DataLoaderTask")
    loader5.requestType = "events"
    loader5.requestUrl = prefs.urlCanais
    loader5.observeField("responseEvents", "onEventsLoaded")
    loader5.control = "run"
    m.loaders.Push(loader5)

    loader6 = CreateObject("roSGNode", "DataLoaderTask")
    loader6.requestType = "radios"
    loader6.requestUrl = prefs.urlCanais
    loader6.observeField("responseRadios", "onRadiosLoaded")
    loader6.control = "run"
    m.loaders.Push(loader6)

    loader7 = CreateObject("roSGNode", "MinhasListasTask")
    loader7.acao = "carregar"
    loader7.observeField("canais", "onMinhasCarregadas")
    loader7.control = "run"
    m.loaders.Push(loader7)

    loadAddonCatalogs()
end sub
sub pararLoaders()
    if m.loaders = invalid then return
    for each loader in m.loaders
        loader.unobserveField("responseChannels")
        loader.unobserveField("responseEpg")
        loader.unobserveField("responseDestaques")
        loader.unobserveField("responseVodItems")
        loader.unobserveField("responseEvents")
        loader.unobserveField("responseRadios")
        loader.unobserveField("canais")
        loader.control = "stop"
    end for
end sub

sub loadAddonCatalogs()
    if m.addonCatalogTask <> invalid then
        m.addonCatalogTask.unobserveField("responseRails")
        m.addonCatalogTask.control = "stop"
        m.addonCatalogTask = invalid
    end if

    if GetEnabledAddons().Count() = 0 then
        m.addonRails = []
        m.addonVodItems = []
        applyCombinedVodAndRails()
        return
    end if

    task = CreateObject("roSGNode", "AddonCatalogTask")
    task.mode = "discover"
    task.includeTmdbDiscovery = true
    task.observeField("responseRails", "onAddonCatalogsLoaded")
    task.control = "run"
    m.addonCatalogTask = task
end sub

sub onAddonCatalogsLoaded(evt as Object)
    if m.addonCatalogTask = invalid then return
    rails = evt.getData()
    vodItems = m.addonCatalogTask.responseVodItems
    m.addonCatalogTask.unobserveField("responseRails")
    m.addonCatalogTask = invalid

    if rails <> invalid and Type(rails) = "roArray" then
        m.addonRails = rails
    else
        m.addonRails = []
    end if
    if vodItems <> invalid and Type(vodItems) = "roArray" then
        m.addonVodItems = vodItems
    else
        m.addonVodItems = []
    end if
    applyCombinedVodAndRails()
end sub

sub applyCombinedVodAndRails()
    combinedRails = []
    if m.localDestaques <> invalid then combinedRails.Append(m.localDestaques)
    if m.addonRails <> invalid then combinedRails.Append(m.addonRails)
    m.cachedDestaques = combinedRails

    combinedVod = []
    if m.localVod <> invalid then combinedVod.Append(m.localVod)
    if m.addonVodItems <> invalid then combinedVod.Append(m.addonVodItems)
    m.cachedVod = combinedVod

    ' Perfil Kids: no Roku a classificação de cada título não fica na memória
    ' (pesa demais num stick de 512 MB), então filmes e séries ficam de fora.
    if KidsAtivo() then
        m.cachedDestaques = []
        m.cachedVod = []
    end if

    if m.currentScreenName = "home" and m.currentScreenNode <> invalid then
        m.currentScreenNode.railsData = m.cachedDestaques
        m.currentScreenNode.vodItems = m.cachedVod
        if m.cachedDestaques.Count() > 0 and m.cachedDestaques[0].items <> invalid and m.cachedDestaques[0].items.Count() > 0 then
            m.currentScreenNode.featuredItem = m.cachedDestaques[0].items[0]
        end if
    else if m.currentScreenName = "vod" and m.currentScreenNode <> invalid then
        if m.addonRails <> invalid then m.currentScreenNode.addonRails = m.addonRails
        m.currentScreenNode.vodItems = m.cachedVod
    else if (m.currentScreenName = "favorites" or m.currentScreenName = "search") and m.currentScreenNode <> invalid then
        m.currentScreenNode.vodItems = m.cachedVod
    end if
end sub

' A tarefa que já entregou sai da lista: o campo de resposta dela guardava uma
' cópia inteira dos canais (ou do guia) enquanto o app estivesse aberto. Com
' lista grande, eram várias cópias vivas ao mesmo tempo num aparelho de 512 MB.
sub soltarTarefa(evt as Object)
    no = evt.getRoSGNode()
    if no = invalid or m.loaders = invalid then return
    for i = m.loaders.Count() - 1 to 0 step -1
        if m.loaders[i].isSameNode(no) then
            m.loaders[i].unobserveField(evt.getField())
            m.loaders.Delete(i)
            exit for
        end if
    end for
end sub

sub onChannelsLoaded(evt as Object)
    m.canaisCatalogo = evt.getData()
    soltarTarefa(evt)
    juntarCanais()
end sub

sub onMinhasCarregadas(evt as Object)
    m.canaisMinhas = evt.getData()
    soltarTarefa(evt)
    if m.canaisMinhas <> invalid and m.canaisMinhas.Count() > 0 then juntarCanais()
end sub

sub onListasMudaram(evt as Object)
    dados = evt.getData()
    m.canaisMinhas = dados.canais
    juntarCanais()
end sub

' Os canais das listas do usuário vêm depois do catálogo, em ordem de nome.
sub juntarCanais()
    ' Sem endereço de canais o catálogo é vazio: as listas da pessoa entram mesmo assim.
    if m.canaisCatalogo = invalid then m.canaisCatalogo = []
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
    m.nomesCanais = {}
    m.canaisInicio = []
    for i = 0 to todos.Count() - 1
        c = todos[i]
        m.nomesCanais[LCase(c.name).Replace(" ", "")] = c.name
        if i < 16 then m.canaisInicio.Push(c)
    end for
    juntarEventos()
    montarArvore()
    if m.currentScreenName = "home" and m.currentScreenNode <> invalid then
        m.currentScreenNode.channels = m.canaisInicio
    else if m.currentScreenName = "favorites" and m.currentScreenNode <> invalid then
        m.currentScreenNode.channels = m.cachedChannels
    else if m.currentScreenName = "search" and m.currentScreenNode <> invalid then
        m.currentScreenNode.channels = m.cachedChannels
    end if
    if m.currentScreenName = "guide" and m.currentScreenNode <> invalid then
        m.currentScreenNode.channels = m.cachedChannels
    end if
    tocarDeepLinkPendente()

end sub

sub onEpgLoaded(evt as Object)
    m.cachedEpg = evt.getData()
    soltarTarefa(evt)
    montarArvore()
    if m.currentScreenName = "home" and m.currentScreenNode <> invalid then
        m.currentScreenNode.epgMap = m.cachedEpg
    end if
    if m.currentScreenName = "guide" and m.currentScreenNode <> invalid then
        m.currentScreenNode.epgMap = m.cachedEpg
    end if
end sub

' Árvore do Ao vivo: montada em segundo plano quando os dados mudam, não no clique.
sub montarArvore()
    if m.cachedChannels = invalid then return
    if m.tarefaArvore <> invalid then
        m.tarefaArvore.unobserveField("arvore")
        m.tarefaArvore.control = "stop"
        m.tarefaArvore = invalid
    end if
    t = CreateObject("roSGNode", "ArvoreCanaisTask")
    t.canais = m.cachedChannels
    if m.cachedEpg <> invalid then t.epg = m.cachedEpg
    t.observeField("arvore", "onArvorePronta")
    m.tarefaArvore = t
    t.control = "run"
end sub

sub onArvorePronta(evt as Object)
    no = evt.getRoSGNode()
    if no = invalid or m.tarefaArvore = invalid then return
    if not no.isSameNode(m.tarefaArvore) then return
    m.arvoreCanais = evt.getData()
    m.tarefaArvore = invalid
    if m.currentScreenName = "live" and m.currentScreenNode <> invalid then m.currentScreenNode.arvore = m.arvoreCanais
end sub

sub onDestaquesLoaded(evt as Object)
    d = evt.getData()
    if d <> invalid and Type(d) = "roArray" then
        m.localDestaques = d
    else
        m.localDestaques = []
    end if
    applyCombinedVodAndRails()
end sub

sub onVodLoaded(evt as Object)
    v = evt.getData()
    soltarTarefa(evt)
    if v <> invalid and Type(v) = "roArray" then
        m.localVod = v
    else
        m.localVod = []
    end if
    applyCombinedVodAndRails()
end sub

' O jogo diz o canal por um apelido (premiere-2); procura em todos os players com nome normalizado.
function canalDoJogo(players as Object) as String
    if players = invalid or m.nomesCanais = invalid or players.Count() = 0 then return ""
    for each player in players
        if type(player) = "roString" or type(player) = "String"
            partes = player.Split("/")
            apelido = LCase(partes[partes.Count() - 1]).Replace("-", "").Replace(" ", "").Replace("_", "")
            if apelido <> ""
                if m.nomesCanais.DoesExist(apelido) then return m.nomesCanais[apelido]
                for each n in m.nomesCanais
                    if Instr(1, n, apelido) > 0 then return m.nomesCanais[n]
                end for
            end if
        end if
    end for
    return ""
end function

sub onEventsLoaded(evt as Object)
    m.eventosCrus = evt.getData()
    soltarTarefa(evt)
    juntarEventos()
end sub

sub juntarEventos()
    if m.eventosCrus = invalid then return
    saida = []
    for each ev in m.eventosCrus
        ev.channelName = canalDoJogo(ev.slugs)
        saida.Push(ev)
    end for
    m.cachedEvents = saida
    if m.currentScreenName = "events" and m.currentScreenNode <> invalid then
        m.currentScreenNode.events = m.cachedEvents
    end if
end sub

sub onRadiosLoaded(evt as Object)
    m.cachedRadios = evt.getData()
    soltarTarefa(evt)
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
    if name = "doacao" then return 7
    if name = "settings" or name = "minhas" or name = "addons" then return 8
    return 1
end function

sub switchScreen(screenName as String, params = invalid as Dynamic)
    ' Guarda tela anterior para retorno ao sair do player
    if m.currentScreenName <> "" and m.currentScreenName <> "player" and m.currentScreenName <> "novelinha" then
        m.previousScreenName = m.currentScreenName
        m.previousScreenParams = m.currentScreenParams
    end if
    m.currentScreenParams = params

    ' Remove tela atual do container se houver e encerra tarefas de vídeo pendentes
    if m.currentScreenNode <> invalid then
        m.currentScreenNode.unobserveField("telaCheia")
        m.currentScreenNode.callFunc("cleanUp")
        m.screensContainer.removeChild(m.currentScreenNode)
        m.currentScreenNode = invalid
    end if

    m.currentScreenName = screenName

    if screenName = "home" then
        node = CreateObject("roSGNode", "HomeScreen")
        node.observeField("minhasListasRequested", "onAbrirMinhasListas")
        node.observeField("addonsRequested", "onAbrirAddons")
        if m.canaisInicio <> invalid then node.channels = m.canaisInicio
        if m.cachedEpg <> invalid then node.epgMap = m.cachedEpg
        if m.cachedVod <> invalid then node.vodItems = m.cachedVod
        if m.cachedDestaques <> invalid then
            node.railsData = m.cachedDestaques
            if m.cachedDestaques.Count() > 0 and m.cachedDestaques[0].items <> invalid and m.cachedDestaques[0].items.Count() > 0 then
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
        if m.arvoreCanais <> invalid then node.arvore = m.arvoreCanais
        node.observeField("telaCheia", "onRadioTelaCheia")
        node.observeField("guiaRequested", "onAbrirGuia")
        node.observeField("sairRequested", "onSairDoApp")
        node.observeField("homeRequested", "onLiveHomeRequested")
        node.observeField("focusUpRequested", "onScreenFocusUp")
        m.currentScreenNode = node

    else if screenName = "vod" then
        node = CreateObject("roSGNode", "VodScreen")
        if m.addonRails <> invalid then node.addonRails = m.addonRails
        if m.cachedVod <> invalid then node.vodItems = m.cachedVod
        node.observeField("itemSelected", "onVodItemSelected")
        node.observeField("novelinhaSelected", "onNovelinhaSelected")
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

    else if screenName = "novelinha" then
        node = CreateObject("roSGNode", "NovelinhaScreen")
        node.observeField("exitRequested", "onPlayerExit")
        if params <> invalid then node.item = params
        m.currentScreenNode = node

    else if screenName = "player" then
        node = CreateObject("roSGNode", "PlayerScreen")
        if params <> invalid then node.playItem = params
        node.observeField("exitRequested", "onPlayerExit")
        m.currentScreenNode = node

    else if screenName = "guide" then
        node = CreateObject("roSGNode", "GuideScreen")
        if m.cachedEpg <> invalid then node.epgMap = m.cachedEpg
        if m.cachedChannels <> invalid then node.channels = m.cachedChannels
        node.observeField("tuneRequested", "onGuideTune")
        node.observeField("voltarRequested", "onGuiaVoltar")
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
        node.observeField("addonsRequested", "onAbrirAddons")
        node.observeField("perfisRequested", "onAbrirPerfis")
        node.observeField("focusUpRequested", "onScreenFocusUp")
        m.currentScreenNode = node

    else if screenName = "doacao" then
        node = CreateObject("roSGNode", "DoacaoScreen")
        node.observeField("focusUpRequested", "onScreenFocusUp")
        m.currentScreenNode = node

    else if screenName = "minhas" then
        node = CreateObject("roSGNode", "MinhasListasScreen")
        node.observeField("listasMudaram", "onListasMudaram")
        node.observeField("reloadRequested", "onSettingsReload")
        node.observeField("addonsRequested", "onAbrirAddons")
        node.observeField("focusUpRequested", "onScreenFocusUp")
        m.currentScreenNode = node

    else if screenName = "addons" then
        node = CreateObject("roSGNode", "AddonsScreen")
        node.observeField("addonsChanged", "onAddonsScreenChanged")
        node.observeField("focusUpRequested", "onScreenFocusUp")
        m.currentScreenNode = node
    end if

    if m.currentScreenNode <> invalid then
        m.screensContainer.appendChild(m.currentScreenNode)
        m.currentScreenNode.setFocus(true)
        if screenName = "minhas" then m.currentScreenNode.callFunc("focar")
    end if

    avisarCelular()

    ' Atualiza visibilidade da barra de navegação (oculta no player de VOD e Live em tela cheia)
    if screenName = "player" or screenName = "guide" or screenName = "novelinha" then
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

sub onNovelinhaSelected(evt as Object)
    switchScreen("novelinha", evt.getData())
end sub

sub onFichaPlayRequested(evt as Object)
    item = evt.getData()
    switchScreen("player", item)
end sub

sub onPlayerExit()
    if m.previousScreenName <> invalid and m.previousScreenName <> "" and m.previousScreenName <> "player" and m.previousScreenName <> "novelinha" then
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

sub avisarCelular()
    tela = m.currentScreenName
    m.connectServer.saida = FormatJson({ t: "state", mode: "idle", screen: tela, channel: "", playing: tela = "live" or tela = "player", multi: false, active: 0, screens: [], tvAudio: "tv", phoneAudio: [] })
end sub

sub onGuiaVoltar()
    switchScreen("live")
end sub

sub onLiveHomeRequested()
    switchScreen("home")
end sub

sub onSairDoApp()
    m.top.sairDoApp = true
end sub

sub onAbrirGuia()
    switchScreen("guide")
end sub

sub onAbrirMinhasListas()
    switchScreen("minhas")
end sub

sub onAbrirAddons()
    switchScreen("addons")
end sub

sub onAddonsScreenChanged()
    loadAddonCatalogs()
end sub

sub onConnectAddonsUpdated()
    if m.currentScreenName = "addons" and m.currentScreenNode <> invalid then
        m.currentScreenNode.callFunc("refresh")
    end if
    loadAddonCatalogs()
end sub

sub onSyncAddonsFinished()
    if m.addonSyncTask <> invalid then
        m.addonSyncTask.unobserveField("result")
        m.addonSyncTask = invalid
    end if
    if m.currentScreenName = "addons" and m.currentScreenNode <> invalid then
        m.currentScreenNode.callFunc("refresh")
    end if
    loadAddonCatalogs()
end sub

sub onConnectCommand(evt as Object)
    cmd = evt.getData()
    if cmd = invalid or cmd.t = invalid then return
    tipo = cmd.t

    if tipo = "brilho" and cmd.valor <> invalid then
        m.top.brilho = cmd.valor
    else if tipo = "tune" and cmd.channel <> invalid then
        tuneChannelByName(cmd.channel)
    else if tipo = "playVod" then
        switchScreen("player", { title: cmd.title, url: cmd.url, isSeries: false })
    else if tipo = "playPause" then
        if m.currentScreenName = "player" and m.currentScreenNode <> invalid then
            m.currentScreenNode.callFunc("playPause")
        end if
    else if tipo = "seek" then
        if m.currentScreenName = "player" and m.currentScreenNode <> invalid and cmd.delta <> invalid then
            m.currentScreenNode.callFunc("seek", cmd.delta)
        end if
    else if tipo = "key" and cmd.code <> invalid then
        handleVirtualKey(cmd.code)
    else if tipo = "text" and cmd.value <> invalid then
        if (m.currentScreenName = "minhas" or m.currentScreenName = "settings" or m.currentScreenName = "addons") and m.currentScreenNode <> invalid then
            m.currentScreenNode.textoRecebido = cmd.value
        end if
    else if tipo = "dados" then
        mudouListas = false
        mudouAddons = false

        ' 1. Listas M3U / catálogos Saimo
        if cmd.listas <> invalid and Type(cmd.listas) = "roAssociativeArray" then
            prefs = LoadPreferences()
            if cmd.listas.canais <> invalid and cmd.listas.canais.ToStr().Trim() <> "" then
                novoCanais = NormalizarEnderecoSaimo(cmd.listas.canais.ToStr())
                if novoCanais <> prefs.urlCanais then
                    prefs.urlCanais = novoCanais
                    mudouListas = true
                end if
            end if
            if cmd.listas.filmes <> invalid and cmd.listas.filmes.ToStr().Trim() <> "" then
                novoFilmes = NormalizarEnderecoSaimo(cmd.listas.filmes.ToStr())
                if novoFilmes <> prefs.urlFilmes then
                    prefs.urlFilmes = novoFilmes
                    mudouListas = true
                end if
            end if
            if mudouListas then
                SavePreferences(prefs)
                m.prefs = prefs
            end if
        end if

        ' 2. Addons Stremio: SÓ altera os addons locais quando a chave "addons" existir explicitamente como array
        if cmd.DoesExist("addons") and cmd.addons <> invalid and Type(cmd.addons) = "roArray" then
            existentes = LoadAddons()
            mapaExistente = {}
            for each ex in existentes
                mapaExistente[ex.baseUrl + "|" + ex.query] = ex
            end for

            novosAddons = []
            for idx = 0 to cmd.addons.Count() - 1
                rawEntry = cmd.addons[idx]
                if Type(rawEntry) = "roAssociativeArray" then
                    rawUrl = ""
                    if rawEntry.url <> invalid then rawUrl = rawEntry.url.ToStr()
                    if rawUrl = "" and rawEntry.transportUrl <> invalid then rawUrl = rawEntry.transportUrl.ToStr()
                    norm = NormalizeAddonUrl(rawUrl)
                    if norm.ok then
                        chave = norm.baseUrl + "|" + norm.query
                        ant = mapaExistente[chave]
                        compact = SanitizeCompactAddonRecord(rawEntry, idx)
                        if compact = invalid then
                            compact = {
                                url: norm.url,
                                baseUrl: norm.baseUrl,
                                query: norm.query,
                                id: norm.baseUrl,
                                name: norm.baseUrl,
                                version: "1.0.0",
                                enabled: (rawEntry.enabled <> false),
                                order: idx,
                                types: [],
                                idPrefixes: [],
                                resources: []
                            }
                            if rawEntry.name <> invalid and rawEntry.name.ToStr().Trim() <> "" then
                                compact.name = rawEntry.name.ToStr().Trim()
                            end if
                        end if
                        ' Preserva metadados já parseados caso o payload de Connect tenha vindo enxuto
                        if ant <> invalid and (compact.resources = invalid or compact.resources.Count() = 0) then
                            compact.id = ant.id
                            compact.name = ant.name
                            compact.version = ant.version
                            compact.types = ant.types
                            compact.idPrefixes = ant.idPrefixes
                            compact.resources = ant.resources
                        end if
                        novosAddons.Push(compact)
                    end if
                end if
            end for

            SaveAddons(novosAddons)
            mudouAddons = true
        end if

        ' 3. Debrid: só altera quando "debrid" existir explicitamente como objeto
        if cmd.DoesExist("debrid") and cmd.debrid <> invalid and Type(cmd.debrid) = "roAssociativeArray" then
            curDebrid = LoadDebridConfig()
            dIn = cmd.debrid
            if dIn.DoesExist("sincronizarConnect") then
                curDebrid.sincronizarConnect = (dIn.sincronizarConnect = true)
            end if
            for each pk in ["torbox", "realDebrid", "allDebrid", "premiumize"]
                if dIn.DoesExist(pk) and Type(dIn[pk]) = "roAssociativeArray" then
                    pIn = dIn[pk]
                    pCur = curDebrid[pk]
                    if pCur = invalid then pCur = { apiKey: "", enabled: false }
                    if pIn.clear = true then
                        pCur.apiKey = ""
                        pCur.enabled = false
                    else if pIn.apiKey <> invalid and pIn.apiKey.ToStr().Trim() <> "" then
                        pCur.apiKey = pIn.apiKey.ToStr().Trim()
                        pCur.enabled = (pIn.enabled <> false)
                    else if pIn.DoesExist("enabled") then
                        pCur.enabled = (pIn.enabled = true and pCur.apiKey <> "")
                    end if
                    curDebrid[pk] = pCur
                end if
            end for
            SaveDebridConfig(curDebrid)
            mudouAddons = true
        end if

        if mudouAddons then
            if m.addonSyncTask <> invalid then
                m.addonSyncTask.unobserveField("result")
                m.addonSyncTask.control = "stop"
                m.addonSyncTask = invalid
            end if
            syncTask = CreateObject("roSGNode", "AddonManageTask")
            syncTask.action = "syncmissing"
            syncTask.observeField("result", "onSyncAddonsFinished")
            syncTask.control = "run"
            m.addonSyncTask = syncTask
        end if

        if mudouListas then
            loadAllData()
        end if
    else if tipo = "fonte" or tipo = "sync" then
        avisarCelular()
    end if
end sub

sub handleVirtualKey(code as String)
    ' O celular também pode pedir saída direta do player e voltar ao início.
    if code = "back" and m.currentScreenName = "player" and m.currentScreenNode <> invalid then
        m.currentScreenNode.exitRequested = true
        return
    end if
    if (code = "options" or code = "menu") and m.currentScreenName = "player" and m.currentScreenNode <> invalid then
        m.currentScreenNode.callFunc("abrirOpcoes")
        return
    end if
    if code = "home" or code = "menu" then
        if m.currentScreenName <> "home" then switchScreen("home")
        return
    end if

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

function campoDeepLink(link as Object, nome as String) as Dynamic
    if link = invalid then return invalid
    for each chave in link
        if LCase(chave) = LCase(nome) then return link[chave]
    end for
    return invalid
end function

sub onDeepLinkChange()
    ' Roku envia contentId/contentid em caixas diferentes conforme a origem.
    link = m.top.deepLink
    contentId = campoDeepLink(link, "contentId")
    if contentId = invalid then return
    contentId = contentId.ToStr().Trim()
    if contentId = "" then return
    m.pendingDeepLinkId = contentId
    tocarDeepLinkPendente()
end sub

sub tocarDeepLinkPendente()
    if m.pendingDeepLinkId = invalid or m.pendingDeepLinkId = "" then return
    if m.cachedChannels = invalid then return
    tuneChannelByName(m.pendingDeepLinkId)
    m.pendingDeepLinkId = invalid
end sub

' ====================================================================
' Tratamento de Teclas Globais do Controle Remoto
' ====================================================================

' ---------- Brilho do app ----------
' Um véu preto por cima de tudo (não o brilho da TV). Com a tela escura (0 a 5%)
' o foco vai para o véu: qualquer botão só traz o brilho de volta, devagar.
sub onBrilho()
    v = m.top.brilho
    if v < 0 then v = 0
    if v > 100 then v = 100
    GetRegistry().Write("brilho_app", v.ToStr())
    GetRegistry().Flush()
    if m.veuBrilho = invalid then return
    m.voltaDoBrilho.control = "stop"
    m.veuBrilho.opacity = 1.0 - (v / 100.0)
    m.veuBrilho.visible = v < 100
    if v <= 5 then
        if m.focoAntesDoEscuro = invalid then m.focoAntesDoEscuro = m.top.focusedChild
        m.veuBrilho.setFocus(true)
    end if
end sub

sub voltarDoEscuro()
    m.interpBrilho = m.top.findNode("interpBrilho")
    m.interpBrilho.keyValue = [m.veuBrilho.opacity, 0.0]
    GetRegistry().Write("brilho_app", "100")
    GetRegistry().Flush()
    m.voltaDoBrilho.control = "start"
    foco = m.focoAntesDoEscuro
    m.focoAntesDoEscuro = invalid
    if foco <> invalid then foco.setFocus(true) else m.screensContainer.setFocus(true)
end sub

sub onVoltaDoBrilho()
    if m.voltaDoBrilho.state = "stopped" and m.veuBrilho.opacity <= 0.01 then m.veuBrilho.visible = false
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if m.veuBrilho <> invalid and m.veuBrilho.hasFocus() then
        if press then voltarDoEscuro()
        return true
    end if
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
        else if m.currentScreenName = "addons" and (m.previousScreenName = "settings" or m.previousScreenName = "minhas") then
            switchScreen(m.previousScreenName)
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

' ====================================================================
' Perfis: "Quem está assistindo?" por cima de tudo.
' ====================================================================
sub abrirPerfis(obrigatoria as Boolean, modo as String)
    if m.telaPerfis <> invalid then return
    m.telaPerfis = CreateObject("roSGNode", "PerfisScreen")
    m.telaPerfis.obrigatoria = obrigatoria
    m.telaPerfis.modo = modo
    m.telaPerfis.observeField("perfilEscolhido", "onPerfilEscolhido")
    m.telaPerfis.observeField("fechar", "onPerfisFechar")
    m.topNavBar.visible = false
    m.top.appendChild(m.telaPerfis)
    ' Foco direto na grade: o grupo em si não repassa o foco em todo aparelho.
    m.telaPerfis.findNode("grade").setFocus(true)
end sub

sub onPerfisFechar()
    if m.telaPerfis = invalid then return
    m.top.removeChild(m.telaPerfis)
    m.telaPerfis = invalid
    m.topNavBar.visible = true
    if m.currentScreenNode = invalid then
        switchScreen("home")
    else
        m.currentScreenNode.setFocus(true)
    end if
end sub

sub onPerfilEscolhido(evt as Object)
    PerfisEntrar(evt.getData())
    onPerfisFechar()
    ' Favoritos e o que está assistindo são do perfil: refaz as telas.
    applyCombinedVodAndRails()
    m.screenStack = []
    m.currentScreenName = ""
    switchScreen("home")
end sub

sub onAbrirPerfis()
    abrirPerfis(false, "escolher")
end sub

' Conta Saimo (opcional): sem login não faz nada. Com login, sincroniza
' alguns segundos depois de abrir e a cada 10 minutos.
sub iniciarConta()
    m.contaRelogio = CreateObject("roSGNode", "Timer")
    m.contaRelogio.duration = 8
    m.contaRelogio.repeat = false
    m.contaRelogio.observeField("fire", "onContaRelogio")
    m.contaRelogio.control = "start"
end sub

sub onContaRelogio()
    ' A cada 15 min (cada sincronia é um pedido cobrado).
    m.contaRelogio.duration = 900
    m.contaRelogio.repeat = true
    m.contaRelogio.control = "start"
    if not ContaLogado() then return
    if m.contaSincronia <> invalid then m.contaSincronia.control = "stop"
    t = CreateObject("roSGNode", "ContaTask")
    t.acao = "sincronizar"
    m.contaSincronia = t
    t.control = "run"
end sub
