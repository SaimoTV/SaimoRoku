' ====================================================================
' Saimo TV - ChannelDrawer (BrightScript)
' Drawer com busca instantânea, favoritos (*) e navegação fluida
' ====================================================================

sub init()
    m.drawerContainer = m.top.findNode("drawerContainer")
    m.countLabel = m.top.findNode("countLabel")
    m.searchBarGroup = m.top.findNode("searchBarGroup")
    m.searchBarBorder = m.top.findNode("searchBarBorder")
    m.searchBarBg = m.top.findNode("searchBarBg")
    m.searchBarLabel = m.top.findNode("searchBarLabel")
    m.keyboardContainer = m.top.findNode("keyboardContainer")
    m.searchKeyboard = m.top.findNode("searchKeyboard")
    m.channelList = m.top.findNode("channelList")

    m.channelList.observeField("itemSelected", "onListItemSelected")
    m.searchKeyboard.observeField("text", "onSearchTextChanged")

    m.focusArea = "list" ' "list", "search", "keyboard"
    m.filterQuery = ""
    m.filteredChannels = []
end sub

sub onChannelsChange()
    populateChannelList()
end sub

sub populateChannelList()
    channels = m.top.channels
    if channels = invalid then return

    filtered = []
    query = m.filterQuery

    for each ch in channels
        if query = "" or Instr(1, LCase(ch.name), query) > 0 or Instr(1, ch.number.ToStr(), query) > 0 then
            filtered.Push(ch)
        end if
    end for

    m.filteredChannels = filtered
    if query <> "" then
        m.countLabel.text = filtered.Count().ToStr() + " canais encontrados"
    else
        m.countLabel.text = channels.Count().ToStr() + " canais disponíveis"
    end if

    content = CreateObject("roSGNode", "ContentNode")
    for each ch in filtered
        item = content.CreateChild("ContentNode")
        favMark = ""
        if IsChannelFavorite(ch.name) then
            favMark = "[*] "
        end if
        item.title = favMark + ch.number.ToStr() + "   " + ch.name
    end for

    m.channelList.content = content
end sub

sub onOpenChange()
    isOpen = m.top.isOpen
    m.drawerContainer.visible = isOpen
    if isOpen then
        m.drawerContainer.translation = [80, 0]
        m.focusArea = "list"
        m.searchBarBorder.visible = false
        m.searchBarBg.color = "#1e293b"
        m.keyboardContainer.visible = false
        m.channelList.translation = [20, 142]
        m.channelList.numRows = 15
        m.filterQuery = ""
        m.searchKeyboard.text = ""
        m.searchBarLabel.text = "Buscar canal... (OK para digitar)"
        populateChannelList()
        m.channelList.setFocus(true)

        if m.top.channels <> invalid and m.top.selectedIndex < m.top.channels.Count() then
            m.channelList.jumpToItem = m.top.selectedIndex
        end if
    else
        m.drawerContainer.translation = [-520, 0]
    end if
end sub

sub onSearchTextChanged()
    m.filterQuery = LCase(m.searchKeyboard.text.Trim())
    if m.filterQuery = "" then
        m.searchBarLabel.text = "Buscar canal... (OK para digitar)"
    else
        m.searchBarLabel.text = "Buscar: " + m.searchKeyboard.text
    end if
    populateChannelList()
end sub

sub onListItemSelected()
    idx = m.channelList.itemSelected
    if m.filteredChannels <> invalid and idx >= 0 and idx < m.filteredChannels.Count() then
        selectedCh = m.filteredChannels[idx]
        m.top.channelSelected = selectedCh
        m.top.isOpen = false
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    ' 1. Foco na Lista de Canais
    if m.focusArea = "list" then
        if key = "options" or key = "replay" then
            ' Tecla * ou Replay favorita o canal atual
            idx = m.channelList.itemFocused
            if idx >= 0 and idx < m.filteredChannels.Count() then
                ch = m.filteredChannels[idx]
                ToggleFavoriteChannel(ch.name)
                populateChannelList()
                m.channelList.jumpToItem = idx
                return true
            end if
        else if key = "up" then
            ' Se estiver no primeiro item da lista (canal 1), sobe para a barra de busca!
            if m.channelList.itemFocused <= 0 then
                m.focusArea = "search"
                m.searchBarBorder.visible = true
                m.searchBarBg.color = "#334155"
                m.top.setFocus(true)
                return true
            end if
        else if key = "right" or key = "back" or key = "left" then
            if m.top.isOpen then
                m.top.isOpen = false
                return true
            end if
        end if

    ' 2. Foco na Barra de Busca
    else if m.focusArea = "search" then
        if key = "down" then
            m.focusArea = "list"
            m.searchBarBorder.visible = false
            m.searchBarBg.color = "#1e293b"
            m.channelList.setFocus(true)
            return true
        else if key = "OK" then
            m.focusArea = "keyboard"
            m.searchBarBorder.visible = false
            m.keyboardContainer.visible = true
            m.channelList.translation = [20, 480]
            m.channelList.numRows = 9
            m.searchKeyboard.setFocus(true)
            return true
        else if key = "right" or key = "back" or key = "left" then
            if m.top.isOpen then
                m.top.isOpen = false
                return true
            end if
        end if

    ' 3. Foco no Teclado Embutido
    else if m.focusArea = "keyboard" then
        if key = "down" then
            m.focusArea = "list"
            m.channelList.setFocus(true)
            return true
        else if key = "back" then
            m.keyboardContainer.visible = false
            m.channelList.translation = [20, 142]
            m.channelList.numRows = 15
            m.focusArea = "search"
            m.searchBarBorder.visible = true
            m.top.setFocus(true)
            return true
        end if
    end if

    return false
end function
