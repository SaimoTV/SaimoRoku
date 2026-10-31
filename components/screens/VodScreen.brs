' ====================================================================
' Saimo TV - VodScreen (BrightScript)
' On Demand como na TV Box: cabeçalho que segue o foco, cartões de categoria
' na primeira fileira e, abaixo, os trilhos da categoria escolhida.
' ====================================================================

sub init()
    m.heroBanner = m.top.findNode("heroBanner")
    m.vodRowList = m.top.findNode("vodRowList")
    m.heroTimer = m.top.findNode("heroTimer")
    m.heroTimer.observeField("fire", "aplicarDestaque")
    m.vodRowList.observeField("rowItemSelected", "onRowItemSelected")
    m.vodRowList.observeField("rowItemFocused", "onRowItemFocused")

    m.currentCategoryIdx = 0
    m.categories = ["Filmes", "Séries", "Animes", "Doramas"]
    m.cores = ["#4FE3D0", "#7AA2FF", "#FFB454", "#FF7EB6"]
    m.icones = ["m_movie", "m_live_tv", "m_star", "m_more"]
    m.top.observeField("focusedChild", "onFocusedChildChange")
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() and not m.vodRowList.isInFocusChain() then m.vodRowList.setFocus(true)
end sub

sub onItemsChange()
    separar()
    montar()
end sub

sub onCategoryChange()
    for i = 0 to m.categories.Count() - 1
        if m.categories[i] = m.top.selectedCategory then m.currentCategoryIdx = i
    end for
    if m.grupos <> invalid then montar()
end sub

sub separar()
    m.grupos = [[], [], [], []]
    allItems = m.top.vodItems
    if allItems = invalid then return
    for each it in allItems
        itCat = ""
        if it.category <> invalid then itCat = LCase(it.category)
        itTitle = ""
        if it.title <> invalid then itTitle = LCase(it.title)
        if Instr(1, itCat, "anime") > 0 or Instr(1, itTitle, "anime") > 0 then
            m.grupos[2].Push(it)
        else if Instr(1, itCat, "dorama") > 0 or Instr(1, itTitle, "dorama") > 0 then
            m.grupos[3].Push(it)
        else if it.isSeries then
            m.grupos[1].Push(it)
        else
            m.grupos[0].Push(it)
        end if
    end for
end sub

function textoTitulos(n as Integer) as String
    if n = 1 then return "1 título"
    return n.ToStr() + " títulos"
end function

sub fileira(raiz as Object, titulo as String, itens as Object, de as Integer, ate as Integer)
    if ate >= itens.Count() then ate = itens.Count() - 1
    if de > ate then return
    linha = raiz.CreateChild("ContentNode")
    linha.title = titulo
    for i = de to ate
        it = itens[i]
        no = linha.CreateChild("ContentNode")
        no.title = it.title
        if it.poster <> invalid then no.hdPosterUrl = it.poster
        no.addFields({ itemType: "vod", rawItem: it })
    end for
end sub

sub montar()
    if m.grupos = invalid then return
    raiz = CreateObject("roSGNode", "ContentNode")
    cats = raiz.CreateChild("ContentNode")
    cats.title = "Categorias"
    for i = 0 to 3
        g = m.grupos[i]
        capas = []
        for c = 0 to 3
            if c < g.Count() and g[c].poster <> invalid then capas.Push(g[c].poster)
        end for
        no = cats.CreateChild("ContentNode")
        no.title = m.categories[i]
        no.addFields({ itemType: "categoria", indice: i, subTitulo: textoTitulos(g.Count()), cor: m.cores[i], icone: "pkg:/images/icons/" + m.icones[i] + ".png", capas: capas })
    end for

    g = m.grupos[m.currentCategoryIdx]
    fileira(raiz, "Em alta", g, 0, 19)
    fileira(raiz, "Recomendados para você", g, 20, 39)
    fileira(raiz, "Mais títulos", g, 40, 119)

    AjustarFileiras(m.vodRowList, raiz)
    m.vodRowList.content = raiz
    mostrarCategoria(m.currentCategoryIdx)
end sub

sub mostrarCategoria(i as Integer)
    m.heroBanner.featuredItem = { title: m.categories[i], genres: textoTitulos(m.grupos[i].Count()), overview: "Lançamentos, clássicos e tudo entre eles, dublados e legendados.", semFundo: true }
end sub

function noEm(coords as Dynamic) as Dynamic
    root = m.vodRowList.content
    if root = invalid or coords = invalid or coords.Count() < 2 then return invalid
    if coords[0] >= root.getChildCount() then return invalid
    linha = root.getChild(coords[0])
    if linha = invalid or coords[1] >= linha.getChildCount() then return invalid
    return linha.getChild(coords[1])
end function

sub onRowItemFocused()
    m.heroTimer.control = "stop"
    m.heroTimer.control = "start"
end sub

sub aplicarDestaque()
    no = noEm(m.vodRowList.rowItemFocused)
    if no = invalid then return
    if no.itemType = "categoria" then
        mostrarCategoria(no.indice)
    else if no.rawItem <> invalid then
        m.heroBanner.featuredItem = no.rawItem
    end if
end sub

sub onRowItemSelected()
    no = noEm(m.vodRowList.rowItemSelected)
    if no = invalid then return
    if no.itemType = "categoria" then
        if no.indice <> m.currentCategoryIdx then
            m.currentCategoryIdx = no.indice
            montar()
            m.vodRowList.jumpToRowItem = [0, no.indice]
        end if
    else if no.rawItem <> invalid then
        m.top.itemSelected = no.rawItem
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
