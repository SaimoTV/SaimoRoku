' ====================================================================
' Saimo TV - HeroBanner (BrightScript)
' ====================================================================

sub init()
    m.backdropPoster = m.top.findNode("backdropPoster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.genreLabel = m.top.findNode("genreLabel")
    m.overviewLabel = m.top.findNode("overviewLabel")
    m.playBtnBg = m.top.findNode("playBtnBg")
    m.detailsBtnBg = m.top.findNode("detailsBtnBg")
    m.focusedButton = 0 ' 0 = Play, 1 = Detalhes
    updateButtonFocus()
end sub

sub onItemChange()
    item = m.top.featuredItem
    if item = invalid then return

    m.titleLabel.text = item.title
    if item.backdrop <> invalid and item.backdrop <> "" then
        m.backdropPoster.uri = item.backdrop
    else if item.poster <> invalid and item.poster <> "" then
        m.backdropPoster.uri = item.poster
    end if

    if item.genres <> invalid then
        m.genreLabel.text = item.genres
    else
        m.genreLabel.text = "Filmes & Séries • HD / 4K"
    end if

    if item.overview <> invalid and item.overview <> "" then
        m.overviewLabel.text = item.overview
    else
        m.overviewLabel.text = "Disponível em alta definição com áudio e legendas."
    end if
end sub

sub updateButtonFocus()
    if m.focusedButton = 0 then
        m.playBtnBg.color = "#4FE3D0"
        m.detailsBtnBg.color = "#1e293b"
    else
        m.playBtnBg.color = "#1e293b"
        m.detailsBtnBg.color = "#4FE3D0"
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "left" then
        if m.focusedButton = 1 then
            m.focusedButton = 0
            updateButtonFocus()
            return true
        end if
    else if key = "right" then
        if m.focusedButton = 0 then
            m.focusedButton = 1
            updateButtonFocus()
            return true
        end if
    else if key = "OK" then
        if m.focusedButton = 0 then
            m.top.playClicked = true
        else
            m.top.detailsClicked = true
        end if
        return true
    end if

    return false
end function
