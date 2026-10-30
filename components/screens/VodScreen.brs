' ====================================================================
' Saimo TV - VodScreen (BrightScript)
' ====================================================================

sub init()
    m.vodPosterGrid = m.top.findNode("vodPosterGrid")
    m.vodCountLabel = m.top.findNode("vodCountLabel")
    m.chipsHint = m.top.findNode("chipsHint")
    m.vodPosterGrid.observeField("itemSelected", "onPosterSelected")
    m.currentCategoryIdx = 0
    m.focusArea = "chips" ' "chips" ou "grid"
    m.categories = ["Filmes", "Séries", "Animes", "Doramas"]
    m.chipColors = ["#4FE3D0", "#7AA2FF", "#FFB454", "#FF7EB6"]
    m.top.observeField("focusedChild", "onFocusedChildChange")
    updateChipStyles()
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() then
        if m.focusArea = "grid" and m.vodPosterGrid <> invalid then
            m.vodPosterGrid.setFocus(true)
        else
            if m.vodPosterGrid <> invalid and m.vodPosterGrid.hasFocus() then
                m.vodPosterGrid.setFocus(false)
            end if
            m.focusArea = "chips"
            updateChipStyles()
        end if
    end if
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
    for i = 0 to 3
        bg = m.top.findNode("chipBg_" + i.ToStr())
        txt = m.top.findNode("chipText_" + i.ToStr())
        border = m.top.findNode("chipBorder_" + i.ToStr())

        if bg <> invalid and txt <> invalid then
            if i = m.currentCategoryIdx then
                bg.color = m.chipColors[i]
                txt.color = "#0b0e14"
                if border <> invalid then
                    border.visible = (m.focusArea = "chips")
                end if
            else
                bg.color = "#1e293b"
                txt.color = "#94a3b8"
                if border <> invalid then border.visible = false
            end if
        end if
    end for

    if m.focusArea = "chips" then
        m.chipsHint.text = "◀ / ▶ Escolher categoria  •  ▼ [OK] Navegar nos títulos  •  ◀ Menu"
        m.chipsHint.color = "#4FE3D0"
    else
        m.chipsHint.text = "[Voltar] Retornar para categorias  •  [OK] Assistir / Detalhes  •  ◀ Menu"
        m.chipsHint.color = "#FFB454"
    end if
end sub

sub applyCategoryFilter()
    allItems = m.top.vodItems
    if allItems = invalid then return

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

    m.filteredList = filtered
    m.vodCountLabel.text = filtered.Count().ToStr() + " títulos em " + cat

    ' Limita a criação inicial de ContentNodes para fluidez instantânea
    maxNodes = 140
    if filtered.Count() < maxNodes then maxNodes = filtered.Count()

    root = CreateObject("roSGNode", "ContentNode")
    for i = 0 to maxNodes - 1
        it = filtered[i]
        node = root.CreateChild("ContentNode")
        node.title = it.title
        node.hdPosterUrl = it.poster
        node.addFields({ rawItem: it })
    end for

    m.vodPosterGrid.content = root
    m.vodPosterGrid.jumpToItem = 0
end sub

sub onPosterSelected()
    idx = m.vodPosterGrid.itemSelected
    if m.filteredList <> invalid and idx >= 0 and idx < m.filteredList.Count() then
        m.top.itemSelected = m.filteredList[idx]
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    ' Se está na grade de posters
    if m.focusArea = "grid" then
        if key = "back" then
            ' [Voltar] na grade retorna o foco para as categorias no topo
            m.focusArea = "chips"
            if m.vodPosterGrid <> invalid then m.vodPosterGrid.setFocus(false)
            m.top.setFocus(true)
            updateChipStyles()
            return true
        else if key = "up" then
            ' Se estiver na linha superior da grade (itens 0-6), sobe para os chips
            if m.vodPosterGrid.itemFocused < 7 then
                m.focusArea = "chips"
                if m.vodPosterGrid <> invalid then m.vodPosterGrid.setFocus(false)
                m.top.setFocus(true)
                updateChipStyles()
                return true
            end if
        else if key = "left" then
            ' Se estiver na coluna da esquerda, abre a barra lateral
            if m.vodPosterGrid.itemFocused mod 7 = 0 then
                return false ' Bubbles para MainScene abrir menu lateral
            end if
        end if
        return false

    ' Se o foco está nos chips de categoria
    else if m.focusArea = "chips" then
        if key = "down" or key = "OK" then
            if m.filteredList <> invalid and m.filteredList.Count() > 0 then
                m.focusArea = "grid"
                m.vodPosterGrid.setFocus(true)
                updateChipStyles()
                return true
            end if
        else if key = "left" then
            if m.currentCategoryIdx > 0 then
                m.currentCategoryIdx = m.currentCategoryIdx - 1
                m.top.selectedCategory = m.categories[m.currentCategoryIdx]
                return true
            else
                return false ' Bubbles para MainScene abrir menu lateral
            end if
        else if key = "right" then
            if m.currentCategoryIdx < 3 then
                m.currentCategoryIdx = m.currentCategoryIdx + 1
                m.top.selectedCategory = m.categories[m.currentCategoryIdx]
                return true
            else
                return true
            end if
        else if key = "back" then
            return false ' Bubbles para MainScene voltar para a Home
        end if
    end if

    return false
end function
