' ====================================================================
' Saimo TV - PlayerScreen (BrightScript)
' Player nativo de VOD, controle de progresso, fallbacks e proxy
' ====================================================================

sub init()
    m.videoPlayer = m.top.findNode("videoPlayer")
    m.bufferingGroup = m.top.findNode("bufferingGroup")
    m.loadingLabel = m.top.findNode("loadingLabel")
    m.errorGroup = m.top.findNode("errorGroup")
    m.errorLabel = m.top.findNode("errorLabel")
    m.debridDialog = m.top.findNode("debridDialog")
    m.debridDialogTitle = m.top.findNode("debridDialogTitle")
    m.debridDialogMsg = m.top.findNode("debridDialogMsg")
    m.playerOsd = m.top.findNode("playerOsd")
    m.progressTimer = m.top.findNode("progressTimer")

    m.candidateUrls = []
    m.candidateStreams = []
    m.addonSubtitles = []
    m.currentExternalSubtitles = []
    m.activeStream = invalid
    m.activeBingeGroup = ""
    m.candidateIdx = 0
    m.tryingProxy = false
    m.manualStreamChoice = false
    m.autoSubtitleApplied = false
    m.debridDialogExitOnClose = false
    m.lastDebridError = ""
    m.resumePos = 0
    m.encerrado = false
    m.trocandoStream = false
    m.debridTask = invalid

    m.videoPlayer.observeField("state", "onVideoState")
    m.videoPlayer.observeField("position", "onVideoPosition")
    m.videoPlayer.observeField("duration", "onVideoDuration")
    m.progressTimer.observeField("fire", "saveCurrentProgress")

    m.playerOsd.observeField("playPauseRequested", "onOsdPlayPause")
    m.playerOsd.observeField("seekRequested", "onOsdSeek")
    m.playerOsd.observeField("skipIntroRequested", "onOsdSkipIntro")
    m.top.findNode("painelOpcoes").observeField("escolhido", "onOpcaoEscolhida")
    m.top.findNode("painelOpcoes").observeField("aberto", "onOpcoesAberto")
end sub

sub onPlayItemChange()
    if m.encerrado = true then return
    item = m.top.playItem
    if item = invalid then return

    m.errorGroup.visible = false
    m.debridDialog.visible = false
    m.debridDialogExitOnClose = false
    m.lastDebridError = ""
    m.loadingLabel.text = "Carregando vídeo..."
    m.bufferingGroup.visible = true

    m.playerOsd.title = item.title
    if item.isSeries then
        epTitle = "Episódio 1"
        if item.episodeTitle <> invalid and item.episodeTitle <> "" then
            epTitle = item.episodeTitle
        else if item.episode <> invalid then
            epTitle = "Episódio " + item.episode.ToStr()
        end if
        seasonNum = 1
        if item.season <> invalid and item.season > 0 then seasonNum = item.season
        m.playerOsd.subtitle = "Temporada " + seasonNum.ToStr() + " • " + epTitle
        m.playerOsd.isSeries = true
    else
        m.playerOsd.subtitle = "Filme • Full HD"
        m.playerOsd.isSeries = false
    end if

    m.candidateUrls = []
    m.candidateStreams = []
    m.addonSubtitles = []
    m.currentExternalSubtitles = []
    m.activeStream = invalid
    m.candidateIdx = 0
    m.tryingProxy = false
    m.manualStreamChoice = false
    m.autoSubtitleApplied = false
    m.resumePos = 0
    if item.resumePos <> invalid then m.resumePos = item.resumePos
    if item.extraSubtitles <> invalid and Type(item.extraSubtitles) = "roArray" then
        m.addonSubtitles = item.extraSubtitles
    end if

    ' 1. Fonte escolhida diretamente na tela de Fontes (FichaScreen)
    if item.directStream <> invalid and Type(item.directStream) = "roAssociativeArray" then
        streamsList = [item.directStream]
        if item.fallbackStreams <> invalid and Type(item.fallbackStreams) = "roArray" then
            for each fb in item.fallbackStreams
                if fb <> invalid and fb <> item.directStream then
                    if fb.url <> item.directStream.url or fb.infoHash <> item.directStream.infoHash then
                        streamsList.Push(fb)
                    end if
                end if
            end for
        end if
        syncCandidateLists(streamsList)
        m.manualStreamChoice = true
        playCandidate(0, false)
        return
    end if

    ' 2. Se já tem URL direta, toca imediatamente
    if item.url <> invalid and item.url <> "" then
        hdrs = []
        if item.httpHeadersArray <> invalid and Type(item.httpHeadersArray) = "roArray" then hdrs = item.httpHeadersArray
        subs = []
        if item.subtitles <> invalid and Type(item.subtitles) = "roArray" then subs = item.subtitles
        bg = ""
        if item.bingeGroup <> invalid then bg = item.bingeGroup.ToStr()
        directObj = {
            sourceKind: "direct",
            title: "Fonte Direta",
            detail: "",
            url: item.url,
            infoHash: "",
            isTorrent: false,
            streamFormat: "",
            bingeGroup: bg,
            httpHeadersArray: hdrs,
            subtitles: subs
        }
        syncCandidateLists([directObj])
        playCandidate(0, false)
    else
        if m.resolverTask <> invalid then
            m.resolverTask.unobserveField("resolvedItem")
            m.resolverTask.control = "stop"
        end if
        ' Resolve a URL usando StreamResolverTask (local + Addons + bridge ID)
        m.resolverTask = CreateObject("roSGNode", "StreamResolverTask")
        m.resolverTask.requestItem = item
        m.resolverTask.observeField("resolvedItem", "onStreamResolved")
        m.resolverTask.control = "run"
    end if
end sub

sub syncCandidateLists(streams as Object)
    m.candidateStreams = []
    m.candidateUrls = []
    if streams = invalid then return
    for each s in streams
        if s <> invalid then
            m.candidateStreams.Push(s)
            u = ""
            if s.url <> invalid then u = s.url.ToStr()
            m.candidateUrls.Push(u)
        end if
    end for
end sub

sub onStreamResolved(evt as Object)
    if m.encerrado = true then return
    resolved = evt.getData()
    if resolved <> invalid then
        if resolved.subtitles <> invalid and Type(resolved.subtitles) = "roArray" then
            m.addonSubtitles = resolved.subtitles
        end if
        if resolved.resumePos <> invalid then m.resumePos = resolved.resumePos

        ' Atualiza IDs resolvidos no playItem para próximos episódios
        item = m.top.playItem
        if item <> invalid then
            if resolved.tmdbId <> invalid and resolved.tmdbId <> "" then item.tmdbId = resolved.tmdbId
            if resolved.imdbId <> invalid and resolved.imdbId <> "" then item.imdbId = resolved.imdbId
        end if

        if resolved.candidateStreams <> invalid and Type(resolved.candidateStreams) = "roArray" and resolved.candidateStreams.Count() > 0 then
            syncCandidateLists(resolved.candidateStreams)
            m.candidateIdx = 0
            m.tryingProxy = false
            playCandidate(0, false)
            return
        else if resolved.candidateUrls <> invalid and resolved.candidateUrls.Count() > 0 then
            wrapped = []
            for idx = 0 to resolved.candidateUrls.Count() - 1
                wrapped.Push({
                    sourceKind: "local",
                    title: "Fonte " + (idx + 1).ToStr(),
                    detail: "",
                    url: resolved.candidateUrls[idx],
                    infoHash: "",
                    isTorrent: false,
                    streamFormat: "",
                    bingeGroup: "",
                    httpHeadersArray: [],
                    subtitles: []
                })
            end for
            syncCandidateLists(wrapped)
            m.candidateIdx = 0
            m.tryingProxy = false
            playCandidate(0, false)
            return
        else if resolved.url <> invalid and resolved.url <> "" then
            syncCandidateLists([{
                sourceKind: "local",
                title: "Fonte 1",
                detail: "",
                url: resolved.url,
                infoHash: "",
                isTorrent: false,
                streamFormat: "",
                bingeGroup: "",
                httpHeadersArray: [],
                subtitles: []
            }])
            m.candidateIdx = 0
            m.tryingProxy = false
            playCandidate(0, false)
            return
        end if
    end if

    m.bufferingGroup.visible = false
    m.errorLabel.text = "Vídeo indisponível no momento"
    m.errorGroup.visible = true
end sub

sub showDebridDialog(titleText as String, msgText as String, exitOnClose as Boolean)
    m.bufferingGroup.visible = false
    m.errorGroup.visible = false
    m.debridDialogTitle.text = titleText
    m.debridDialogMsg.text = msgText
    m.debridDialogExitOnClose = exitOnClose
    m.debridDialog.visible = true
    m.top.setFocus(true)
end sub

function anyHttpStreamAvailable() as Boolean
    if m.candidateStreams = invalid then return false
    for each s in m.candidateStreams
        if s <> invalid and s.url <> invalid and s.url <> "" then return true
    end for
    return false
end function

sub playCandidate(idx as Integer, useProxy as Boolean)
    if m.encerrado = true or m.videoPlayer = invalid then return
    if m.candidateStreams = invalid or idx < 0 or idx >= m.candidateStreams.Count() then
        m.bufferingGroup.visible = false
        if m.lastDebridError <> "" then
            m.errorLabel.text = m.lastDebridError
        else
            m.errorLabel.text = "Vídeo indisponível no momento"
        end if
        m.errorGroup.visible = true
        return
    end if

    streamObj = m.candidateStreams[idx]
    if streamObj = invalid then
        tryNextCandidate()
        return
    end if

    rawUrl = ""
    if streamObj.url <> invalid then rawUrl = streamObj.url.ToStr().Trim()

    ' Stream torrent via infoHash ainda não resolvido em HTTP
    if rawUrl = "" and streamObj.isTorrent = true and streamObj.infoHash <> invalid and streamObj.infoHash <> "" then
        if not HasAnyDebridConfigured() then
            if m.manualStreamChoice or (not anyHttpStreamAvailable()) then
                showDebridDialog(
                    "Requer conta Debrid para Torrent",
                    "Este stream é um torrent (infoHash). Configure TorBox, Real-Debrid, AllDebrid ou Premiumize em Ajustes > Addons e Debrid (ou pelo QR Code em /addons) para reproduzir torrents no Roku.",
                    (not anyHttpStreamAvailable() and m.activeStream = invalid)
                )
            else
                m.candidateIdx = idx
                tryNextCandidate()
            end if
            return
        end if

        if m.debridTask <> invalid then
            m.debridTask.unobserveField("result")
            m.debridTask.control = "stop"
            m.debridTask = invalid
        end if
        m.candidateIdx = idx
        m.loadingLabel.text = "Resolvendo torrent via Debrid..."
        m.errorGroup.visible = false
        m.bufferingGroup.visible = true
        m.debridTask = CreateObject("roSGNode", "DebridResolveTask")
        m.debridTask.streamInfo = {
            infoHash: streamObj.infoHash,
            fileIdx: streamObj.fileIdx,
            sources: streamObj.sources
        }
        m.debridTask.observeField("result", "onDebridResolved")
        m.debridTask.control = "run"
        return
    end if

    if rawUrl = "" then
        m.candidateIdx = idx
        tryNextCandidate()
        return
    end if

    playUrl = rawUrl
    isTxt = (Instr(1, LCase(rawUrl), ".txt") > 0)

    ' Se está no modo proxy ou é .txt e ainda não está com api/proxy
    if (useProxy or isTxt) and Instr(1, playUrl, "api/proxy") = 0 then
        ut = CreateObject("roUrlTransfer")
        playUrl = "https://saimo-tv.pages.dev/api/proxy?url=" + ut.Escape(rawUrl)
    end if

    startPlayback(playUrl, m.resumePos, streamObj)
end sub

sub onDebridResolved(evt as Object)
    if m.encerrado = true then return
    res = evt.getData()
    if m.debridTask <> invalid then
        m.debridTask.unobserveField("result")
        m.debridTask = invalid
    end if

    m.loadingLabel.text = "Carregando vídeo..."

    if res <> invalid and res.ok = true and res.url <> invalid and res.url <> "" then
        if m.candidateIdx >= 0 and m.candidateIdx < m.candidateStreams.Count() then
            m.candidateStreams[m.candidateIdx].url = res.url
            m.candidateUrls[m.candidateIdx] = res.url
            startPlayback(res.url, m.resumePos, m.candidateStreams[m.candidateIdx])
            return
        end if
    end if

    errMsg = "Falha ao resolver torrent no Debrid."
    if res <> invalid and res.error <> invalid and res.error <> "" then errMsg = res.error

    if res <> invalid and res.needsConfig = true then
        if m.manualStreamChoice or (not anyHttpStreamAvailable()) then
            showDebridDialog("Requer conta Debrid para Torrent", errMsg, (not anyHttpStreamAvailable() and m.activeStream = invalid))
            return
        end if
    end if

    m.lastDebridError = errMsg
    if m.manualStreamChoice then
        m.manualStreamChoice = false
        showDebridDialog("Erro ao resolver Debrid", errMsg, (m.activeStream = invalid and m.candidateIdx >= m.candidateStreams.Count() - 1))
        return
    end if
    tryNextCandidate()
end sub

sub tryNextCandidate()
    if m.encerrado = true or m.videoPlayer = invalid then return
    if m.candidateStreams = invalid or m.candidateStreams.Count() = 0 then
        m.bufferingGroup.visible = false
        m.errorLabel.text = "Falha ao reproduzir o vídeo"
        m.errorGroup.visible = true
        return
    end if

    currentStream = invalid
    currentUrl = ""
    if m.candidateIdx >= 0 and m.candidateIdx < m.candidateStreams.Count() then
        currentStream = m.candidateStreams[m.candidateIdx]
        if currentStream <> invalid and currentStream.url <> invalid then currentUrl = currentStream.url.ToStr()
    end if
    ehHttp = (Left(LCase(currentUrl), 7) = "http://")

    ' 1. Tenta a fonte atual via proxy da Cloudflare apenas se NÃO tiver proxyHeaders customizados e for HTTPS
    hasCustomHeaders = (currentStream <> invalid and currentStream.httpHeadersArray <> invalid and currentStream.httpHeadersArray.Count() > 0)
    isTorrentResolved = (currentStream <> invalid and currentStream.isTorrent = true)
    if currentUrl <> "" and not m.tryingProxy and not ehHttp and not hasCustomHeaders and not isTorrentResolved and Instr(1, currentUrl, "api/proxy") = 0 then
        m.tryingProxy = true
        playCandidate(m.candidateIdx, true)
        return
    end if

    ' 2. Se o proxy da fonte atual também falhou, avança para a próxima fonte
    m.candidateIdx = m.candidateIdx + 1
    m.tryingProxy = false
    m.manualStreamChoice = false

    if m.candidateIdx < m.candidateStreams.Count() then
        playCandidate(m.candidateIdx, false)
    else
        ' Esgotou todos os candidatos
        m.bufferingGroup.visible = false
        if m.lastDebridError <> "" then
            m.errorLabel.text = m.lastDebridError
        else
            m.errorLabel.text = "Vídeo indisponível no momento"
        end if
        m.errorGroup.visible = true
    end if
end sub

function buildMergedSubtitles(streamObj as Dynamic) as Object
    merged = []
    seen = {}

    if streamObj <> invalid and streamObj.subtitles <> invalid and Type(streamObj.subtitles) = "roArray" then
        for each s in streamObj.subtitles
            if s <> invalid and s.TrackName <> invalid and s.TrackName <> "" and not seen.DoesExist(s.TrackName) then
                seen[s.TrackName] = true
                merged.Push(s)
            end if
        end for
    end if

    if m.addonSubtitles <> invalid then
        for each s in m.addonSubtitles
            if s <> invalid and s.TrackName <> invalid and s.TrackName <> "" and not seen.DoesExist(s.TrackName) then
                seen[s.TrackName] = true
                merged.Push(s)
            end if
        end for
    end if

    ' Ordena: Português primeiro (maior priority)
    if merged.Count() > 1 then
        for i = 0 to merged.Count() - 1
            p = 10
            if merged[i].priority <> invalid then p = merged[i].priority
            merged[i]._sortPrio = p * 1000 - i
        end for
        merged.SortBy("_sortPrio", "r")
    end if

    rokuTracks = []
    for each s in merged
        langCode = "und"
        if s.Language <> invalid and s.Language <> "" then langCode = s.Language
        descText = "Legenda"
        if s.Description <> invalid and s.Description <> "" then descText = s.Description
        rokuTracks.Push({
            TrackName: s.TrackName,
            Language: langCode,
            Description: descText
        })
    end for
    return rokuTracks
end function

sub startPlayback(streamUrl as String, resumePos as Dynamic, streamObj = invalid as Dynamic)
    if m.encerrado = true or m.videoPlayer = invalid then return
    content = CreateObject("roSGNode", "ContentNode")
    content.url = streamUrl
    content.title = m.playerOsd.title

    ' Monta HttpHeaders preservando proxyHeaders.request do Stremio quando existir
    headers = []
    hasUserAgent = false
    hasAccept = false
    if streamObj <> invalid and streamObj.httpHeadersArray <> invalid and Type(streamObj.httpHeadersArray) = "roArray" then
        for each h in streamObj.httpHeadersArray
            if h <> invalid and h <> "" then
                lh = LCase(h)
                if Left(lh, 11) = "user-agent:" then hasUserAgent = true
                if Left(lh, 7) = "accept:" then hasAccept = true
                headers.Push(h)
            end if
        end for
    end if
    if not hasUserAgent then headers.Push("User-Agent: SaimoTV/3.0.5 (RokuOS)")
    if not hasAccept then headers.Push("Accept: */*")
    content.HttpHeaders = headers
    content.HttpSendClientHeaders = true

    lowerUrl = LCase(streamUrl)
    hintFmt = ""
    if streamObj <> invalid and streamObj.streamFormat <> invalid then hintFmt = streamObj.streamFormat
    if Instr(1, lowerUrl, ".m3u8") > 0 or Instr(1, lowerUrl, "master.txt") > 0 or Instr(1, lowerUrl, "/hls/") > 0 or Instr(1, lowerUrl, "api/proxy") > 0 then
        content.streamFormat = "hls"
    else if Instr(1, lowerUrl, ".mpd") > 0 then
        content.streamFormat = "dash"
    else if Instr(1, lowerUrl, ".mkv") > 0 then
        content.streamFormat = "mkv"
    else if Instr(1, lowerUrl, ".mp4") > 0 or Instr(1, lowerUrl, ".m4v") > 0 then
        content.streamFormat = "mp4"
    else if hintFmt = "hls" or hintFmt = "mp4" or hintFmt = "mkv" or hintFmt = "dash" then
        content.streamFormat = hintFmt
    else
        content.streamFormat = "mp4"
    end if

    ' Injeta faixas externas de legenda do stream + addons de legenda
    extSubs = buildMergedSubtitles(streamObj)
    m.currentExternalSubtitles = extSubs
    if extSubs.Count() > 0 then
        content.SubtitleTracks = extSubs
    end if

    m.activeStream = streamObj
    if streamObj <> invalid and streamObj.bingeGroup <> invalid and streamObj.bingeGroup <> "" then
        m.activeBingeGroup = streamObj.bingeGroup
    end if

    if resumePos <> invalid and resumePos > 0 then
        content.playStart = resumePos
    end if

    m.trocandoStream = true
    m.loadingLabel.text = "Carregando vídeo..."
    m.bufferingGroup.visible = true
    m.errorGroup.visible = false
    m.debridDialog.visible = false
    m.videoPlayer.control = "stop"
    m.videoPlayer.mute = false
    m.videoPlayer.content = content
    m.videoPlayer.control = "play"
    m.trocandoStream = false
    m.progressTimer.control = "start"
    m.playerOsd.isOpen = true
    if not m.top.findNode("painelOpcoes").aberto then m.top.setFocus(true)
end sub

sub onVideoState()
    if m.encerrado = true or m.trocandoStream = true or m.videoPlayer = invalid then return
    state = m.videoPlayer.state
    if state = "playing" then
        m.bufferingGroup.visible = false
        m.errorGroup.visible = false
        m.loadingLabel.text = "Carregando vídeo..."
        m.playerOsd.isPlaying = true

        ' Se usuário prefere legendado e há legenda em português, ativa automaticamente uma vez
        if not m.autoSubtitleApplied then
            m.autoSubtitleApplied = true
            prefs = LoadPreferences()
            if prefs <> invalid and prefs.versaoAudio = "leg" then
                selTrack = ""
                if m.currentExternalSubtitles <> invalid then
                    for each es in m.currentExternalSubtitles
                        if es.Language = "por" and es.TrackName <> invalid and es.TrackName <> "" then
                            selTrack = es.TrackName
                            exit for
                        end if
                    end for
                end if
                if selTrack = "" and m.videoPlayer.availableSubtitleTracks <> invalid then
                    for each vt in m.videoPlayer.availableSubtitleTracks
                        if vt.Language <> invalid and (Left(LCase(vt.Language), 2) = "pt" or LCase(vt.Language) = "por") then
                            selTrack = vt.TrackName
                            exit for
                        end if
                    end for
                end if
                if selTrack <> "" then
                    m.videoPlayer.globalCaptionMode = "On"
                    m.videoPlayer.subtitleTrack = selTrack
                end if
            end if
        end if
    else if state = "paused" then
        m.playerOsd.isPlaying = false
    else if state = "buffering" then
        m.bufferingGroup.visible = true
    else if state = "finished" then
        videoPos = m.videoPlayer.position
        if videoPos > 10 then
            saveCurrentProgress()
            item = m.top.playItem
            prefs = LoadPreferences()
            autoNext = true
            if prefs <> invalid and prefs.proximoAutomatico = false then autoNext = false

            hasNextEp = true
            if item <> invalid and item.episodeCount <> invalid and item.episodeCount > 0 and item.episode <> invalid then
                if item.episode >= item.episodeCount then hasNextEp = false
            end if

            if autoNext and hasNextEp and item <> invalid and item.isSeries and item.episode <> invalid then
                ' Auto-avançar para o próximo episódio propagando bingeGroup da fonte atual
                nextEp = item.episode + 1
                item.episode = nextEp
                item.resumePos = 0
                item.episodeTitle = "Episódio " + nextEp.ToStr()
                item.url = "" ' Limpa URL direta para que StreamResolverTask resolva o próximo episódio
                item.directStream = invalid
                item.fallbackStreams = invalid
                item.rawVideoId = ""
                if m.activeBingeGroup <> "" then
                    item.preferredBingeGroup = m.activeBingeGroup
                end if
                m.top.playItem = item
                onPlayItemChange()
            else
                m.top.exitRequested = true
            end if
        else
            ' Vídeo finalizou sem sequer começar -> falha de stream
            m.bufferingGroup.visible = false
            tryNextCandidate()
        end if
    else if state = "error" then
        m.bufferingGroup.visible = false
        tryNextCandidate()
    end if
end sub

sub onVideoPosition()
    m.playerOsd.positionSec = Int(m.videoPlayer.position)
end sub

sub onVideoDuration()
    m.playerOsd.durationSec = Int(m.videoPlayer.duration)
end sub

sub onOsdPlayPause()
    if m.videoPlayer.state = "playing" then
        m.videoPlayer.control = "pause"
    else
        m.videoPlayer.control = "resume"
    end if
end sub

sub onOsdSeek()
    delta = m.playerOsd.seekRequested
    newPos = m.videoPlayer.position + delta
    if newPos < 0 then newPos = 0
    if newPos > m.videoPlayer.duration then newPos = m.videoPlayer.duration
    m.videoPlayer.seek = newPos
end sub

sub onOsdSkipIntro()
    newPos = m.videoPlayer.position + 85
    if newPos > m.videoPlayer.duration then newPos = m.videoPlayer.duration
    m.videoPlayer.seek = newPos
end sub

sub saveCurrentProgress()
    if m.top.playItem = invalid then return
    currentPos = Int(m.videoPlayer.position)
    dur = Int(m.videoPlayer.duration)
    if dur > 60 then
        item = m.top.playItem
        season = 0
        episode = 0
        epTitle = ""
        url = ""
        if item.season <> invalid then season = item.season
        if item.episode <> invalid then episode = item.episode
        if item.episodeTitle <> invalid then epTitle = item.episodeTitle
        if item.url <> invalid then url = item.url
        SaveVODProgress(item.title, currentPos, dur, season, episode, epTitle, url, { poster: item.poster, isSeries: item.isSeries, letter: item.letter })
    end if
end sub

' Tecla *: áudio, legendas e fontes do que está tocando.
sub abrirOpcoes()
    m.opcoes = []
    lista = []
    faixas = m.videoPlayer.availableAudioTracks
    if faixas <> invalid then
        for i = 0 to faixas.Count() - 1
            t = faixas[i]
            nome = "Áudio " + (i + 1).ToStr()
            if t.Language <> invalid and t.Language <> "" then nome = "Áudio: " + t.Language
            lista.Push({ titulo: nome })
            m.opcoes.Push({ tipo: "audio", valor: t.Track })
        end for
    end if

    seenLeg = {}
    legendas = m.videoPlayer.availableSubtitleTracks
    if legendas <> invalid then
        for i = 0 to legendas.Count() - 1
            t = legendas[i]
            tn = ""
            if t.TrackName <> invalid then tn = t.TrackName
            nome = "Legenda " + (i + 1).ToStr()
            if t.Description <> invalid and t.Description <> "" then
                nome = t.Description
            else if t.Language <> invalid and t.Language <> "" then
                nome = "Legenda: " + t.Language
            end if
            if tn <> "" then seenLeg[tn] = true
            lista.Push({ titulo: nome })
            m.opcoes.Push({ tipo: "legenda", valor: tn })
        end for
    end if
    if m.currentExternalSubtitles <> invalid then
        for each es in m.currentExternalSubtitles
            if es.TrackName <> invalid and es.TrackName <> "" and not seenLeg.DoesExist(es.TrackName) then
                seenLeg[es.TrackName] = true
                nome = "Legenda Externa"
                if es.Description <> invalid and es.Description <> "" then nome = es.Description
                lista.Push({ titulo: nome })
                m.opcoes.Push({ tipo: "legenda", valor: es.TrackName })
            end if
        end for
    end if
    if lista.Count() > 0 or (m.currentExternalSubtitles <> invalid and m.currentExternalSubtitles.Count() > 0) then
        lista.Push({ titulo: "Sem legenda" })
        m.opcoes.Push({ tipo: "legenda", valor: "" })
    end if

    if m.candidateStreams <> invalid then
        for i = 0 to m.candidateStreams.Count() - 1
            st = m.candidateStreams[i]
            tituloStr = "Fonte " + (i + 1).ToStr()
            detalheStr = ""
            if st <> invalid then
                if st.title <> invalid and st.title <> "" then tituloStr = st.title
                if i = m.candidateIdx then tituloStr = "● " + tituloStr
                if st.detail <> invalid then detalheStr = st.detail
            end if
            lista.Push({ titulo: tituloStr, detalhe: detalheStr })
            m.opcoes.Push({ tipo: "fonte", valor: i })
        end for
    end if

    painel = m.top.findNode("painelOpcoes")
    painel.titulo = "Opções"
    painel.ajuda = "Escolha áudio, legenda ou fonte do stream"
    painel.opcoes = lista
    painel.aberto = true
end sub

sub onOpcaoEscolhida()
    painel = m.top.findNode("painelOpcoes")
    o = m.opcoes[painel.escolhido]
    painel.aberto = false
    if o = invalid then return
    if o.tipo = "audio" then
        m.videoPlayer.audioTrack = o.valor
    else if o.tipo = "legenda" then
        if o.valor = "" then
            m.videoPlayer.globalCaptionMode = "Off"
        else
            m.videoPlayer.globalCaptionMode = "On"
            m.videoPlayer.subtitleTrack = o.valor
        end if
    else
        m.tryingProxy = false
        m.manualStreamChoice = true
        m.candidateIdx = o.valor
        playCandidate(o.valor, false)
    end if
end sub

sub onOpcoesAberto()
    if not m.top.findNode("painelOpcoes").aberto then m.top.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.debridDialog <> invalid and m.debridDialog.visible then
        if key = "OK" or key = "back" then
            m.debridDialog.visible = false
            if m.debridDialogExitOnClose then
                cleanUp()
                m.top.exitRequested = true
            else
                m.top.setFocus(true)
            end if
            return true
        end if
        return true
    end if

    if m.top.findNode("painelOpcoes").aberto then return false

    if key = "options" then
        abrirOpcoes()
        return true
    end if

    ' A barra não recebe foco: as teclas do player ficam aqui.
    osd = m.playerOsd
    if key = "OK" or key = "play" then
        onOsdPlayPause()
        osd.isOpen = true
        return true
    else if key = "left" or key = "rewind" then
        osd.seekRequested = -10
        osd.isOpen = true
        return true
    else if key = "right" or key = "fastforward" then
        osd.seekRequested = 10
        osd.isOpen = true
        return true
    else if key = "replay" then
        osd.seekRequested = -30
        osd.isOpen = true
        return true
    else if key = "up" then
        if osd.isSeries then onOsdSkipIntro()
        osd.isOpen = true
        return true
    else if key = "down" then
        osd.isOpen = not osd.isOpen
        return true
    end if

    if key = "back" then
        cleanUp()
        m.top.exitRequested = true
        return true
    end if

    return false
end function

sub cleanUp()
    if m.encerrado = true then return
    saveCurrentProgress()
    m.encerrado = true
    m.trocandoStream = true
    if m.progressTimer <> invalid then
        m.progressTimer.control = "stop"
    end if
    if m.debridTask <> invalid then
        m.debridTask.unobserveField("result")
        m.debridTask.control = "stop"
        m.debridTask = invalid
    end if
    if m.resolverTask <> invalid then
        m.resolverTask.unobserveField("resolvedItem")
        m.resolverTask.control = "stop"
        m.resolverTask = invalid
    end if
    if m.videoPlayer <> invalid then
        m.videoPlayer.unobserveField("state")
        m.videoPlayer.unobserveField("position")
        m.videoPlayer.unobserveField("duration")
        m.videoPlayer.mute = true
        m.videoPlayer.control = "pause"
        m.videoPlayer.control = "stop"
        m.videoPlayer.content = CreateObject("roSGNode", "ContentNode")
        m.videoPlayer.control = "stop"
        m.videoPlayer.content = invalid
        m.videoPlayer.visible = false
    end if
end sub
