' ====================================================================
' Saimo TV - PosterItem (BrightScript para RowList)
' Mesmos cartões da TV Box: capa 2:3 para títulos, cartão largo com o logo
' inteiro para canais e rádios. A moldura de foco abraça imagem e nome.
' ====================================================================

sub init()
    m.moldura = m.top.findNode("moldura")
    m.fundo = m.top.findNode("fundo")
    m.inicial = m.top.findNode("inicial")
    m.poster = m.top.findNode("poster")
    m.canto = m.top.findNode("canto")
    m.title = m.top.findNode("title")
    m.sub = m.top.findNode("sub")
    m.progressTrack = m.top.findNode("progressTrack")
    m.progressBar = m.top.findNode("progressBar")
    m.larguraBarra = 248
end sub

sub modoLargo()
    m.moldura.width = 528 : m.moldura.height = 400
    m.fundo.width = 504 : m.fundo.height = 280
    m.canto.visible = false
    m.inicial.width = 504 : m.inicial.height = 280
    m.poster.translation = [132, 42]
    m.poster.width = 264 : m.poster.height = 220
    m.poster.loadWidth = 264 : m.poster.loadHeight = 220
    m.poster.loadDisplayMode = "scaleToFit"
    m.title.translation = [18, 304]
    m.title.width = 492 : m.title.height = 36
    m.title.maxLines = 1
end sub

sub onItemContentChange()
    item = m.top.itemContent
    if item = invalid then return

    if item.itemType = "channel" or item.itemType = "radio" then modoLargo()
    temImagem = item.hdPosterUrl <> invalid and item.hdPosterUrl <> ""
    if temImagem then
        m.poster.uri = item.hdPosterUrl
        m.inicial.text = ""
    else if item.title <> invalid then
        m.inicial.text = UCase(Left(item.title, 1))
    end if
    if item.title <> invalid then m.title.text = item.title
    if item.subTitulo <> invalid and item.subTitulo <> "" then
        m.sub.text = item.subTitulo
        m.sub.visible = true
    end if

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
    m.moldura.visible = m.top.focusPercent > 0.5 and m.top.rowListHasFocus
end sub
