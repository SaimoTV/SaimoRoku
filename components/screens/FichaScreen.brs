' ====================================================================
' Saimo TV - FichaScreen (BrightScript)
' ====================================================================

sub init()
    m.backdropPoster = m.top.findNode("backdropPoster")
    m.posterNode = m.top.findNode("posterNode")
    m.titleLabel = m.top.findNode("titleLabel")
    m.metaLabel = m.top.findNode("metaLabel")
    m.genresLabel = m.top.findNode("genresLabel")
    m.overviewLabel = m.top.findNode("overviewLabel")
    m.playBtnBg = m.top.findNode("playBtnBg")
    m.playBtnText = m.top.findNode("playBtnText")
    m.resumeBtnGroup = m.top.findNode("resumeBtnGroup")
    m.resumeBtnBg = m.top.findNode("resumeBtnBg")
    m.resumeBtnText = m.top.findNode("resumeBtnText")
    m.seriesPanel = m.top.findNode("seriesPanel")
    m.episodesRowList = m.top.findNode("episodesRowList")
    m.episodesRowList.observeField("rowItemSelected", "onEpisodeSelected")
    m.focusedControl = "play" ' "play", "resume", "episodes"
    m.top.observeField("focusedChild", "onFocusedChildChange")
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() then
        updateButtonFocus()
    end if
end sub

sub onItemChange()
    item = m.top.item
    if item = invalid then return

    m.titleLabel.text = item.title
    if item.poster <> invalid then m.posterNode.uri = item.poster
    if item.backdrop <> invalid and item.backdrop <> "" then
        m.backdropPoster.uri = item.backdrop
    else if item.poster <> invalid then
        m.backdropPoster.uri = item.poster
    end if

    year = "2026"
    if item.year <> invalid and item.year <> "" then year = item.year
    m.metaLabel.text = year + " • Full HD • ★ 8.5"

    if item.genres <> invalid then
        m.genresLabel.text = item.genres
    else
        m.genresLabel.text = "Gênero Geral"
    end if

    if item.overview <> invalid and item.overview <> "" then
        m.overviewLabel.text = item.overview
    else
        m.overviewLabel.text = "Disponível completo com alta taxa de bits e áudio estéreo/5.1."
    end if

    ' Checa se tem progresso salvo ("Continuar Assistindo")
    prog = GetVODProgress(item.title)
    if prog <> invalid and prog.position > 60 then
        m.resumeBtnGroup.visible = true
        minRemaining = Int(prog.position / 60)
        m.resumeBtnText.text = "Continuar (" + minRemaining.ToStr() + "m)"
    else
        m.resumeBtnGroup.visible = false
    end if

    ' Se for série, exibe grade de episódios
    if item.isSeries then
        m.seriesPanel.visible = true
        populateEpisodes(item)
    else
        m.seriesPanel.visible = false
    end if

    m.focusedControl = "play"
    updateButtonFocus()
end sub

sub populateEpisodes(item as Object)
    root = CreateObject("roSGNode", "ContentNode")
    row = root.CreateChild("ContentNode")

    thumbUrl = ""
    if item.backdrop <> invalid and item.backdrop <> "" then
        thumbUrl = item.backdrop
    else if item.poster <> invalid then
        thumbUrl = item.poster
    end if

    for ep = 1 to 12
        node = row.CreateChild("ContentNode")
        node.title = "Episódio " + ep.ToStr()
        if thumbUrl <> "" then node.hdPosterUrl = thumbUrl
        node.addFields({
            episodeNum: ep,
            episodeTitle: "Episódio " + ep.ToStr(),
            rawItem: item
        })
    end for
    m.episodesRowList.content = root
end sub

sub onEpisodeSelected()
    coords = m.episodesRowList.rowItemSelected
    col = coords[1]
    root = m.episodesRowList.content
    if root <> invalid and root.getChildCount() > 0 then
        row = root.getChild(0)
        if col < row.getChildCount() then
            epNode = row.getChild(col)
            m.top.playRequested = {
                title: m.top.item.title,
                letter: m.top.item.letter,
                year: m.top.item.year,
                season: 1,
                episode: epNode.episodeNum,
                episodeTitle: epNode.episodeTitle,
                isSeries: true
            }
        end if
    end if
end sub

sub updateButtonFocus()
    if m.focusedControl = "play" then
        m.playBtnBg.color = "#4FE3D0"
        m.playBtnText.color = "#0b0e14"
        m.resumeBtnBg.color = "#1e293b"
        m.resumeBtnText.color = "#FFFFFF"
    else if m.focusedControl = "resume" then
        m.playBtnBg.color = "#1e293b"
        m.playBtnText.color = "#FFFFFF"
        m.resumeBtnBg.color = "#4FE3D0"
        m.resumeBtnText.color = "#0b0e14"
    else if m.focusedControl = "episodes" then
        m.playBtnBg.color = "#1e293b"
        m.playBtnText.color = "#94a3b8"
        m.resumeBtnBg.color = "#1e293b"
        m.resumeBtnText.color = "#94a3b8"
        m.episodesRowList.setFocus(true)
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "down" then
        if (m.focusedControl = "play" or m.focusedControl = "resume") and m.seriesPanel.visible then
            m.focusedControl = "episodes"
            updateButtonFocus()
            return true
        end if
    else if key = "up" then
        if m.focusedControl = "episodes" then
            m.focusedControl = "play"
            updateButtonFocus()
            return true
        end if
    else if key = "left" then
        if m.focusedControl = "resume" then
            m.focusedControl = "play"
            updateButtonFocus()
            return true
        else if m.focusedControl = "play" then
            return false ' Bubbles to MainScene to open sidebar
        end if
    else if key = "right" then
        if m.focusedControl = "play" and m.resumeBtnGroup.visible then
            m.focusedControl = "resume"
            updateButtonFocus()
            return true
        end if
    else if key = "OK" then
        itemId = ""
        if m.top.item <> invalid and m.top.item.id <> invalid then itemId = m.top.item.id
        if m.focusedControl = "play" then
            m.top.playRequested = {
                title: m.top.item.title,
                letter: m.top.item.letter,
                year: m.top.item.year,
                resumePos: 0,
                isSeries: m.top.item.isSeries,
                id: itemId
            }
            return true
        else if m.focusedControl = "resume" then
            prog = GetVODProgress(m.top.item.title)
            resumePosition = 0
            if prog <> invalid then resumePosition = prog.position
            m.top.playRequested = {
                title: m.top.item.title,
                letter: m.top.item.letter,
                year: m.top.item.year,
                resumePos: resumePosition,
                isSeries: m.top.item.isSeries,
                id: itemId
            }
            return true
        end if
    end if

    return false
end function
