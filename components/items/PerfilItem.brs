sub init()
    m.moldura = m.top.findNode("moldura")
    m.avatar = m.top.findNode("avatar")
    m.mais = m.top.findNode("mais")
    m.selo = m.top.findNode("selo")
    m.nome = m.top.findNode("nome")
    m.escolhido = false
end sub

sub onItemContentChange()
    c = m.top.itemContent
    if c = invalid then return
    m.nome.text = c.title
    if c.HDPosterUrl <> invalid and c.HDPosterUrl <> "" then
        m.avatar.uri = c.HDPosterUrl
        m.mais.visible = false
    else
        m.avatar.uri = ""
        m.mais.visible = true
    end if
    m.selo.visible = (c.shortDescriptionLine2 = "kids")
    m.escolhido = (c.shortDescriptionLine2 = "escolhido")
    onFocusChange()
end sub

sub onFocusChange()
    foco = m.top.gridHasFocus and m.top.focusPercent > 0.5
    ' Foco: moldura branca; avatar escolhido na edição: ciano.
    if foco then
        m.moldura.color = "#FFFFFF"
    else
        m.moldura.color = "#4FE3D0"
    end if
    m.moldura.visible = foco or m.escolhido
end sub
