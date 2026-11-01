' ====================================================================
' Saimo TV - StreamResolverTask (BrightScript)
' Resolução ultra-rápida de URLs de streaming para filmes e séries
' Suporte a múltiplas fontes, proxy automático para .txt e fallbacks
' ====================================================================

sub init()
    m.top.functionName = "resolveStream"
end sub

sub resolveStream()
    item = m.top.requestItem
    if item = invalid then return

    title = ""
    if item.title <> invalid then title = item.title
    if title = "" then return

    isSeries = false
    if item.isSeries <> invalid then isSeries = item.isSeries

    season = 1
    if item.season <> invalid and item.season > 0 then season = item.season

    episode = 1
    if item.episode <> invalid and item.episode > 0 then episode = item.episode

    resumePos = 0
    if item.resumePos <> invalid then resumePos = item.resumePos

    ' Determina a gaveta da letra
    letter = getLetterGaveta(title, item)

    ' Bases do índice
    bases = getIndiceBases()

    candidatesList = []

    if isSeries then
        candidatesList = resolveSeriesStream(title, letter, season, episode, bases)
    else
        candidatesList = resolveMovieStream(title, letter, bases)
    end if

    ' Se não encontrou no catálogo ou precisa de fonte extra, consulta api/stream por id TMDB
    if item <> invalid and item.id <> invalid and item.id.ToStr() <> "" and item.id.ToStr() <> "0" then
        tipoReq = "movie"
        if isSeries then tipoReq = "series"
        apiUrl = "https://saimo-tv.pages.dev/api/stream?tipo=" + tipoReq + "&id=" + item.id.ToStr() + "&versao=dub"
        if isSeries then apiUrl = apiUrl + "&s=" + season.ToStr() + "&e=" + episode.ToStr()
        resolvedUrl = buildCandidateUrl(apiUrl, bases)
        if resolvedUrl <> "" then
            ' Adiciona à lista se ainda não estiver nela
            alreadyIn = false
            for each c in candidatesList
                if c = resolvedUrl then
                    alreadyIn = true
                    exit for
                end if
            end for
            if not alreadyIn then candidatesList.Push(resolvedUrl)
        end if
    end if

    streamUrl = ""
    if candidatesList.Count() > 0 then
        streamUrl = candidatesList[0]
    end if

    resolved = {
        title: title,
        url: streamUrl,
        candidateUrls: candidatesList,
        isSeries: isSeries,
        season: season,
        episode: episode,
        resumePos: resumePos
    }

    if isSeries and item.episodeTitle <> invalid then
        resolved.episodeTitle = item.episodeTitle
    else if isSeries then
        resolved.episodeTitle = "Episódio " + episode.ToStr()
    end if

    m.top.resolvedItem = resolved
end sub

function getLetterGaveta(title as String, item as Object) as String
    if item <> invalid and item.letter <> invalid and item.letter <> "" then
        targetLetter = item.letter.Trim()
        if targetLetter = "#" then return "%23"
        return UCase(targetLetter)
    end if

    clean = title.Trim()
    if clean = "" then return "%23"
    first = UCase(Left(clean, 1))
    code = Asc(first)
    if code >= 65 and code <= 90 then ' A-Z
        return first
    end if
    return "%23"
end function

function getIndiceBases() as Object
    if m.globalBases <> invalid then return m.globalBases

    url = "https://filmes-saimo.pages.dev/indice.txt"
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.AddHeader("User-Agent", "SaimoTV/2.6.3 (RokuOS)")
    ut.RetainBodyOnError(true)
    text = ut.GetToString()

    bases = {}
    if text <> "" then
        lines = text.Split(Chr(10))
        for each rawLine in lines
            line = rawLine.Trim()
            if Left(line, 5) = "base:" then
                rest = Mid(line, 6).Trim()
                spaceIdx = Instr(1, rest, " ")
                if spaceIdx > 1 then
                    bId = Val(Left(rest, spaceIdx - 1))
                    bUrl = Mid(rest, spaceIdx + 1).Trim()
                    bases[bId.ToStr()] = bUrl
                end if
            end if
        end for
    end if

    m.globalBases = bases
    return bases
end function

function resolveMovieStream(title as String, letter as String, bases as Object) as Object
    results = []
    url = "https://filmes-saimo.pages.dev/filmes-" + letter + ".txt"
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.AddHeader("User-Agent", "SaimoTV/2.6.3 (RokuOS)")
    ut.RetainBodyOnError(true)
    text = ut.GetToString()
    if text = "" then return results

    lines = text.Split(Chr(10))
    cleanTitle = LCase(title.Trim())
    targetLine = ""

    for each rawLine in lines
        line = rawLine.Trim()
        if line = "" then continue for
        tabIdx = Instr(1, line, Chr(9))
        if tabIdx > 1 then
            lineTitle = LCase(Left(line, tabIdx - 1).Trim())
            if lineTitle = cleanTitle then
                targetLine = line
                exit for
            end if
        end if
    end for

    ' Se não achou com correspondência exata, tenta buscar sem o ano (ex: "Verity (2026)" -> "Verity")
    if targetLine = "" and Instr(1, cleanTitle, " (") > 0 then
        openParen = Instr(1, cleanTitle, " (")
        baseTitle = Left(cleanTitle, openParen - 1).Trim()
        for each rawLine in lines
            line = rawLine.Trim()
            if line = "" then continue for
            tabIdx = Instr(1, line, Chr(9))
            if tabIdx > 1 then
                lineTitle = LCase(Left(line, tabIdx - 1).Trim())
                if lineTitle = baseTitle or Instr(1, lineTitle, baseTitle) = 1 then
                    targetLine = line
                    exit for
                end if
            end if
        end for
    end if

    if targetLine = "" then return results

    ' Extrai URLs das fontes (dub ou leg)
    parts = targetLine.Split(Chr(9))
    if parts.Count() < 2 then return results

    for p = 1 to parts.Count() - 1
        part = parts[p]
        eqIdx = Instr(1, part, "=")
        if eqIdx > 1 then
            urlsStr = Mid(part, eqIdx + 1)
            candidates = urlsStr.Split(",")
            for each c in candidates
                cand = c.Trim()
                resolved = buildCandidateUrl(cand, bases)
                if resolved <> "" then
                    results.Push(resolved)
                end if
            end for
        end if
    end for

    return results
end function

function resolveSeriesStream(title as String, letter as String, season as Integer, episode as Integer, bases as Object) as Object
    results = []

    ' 1. Busca índice de pedaços da série em series-<letra>.txt
    url = "https://filmes-saimo.pages.dev/series-" + letter + ".txt"
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.AddHeader("User-Agent", "SaimoTV/2.6.3 (RokuOS)")
    ut.RetainBodyOnError(true)
    text = ut.GetToString()

    pedaco = 0
    cleanTitle = LCase(title.Trim())
    if text <> "" then
        lines = text.Split(Chr(10))
        for each rawLine in lines
            line = rawLine.Trim()
            if line = "" then continue for
            fields = line.Split(Chr(9))
            if fields.Count() >= 3 then
                sTitle = LCase(fields[0].Trim())
                if sTitle = cleanTitle or Instr(1, sTitle, cleanTitle) = 1 then
                    pedaco = Val(fields[2].Trim())
                    exit for
                end if
            end if
        end for
    end if

    ' 2. Baixa o pedaço correspondente: series-<letra>-<pedaco>.txt
    chunkUrl = "https://filmes-saimo.pages.dev/series-" + letter + "-" + pedaco.ToStr() + ".txt"
    ut.SetUrl(chunkUrl)
    chunkText = ut.GetToString()

    if chunkText <> "" then
        lines = chunkText.Split(Chr(10))
        inSeries = false
        targetHeader = "@" + cleanTitle

        for each rawLine in lines
            line = rawLine.Trim()
            if line = "" then continue for

            if Left(line, 1) = "@" then
                if inSeries then
                    exit for
                end if
                headerTitle = LCase(line)
                if headerTitle = targetHeader or Instr(1, headerTitle, targetHeader) = 1 then
                    inSeries = true
                end if
            else if inSeries then
                epFields = line.Split(Chr(9))
                if epFields.Count() >= 4 then
                    epSeason = Val(epFields[0].Trim())
                    epNum = Val(epFields[1].Trim())
                    if epSeason = season and epNum = episode then
                        urlsStr = epFields[3].Trim()
                        candidates = urlsStr.Split(",")
                        for each c in candidates
                            cand = c.Trim()
                            resolved = buildCandidateUrl(cand, bases)
                            if resolved <> "" then
                                results.Push(resolved)
                            end if
                        end for
                    end if
                end if
            end if
        end for
    end if

    if results.Count() > 0 then return results

    ' 3. Se não achou, tenta em animes e doramas
    animeUrl = "https://filmes-saimo.pages.dev/redeflix/links-animes.txt"
    resolvedAnime = findInRedeflix(animeUrl, cleanTitle, season, episode, bases)
    if resolvedAnime.Count() > 0 then return resolvedAnime

    doramaUrl = "https://filmes-saimo.pages.dev/redeflix/links-doramas.txt"
    resolvedDorama = findInRedeflix(doramaUrl, cleanTitle, season, episode, bases)
    if resolvedDorama.Count() > 0 then return resolvedDorama

    return results
end function

function buildCandidateUrl(cand as String, bases as Object) as String
    if cand = "" or Instr(1, cand, "desativado.invalid") > 0 then return ""

    ' Se aponta para o relay central api/stream, consulta o endpoint com &json=1 para obter a URL direta do vídeo
    if Instr(1, cand, "api/stream") > 0 then
        jsonUrl = cand
        if Instr(1, jsonUrl, "?") > 0 then
            jsonUrl = jsonUrl + "&json=1"
        else
            jsonUrl = jsonUrl + "?json=1"
        end if

        utJson = CreateObject("roUrlTransfer")
        utJson.SetUrl(jsonUrl)
        utJson.SetCertificatesFile("common:/certs/ca-bundle.crt")
        utJson.AddHeader("User-Agent", "SaimoTV/2.6.3 (RokuOS)")
        utJson.RetainBodyOnError(true)
        respText = utJson.GetToString()
        if respText <> "" then
            parsed = ParseJson(respText)
            if parsed <> invalid and parsed.url <> invalid and parsed.url <> "" then
                finalUrl = parsed.url
                ' Se a URL final termina em .txt, passa pelo proxy da Cloudflare
                if Instr(1, LCase(finalUrl), ".txt") > 0 and Instr(1, finalUrl, "api/proxy") = 0 then
                    ut = CreateObject("roUrlTransfer")
                    finalUrl = "https://saimo-tv.pages.dev/api/proxy?url=" + ut.Escape(finalUrl)
                end if
                return finalUrl
            end if
        end if
        return ""
    end if

    if Left(cand, 7) = "http://" or Left(cand, 8) = "https://" then
        finalUrl = cand
        ' Se termina em .txt (ex: master.txt de embedplayer2), usa proxy Cloudflare para converter text/plain -> mpegurl
        if Instr(1, LCase(finalUrl), ".txt") > 0 and Instr(1, finalUrl, "api/proxy") = 0 then
            ut = CreateObject("roUrlTransfer")
            finalUrl = "https://saimo-tv.pages.dev/api/proxy?url=" + ut.Escape(finalUrl)
        end if
        return finalUrl
    end if

    colonIdx = Instr(1, cand, ":")
    if colonIdx > 1 then
        baseId = Left(cand, colonIdx - 1).Trim()
        streamPath = Mid(cand, colonIdx + 1).Trim()
        if bases[baseId] <> invalid then
            baseHost = bases[baseId]
            if Instr(1, baseHost, "desativado.invalid") = 0 then
                res = baseHost + streamPath
                if Instr(1, streamPath, ".") = 0 then
                    res = res + ".mp4"
                end if
                if Instr(1, LCase(res), ".txt") > 0 and Instr(1, res, "api/proxy") = 0 then
                    ut = CreateObject("roUrlTransfer")
                    res = "https://saimo-tv.pages.dev/api/proxy?url=" + ut.Escape(res)
                end if
                return res
            end if
        end if
    end if

    return ""
end function

function findInRedeflix(url as String, cleanTitle as String, season as Integer, episode as Integer, bases as Object) as Object
    results = []
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.AddHeader("User-Agent", "SaimoTV/2.6.3 (RokuOS)")
    ut.RetainBodyOnError(true)
    text = ut.GetToString()
    if text = "" then return results

    lines = text.Split(Chr(10))
    inSeries = false
    targetHeader = "@" + cleanTitle

    for each rawLine in lines
        line = rawLine.Trim()
        if line = "" then continue for

        if Left(line, 1) = "@" then
            if inSeries then exit for
            headerTitle = LCase(line)
            if headerTitle = targetHeader or Instr(1, headerTitle, targetHeader) = 1 then
                inSeries = true
            end if
        else if inSeries then
            epFields = line.Split(Chr(9))
            if epFields.Count() >= 4 then
                epSeason = Val(epFields[0].Trim())
                epNum = Val(epFields[1].Trim())
                if epSeason = season and epNum = episode then
                    urlsStr = epFields[3].Trim()
                    candidates = urlsStr.Split(",")
                    for each c in candidates
                        resolved = buildCandidateUrl(c.Trim(), bases)
                        if resolved <> "" then
                            results.Push(resolved)
                        end if
                    end for
                end if
            end if
        end if
    end for

    return results
end function
