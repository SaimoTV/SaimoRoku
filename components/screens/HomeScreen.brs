' ====================================================================
' Saimo TV - HomeScreen (BrightScript)
' Tela inicial idêntica ao Android TV Box (EscolhaActivity.kt)
' Fileiras: Continue assistindo, Ao vivo agora, Favoritos e Destaques
' ====================================================================

sub init()
    m.heroBanner = m.top.findNode("heroBanner")
    m.contentRowList = m.top.findNode("contentRowList")

    m.contentRowList.observeField("rowItemSelected", "onRowItemSelected")
    m.contentRowList.observeField("rowItemFocused", "onRowItemFocused")

    m.heroTimer = m.top.findNode("heroTimer")
    m.heroTimer.observeField("fire", "aplicarDestaque")
    m.montarTimer = m.top.findNode("montarTimer")
    m.montarTimer.observeField("fire", "montarFileiras")

    m.top.observeField("focusedChild", "onFocusedChildChange")
    saudar()
end sub

sub saudar()
    agora = CreateObject("roDateTime")
    agora.ToLocalTime()
    h = agora.GetHours()
    texto = "Boa noite"
    if h >= 5 and h < 12 then texto = "Bom dia"
    if h >= 12 and h < 18 then texto = "Boa tarde"
    m.heroBanner.featuredItem = { title: texto, genres: "O que vamos assistir?", semFundo: true }
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() and not m.contentRowList.isInFocusChain() then
        m.contentRowList.setFocus(true)
    end if
end sub

sub onFeaturedChange()
end sub

' Canais e destaques chegam em momentos diferentes: junta tudo e monta uma vez.
sub onRailsChange()
    m.montarTimer.control = "stop"
    m.montarTimer.control = "start"
end sub

sub montarFileiras()
    rootNode = CreateObject("roSGNode", "ContentNode")

    ' 1. Fileira: Continue Assistindo (se houver progresso salvo)
    inProg = GetInProgressList()
    if inProg <> invalid and inProg.Count() > 0 then
        rowProg = rootNode.CreateChild("ContentNode")
        rowProg.title = "Continuar assistindo"
        for each p in inProg
            itemNode = rowProg.CreateChild("ContentNode")
            itemNode.title = p.title
            itemPerc = 0
            if p.percent <> invalid then itemPerc = p.percent
            if p.poster <> invalid and p.poster <> "" then
                itemNode.hdPosterUrl = p.poster
            end if
            itemNode.addFields({ itemType: "vod", rawItem: p, percent: itemPerc })
        end for
    end if

    ' 2. Fileira: Ao Vivo Agora (Canais principais com o programa do ar)
    channels = m.top.channels
    if channels <> invalid and channels.Count() > 0 then
        rowLive = rootNode.CreateChild("ContentNode")
        rowLive.title = "Ao vivo agora"
        maxChannels = 16
        if channels.Count() < maxChannels then maxChannels = channels.Count()

        epg = m.top.epgMap

        for i = 0 to maxChannels - 1
            ch = channels[i]
            itemNode = rowLive.CreateChild("ContentNode")
            progTitle = invalid
            if epg <> invalid and epg[ch.name] <> invalid and epg[ch.name].Count() > 0 then
                for each p in epg[ch.name]
                    if p.isCurrent then
                        progTitle = p.title
                        exit for
                    end if
                end for
            end if

            itemNode.title = ch.name
            if ch.logo <> invalid and ch.logo <> "" then
                itemNode.hdPosterUrl = ch.logo
            end if
            itemNode.addFields({
                itemType: "channel",
                rawChannel: ch,
                programTitle: progTitle
            })
        end for
    end if

    ' 3. Fileira: Favoritos VOD (se houver)
    favVod = LoadFavoriteVOD()
    if favVod <> invalid and favVod.Count() > 0 then
        rowFav = rootNode.CreateChild("ContentNode")
        rowFav.title = "Favoritos"
        for each f in favVod
            itemNode = rowFav.CreateChild("ContentNode")
            itemNode.title = f.title
            if f.poster <> invalid and f.poster <> "" then
                itemNode.hdPosterUrl = f.poster
            else if f.backdrop <> invalid and f.backdrop <> "" then
                itemNode.hdPosterUrl = f.backdrop
            end if
            itemNode.addFields({ itemType: "vod", rawItem: f })
        end for
    end if

    ' 4. Fileiras de Destaques do Catálogo (Em Alta, Filmes Populares, Séries)
    rails = m.top.railsData
    if rails <> invalid then
        for each rail in rails
            rowNode = rootNode.CreateChild("ContentNode")
            rowNode.title = rail.title
            for each it in rail.items
                itemNode = rowNode.CreateChild("ContentNode")
                itemNode.title = it.title
                if it.poster <> invalid then itemNode.hdPosterUrl = it.poster
                itemNode.addFields({ itemType: "vod", rawItem: it })
            end for
        end for
    end if

    AjustarFileiras(m.contentRowList, rootNode)
    m.contentRowList.content = rootNode

end sub

sub onRowItemFocused()
    coords = m.contentRowList.rowItemFocused
    if coords = invalid or coords.Count() < 2 then return
    rowIndex = coords[0]
    colIndex = coords[1]

    ' Espera o foco parar antes de trocar o destaque: rolar pelos trilhos não
    ' pode baixar uma imagem grande por item.
    m.focoLinha = rowIndex
    m.focoColuna = colIndex
    m.heroTimer.control = "stop"
    m.heroTimer.control = "start"
end sub

sub aplicarDestaque()
    root = m.contentRowList.content
    if root = invalid or m.focoLinha >= root.getChildCount() then return
    rowNode = root.getChild(m.focoLinha)
    if rowNode = invalid or m.focoColuna >= rowNode.getChildCount() then return
    selectedNode = rowNode.getChild(m.focoColuna)
    if selectedNode = invalid then return
    if selectedNode.itemType = "vod" and selectedNode.rawItem <> invalid then
        m.heroBanner.featuredItem = selectedNode.rawItem
    else if selectedNode.itemType = "channel" and selectedNode.rawChannel <> invalid then
        ch = selectedNode.rawChannel
        prog = ""
        if selectedNode.programTitle <> invalid then prog = "Agora: " + selectedNode.programTitle
        m.heroBanner.featuredItem = { title: ch.name, overview: prog, genres: ch.category, semFundo: true }
    end if
end sub

sub onRowItemSelected()
    coords = m.contentRowList.rowItemSelected
    if coords = invalid or coords.Count() < 2 then return
    rowIndex = coords[0]
    colIndex = coords[1]

    root = m.contentRowList.content
    if root <> invalid and rowIndex < root.getChildCount() then
        rowNode = root.getChild(rowIndex)
        if rowNode <> invalid and colIndex < rowNode.getChildCount() then
            selectedNode = rowNode.getChild(colIndex)
            if selectedNode <> invalid then
                if selectedNode.itemType = "vod" and selectedNode.rawItem <> invalid then
                    m.top.itemSelected = selectedNode.rawItem
                else if selectedNode.itemType = "channel" and selectedNode.rawChannel <> invalid then
                    m.top.tuneRequested = selectedNode.rawChannel
                end if
            end if
        end if
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "up" then
        m.top.focusUpRequested = true
        return true
    end if
    return false
end function

sub cleanUp()
end sub
