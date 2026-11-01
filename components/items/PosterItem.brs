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
    m.title.translation = [18, 300]
    m.title.width = 492 : m.title.height = 36
    m.title.maxLines = 1
end sub

' Cartão comum é a maioria: evento e categoria criam as peças só quando precisam.
function novoRotulo(pai as Object, x as Integer, y as Integer, w as Integer, h as Integer, cor as String, tamanho as Integer, fonte as String, texto as String) as Object
    r = pai.createChild("Label")
    r.translation = [x, y]
    r.width = w
    if h > 0 then r.height = h
    r.color = cor
    r.font.uri = "pkg:/fonts/Roboto-" + fonte + ".ttf"
    r.font.size = tamanho
    r.text = texto
    return r
end function

function novoPoster(pai as Object, x as Integer, y as Integer, w as Integer, h as Integer, uri as String) as Object
    c = pai.createChild("Poster")
    c.translation = [x, y]
    c.width = w
    c.height = h
    c.loadWidth = w
    c.loadHeight = h
    c.uri = uri
    return c
end function

sub modoEvento(item as Object)
    g = m.top.createChild("Group")
    fundo = novoPoster(g, 32, 30, 170, 44, "pkg:/images/p_branca.9.png")
    fundo.blendColor = "#FF4D4F"
    selo = novoRotulo(g, 32, 30, 170, 44, "#FFFFFF", 24, "Medium", item.hora)
    selo.horizAlign = "center"
    selo.vertAlign = "center"
    novoPoster(g, 70, 90, 140, 140, item.casa).loadDisplayMode = "scaleToFit"
    novoPoster(g, 318, 90, 140, 140, item.fora).loadDisplayMode = "scaleToFit"
    x = novoRotulo(g, 210, 90, 108, 140, "#A8B4C0", 48, "Medium", "x")
    x.horizAlign = "center"
    x.vertAlign = "center"
end sub

sub modoCategoria(item as Object)
    m.moldura.width = 720 : m.moldura.height = 410
    m.fundo.visible = false : m.poster.visible = false : m.canto.visible = false
    m.title.visible = false
    g = m.top.createChild("Group")
    x = 12
    for each uri in item.capas
        novoPoster(g, x, 12, 174, 386, uri).loadDisplayMode = "scaleToZoom"
        x = x + 174
    end for
    veu = g.createChild("Rectangle")
    veu.translation = [12, 12]
    veu.width = 696
    veu.height = 386
    veu.color = "#0b0e14A0"
    novoPoster(g, 44, 270, 96, 96, "pkg:/images/p_circulo.png").blendColor = item.cor
    novoPoster(g, 68, 294, 48, 48, item.icone).blendColor = "#0b0e14"
    novoRotulo(g, 162, 262, 520, 0, "#FFFFFF", 44, "Medium", item.title)
    novoRotulo(g, 162, 318, 520, 0, "#D5DCE5", 24, "Regular", item.subTitulo)
end sub

sub onItemContentChange()
    item = m.top.itemContent
    if item = invalid then return
    if item.itemType = "categoria" then
        modoCategoria(item)
        return
    end if

    if item.itemType = "channel" or item.itemType = "radio" or item.itemType = "evento" then modoLargo()
    if item.itemType = "evento" then
        modoEvento(item)
        m.poster.visible = false
        m.sub.translation = [18, 340]
    end if
    temImagem = item.hdPosterUrl <> invalid and item.hdPosterUrl <> ""
    if temImagem then
        m.poster.uri = item.hdPosterUrl
        m.inicial.text = ""
    else if item.title <> invalid and item.itemType <> "evento" then
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
