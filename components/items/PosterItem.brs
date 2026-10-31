' ====================================================================
' Saimo TV - PosterItem (BrightScript para RowList)
' Capa 2:3 para filmes; cartão 16:9 com o logo inteiro para canais
' ====================================================================

sub init()
    m.poster = m.top.findNode("poster")
    m.title = m.top.findNode("title")
    m.focusBorder = m.top.findNode("focusBorder")
    m.cardBg = m.top.findNode("cardBg")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressBar = m.top.findNode("progressBar")
    m.larguraBarra = 200
end sub

sub modoCanal()
    m.cardBg.width = 280 : m.cardBg.height = 158
    m.focusBorder.width = 290 : m.focusBorder.height = 168
    m.poster.translation = [50, 24]
    m.poster.width = 180 : m.poster.height = 110
    m.poster.loadWidth = 180 : m.poster.loadHeight = 110
    m.poster.loadDisplayMode = "scaleToFit"
    m.title.translation = [0, 168]
    m.title.width = 280
end sub

sub onItemContentChange()
    item = m.top.itemContent
    if item = invalid then return

    if item.itemType = "channel" then modoCanal()
    if item.hdPosterUrl <> invalid then m.poster.uri = item.hdPosterUrl
    if item.title <> invalid then m.title.text = item.title

    ' Barra de progresso para Continue Assistindo
    if item.percent <> invalid and item.percent > 0 then
        m.progressTrack.visible = true
        m.progressBar.visible = true
        pWidth = Int((item.percent / 100.0) * m.larguraBarra)
        if pWidth < 5 then pWidth = 5
        if pWidth > m.larguraBarra then pWidth = m.larguraBarra
        m.progressBar.width = pWidth
    else
        m.progressTrack.visible = false
        m.progressBar.visible = false
    end if
end sub

sub onFocusChange()
    focado = m.top.focusPercent > 0.5 and m.top.rowListHasFocus
    m.focusBorder.visible = focado
    if focado then m.title.color = "#FFFFFF" else m.title.color = "#A8B4C0"
end sub
