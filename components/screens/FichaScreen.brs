' ====================================================================
' Saimo TV - FichaScreen (BrightScript)
' Ficha completa com botões de ação (Assistir, Continuar, Versão, Fontes, Favoritar),
' Seletor dinâmico de temporadas + episódios TMDB/Addon e escolha de streams
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

    m.sourcesBtnGroup = m.top.findNode("sourcesBtnGroup")
    m.sourcesBtnBg = m.top.findNode("sourcesBtnBg")
    m.sourcesBtnText = m.top.findNode("sourcesBtnText")
    m.sourcesBtnBorder = m.top.findNode("sourcesBtnBorder")

    m.favBtnGroup = m.top.findNode("favBtnGroup")
    m.favBtnBg = m.top.findNode("favBtnBg")
    m.favBtnText = m.top.findNode("favBtnText")
    m.favBtnBorder = m.top.findNode("favBtnBorder")

    m.seriesPanel = m.top.findNode("seriesPanel")
    m.seasonsRowList = m.top.findNode("seasonsRowList")
    m.seasonsRowList.observeField("rowItemSelected", "onSeasonSelected")
    m.seasonsRowList.observeField("rowItemFocused", "onSeasonFocused")

    m.episodesRowList = m.top.findNode("episodesRowList")
    m.episodesRowList.observeField("rowItemSelected", "onEpisodeSelected")

    m.painelFontes = m.top.findNode("painelFontes")
    m.painelFontes.observeField("escolhido", "onFonteEscolhida")
    m.painelFontes.observeField("aberto", "onFontesAberto")

    m.debridDialog = m.top.findNode("debridDialog")
    m.debridDialogTitle = m.top.findNode("debridDialogTitle")
    m.debridDialogMsg = m.top.findNode("debridDialogMsg")

    m.focusedArea = "buttons" ' "buttons", "seasons", "episodes"
    m.focusedButton = 0 ' 0 = Play, 1 = Resume, 2 = Version, 3 = Fontes, 4 = Fav
    m.currentSeason = 1
    m.currentVersion = "dub"
    m.seasonsData = []
    m.isRebuildingSeasons = false
    m.episodesCacheBySeason = {}
    m.resolvedTmdbId = ""
    m.resolvedImdbId = ""
    m.resolvedRawId = ""
    m.hasExplicitGenres = false
    m.hasExplicitOverview = false
    m.metaTask = invalid
    m.sourcesTask = invalid
    m.fontesStreams = []
    m.fontesSubtitles = []
    m.pendingPlayReq = invalid

    m.top.observeField("focusedChild", "onFocusedChildChange")
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() and not m.painelFontes.aberto then
        updateFocusVisuals()
    end if
end sub

sub stopAsyncTasks()
    if m.metaTask <> invalid then
        m.metaTask.unobserveField("metadataResult")
        m.metaTask.control = "stop"
        m.metaTask = invalid
    end if
    if m.sourcesTask <> invalid then
        m.sourcesTask.unobserveField("resolvedItem")
        m.sourcesTask.control = "stop"
        m.sourcesTask = invalid
    end if
end sub

sub onItemChange()
    item = m.top.item
    if item = invalid then return

    stopAsyncTasks()
    m.debridDialog.visible = false
    m.painelFontes.aberto = false
    m.seasonsData = []
    m.episodesCacheBySeason = {}
    m.fontesStreams = []
    m.fontesSubtitles = []
    m.pendingPlayReq = invalid

    m.resolvedTmdbId = ""
    if item.tmdbId <> invalid then m.resolvedTmdbId = item.tmdbId.ToStr().Trim()
    m.resolvedImdbId = ""
    if item.imdbId <> invalid then m.resolvedImdbId = item.imdbId.ToStr().Trim()
    m.resolvedRawId = ""
    if item.rawId <> invalid then m.resolvedRawId = item.rawId.ToStr().Trim()

    m.titleLabel.text = item.title
    if item.poster <> invalid then m.posterNode.uri = item.poster
    if item.backdrop <> invalid and item.backdrop <> "" then
        m.backdropPoster.uri = item.backdrop
    else if item.poster <> invalid then
        m.backdropPoster.uri = item.poster
    end if

    tipo = "Filme"
    if item.isSeries then tipo = "Série"
    partes = [tipo]
    if item.year <> invalid and item.year <> "" then partes.Push(item.year)
    partes.Push("Full HD")
    m.metaLabel.text = partes.Join(" • ")

    if item.genres <> invalid and item.genres.ToStr().Trim() <> "" then
        m.genresLabel.text = item.genres
        m.hasExplicitGenres = true
    else
        m.genresLabel.text = "Ação, Aventura, Ficção"
        m.hasExplicitGenres = false
    end if

    if item.overview <> invalid and item.overview.ToStr().Trim() <> "" then
        m.overviewLabel.text = item.overview
        m.hasExplicitOverview = true
    else
        m.overviewLabel.text = "Disponível completo em alta resolução com opções de áudio e legendas."
        m.hasExplicitOverview = false
    end if

    ' Progresso salvo ("Continuar Assistindo")
    prog = GetVODProgress(item.title)
    if prog <> invalid and prog.position > 60 then
        m.resumeBtnGroup.visible = true
        minRemaining = Int(prog.position / 60)
        m.resumeBtnText.text = "Continuar (" + minRemaining.ToStr() + "m)"
        m.versionBtnGroup.translation = [552, 0]
        m.sourcesBtnGroup.translation = [858, 0]
        m.favBtnGroup.translation = [1094, 0]
    else
        m.resumeBtnGroup.visible = false
        m.versionBtnGroup.translation = [246, 0]
        m.sourcesBtnGroup.translation = [552, 0]
        m.favBtnGroup.translation = [788, 0]
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
        initSeason = 1
        if prog <> invalid and prog.season <> invalid and prog.season > 0 then
            initSeason = prog.season
        end if
        m.currentSeason = initSeason

        if item.seasons <> invalid and Type(item.seasons) = "roArray" and item.seasons.Count() > 0 then
            m.seasonsData = item.seasons
        else
            m.seasonsData = [
                { seasonNumber: 1, name: "Temporada 1", episodeCount: 16 },
                { seasonNumber: 2, name: "Temporada 2", episodeCount: 16 },
                { seasonNumber: 3, name: "Temporada 3", episodeCount: 16 }
            ]
        end if
        rebuildSeasonsRow()
        populatePlaceholderEpisodes(item, m.currentSeason)
    else
        m.seriesPanel.visible = false
    end if

    m.focusedArea = "buttons"
    m.focusedButton = 0
    updateFocusVisuals()

    ' Carrega metadados reais do TMDB (external_ids + temporadas + episódios) em segundo plano
    loadRichMetadata(m.currentSeason)
end sub

sub loadRichMetadata(seasonNum as Integer)
    item = m.top.item
    if item = invalid then return
    if m.metaTask <> invalid then
        m.metaTask.unobserveField("metadataResult")
        m.metaTask.control = "stop"
        m.metaTask = invalid
    end if

    metaReq = {}
    for each k in item
        metaReq[k] = item[k]
    end for
    if m.resolvedTmdbId <> "" then metaReq.tmdbId = m.resolvedTmdbId
    if m.resolvedImdbId <> "" then metaReq.imdbId = m.resolvedImdbId
    if m.resolvedRawId <> "" then metaReq.rawId = m.resolvedRawId

    m.metaTask = CreateObject("roSGNode", "FichaMetadataTask")
    m.metaTask.item = metaReq
    m.metaTask.seasonNumber = seasonNum
    m.metaTask.observeField("metadataResult", "onMetadataLoaded")
    m.metaTask.control = "run"
end sub

sub onMetadataLoaded(evt as Object)
    res = evt.getData()
    if m.metaTask <> invalid then
        m.metaTask.unobserveField("metadataResult")
        m.metaTask = invalid
    end if
    if res = invalid or m.top.item = invalid then return

    if res.tmdbId <> invalid and res.tmdbId <> "" then m.resolvedTmdbId = res.tmdbId
    if res.imdbId <> invalid and res.imdbId <> "" then m.resolvedImdbId = res.imdbId
    if res.rawId <> invalid and res.rawId <> "" then m.resolvedRawId = res.rawId

    if res.poster <> invalid and res.poster <> "" and m.posterNode.uri = "" then
        m.posterNode.uri = res.poster
    end if
    if res.backdrop <> invalid and res.backdrop <> "" and (m.top.item.backdrop = invalid or m.top.item.backdrop = "") then
        m.backdropPoster.uri = res.backdrop
    end if
    if not m.hasExplicitGenres and res.genres <> invalid and res.genres <> "" then
        m.genresLabel.text = res.genres
        m.hasExplicitGenres = true
    end if
    if not m.hasExplicitOverview and res.overview <> invalid and res.overview <> "" then
        m.overviewLabel.text = res.overview
        m.hasExplicitOverview = true
    end if

    tipo = "Filme"
    if m.top.item.isSeries then tipo = "Série"
    partes = [tipo]
    yr = ""
    if m.top.item.year <> invalid and m.top.item.year <> "" then yr = m.top.item.year.ToStr()
    if yr = "" and res.year <> invalid and res.year <> "" then yr = res.year.ToStr()
    if yr <> "" then partes.Push(yr)
    if res.rating <> invalid and res.rating <> "" then partes.Push("TMDB " + res.rating.ToStr())
    partes.Push("Full HD")
    m.metaLabel.text = partes.Join(" • ")

    if m.top.item.isSeries then
        seasonsChanged = false
        if res.seasons <> invalid and Type(res.seasons) = "roArray" and res.seasons.Count() > 0 then
            if m.seasonsData = invalid or m.seasonsData.Count() <> res.seasons.Count() then
                seasonsChanged = true
            else
                for i = 0 to res.seasons.Count() - 1
                    if m.seasonsData[i].seasonNumber <> res.seasons[i].seasonNumber then
                        seasonsChanged = true
                        exit for
                    end if
                end for
            end if
            m.seasonsData = res.seasons
        end if

        resSeason = res.seasonNumber
        if resSeason = invalid or resSeason <= 0 then resSeason = m.currentSeason

        if res.episodes <> invalid and Type(res.episodes) = "roArray" and res.episodes.Count() > 0 then
            m.episodesCacheBySeason[resSeason.ToStr()] = res.episodes
            if resSeason = m.currentSeason then
                populateRealEpisodes(m.top.item, m.currentSeason, res.episodes)
            end if
        end if

        if seasonsChanged then
            rebuildSeasonsRow()
        else
            updateSeasonsSelection(m.currentSeason)
        end if
    end if
end sub

function getSeasonIndex(seasonNum as Integer) as Integer
    if m.seasonsData = invalid then return 0
    for i = 0 to m.seasonsData.Count() - 1
        s = m.seasonsData[i]
        if s <> invalid and s.seasonNumber = seasonNum then return i
    end for
    return 0
end function

sub rebuildSeasonsRow()
    if m.seasonsData = invalid or m.seasonsData.Count() = 0 then return

    m.isRebuildingSeasons = true
    root = CreateObject("roSGNode", "ContentNode")
    row = root.CreateChild("ContentNode")
    for each s in m.seasonsData
        node = row.CreateChild("ContentNode")
        sn = 1
        if s.seasonNumber <> invalid then sn = s.seasonNumber
        sName = "Temporada " + sn.ToStr()
        if sn = 0 then sName = "Especiais"
        if s.name <> invalid and s.name <> "" then sName = s.name
        node.title = sName
        node.addFields({
            seasonNumber: sn,
            selecionada: (sn = m.currentSeason)
        })
    end for
    m.seasonsRowList.content = root

    curIdx = getSeasonIndex(m.currentSeason)
    m.seasonsRowList.jumpToRowItem = [0, curIdx]
    m.isRebuildingSeasons = false
end sub

sub updateSeasonsSelection(seasonNum as Integer)
    root = m.seasonsRowList.content
    if root <> invalid and root.getChildCount() > 0 then
        row = root.getChild(0)
        for i = 0 to row.getChildCount() - 1
            n = row.getChild(i)
            if n <> invalid then
                n.selecionada = (n.seasonNumber = seasonNum)
            end if
        end for
    end if
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

sub populatePlaceholderEpisodes(item as Object, seasonNum as Integer)
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
            rawVideoId: "",
            episodeCount: 0,
            rawItem: item
        })
    end for

    m.episodesRowList.content = root
end sub

sub populateRealEpisodes(item as Object, seasonNum as Integer, episodes as Object)
    root = CreateObject("roSGNode", "ContentNode")
    row = root.CreateChild("ContentNode")

    fallbackThumb = ""
    if item.backdrop <> invalid and item.backdrop <> "" then
        fallbackThumb = item.backdrop
    else if item.poster <> invalid then
        fallbackThumb = item.poster
    end if

    epCount = episodes.Count()
    for each ep in episodes
        epNum = 1
        if ep.episodeNumber <> invalid then epNum = ep.episodeNumber
        epName = "Episódio " + epNum.ToStr()
        if ep.name <> invalid and ep.name <> "" then epName = ep.name

        thumbUrl = fallbackThumb
        if ep.stillUrl <> invalid and ep.stillUrl <> "" then thumbUrl = ep.stillUrl

        node = row.CreateChild("ContentNode")
        node.title = epName
        if thumbUrl <> "" then node.hdPosterUrl = thumbUrl
        rawVid = ""
        if ep.rawVideoId <> invalid then rawVid = ep.rawVideoId.ToStr()
        node.addFields({
            seasonNum: seasonNum,
            episodeNum: epNum,
            episodeTitle: "T" + seasonNum.ToStr() + ":E" + epNum.ToStr() + " - " + epName,
            rawVideoId: rawVid,
            episodeCount: epCount,
            rawItem: item
        })
    end for

    m.episodesRowList.content = root
end sub

sub switchToSeason(seasonNum as Integer)
    if seasonNum = m.currentSeason then return
    m.currentSeason = seasonNum
    sk = seasonNum.ToStr()

    updateSeasonsSelection(seasonNum)

    if m.episodesCacheBySeason.DoesExist(sk) then
        populateRealEpisodes(m.top.item, seasonNum, m.episodesCacheBySeason[sk])
    else
        populatePlaceholderEpisodes(m.top.item, seasonNum)
        loadRichMetadata(seasonNum)
    end if
end sub

sub onSeasonFocused()
    if m.focusedArea <> "seasons" or m.isRebuildingSeasons = true then return
    coords = m.seasonsRowList.rowItemFocused
    if coords = invalid or coords.Count() < 2 then return
    col = coords[1]
    if col >= 0 and col < m.seasonsData.Count() then
        sn = m.seasonsData[col].seasonNumber
        if sn <> invalid and sn <> m.currentSeason then switchToSeason(sn)
    end if
end sub

sub onSeasonSelected()
    if m.isRebuildingSeasons = true then return
    coords = m.seasonsRowList.rowItemSelected
    if coords = invalid or coords.Count() < 2 then return
    col = coords[1]
    if col >= 0 and col < m.seasonsData.Count() then
        sn = m.seasonsData[col].seasonNumber
        if sn <> invalid then
            switchToSeason(sn)
            ' Ao confirmar temporada com OK, foca diretamente nos episódios da temporada
            m.focusedArea = "episodes"
            updateFocusVisuals()
        end if
    end if
end sub

sub updateFocusVisuals()
    isBtns = (m.focusedArea = "buttons")

    ' Limpa bordas de todos os botões
    m.playBtnBorder.visible = (isBtns and m.focusedButton = 0)
    m.resumeBtnBorder.visible = (isBtns and m.focusedButton = 1)
    m.versionBtnBorder.visible = (isBtns and m.focusedButton = 2)
    m.sourcesBtnBorder.visible = (isBtns and m.focusedButton = 3)
    m.favBtnBorder.visible = (isBtns and m.focusedButton = 4)

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
        m.sourcesBtnBg.blendColor = "#FFFFFF"
        m.sourcesBtnText.color = "#0b0e14"
    else
        m.sourcesBtnBg.blendColor = "#FFFFFF24"
        m.sourcesBtnText.color = "#FFFFFF"
    end if

    if isBtns and m.focusedButton = 4 then
        m.favBtnBg.blendColor = "#FFFFFF"
        m.favBtnText.color = "#0b0e14"
    else
        m.favBtnBg.blendColor = "#FFFFFF24"
        m.favBtnText.color = "#FFFFFF"
    end if

    if m.focusedArea = "episodes" then
        m.episodesRowList.setFocus(true)
    else if m.focusedArea = "seasons" then
        curIdx = getSeasonIndex(m.currentSeason)
        m.seasonsRowList.jumpToRowItem = [0, curIdx]
        m.seasonsRowList.setFocus(true)
    else
        m.top.setFocus(true)
    end if
end sub

function buildPlayRequestBase(seasonNum as Integer, epNum as Integer, epTitle as String, resumePos as Integer, rawVideoId = "" as String, epCount = 0 as Integer) as Object
    item = m.top.item
    itemId = ""
    if item <> invalid and item.id <> invalid then itemId = item.id
    req = {
        title: item.title,
        letter: item.letter,
        poster: item.poster,
        year: item.year,
        resumePos: resumePos,
        isSeries: item.isSeries,
        season: seasonNum,
        episode: epNum,
        episodeTitle: epTitle,
        id: itemId,
        tmdbId: m.resolvedTmdbId,
        imdbId: m.resolvedImdbId,
        rawId: m.resolvedRawId,
        rawVideoId: rawVideoId,
        episodeCount: epCount
    }
    return req
end function

sub onEpisodeSelected()
    coords = m.episodesRowList.rowItemSelected
    col = coords[1]
    root = m.episodesRowList.content
    if root <> invalid and root.getChildCount() > 0 then
        row = root.getChild(0)
        if col < row.getChildCount() then
            epNode = row.getChild(col)
            rawVid = ""
            if epNode.rawVideoId <> invalid then rawVid = epNode.rawVideoId
            epCnt = 0
            if epNode.episodeCount <> invalid then epCnt = epNode.episodeCount
            m.top.playRequested = buildPlayRequestBase(epNode.seasonNum, epNode.episodeNum, epNode.episodeTitle, 0, rawVid, epCnt)
        end if
    end if
end sub

sub openSourcesPicker(req as Object)
    m.pendingPlayReq = req
    if m.sourcesTask <> invalid then
        m.sourcesTask.unobserveField("resolvedItem")
        m.sourcesTask.control = "stop"
        m.sourcesTask = invalid
    end if

    m.painelFontes.titulo = "Fontes de Reprodução"
    m.painelFontes.ajuda = "Buscando links nas listas e Addons Stremio..."
    m.painelFontes.opcoes = [{ titulo: "Carregando fontes...", detalhe: "Aguarde alguns segundos" }]
    m.fontesStreams = []
    m.fontesSubtitles = []
    m.painelFontes.aberto = true

    m.sourcesTask = CreateObject("roSGNode", "StreamResolverTask")
    m.sourcesTask.requestItem = req
    m.sourcesTask.observeField("resolvedItem", "onSourcesResolved")
    m.sourcesTask.control = "run"
end sub

sub onSourcesResolved(evt as Object)
    res = evt.getData()
    if m.sourcesTask <> invalid then
        m.sourcesTask.unobserveField("resolvedItem")
        m.sourcesTask = invalid
    end if

    m.fontesStreams = []
    m.fontesSubtitles = []
    opcoes = []

    if res <> invalid then
        if res.subtitles <> invalid and Type(res.subtitles) = "roArray" then
            m.fontesSubtitles = res.subtitles
        end if
        if res.tmdbId <> invalid and res.tmdbId <> "" then m.resolvedTmdbId = res.tmdbId
        if res.imdbId <> invalid and res.imdbId <> "" then m.resolvedImdbId = res.imdbId
        if res.candidateStreams <> invalid and Type(res.candidateStreams) = "roArray" then
            m.fontesStreams = res.candidateStreams
        end if
    end if

    for each st in m.fontesStreams
        tLabel = "Fonte"
        if st.title <> invalid and st.title <> "" then tLabel = st.title
        dLabel = ""
        if st.detail <> invalid then dLabel = st.detail
        opcoes.Push({ titulo: tLabel, detalhe: dLabel })
    end for

    if opcoes.Count() = 0 then
        opcoes.Push({
            titulo: "Nenhuma fonte encontrada",
            detalhe: "Adicione uma lista VOD ou Addons Stremio em Ajustes > Addons e Debrid"
        })
    end if

    subInfo = ""
    if m.fontesSubtitles.Count() > 0 then
        subInfo = " · " + m.fontesSubtitles.Count().ToStr() + " legenda(s) externa(s)"
    end if
    m.painelFontes.ajuda = opcoes.Count().ToStr() + " fonte(s) encontrada(s)" + subInfo
    m.painelFontes.opcoes = opcoes
end sub

sub onFonteEscolhida()
    idx = m.painelFontes.escolhido
    if idx < 0 or idx >= m.fontesStreams.Count() then
        m.painelFontes.aberto = false
        return
    end if

    chosen = m.fontesStreams[idx]
    if chosen.isTorrent = true and (chosen.url = invalid or chosen.url = "") and not HasAnyDebridConfigured() then
        m.painelFontes.aberto = false
        m.debridDialogTitle.text = "Requer conta Debrid para Torrent"
        m.debridDialogMsg.text = "Este stream é um torrent (infoHash). Configure TorBox, Real-Debrid, AllDebrid ou Premiumize em Ajustes > Addons e Debrid (ou pelo QR Code em /addons) para reproduzir torrents."
        m.debridDialog.visible = true
        m.top.setFocus(true)
        return
    end if

    m.painelFontes.aberto = false
    if m.pendingPlayReq <> invalid then
        req = m.pendingPlayReq
        req.directStream = chosen
        req.fallbackStreams = m.fontesStreams
        req.extraSubtitles = m.fontesSubtitles
        if m.resolvedTmdbId <> "" then req.tmdbId = m.resolvedTmdbId
        if m.resolvedImdbId <> "" then req.imdbId = m.resolvedImdbId
        m.top.playRequested = req
    end if
end sub

sub onFontesAberto()
    if not m.painelFontes.aberto then
        updateFocusVisuals()
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.debridDialog <> invalid and m.debridDialog.visible then
        if key = "OK" or key = "back" then
            m.debridDialog.visible = false
            updateFocusVisuals()
            return true
        end if
        return true
    end if

    if m.painelFontes.aberto then return false

    ' 1. Foco na linha de botões superiores
    if m.focusedArea = "buttons" then
        if key = "right" then
            if m.focusedButton < 4 then
                m.focusedButton = m.focusedButton + 1
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

    ' 2. Foco no seletor de temporadas dinâmico
    else if m.focusedArea = "seasons" then
        if key = "down" then
            coords = m.seasonsRowList.rowItemFocused
            if coords <> invalid and coords.Count() >= 2 then
                col = coords[1]
                if col >= 0 and col < m.seasonsData.Count() then
                    sn = m.seasonsData[col].seasonNumber
                    if sn <> invalid and sn <> m.currentSeason then switchToSeason(sn)
                end if
            end if
            m.focusedArea = "episodes"
            updateFocusVisuals()
            return true
        else if key = "up" then
            m.focusedArea = "buttons"
            updateFocusVisuals()
            return true
        else if key = "back" then
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
        else if key = "options" then
            coords = m.episodesRowList.rowItemFocused
            if coords <> invalid and coords.Count() >= 2 then
                root = m.episodesRowList.content
                if root <> invalid and root.getChildCount() > 0 then
                    row = root.getChild(0)
                    col = coords[1]
                    if col >= 0 and col < row.getChildCount() then
                        epNode = row.getChild(col)
                        rawVid = ""
                        if epNode.rawVideoId <> invalid then rawVid = epNode.rawVideoId
                        epCnt = 0
                        if epNode.episodeCount <> invalid then epCnt = epNode.episodeCount
                        openSourcesPicker(buildPlayRequestBase(epNode.seasonNum, epNode.episodeNum, epNode.episodeTitle, 0, rawVid, epCnt))
                        return true
                    end if
                end if
            end if
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

    epCnt = 0
    sk = m.currentSeason.ToStr()
    if m.episodesCacheBySeason.DoesExist(sk) then epCnt = m.episodesCacheBySeason[sk].Count()

    if m.focusedButton = 0 then
        ' Assistir do início
        ep1Title = ""
        if item.isSeries then ep1Title = "T" + m.currentSeason.ToStr() + ":E1 - Episódio 1"
        m.top.playRequested = buildPlayRequestBase(m.currentSeason, 1, ep1Title, 0, "", epCnt)
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
        m.top.playRequested = buildPlayRequestBase(resSeason, resEp, "", resPos, "", epCnt)
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
        ' Fontes (abre PainelLateral com streams locais + Addons + Debrid)
        reqEp = 1
        reqSeason = m.currentSeason
        if item.isSeries then
            prog = GetVODProgress(item.title)
            if prog <> invalid and prog.episode <> invalid and prog.episode > 0 then
                reqEp = prog.episode
                if prog.season <> invalid and prog.season > 0 then reqSeason = prog.season
            end if
        end if
        openSourcesPicker(buildPlayRequestBase(reqSeason, reqEp, "", 0, "", epCnt))
    else if m.focusedButton = 4 then
        ' Favoritar / Desfavoritar
        ToggleFavoriteVOD(item)
        updateFavButtonText()
    end if
end sub

sub cleanUp()
    stopAsyncTasks()
end sub
