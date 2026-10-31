' ====================================================================
' Saimo TV - FavoritesScreen (BrightScript)
' Tela dedicada de Favoritos idêntica ao Android TV Box (Aba.FAVORITOS)
' ====================================================================

sub init()
    m.favoritesRowList = m.top.findNode("favoritesRowList")
    m.emptyState = m.top.findNode("emptyState")
    m.countLabel = m.top.findNode("countLabel")

    m.favoritesRowList.observeField("rowItemSelected", "onRowItemSelected")
    m.top.observeField("focusedChild", "onFocusedChildChange")
    refreshFavorites()
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() and not m.favoritesRowList.isInFocusChain() then
        if m.favoritesRowList.visible and m.favoritesRowList.content <> invalid and m.favoritesRowList.content.getChildCount() > 0 then
            m.favoritesRowList.setFocus(true)
        end if
    end if
end sub

sub refreshFavorites()
    favChannels = LoadFavoriteChannels()
    favVod = LoadFavoriteVOD()

    hasAny = (favChannels.Count() > 0 or favVod.Count() > 0)
    m.emptyState.visible = not hasAny
    m.favoritesRowList.visible = hasAny

    totalCount = favChannels.Count() + favVod.Count()
    m.countLabel.text = totalCount.ToStr() + " itens marcados nos seus favoritos"

    if not hasAny then return

    rootNode = CreateObject("roSGNode", "ContentNode")

    ' 1. Fileira de Canais Favoritos
    if favChannels.Count() > 0 and m.top.channels <> invalid then
        rowChannels = rootNode.CreateChild("ContentNode")
        rowChannels.title = "Canais Favoritos (" + favChannels.Count().ToStr() + ")"

        for each favName in favChannels
            for each ch in m.top.channels
                if ch.name = favName then
                    itemNode = rowChannels.CreateChild("ContentNode")
                    itemNode.title = ch.name
                    if ch.logo <> invalid and ch.logo <> "" then
                        itemNode.hdPosterUrl = ch.logo
                    end if
                    itemNode.addFields({ itemType: "channel", rawChannel: ch })
                    exit for
                end if
            end for
        end for
    end if

    ' 2. Fileira de Filmes e Séries Favoritos
    if favVod.Count() > 0 then
        rowVod = rootNode.CreateChild("ContentNode")
        rowVod.title = "Filmes e Séries Favoritos (" + favVod.Count().ToStr() + ")"

        for each v in favVod
            itemNode = rowVod.CreateChild("ContentNode")
            itemNode.title = v.title
            if v.poster <> invalid and v.poster <> "" then
                itemNode.hdPosterUrl = v.poster
            else if v.backdrop <> invalid and v.backdrop <> "" then
                itemNode.hdPosterUrl = v.backdrop
            end if
            itemNode.addFields({ itemType: "vod", rawVod: v })
        end for
    end if

    m.favoritesRowList.content = rootNode
end sub

sub onRowItemSelected()
    coords = m.favoritesRowList.rowItemSelected
    rowIndex = coords[0]
    colIndex = coords[1]

    root = m.favoritesRowList.content
    if root <> invalid and rowIndex < root.getChildCount() then
        row = root.getChild(rowIndex)
        if row <> invalid and colIndex < row.getChildCount() then
            node = row.getChild(colIndex)
            if node <> invalid then
                if node.itemType = "channel" and node.rawChannel <> invalid then
                    m.top.tuneRequested = node.rawChannel
                else if node.itemType = "vod" and node.rawVod <> invalid then
                    m.top.itemSelected = node.rawVod
                end if
            end if
        end if
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "up" then
        if m.favoritesRowList.isInFocusChain() then
            rowFocused = m.favoritesRowList.rowItemFocused
            if rowFocused <> invalid and rowFocused.Count() > 0 and rowFocused[0] = 0 then
                m.top.focusUpRequested = true
                return true
            end if
        else
            m.top.focusUpRequested = true
            return true
        end if
    else if key = "left" then
        return true
    else if key = "back" then
        return false ' Bubbles to MainScene
    end if

    return false
end function
