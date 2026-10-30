' ====================================================================
' Saimo TV - HomeScreen (BrightScript)
' ====================================================================

sub init()
    m.heroBanner = m.top.findNode("heroBanner")
    m.contentRowList = m.top.findNode("contentRowList")
    m.heroBanner.observeField("playClicked", "onHeroPlay")
    m.heroBanner.observeField("detailsClicked", "onHeroDetails")
    m.contentRowList.observeField("rowItemSelected", "onRowItemSelected")
    m.currentFocus = "hero" ' "hero" ou "rows"
    m.top.observeField("focusedChild", "onFocusedChildChange")
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() and not m.heroBanner.isInFocusChain() and not m.contentRowList.isInFocusChain() then
        updateLayoutFocus()
    end if
end sub

sub updateLayoutFocus()
    if m.currentFocus = "rows" then
        m.heroBanner.translation = [80, -320]
        m.contentRowList.translation = [80, 110]
        if m.contentRowList <> invalid then m.contentRowList.setFocus(true)
    else
        m.heroBanner.translation = [80, 0]
        m.contentRowList.translation = [80, 480]
        if m.heroBanner <> invalid then m.heroBanner.setFocus(true)
    end if
end sub

sub onFeaturedChange()
    m.heroBanner.featuredItem = m.top.featuredItem
end sub

sub onRailsChange()
    rails = m.top.railsData
    if rails = invalid then return

    rootNode = CreateObject("roSGNode", "ContentNode")
    for each rail in rails
        rowNode = rootNode.CreateChild("ContentNode")
        rowNode.title = rail.title
        for each it in rail.items
            itemNode = rowNode.CreateChild("ContentNode")
            itemNode.title = it.title
            if it.poster <> invalid then itemNode.hdPosterUrl = it.poster
            itemNode.addFields({ rawItem: it })
        end for
    end for

    m.contentRowList.content = rootNode
end sub

sub onHeroPlay()
    if m.top.featuredItem <> invalid then
        m.top.playRequested = m.top.featuredItem
    end if
end sub

sub onHeroDetails()
    if m.top.featuredItem <> invalid then
        m.top.itemSelected = m.top.featuredItem
    end if
end sub

sub onRowItemSelected()
    coords = m.contentRowList.rowItemSelected
    rowIndex = coords[0]
    colIndex = coords[1]

    root = m.contentRowList.content
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
        end if
    else if key = "left" then
        if m.currentFocus = "rows" then
            rowFocused = m.contentRowList.rowItemFocused
            if rowFocused <> invalid and rowFocused.Count() > 1 and rowFocused[1] = 0 then
                return false ' bubbles to MainScene to open sidebar
            end if
        else if m.currentFocus = "hero" then
            return false ' bubbles to MainScene to open sidebar
        end if
    end if

    return false
end function
