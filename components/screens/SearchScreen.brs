' ====================================================================
' Saimo TV - SearchScreen (BrightScript)
' ====================================================================

sub init()
    m.searchKeyboard = m.top.findNode("searchKeyboard")
    m.resultsHeader = m.top.findNode("resultsHeader")
    m.resultsList = m.top.findNode("resultsList")

    m.searchKeyboard.observeField("text", "onSearchTextChanged")
    m.resultsList.observeField("itemSelected", "onResultSelected")
    m.searchKeyboard.setFocus(true)
end sub

sub onSearchTextChanged()
    query = LCase(m.searchKeyboard.text.Trim())
    if Len(query) < 2 then
        m.resultsHeader.text = "DIGITE PELO MENOS 2 LETRAS"
        m.resultsList.content = invalid
        return
    end if

    root = CreateObject("roSGNode", "ContentNode")
    count = 0

    ' 1. Busca em canais ao vivo
    channels = m.top.channels
    if channels <> invalid then
        for each ch in channels
            if Instr(1, LCase(ch.name), query) > 0 then
                node = root.CreateChild("ContentNode")
                node.title = "[CANAL] " + ch.number.ToStr() + " - " + ch.name
                node.addFields({ type: "channel", item: ch })
                count = count + 1
                if count >= 30 then exit for
            end if
        end for
    end if

    ' 2. Busca em VOD (filmes e séries)
    vodItems = m.top.vodItems
    if vodItems <> invalid and count < 30 then
        for each it in vodItems
            if Instr(1, LCase(it.title), query) > 0 then
                node = root.CreateChild("ContentNode")
                tag = "FILME"
                if it.isSeries then tag = "SÉRIE"
                node.title = "[" + tag + "] " + it.title
                node.addFields({ type: "vod", item: it })
                count = count + 1
                if count >= 30 then exit for
            end if
        end for
    end if

    m.resultsHeader.text = count.ToStr() + " RESULTADOS ENCONTRADOS"
    m.resultsList.content = root
end sub

sub onResultSelected()
    idx = m.resultsList.itemSelected
    root = m.resultsList.content
    if root <> invalid and idx < root.getChildCount() then
        node = root.getChild(idx)
        if node <> invalid then
            if node.type = "channel" then
                m.top.tuneRequested = node.item
            else if node.type = "vod" then
                m.top.itemSelected = node.item
            end if
        end if
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "right" and m.searchKeyboard.hasFocus() then
        if m.resultsList.content <> invalid and m.resultsList.content.getChildCount() > 0 then
            m.resultsList.setFocus(true)
            return true
        end if
    else if key = "left" and m.resultsList.hasFocus() then
        m.searchKeyboard.setFocus(true)
        return true
    end if

    return false
end function
