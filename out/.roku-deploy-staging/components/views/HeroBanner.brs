' ====================================================================
' Saimo TV - HeroBanner (BrightScript)
' Cabeçalho que acompanha o foco: nome, dados e sinopse do item em foco.
' ====================================================================

sub init()
    m.backdropPoster = m.top.findNode("backdropPoster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.genreLabel = m.top.findNode("genreLabel")
    m.overviewLabel = m.top.findNode("overviewLabel")
end sub

function textoDe(item as Object, campo as String) as String
    v = item[campo]
    if v = invalid then return ""
    return v.ToStr()
end function

sub onItemChange()
    item = m.top.featuredItem
    if item = invalid then return

    m.titleLabel.text = textoDe(item, "title")
    m.top.findNode("veu").visible = item.semFundo <> true
    if item.semFundo = true then
        m.backdropPoster.uri = ""
    else if textoDe(item, "backdrop") <> "" then
        m.backdropPoster.uri = item.backdrop
    else if textoDe(item, "poster") <> "" then
        m.backdropPoster.uri = item.poster
    end if

    dados = []
    if textoDe(item, "rating") <> "" then dados.Push("★ " + textoDe(item, "rating"))
    if textoDe(item, "year") <> "" then dados.Push(textoDe(item, "year"))
    if textoDe(item, "genres") <> "" then dados.Push(textoDe(item, "genres"))
    m.genreLabel.text = dados.Join("  ·  ")
    m.overviewLabel.text = textoDe(item, "overview")
end sub
