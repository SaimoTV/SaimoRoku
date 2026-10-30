' ====================================================================
' Saimo TV - VodScreen (BrightScript)
' ====================================================================

sub init()
    m.vodPosterGrid = m.top.findNode("vodPosterGrid")
    m.vodCountLabel = m.top.findNode("vodCountLabel")
    m.vodPosterGrid.observeField("itemSelected", "onPosterSelected")
    m.currentCategoryIdx = 0
    m.focusArea = "grid" ' "chips" ou "grid"
    m.categories = ["Filmes", "Séries", "Animes", "Doramas"]
    m.chipColors = ["#4FE3D0", "#7AA2FF", "#FFB454", "#FF7EB6"]
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
        if bg <> invalid and txt <> invalid then
            if i = m.currentCategoryIdx then
                bg.color = m.chipColors[i]
                txt.color = "#0b0e14"
            else
                bg.color = "#1e293b"
                txt.color = "#94a3b8"
            end if
        end if
    end for
end sub

sub applyCategoryFilter()
    allItems = m.top.vodItems
    if allItems = invalid then return

    cat = m.categories[m.currentCategoryIdx]
    filtered = []

    for each it in allItems
        if it.category = cat or (cat = "Filmes" and not it.isSeries) then
            filtered.Push(it)
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
end sub

sub onPosterSelected()
    idx = m.vodPosterGrid.itemSelected
    if m.filteredList <> invalid and idx < m.filteredList.Count() then
        m.top.itemSelected = m.filteredList[idx]
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "up" and m.focusArea = "grid" and m.vodPosterGrid.itemFocused < 7 then
        m.focusArea = "chips"
        updateChipStyles()
        return true
    else if key = "down" and m.focusArea = "chips" then
        m.focusArea = "grid"
        m.vodPosterGrid.setFocus(true)
        return true
    else if key = "left" and m.focusArea = "chips" then
        if m.currentCategoryIdx > 0 then
            m.currentCategoryIdx = m.currentCategoryIdx - 1
            m.top.selectedCategory = m.categories[m.currentCategoryIdx]
            return true
        end if
    else if key = "right" and m.focusArea = "chips" then
        if m.currentCategoryIdx < 3 then
            m.currentCategoryIdx = m.currentCategoryIdx + 1
            m.top.selectedCategory = m.categories[m.currentCategoryIdx]
            return true
        end if
    end if

    return false
end function
