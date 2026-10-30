' ====================================================================
' Saimo TV - SidebarMenu (BrightScript)
' ====================================================================

sub init()
    m.menuBg = m.top.findNode("menuBg")
    m.menuDivider = m.top.findNode("menuDivider")
    m.menuLogoText = m.top.findNode("menuLogoText")
    m.focusPill = m.top.findNode("focusPill")
    m.focusBar = m.top.findNode("focusBar")
    m.versionLabel = m.top.findNode("versionLabel")
    m.itemNames = ["home", "live", "vod", "guide", "events", "radios", "search", "settings"]
    updateSelection(0)
end sub

sub onExpandedChange()
    expanded = m.top.isExpanded
    width = 80
    if expanded then width = 260

    m.menuBg.width = width
    m.menuDivider.translation = [width - 1, 0]
    m.focusPill.width = width - 16
    m.menuLogoText.visible = expanded
    m.versionLabel.visible = expanded

    for i = 0 to 7
        labelNode = m.top.findNode("label_" + i.ToStr())
        if labelNode <> invalid then labelNode.visible = expanded
    end for
end sub

sub onIndexChange()
    updateSelection(m.top.selectedIndex)
end sub

sub updateSelection(index as Integer)
    if index < 0 then index = 0
    if index > 7 then index = 7
    m.top.selectedIndex = index

    yPos = 120 + (index * 60)
    m.focusPill.translation = [8, yPos]
    m.focusBar.translation = [8, yPos]

    for i = 0 to 7
        iconNode = m.top.findNode("icon_" + i.ToStr())
        labelNode = m.top.findNode("label_" + i.ToStr())
        if i = index then
            if iconNode <> invalid then iconNode.color = "#4FE3D0"
            if labelNode <> invalid then labelNode.color = "#4FE3D0"
        else
            if iconNode <> invalid then iconNode.color = "#94a3b8"
            if labelNode <> invalid then labelNode.color = "#94a3b8"
        end if
    end for
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "up" then
        if m.top.selectedIndex > 0 then
            m.top.selectedIndex = m.top.selectedIndex - 1
            return true
        end if
    else if key = "down" then
        if m.top.selectedIndex < 7 then
            m.top.selectedIndex = m.top.selectedIndex + 1
            return true
        end if
    else if key = "OK" or key = "right" then
        m.top.itemSelected = m.itemNames[m.top.selectedIndex]
        return true
    end if

    return false
end function
