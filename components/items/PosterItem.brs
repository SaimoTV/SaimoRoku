' ====================================================================
' Saimo TV - PosterItem (BrightScript para RowList)
' ====================================================================

sub init()
    m.poster = m.top.findNode("poster")
    m.title = m.top.findNode("title")
end sub

sub onItemContentChange()
    item = m.top.itemContent
    if item <> invalid then
        if item.hdPosterUrl <> invalid and item.hdPosterUrl <> "" then
            m.poster.uri = item.hdPosterUrl
        end if
        if item.title <> invalid then
            m.title.text = item.title
        end if
    end if
end sub
