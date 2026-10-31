' ====================================================================
' Saimo TV - FichaScreen (BrightScript)
' Ficha completa com botões de ação (Assistir, Versão, Favoritar),
' Seletor de temporadas e grade de episódios (estilo TV Box)
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
    m.playBtnBorder = m.top.findNode("playBtnBorder")

    m.resumeBtnGroup = m.top.findNode("resumeBtnGroup")
    m.resumeBtnBg = m.top.findNode("resumeBtnBg")
    m.resumeBtnText = m.top.findNode("resumeBtnText")
    m.resumeBtnBorder = m.top.findNode("resumeBtnBorder")

    m.versionBtnGroup = m.top.findNode("versionBtnGroup")
    m.versionBtnBg = m.top.findNode("versionBtnBg")
    m.versionBtnText = m.top.findNode("versionBtnText")
    m.versionBtnBorder = m.top.findNode("versionBtnBorder")

    m.favBtnGroup = m.top.findNode("favBtnGroup")
    m.favBtnBg = m.top.findNode("favBtnBg")
    m.favBtnText = m.top.findNode("favBtnText")
    m.favBtnBorder = m.top.findNode("favBtnBorder")

    m.seriesPanel = m.top.findNode("seriesPanel")
    m.episodesRowList = m.top.findNode("episodesRowList")
    m.episodesRowList.observeField("rowItemSelected", "onEpisodeSelected")

    m.focusedArea = "buttons" ' "buttons", "seasons", "episodes"
    m.focusedButton = 0 ' 0 = Play, 1 = Resume, 2 = Version, 3 = Fav
    m.currentSeason = 1
    m.currentVersion = "dub"

    m.top.observeField("focusedChild", "onFocusedChildChange")
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() then
        updateFocusVisuals()
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
    tipo = "Filme"
    if item.isSeries then tipo = "Série"
    m.metaLabel.text = tipo + " • " + year + " • Full HD • Classificação Livre"

    if item.genres <> invalid then
        m.genresLabel.text = item.genres
    else
        m.genresLabel.text = "Ação, Aventura, Ficção"
    end if

    if item.overview <> invalid and item.overview <> "" then
        m.overviewLabel.text = item.overview
    else
        m.overviewLabel.text = "Disponível completo em alta resolução com opções de áudio e legendas."
    end if

    ' Progresso salvo ("Continuar Assistindo")
    prog = GetVODProgress(item.title)
    if prog <> invalid and prog.position > 60 then
        m.resumeBtnGroup.visible = true
        minRemaining = Int(prog.position / 60)
        m.resumeBtnText.text = "Continuar (" + minRemaining.ToStr() + "m)"
    else
        m.resumeBtnGroup.visible = false
    end if

    ' Atualiza texto do botão Favoritar
    updateFavButtonText()

    ' Preferência de versão de áudio
    prefs = LoadPreferences()
    if prefs <> invalid and prefs.versaoAudio <> invalid then
        m.currentVersion = prefs.versaoAudio
    end if
    updateVersionButtonText()

    ' Se for série, exibe temporadas e episódios
    if item.isSeries then
        m.seriesPanel.visible = true
        m.currentSeason = 1
        populateEpisodes(item, 1)
        updateSeasonTabsVisuals()
    else
        m.seriesPanel.visible = false
    end if

    m.focusedArea = "buttons"
    m.focusedButton = 0
    updateFocusVisuals()
end sub

sub updateFavButtonText()
    if m.top.item = invalid then return
    if IsVODFavorite(m.top.item.title) then
        m.favBtnText.text = "Nos favoritos"
    else
        m.favBtnText.text = "Favoritar"
    end if
end sub

sub updateVersionButtonText()
    if m.currentVersion = "leg" then
        m.versionBtnText.text = "Versão: Legendado"
    else
        m.versionBtnText.text = "Versão: Dublado"
    end if
end sub

sub populateEpisodes(item as Object, seasonNum as Integer)
    root = CreateObject("roSGNode", "ContentNode")
    row = root.CreateChild("ContentNode")

    thumbUrl = ""
    if item.backdrop <> invalid and item.backdrop <> "" then
        thumbUrl = item.backdrop
    else if item.poster <> invalid then
        thumbUrl = item.poster
    end if

    for ep = 1 to 16
        node = row.CreateChild("ContentNode")
        node.title = "Episódio " + ep.ToStr()
        if thumbUrl <> "" then node.hdPosterUrl = thumbUrl
        node.addFields({
            seasonNum: seasonNum,
            episodeNum: ep,
            episodeTitle: "T" + seasonNum.ToStr() + ":E" + ep.ToStr() + " - Episódio " + ep.ToStr(),
            rawItem: item
        })
    end for

    m.episodesRowList.content = root
end sub

sub updateSeasonTabsVisuals()
    for s = 1 to 3
        bg = m.top.findNode("seasonBg_" + s.ToStr())
        txt = m.top.findNode("seasonText_" + s.ToStr())
        border = m.top.findNode("seasonBorder_" + s.ToStr())

        if bg <> invalid and txt <> invalid then
            if s = m.currentSeason then
                bg.blendColor = "#FFFFFF"
                txt.color = "#0b0e14"
                if border <> invalid then border.visible = (m.focusedArea = "seasons")
            else
                bg.blendColor = "#FFFFFF24"
                txt.color = "#FFFFFF"
                if border <> invalid then border.visible = false
            end if
        end if
    end for
end sub

sub updateFocusVisuals()
    isBtns = (m.focusedArea = "buttons")

    ' Limpa bordas de todos os botões
    m.playBtnBorder.visible = (isBtns and m.focusedButton = 0)
    m.resumeBtnBorder.visible = (isBtns and m.focusedButton = 1)
    m.versionBtnBorder.visible = (isBtns and m.focusedButton = 2)
    m.favBtnBorder.visible = (isBtns and m.focusedButton = 3)

    ' Cores de destaque nos botões
    if isBtns and m.focusedButton = 0 then
        m.playBtnBg.blendColor = "#FFFFFF"
        m.playBtnText.color = "#0b0e14"
    else
        m.playBtnBg.blendColor = "#FFFFFF24"
        m.playBtnText.color = "#FFFFFF"
    end if

    if isBtns and m.focusedButton = 1 then
        m.resumeBtnBg.blendColor = "#FFFFFF"
        m.resumeBtnText.color = "#0b0e14"
    else
        m.resumeBtnBg.blendColor = "#FFFFFF24"
        m.resumeBtnText.color = "#FFFFFF"
    end if

    if isBtns and m.focusedButton = 2 then
        m.versionBtnBg.blendColor = "#FFFFFF"
        m.versionBtnText.color = "#0b0e14"
    else
        m.versionBtnBg.blendColor = "#FFFFFF24"
        m.versionBtnText.color = "#FFFFFF"
    end if

    if isBtns and m.focusedButton = 3 then
        m.favBtnBg.blendColor = "#FFFFFF"
        m.favBtnText.color = "#0b0e14"
    else
        m.favBtnBg.blendColor = "#FFFFFF24"
        m.favBtnText.color = "#FFFFFF"
    end if

    updateSeasonTabsVisuals()

    if m.focusedArea = "episodes" then
        m.episodesRowList.setFocus(true)
    else
        m.top.setFocus(true)
    end if
end sub

sub onEpisodeSelected()
    coords = m.episodesRowList.rowItemSelected
    col = coords[1]
    root = m.episodesRowList.content
    if root <> invalid and root.getChildCount() > 0 then
        row = root.getChild(0)
        if col < row.getChildCount() then
            epNode = row.getChild(col)
            itemId = ""
            if m.top.item <> invalid and m.top.item.id <> invalid then itemId = m.top.item.id

            m.top.playRequested = {
                title: m.top.item.title,
                letter: m.top.item.letter,
                year: m.top.item.year,
                season: epNode.seasonNum,
                episode: epNode.episodeNum,
                episodeTitle: epNode.episodeTitle,
                isSeries: true,
                id: itemId
            }
        end if
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    ' 1. Foco na linha de botões superiores
    if m.focusedArea = "buttons" then
        if key = "right" then
            if m.focusedButton < 3 then
                m.focusedButton = m.focusedButton + 1
                ' Se pulou para resume mas resume está oculto
                if m.focusedButton = 1 and not m.resumeBtnGroup.visible then
                    m.focusedButton = 2
                end if
                updateFocusVisuals()
                return true
            end if
        else if key = "left" then
            if m.focusedButton > 0 then
                m.focusedButton = m.focusedButton - 1
                if m.focusedButton = 1 and not m.resumeBtnGroup.visible then
                    m.focusedButton = 0
                end if
                updateFocusVisuals()
                return true
            end if
        else if key = "down" then
            if m.seriesPanel.visible then
                m.focusedArea = "seasons"
                updateFocusVisuals()
                return true
            end if
        else if key = "up" then
            m.top.focusUpRequested = true
            return true
        else if key = "OK" then
            handleButtonClick()
            return true
        end if

    ' 2. Foco no seletor de temporadas
    else if m.focusedArea = "seasons" then
        if key = "right" then
            if m.currentSeason < 3 then
                m.currentSeason = m.currentSeason + 1
                populateEpisodes(m.top.item, m.currentSeason)
                updateSeasonTabsVisuals()
                return true
            end if
        else if key = "left" then
            if m.currentSeason > 1 then
                m.currentSeason = m.currentSeason - 1
                populateEpisodes(m.top.item, m.currentSeason)
                updateSeasonTabsVisuals()
                return true
            end if
        else if key = "down" then
            m.focusedArea = "episodes"
            updateFocusVisuals()
            return true
        else if key = "up" then
            m.focusedArea = "buttons"
            updateFocusVisuals()
            return true
        end if

    ' 3. Foco na grade de episódios
    else if m.focusedArea = "episodes" then
        if key = "up" then
            m.focusedArea = "seasons"
            updateFocusVisuals()
            return true
        else if key = "back" then
            m.focusedArea = "buttons"
            updateFocusVisuals()
            return true
        end if
    end if

    return false
end function

sub handleButtonClick()
    item = m.top.item
    if item = invalid then return

    itemId = ""
    if item.id <> invalid then itemId = item.id

    if m.focusedButton = 0 then
        ' Assistir do início
        m.top.playRequested = {
            title: item.title,
            letter: item.letter,
            year: item.year,
            resumePos: 0,
            isSeries: item.isSeries,
            season: 1,
            episode: 1,
            id: itemId
        }
    else if m.focusedButton = 1 then
        ' Continuar de onde parou
        prog = GetVODProgress(item.title)
        resPos = 0
        resSeason = 1
        resEp = 1
        if prog <> invalid then
            if prog.position <> invalid then resPos = prog.position
            if prog.season <> invalid and prog.season > 0 then resSeason = prog.season
            if prog.episode <> invalid and prog.episode > 0 then resEp = prog.episode
        end if
        m.top.playRequested = {
            title: item.title,
            letter: item.letter,
            year: item.year,
            resumePos: resPos,
            isSeries: item.isSeries,
            season: resSeason,
            episode: resEp,
            id: itemId
        }
    else if m.focusedButton = 2 then
        ' Alternar Versão (Dublado / Legendado)
        if m.currentVersion = "dub" then
            m.currentVersion = "leg"
        else
            m.currentVersion = "dub"
        end if
        updateVersionButtonText()
        prefs = LoadPreferences()
        prefs.versaoAudio = m.currentVersion
        SavePreferences(prefs)
    else if m.focusedButton = 3 then
        ' Favoritar / Desfavoritar
        ToggleFavoriteVOD(item)
        updateFavButtonText()
    end if
end sub
