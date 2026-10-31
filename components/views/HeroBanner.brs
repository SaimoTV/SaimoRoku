' ====================================================================
' Saimo TV - HeroBanner (BrightScript)
' ====================================================================

sub init()
    m.backdropPoster = m.top.findNode("backdropPoster")
    m.titleLabel = m.top.findNode("titleLabel")
    m.genreLabel = m.top.findNode("genreLabel")
    m.overviewLabel = m.top.findNode("overviewLabel")
    m.playBtnBg = m.top.findNode("playBtnBg")
    m.playBtnText = m.top.findNode("playBtnText")
    m.playBtnBorder = m.top.findNode("playBtnBorder")
    m.detailsBtnBg = m.top.findNode("detailsBtnBg")
    m.detailsBtnText = m.top.findNode("detailsBtnText")
    m.detailsBtnBorder = m.top.findNode("detailsBtnBorder")
    m.focusedButton = 0 ' 0 = Play, 1 = Detalhes
    m.top.observeField("focusedChild", "onFocusedChildChange")
    updateButtonFocus()
end sub

sub onFocusedChildChange()
    updateButtonFocus()
end sub

sub onItemChange()
    item = m.top.featuredItem
    if item = invalid then return

    m.titleLabel.text = item.title
    ' Canal não tem capa larga: só limpa o fundo, para o logo não ficar esticado.
    if item.semFundo = true then
        m.backdropPoster.uri = ""
    else if item.backdrop <> invalid and item.backdrop <> "" then
        m.backdropPoster.uri = item.backdrop
    else if item.poster <> invalid and item.poster <> "" then
        m.backdropPoster.uri = item.poster
    end if

    if item.genres <> invalid and item.genres <> "" then
        m.genreLabel.text = item.genres
    else if item.year <> invalid and item.year <> "" then
        m.genreLabel.text = item.year
    else
        m.genreLabel.text = ""
    end if

    if item.overview <> invalid and item.overview <> "" then
        m.overviewLabel.text = item.overview
    else
        m.overviewLabel.text = ""
    end if
end sub

sub updateButtonFocus()
    hasFoc = m.top.hasFocus()
    if m.focusedButton = 0 then
        m.playBtnBg.color = "#4FE3D0"
        m.playBtnText.color = "#0b0e14"
        if m.playBtnBorder <> invalid then m.playBtnBorder.visible = hasFoc
        m.detailsBtnBg.color = "#1e293b"
        m.detailsBtnText.color = "#FFFFFF"
        if m.detailsBtnBorder <> invalid then m.detailsBtnBorder.visible = false
    else
        m.playBtnBg.color = "#1e293b"
        m.playBtnText.color = "#FFFFFF"
        if m.playBtnBorder <> invalid then m.playBtnBorder.visible = false
        m.detailsBtnBg.color = "#4FE3D0"
        m.detailsBtnText.color = "#0b0e14"
        if m.detailsBtnBorder <> invalid then m.detailsBtnBorder.visible = hasFoc
    end if
    m.top.focusedButton = m.focusedButton
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
