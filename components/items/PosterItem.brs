' ====================================================================
' Saimo TV - PosterItem (BrightScript para RowList)
' Cartão moderno estilo TV Box com borda de foco e barra de progresso
' ====================================================================

sub init()
    m.poster = m.top.findNode("poster")
    m.title = m.top.findNode("title")
    m.focusBorder = m.top.findNode("focusBorder")
    m.cardBg = m.top.findNode("cardBg")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressBar = m.top.findNode("progressBar")
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

        ' Barra de progresso para Continue Assistindo
        if item.percent <> invalid and item.percent > 0 then
            m.progressTrack.visible = true
            m.progressBar.visible = true
            pWidth = Int((item.percent / 100.0) * 180)
            if pWidth < 5 then pWidth = 5
            if pWidth > 180 then pWidth = 180
            m.progressBar.width = pWidth
        else
            m.progressTrack.visible = false
            m.progressBar.visible = false
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
