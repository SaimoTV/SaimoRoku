' ====================================================================
' Saimo TV - EpisodeItem (BrightScript para Grade de Episódios)
' ====================================================================

sub init()
    m.thumb = m.top.findNode("thumb")
    m.title = m.top.findNode("title")
    m.epBadge = m.top.findNode("epBadge")
    m.focusBorder = m.top.findNode("focusBorder")
end sub

sub onItemContentChange()
    item = m.top.itemContent
    if item <> invalid then
        if item.hdPosterUrl <> invalid and item.hdPosterUrl <> "" then
            m.thumb.uri = item.hdPosterUrl
        end if
        if item.title <> invalid then
            m.title.text = item.title
        end if
        if item.episodeNum <> invalid then
            m.epBadge.text = "EPISÓDIO " + item.episodeNum.ToStr()
        else
            m.epBadge.text = "EPISÓDIO"
        end if
    end if
end sub

sub onFocusChange()
    if m.top.rowFocusPercent > 0.5 then
        m.focusBorder.visible = true
        m.title.color = "#FFFFFF"
    else
        m.focusBorder.visible = false
        m.title.color = "#94a3b8"
    end if
end sub
