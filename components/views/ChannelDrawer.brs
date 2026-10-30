' ====================================================================
' Saimo TV - ChannelDrawer (BrightScript)
' ====================================================================

sub init()
    m.drawerContainer = m.top.findNode("drawerContainer")
    m.countLabel = m.top.findNode("countLabel")
    m.channelList = m.top.findNode("channelList")
    m.channelList.observeField("itemSelected", "onListItemSelected")
end sub

sub onChannelsChange()
    channels = m.top.channels
    if channels = invalid then return
    m.countLabel.text = channels.Count().ToStr() + " canais disponíveis"

    content = CreateObject("roSGNode", "ContentNode")
    for each ch in channels
        item = content.CreateChild("ContentNode")
        item.title = ch.number.ToStr() + "  " + ch.name
    end for
    m.channelList.content = content
end sub

sub onOpenChange()
    isOpen = m.top.isOpen
    m.drawerContainer.visible = isOpen
    if isOpen then
        m.drawerContainer.translation = [80, 0]
        m.channelList.setFocus(true)
        if m.top.selectedIndex < m.top.channels.Count() then
            m.channelList.jumpToItem = m.top.selectedIndex
        end if
    else
        m.drawerContainer.translation = [-500, 0]
    end if
end sub

sub onListItemSelected()
    idx = m.channelList.itemSelected
    m.top.selectedIndex = idx
    if m.top.channels <> invalid and idx < m.top.channels.Count() then
        m.top.channelSelected = m.top.channels[idx]
        m.top.isOpen = false
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back" or key = "left" then
        if m.top.isOpen then
            m.top.isOpen = false
            return true
        end if
    end if

    return false
end function
