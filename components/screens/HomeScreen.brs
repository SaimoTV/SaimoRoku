' ====================================================================
' Saimo TV - HomeScreen (BrightScript)
' Tela inicial idêntica ao Android TV Box (EscolhaActivity.kt)
' Fileiras: Continue assistindo, Ao vivo agora, Favoritos e Destaques
' ====================================================================

sub init()
    m.heroBanner = m.top.findNode("heroBanner")
    m.contentRowList = m.top.findNode("contentRowList")

    m.heroBanner.observeField("playClicked", "onHeroPlay")
    m.heroBanner.observeField("detailsClicked", "onHeroDetails")
    m.contentRowList.observeField("rowItemSelected", "onRowItemSelected")
    m.contentRowList.observeField("rowItemFocused", "onRowItemFocused")

    m.heroTimer = m.top.findNode("heroTimer")
    m.heroTimer.observeField("fire", "aplicarDestaque")

    m.currentFocus = "hero" ' "rows" ou "hero"
    m.top.observeField("focusedChild", "onFocusedChildChange")
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() and not m.heroBanner.isInFocusChain() and not m.contentRowList.isInFocusChain() then
        updateLayoutFocus()
    end if
end sub

sub updateLayoutFocus()
    if m.currentFocus = "rows" then
        if m.contentRowList <> invalid then m.contentRowList.setFocus(true)
    else
        if m.heroBanner <> invalid then m.heroBanner.setFocus(true)
    end if
end sub

sub onFeaturedChange()
    if m.top.featuredItem <> invalid then
        m.heroBanner.featuredItem = m.top.featuredItem
    end if
end sub

sub onRailsChange()
    rootNode = CreateObject("roSGNode", "ContentNode")

    ' 1. Fileira: Continue Assistindo (se houver progresso salvo)
    inProg = GetInProgressList()
    if inProg <> invalid and inProg.Count() > 0 then
        rowProg = rootNode.CreateChild("ContentNode")
        rowProg.title = "Continue Assistindo"
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
        rowLive.title = "Ao Vivo Agora"
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

            itemNode.title = ch.number.ToStr() + ". " + ch.name
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
        rowFav.title = "Meus Favoritos"
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

    ' Canais têm cartão 16:9, mais baixo que as capas.
    alturas = []
    tamanhos = []
    for i = 0 to rootNode.getChildCount() - 1
        linha = rootNode.getChild(i)
        ehCanal = linha.getChildCount() > 0 and linha.getChild(0).itemType = "channel"
        if ehCanal then
            alturas.Push(280) : tamanhos.Push([280, 230])
        else
            alturas.Push(410) : tamanhos.Push([200, 356])
        end if
    end for
    m.contentRowList.rowHeights = alturas
    m.contentRowList.rowItemSize = tamanhos
    m.contentRowList.content = rootNode

    ' Define o primeiro destaque do hero banner se ainda não definido
    if m.top.featuredItem = invalid and rails <> invalid and rails.Count() > 0 and rails[0].items.Count() > 0 then
        m.top.featuredItem = rails[0].items[0]
    end if
end sub

sub onRowItemFocused()
    coords = m.contentRowList.rowItemFocused
    if coords = invalid or coords.Count() < 2 then return
    rowIndex = coords[0]
    colIndex = coords[1]

    ' Longe do topo, os trilhos ocupam a tela toda.
    if rowIndex > 0 then
        if m.heroBanner.visible then
            m.heroBanner.visible = false
            m.contentRowList.translation = [80, 100]
        end if
    else
        if not m.heroBanner.visible then
            m.heroBanner.visible = true
            m.contentRowList.translation = [80, 640]
        end if
    end if

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
        m.heroBanner.featuredItem = {
            title: ch.name,
            overview: prog,
            genres: "Canal ao vivo",
            poster: ch.logo,
            semFundo: true
        }
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

sub onHeroPlay()
    if m.heroBanner.featuredItem <> invalid then
        m.top.playRequested = m.heroBanner.featuredItem
    else if m.top.featuredItem <> invalid then
        m.top.playRequested = m.top.featuredItem
    end if
end sub

sub onHeroDetails()
    if m.heroBanner.featuredItem <> invalid then
        m.top.itemSelected = m.heroBanner.featuredItem
    else if m.top.featuredItem <> invalid then
        m.top.itemSelected = m.top.featuredItem
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "down" then
        if m.currentFocus = "hero" then
            if m.contentRowList.content <> invalid and m.contentRowList.content.getChildCount() > 0 then
                m.currentFocus = "rows"
                updateLayoutFocus()
                return true
            end if
        end if
    else if key = "up" then
        if m.currentFocus = "rows" then
            rowFocused = m.contentRowList.rowItemFocused
            if rowFocused <> invalid and rowFocused.Count() > 0 and rowFocused[0] = 0 then
                m.currentFocus = "hero"
                updateLayoutFocus()
                return true
            end if
        else if m.currentFocus = "hero" then
            m.top.focusUpRequested = true
            return true
        end if
    end if

    return false
end function
