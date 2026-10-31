' ====================================================================
' Saimo TV - ChannelDrawer (BrightScript)
' Drawer com filtros por categoria, busca instantânea e favoritos estilo TV Box
' ====================================================================

sub init()
    m.drawerContainer = m.top.findNode("drawerContainer")
    m.countLabel = m.top.findNode("countLabel")
    m.searchBarGroup = m.top.findNode("searchBarGroup")
    m.searchBarBorder = m.top.findNode("searchBarBorder")
    m.searchBarBg = m.top.findNode("searchBarBg")
    m.searchBarLabel = m.top.findNode("searchBarLabel")
    m.categoryChipsGroup = m.top.findNode("categoryChipsGroup")
    m.keyboardContainer = m.top.findNode("keyboardContainer")
    m.searchKeyboard = m.top.findNode("searchKeyboard")
    m.channelList = m.top.findNode("channelList")

    m.channelList.observeField("itemSelected", "onListItemSelected")
    m.searchKeyboard.observeField("text", "onSearchTextChanged")

    m.focusArea = "list" ' "list", "chips", "search", "keyboard"
    m.currentCategoryIdx = 0 ' 0 = Todos, 1 = Favoritos, 2 = Aberta, 3 = Esportes, 4 = Filmes
    m.chipColors = ["#4FE3D0", "#FFB454", "#7AA2FF", "#38BDF8", "#F472B6"]
    m.filterQuery = ""
    m.filteredChannels = []

    updateCategoryChipsVisuals()
end sub

sub onChannelsChange()
    populateChannelList()
end sub

sub updateCategoryChipsVisuals()
    for i = 0 to 4
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
end sub

sub populateChannelList()
    channels = m.top.channels
    if channels = invalid then return

    filtered = []
    query = m.filterQuery
    catIdx = m.currentCategoryIdx

    for each ch in channels
        ' 1. Filtro de Categoria
        matchCat = true
        chCat = ""
        if ch.category <> invalid then chCat = LCase(ch.category)
        chName = LCase(ch.name)

        if catIdx = 1 then
            ' Favoritos
            matchCat = IsChannelFavorite(ch.name)
        else if catIdx = 2 then
            ' Aberta / Variedades
            matchCat = (Instr(1, chCat, "aberta") > 0 or Instr(1, chCat, "variedades") > 0 or Instr(1, chCat, "globo") > 0 or Instr(1, chCat, "sbt") > 0 or Instr(1, chCat, "record") > 0 or Instr(1, chCat, "band") > 0)
        else if catIdx = 3 then
            ' Esportes
            matchCat = (Instr(1, chCat, "esporte") > 0 or Instr(1, chName, "sportv") > 0 or Instr(1, chName, "espn") > 0 or Instr(1, chName, "premiere") > 0 or Instr(1, chName, "combate") > 0)
        else if catIdx = 4 then
            ' Filmes e Séries
            matchCat = (Instr(1, chCat, "filme") > 0 or Instr(1, chCat, "série") > 0 or Instr(1, chCat, "cinema") > 0 or Instr(1, chName, "telecine") > 0 or Instr(1, chName, "hbo") > 0 or Instr(1, chName, "paramount") > 0)
        end if

        if matchCat then
            ' 2. Filtro de Texto (se houver)
            if query = "" or Instr(1, chName, query) > 0 or Instr(1, ch.number.ToStr(), query) > 0 then
                filtered.Push(ch)
            end if
        end if
    end for

    m.filteredChannels = filtered
    if query <> "" then
        m.countLabel.text = filtered.Count().ToStr() + " canais encontrados"
    else if catIdx = 1 then
        m.countLabel.text = filtered.Count().ToStr() + " canais favoritos"
    else
        m.countLabel.text = filtered.Count().ToStr() + " canais disponíveis"
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
    if filtered.Count() > 0 then
        m.channelList.jumpToItem = 0
    end if
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
        m.categoryChipsGroup.visible = true
        m.channelList.translation = [20, 178]
        m.channelList.numRows = 14
        m.filterQuery = ""
        m.searchKeyboard.text = ""
        m.searchBarLabel.text = "Buscar canal... (OK para digitar)"
        updateCategoryChipsVisuals()
        populateChannelList()
        m.channelList.setFocus(true)

        if m.top.channels <> invalid and m.top.selectedIndex < m.top.channels.Count() and m.currentCategoryIdx = 0 then
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
        if key = "options" or key = "replay" or key = "play" then
            ' Tecla Replay, Play ou * favorita o canal atual
            idx = m.channelList.itemFocused
            if idx >= 0 and idx < m.filteredChannels.Count() then
                ch = m.filteredChannels[idx]
                ToggleFavoriteChannel(ch.name)
                populateChannelList()
                m.channelList.jumpToItem = idx
                return true
            end if
        else if key = "up" then
            ' Se estiver no primeiro item da lista (canal 1), sobe para os chips de categoria!
            if m.channelList.itemFocused <= 0 then
                m.focusArea = "chips"
                updateCategoryChipsVisuals()
                m.top.setFocus(true)
                return true
            end if
        else if key = "right" or key = "back" or key = "left" then
            if m.top.isOpen then
                m.top.isOpen = false
                return true
            end if
        end if

    ' 2. Foco nos Chips de Categorias
    else if m.focusArea = "chips" then
        if key = "left" then
            if m.currentCategoryIdx > 0 then
                m.currentCategoryIdx = m.currentCategoryIdx - 1
                updateCategoryChipsVisuals()
                populateChannelList()
                return true
            end if
        else if key = "right" then
            if m.currentCategoryIdx < 4 then
                m.currentCategoryIdx = m.currentCategoryIdx + 1
                updateCategoryChipsVisuals()
                populateChannelList()
                return true
            end if
        else if key = "up" then
            ' Sobe para a barra de busca
            m.focusArea = "search"
            updateCategoryChipsVisuals()
            m.searchBarBorder.visible = true
            m.searchBarBg.color = "#334155"
            m.top.setFocus(true)
            return true
        else if key = "down" or key = "OK" then
            ' Desce para a lista de canais
            m.focusArea = "list"
            updateCategoryChipsVisuals()
            m.channelList.setFocus(true)
            return true
        else if key = "back" then
            if m.top.isOpen then
                m.top.isOpen = false
                return true
            end if
        end if

    ' 3. Foco na Barra de Busca
    else if m.focusArea = "search" then
        if key = "down" then
            m.focusArea = "chips"
            m.searchBarBorder.visible = false
            m.searchBarBg.color = "#1e293b"
            updateCategoryChipsVisuals()
            m.top.setFocus(true)
            return true
        else if key = "OK" then
            m.focusArea = "keyboard"
            m.searchBarBorder.visible = false
            m.categoryChipsGroup.visible = false
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

    ' 4. Foco no Teclado Embutido
    else if m.focusArea = "keyboard" then
        if key = "down" then
            m.focusArea = "list"
            m.channelList.setFocus(true)
            return true
        else if key = "back" then
            m.keyboardContainer.visible = false
            m.categoryChipsGroup.visible = true
            m.channelList.translation = [20, 178]
            m.channelList.numRows = 14
            m.focusArea = "search"
            m.searchBarBorder.visible = true
            m.top.setFocus(true)
            return true
        end if
    end if

    return false
end function
