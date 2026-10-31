' ====================================================================
' Saimo TV - VodScreen (BrightScript)
' On Demand idêntico ao Android TV Box (PaginaActivity.kt / OnDemandActivity.kt)
' HeroBanner cinematográfico + Categorias + Fileiras de Cartões
' ====================================================================

sub init()
    m.heroBanner = m.top.findNode("heroBanner")
    m.vodRowList = m.top.findNode("vodRowList")
    m.vodCountLabel = m.top.findNode("vodCountLabel")

    m.heroBanner.observeField("playClicked", "onHeroPlay")
    m.heroBanner.observeField("detailsClicked", "onHeroDetails")
    m.vodRowList.observeField("rowItemSelected", "onRowItemSelected")
    m.vodRowList.observeField("rowItemFocused", "onRowItemFocused")

    m.currentCategoryIdx = 0
    m.currentFocus = "chips" ' "chips", "rows", "hero"
    m.categories = ["Filmes", "Séries", "Animes", "Doramas"]
    m.chipColors = ["#4FE3D0", "#7AA2FF", "#FFB454", "#FF7EB6"]

    m.top.observeField("focusedChild", "onFocusedChildChange")
    updateChipStyles()
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() and not m.vodRowList.isInFocusChain() and not m.heroBanner.isInFocusChain() then
        updateLayoutFocus()
    end if
end sub

sub updateLayoutFocus()
    if m.currentFocus = "rows" then
        if m.vodRowList <> invalid then m.vodRowList.setFocus(true)
    else if m.currentFocus = "hero" then
        if m.heroBanner <> invalid then m.heroBanner.setFocus(true)
    else
        ' Foco nos chips
        if m.vodRowList <> invalid and m.vodRowList.hasFocus() then m.vodRowList.setFocus(false)
        if m.heroBanner <> invalid and m.heroBanner.hasFocus() then m.heroBanner.setFocus(false)
        m.top.setFocus(true)
    end if
    updateChipStyles()
end sub

sub onItemsChange()
    applyCategoryFilter()
end sub

sub onCategoryChange()
    for i = 0 to m.categories.Count() - 1
        if m.categories[i] = m.top.selectedCategory then
            m.currentCategoryIdx = i
            exit for
        end if
    end for
    updateChipStyles()
    applyCategoryFilter()
end sub

sub updateChipStyles()
    hasChipFocus = (m.currentFocus = "chips")
    for i = 0 to 3
        bg = m.top.findNode("chipBg_" + i.ToStr())
        txt = m.top.findNode("chipText_" + i.ToStr())
        border = m.top.findNode("chipBorder_" + i.ToStr())

        if bg <> invalid and txt <> invalid then
            if i = m.currentCategoryIdx then
                bg.color = m.chipColors[i]
                txt.color = "#0b0e14"
                if border <> invalid then
                    border.visible = hasChipFocus
                end if
            else
                bg.color = "#1e293b"
                txt.color = "#94a3b8"
                if border <> invalid then border.visible = false
            end if
        end if
    end for
end sub

sub applyCategoryFilter()
    allItems = m.top.vodItems
    if allItems = invalid or allItems.Count() = 0 then return

    cat = m.categories[m.currentCategoryIdx]
    filtered = []

    for each it in allItems
        itCat = ""
        if it.category <> invalid then itCat = LCase(it.category)
        itTitle = ""
        if it.title <> invalid then itTitle = LCase(it.title)

        isAnime = (Instr(1, itCat, "anime") > 0 or Instr(1, itTitle, "anime") > 0)
        isDorama = (Instr(1, itCat, "dorama") > 0 or Instr(1, itTitle, "dorama") > 0)

        if cat = "Filmes" then
            if not it.isSeries and not isAnime and not isDorama then
                filtered.Push(it)
            end if
        else if cat = "Séries" then
            if it.isSeries and not isAnime and not isDorama then
                filtered.Push(it)
            end if
        else if cat = "Animes" then
            if isAnime then
                filtered.Push(it)
            end if
        else if cat = "Doramas" then
            if isDorama then
                filtered.Push(it)
            end if
        end if
    end for

    m.vodCountLabel.text = Str(filtered.Count()).Trim() + " títulos disponíveis"

    if filtered.Count() = 0 then return

    ' Monta as Fileiras temáticas estilo TV Box (Em Alta, Populares, Catálogo Completo)
    rootNode = CreateObject("roSGNode", "ContentNode")

    ' 1. Fileira: Em Alta
    rowAlta = rootNode.CreateChild("ContentNode")
    rowAlta.title = "Em Alta no " + cat
    countAlta = 20
    if filtered.Count() < countAlta then countAlta = filtered.Count()
    for i = 0 to countAlta - 1
        it = filtered[i]
        itemNode = rowAlta.CreateChild("ContentNode")
        itemNode.title = it.title
        if it.poster <> invalid then itemNode.hdPosterUrl = it.poster
        itemNode.addFields({ rawItem: it })
    end for

    ' 2. Fileira: Populares e Lançamentos
    if filtered.Count() > 20 then
        rowPop = rootNode.CreateChild("ContentNode")
        rowPop.title = "Recomendados para Você"
        countPop = 40
        if filtered.Count() < countPop then countPop = filtered.Count()
        for i = 20 to countPop - 1
            it = filtered[i]
            itemNode = rowPop.CreateChild("ContentNode")
            itemNode.title = it.title
            if it.poster <> invalid then itemNode.hdPosterUrl = it.poster
            itemNode.addFields({ rawItem: it })
        end for
    end if

    ' 3. Fileira: Catálogo Geral
    rowAll = rootNode.CreateChild("ContentNode")
    rowAll.title = "Todos de A a Z (" + cat + ")"
    maxAll = 80
    if filtered.Count() < maxAll then maxAll = filtered.Count()
    for i = 0 to maxAll - 1
        it = filtered[i]
        itemNode = rowAll.CreateChild("ContentNode")
        itemNode.title = it.title
        if it.poster <> invalid then itemNode.hdPosterUrl = it.poster
        itemNode.addFields({ rawItem: it })
    end for

    m.vodRowList.content = rootNode

    ' Define o destaque inicial do HeroBanner
    if filtered.Count() > 0 then
        m.heroBanner.featuredItem = filtered[0]
    end if
end sub

sub onRowItemFocused()
    coords = m.vodRowList.rowItemFocused
    if coords = invalid or coords.Count() < 2 then return
    rowIndex = coords[0]
    colIndex = coords[1]

    root = m.vodRowList.content
    if root <> invalid and rowIndex < root.getChildCount() then
        rowNode = root.getChild(rowIndex)
        if rowNode <> invalid and colIndex < rowNode.getChildCount() then
            selectedNode = rowNode.getChild(colIndex)
            if selectedNode <> invalid and selectedNode.rawItem <> invalid then
                m.heroBanner.featuredItem = selectedNode.rawItem
            end if
        end if
    end if
end sub

sub onRowItemSelected()
    coords = m.vodRowList.rowItemSelected
    if coords = invalid or coords.Count() < 2 then return
    rowIndex = coords[0]
    colIndex = coords[1]

    root = m.vodRowList.content
    if root <> invalid and rowIndex < root.getChildCount() then
        rowNode = root.getChild(rowIndex)
        if rowNode <> invalid and colIndex < rowNode.getChildCount() then
            selectedNode = rowNode.getChild(colIndex)
            if selectedNode <> invalid and selectedNode.rawItem <> invalid then
                m.top.itemSelected = selectedNode.rawItem
            end if
        end if
    end if
end sub

sub onHeroPlay()
    if m.heroBanner.featuredItem <> invalid then
        m.top.playRequested = m.heroBanner.featuredItem
    end if
end sub

sub onHeroDetails()
    if m.heroBanner.featuredItem <> invalid then
        m.top.itemSelected = m.heroBanner.featuredItem
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    ' 1. Foco nas Fileiras de Cards
    if m.currentFocus = "rows" then
        if key = "up" then
            coords = m.vodRowList.rowItemFocused
            if coords <> invalid and coords.Count() > 0 and coords[0] = 0 then
                ' Subiu da primeira fileira -> vai para os chips de categoria
                m.currentFocus = "chips"
                updateLayoutFocus()
                return true
            end if
        else if key = "back" then
            m.currentFocus = "chips"
            updateLayoutFocus()
            return true
        end if

    ' 2. Foco nos Chips de Categorias
    else if m.currentFocus = "chips" then
        if key = "left" then
            if m.currentCategoryIdx > 0 then
                m.currentCategoryIdx = m.currentCategoryIdx - 1
                m.top.selectedCategory = m.categories[m.currentCategoryIdx]
                updateChipStyles()
                applyCategoryFilter()
                return true
            end if
        else if key = "right" then
            if m.currentCategoryIdx < 3 then
                m.currentCategoryIdx = m.currentCategoryIdx + 1
                m.top.selectedCategory = m.categories[m.currentCategoryIdx]
                updateChipStyles()
                applyCategoryFilter()
                return true
            end if
        else if key = "down" then
            if m.vodRowList.content <> invalid and m.vodRowList.content.getChildCount() > 0 then
                m.currentFocus = "rows"
                updateLayoutFocus()
                return true
            end if
        else if key = "up" then
            ' Sobe para o menu de abas do topo
            m.top.focusUpRequested = true
            return true
        else if key = "OK" then
            if m.vodRowList.content <> invalid and m.vodRowList.content.getChildCount() > 0 then
                m.currentFocus = "rows"
                updateLayoutFocus()
                return true
            end if
        else if key = "back" then
            return false ' MainScene volta para a Home
        end if

    ' 3. Foco no HeroBanner
    else if m.currentFocus = "hero" then
        if key = "down" then
            m.currentFocus = "chips"
            updateLayoutFocus()
            return true
        else if key = "up" then
            m.top.focusUpRequested = true
            return true
        end if
    end if

    return false
end function
