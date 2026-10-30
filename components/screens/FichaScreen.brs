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
    m.resumeBtnBg = m.top.findNode("resumeBtnBg")
    m.resumeBtnText = m.top.findNode("resumeBtnText")
    m.seriesPanel = m.top.findNode("seriesPanel")
    m.episodesRowList = m.top.findNode("episodesRowList")
    m.episodesRowList.observeField("rowItemSelected", "onEpisodeSelected")
    m.focusedControl = "play" ' "play", "resume", "episodes"
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
    m.metaLabel.text = year + " • Full HD • ★ 8.4"

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
        m.resumeBtnBg.visible = true
        m.resumeBtnText.visible = true
        minRemaining = Int(prog.position / 60)
        m.resumeBtnText.text = "↺ Continuar (" + minRemaining.ToStr() + "m)"
    else
        m.resumeBtnBg.visible = false
        m.resumeBtnText.visible = false
    end if

    ' Se for série, exibe grade de episódios
    if item.isSeries then
        m.seriesPanel.visible = true
        populateEpisodes(item)
    else
        m.seriesPanel.visible = false
    end if
end sub

sub populateEpisodes(item as Object)
    root = CreateObject("roSGNode", "ContentNode")
    row = root.CreateChild("ContentNode")
    ' Popula episódios padrão
    for ep = 1 to 12
        node = row.CreateChild("ContentNode")
        node.title = "Episódio " + ep.ToStr()
        if item.poster <> invalid then node.hdPosterUrl = item.poster
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
                episode: epNode.episodeNum,
                episodeTitle: epNode.episodeTitle,
                isSeries: true
            }
        end if
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "down" then
        if m.focusedControl = "play" or m.focusedControl = "resume" then
            if m.seriesPanel.visible then
                m.focusedControl = "episodes"
                m.episodesRowList.setFocus(true)
                return true
            end if
        end if
    else if key = "up" then
        if m.focusedControl = "episodes" then
            m.focusedControl = "play"
            m.playBtnBg.color = "#4FE3D0"
            return true
        end if
    else if key = "left" then
        if m.focusedControl = "resume" then
            m.focusedControl = "play"
            m.playBtnBg.color = "#4FE3D0"
            m.resumeBtnBg.color = "#1e293b"
            return true
        end if
    else if key = "right" then
        if m.focusedControl = "play" and m.resumeBtnBg.visible then
            m.focusedControl = "resume"
            m.playBtnBg.color = "#1e293b"
            m.resumeBtnBg.color = "#4FE3D0"
            return true
        end if
    else if key = "OK" then
        if m.focusedControl = "play" then
            m.top.playRequested = {
                title: m.top.item.title,
                resumePos: 0,
                isSeries: m.top.item.isSeries
            }
            return true
        else if m.focusedControl = "resume" then
            prog = GetVODProgress(m.top.item.title)
            resumePosition = 0
            if prog <> invalid then resumePosition = prog.position
            m.top.playRequested = {
                title: m.top.item.title,
                resumePos: resumePosition,
                isSeries: m.top.item.isSeries
            }
            return true
        end if
    end if

    return false
end function
