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
            m.currentFocus = "rows"
            m.contentRowList.setFocus(true)
            return true
        end if
    else if key = "up" then
        if m.currentFocus = "rows" and m.contentRowList.rowItemFocused[0] = 0 then
            m.currentFocus = "hero"
            m.heroBanner.setFocus(true)
            return true
        end if
    end if

    return false
end function
