' ====================================================================
' Saimo TV - VodScreen (BrightScript)
' ====================================================================

sub init()
    m.vodPosterGrid = m.top.findNode("vodPosterGrid")
    m.vodCountLabel = m.top.findNode("vodCountLabel")
    m.chipsHint = m.top.findNode("chipsHint")
    m.vodPosterGrid.observeField("itemSelected", "onPosterSelected")
    m.currentCategoryIdx = 0
    m.focusArea = "grid" ' "chips" ou "grid"
    m.categories = ["Filmes", "Séries", "Animes", "Doramas"]
    m.chipColors = ["#4FE3D0", "#7AA2FF", "#FFB454", "#FF7EB6"]
    m.top.observeField("focused", "onFocusChange")
end sub

sub onFocusChange()
    if m.top.hasFocus() then
        if m.focusArea = "chips" then
            updateChipStyles()
        else if m.vodPosterGrid <> invalid then
            m.vodPosterGrid.setFocus(true)
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
                if m.focusArea = "chips" and border <> invalid then
                    border.visible = true
                    border.color = "#FFFFFF"
                else if border <> invalid then
                    border.visible = false
                end if
            else
                bg.color = "#1e293b"
                txt.color = "#94a3b8"
                if border <> invalid then border.visible = false
            end if
        end if
    end for

    if m.focusArea = "chips" then
        m.chipsHint.text = "◀ / ▶ Trocar categoria  •  [OK] ou ▼ Navegar títulos  •  ◀ Menu"
        m.chipsHint.color = "#FFFFFF"
    else
        m.chipsHint.text = "▲ Suba para trocar categorias  •  [OK] Ver detalhes  •  ◀ Menu"
        m.chipsHint.color = "#4FE3D0"
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

    root = CreateObject("roSGNode", "ContentNode")
    for each it in filtered
        node = root.CreateChild("ContentNode")
        node.title = it.title
        node.hdPosterUrl = it.poster
        node.addFields({ rawItem: it })
    end for

    m.vodPosterGrid.content = root
    if m.focusArea = "grid" and m.vodPosterGrid <> invalid then
        m.vodPosterGrid.jumpToItem = 0
        if m.top.hasFocus() then m.vodPosterGrid.setFocus(true)
    end if
end sub

sub onPosterSelected()
    idx = m.vodPosterGrid.itemSelected
    if m.filteredList <> invalid and idx >= 0 and idx < m.filteredList.Count() then
        m.top.itemSelected = m.filteredList[idx]
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "up" and m.focusArea = "grid" and m.vodPosterGrid.itemFocused < 7 then
        m.focusArea = "chips"
        m.top.setFocus(true)
        updateChipStyles()
        return true
    else if (key = "down" or key = "OK") and m.focusArea = "chips" then
        m.focusArea = "grid"
        m.vodPosterGrid.setFocus(true)
        updateChipStyles()
        return true
    else if key = "left" and m.focusArea = "chips" then
        if m.currentCategoryIdx > 0 then
            m.currentCategoryIdx = m.currentCategoryIdx - 1
            m.top.selectedCategory = m.categories[m.currentCategoryIdx]
            updateChipStyles()
            applyCategoryFilter()
            return true
        else
            return false ' Bubbles to MainScene to open sidebar
        end if
    else if key = "right" and m.focusArea = "chips" then
        if m.currentCategoryIdx < 3 then
            m.currentCategoryIdx = m.currentCategoryIdx + 1
            m.top.selectedCategory = m.categories[m.currentCategoryIdx]
            updateChipStyles()
            applyCategoryFilter()
            return true
        else
            return true
        end if
    else if key = "up" and m.focusArea = "chips" then
        return true
    else if key = "left" and m.focusArea = "grid" then
        if m.vodPosterGrid.itemFocused mod 7 = 0 then
            return false ' Bubbles to MainScene to open sidebar
        end if
    end if

    return false
end function
