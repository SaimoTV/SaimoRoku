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

    prefs = LoadPreferences()
    versaoPref = "dub"
    if prefs <> invalid and prefs.versaoAudio <> invalid and prefs.versaoAudio <> "" then
        versaoPref = LCase(prefs.versaoAudio)
    end if

    candidatesList = []

    if isSeries then
        candidatesList = resolveSeriesStream(title, letter, season, episode, versaoPref)
    else
        candidatesList = resolveMovieStream(title, letter, versaoPref)
    end if

    ' Se não encontrou nenhuma fonte no catálogo, consulta api/stream por id TMDB
    if candidatesList.Count() = 0 and item <> invalid and item.id <> invalid and item.id.ToStr() <> "" and item.id.ToStr() <> "0" then
        tipoReq = "movie"
        if isSeries then tipoReq = "series"
        apiUrl = "https://saimo-tv.pages.dev/api/stream?tipo=" + tipoReq + "&id=" + item.id.ToStr() + "&versao=" + versaoPref
        if isSeries then apiUrl = apiUrl + "&s=" + season.ToStr() + "&e=" + episode.ToStr()
        resolvedUrl = buildCandidateUrl(apiUrl)
        if resolvedUrl <> "" then
            candidatesList.Push(resolvedUrl)
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

    url = baseFilmes() + "indice.txt"
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.AddHeader("User-Agent", "SaimoTV/2.6.4 (RokuOS)")
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

function buscarLinhaPorTitulo(text as String, cleanTitle as String) as String
    if text = "" or cleanTitle = "" then return ""
    lowerText = Chr(10) + LCase(text)
    idxPos = Instr(1, lowerText, Chr(10) + cleanTitle + Chr(9))
    if idxPos = 0 and Instr(1, cleanTitle, " (") > 0 then
        openParen = Instr(1, cleanTitle, " (")
        baseTitle = Left(cleanTitle, openParen - 1).Trim()
        idxPos = Instr(1, lowerText, Chr(10) + baseTitle + Chr(9))
        if idxPos = 0 then
            idxPos = Instr(1, lowerText, Chr(10) + baseTitle + " (")
        end if
    end if
    if idxPos = 0 then
        idxPos = Instr(1, lowerText, Chr(10) + cleanTitle + " (")
    end if
    if idxPos = 0 then return ""
    fimLinha = Instr(idxPos, text, Chr(10))
    if fimLinha > 0 then
        return Mid(text, idxPos, fimLinha - idxPos).Trim()
    end if
    return Mid(text, idxPos).Trim()
end function

function ordenarEResolverCandidatos(rawPref as Object, rawAlt as Object) as Object
    diretasHttps = []
    diretasOutras = []
    relays = []

    listas = [rawPref, rawAlt]
    for each lista in listas
        for each c in lista
            cand = c.Trim()
            if cand <> "" and Instr(1, cand, "desativado.invalid") = 0 then
                if Instr(1, cand, "api/stream") > 0 then
                    relays.Push(cand)
                else if Left(LCase(cand), 8) = "https://" then
                    diretasHttps.Push(cand)
                else
                    diretasOutras.Push(cand)
                end if
            end if
        end for
    end for

    results = []
    for each c in diretasHttps
        r = buildCandidateUrl(c)
        if r <> "" then results.Push(r)
    end for

    ' Se não achou fonte direta https://, resolve no máximo 1 relay api/stream (que retorna https://)
    if results.Count() = 0 and relays.Count() > 0 then
        r = buildCandidateUrl(relays[0])
        if r <> "" then results.Push(r)
    end if

    for each c in diretasOutras
        r = buildCandidateUrl(c)
        if r <> "" then results.Push(r)
    end for

    return results
end function

function resolveMovieStream(title as String, letter as String, versaoPref as String) as Object
    results = []
    url = baseFilmes() + "filmes-" + letter + ".txt"
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.AddHeader("User-Agent", "SaimoTV/3.0.3 (RokuOS)")
    ut.RetainBodyOnError(true)
    text = ut.GetToString()
    if text = "" then return results

    cleanTitle = LCase(title.Trim())
    targetLine = buscarLinhaPorTitulo(text, cleanTitle)
    if targetLine = "" then return results

    ' Extrai URLs das fontes priorizando a versão escolhida (dub ou leg)
    parts = targetLine.Split(Chr(9))
    if parts.Count() < 2 then return results

    rawPref = []
    rawAlt = []
    for p = 1 to parts.Count() - 1
        part = parts[p]
        eqIdx = Instr(1, part, "=")
        if eqIdx > 1 then
            tag = LCase(Left(part, eqIdx - 1).Trim())
            urlsStr = Mid(part, eqIdx + 1)
            candidates = urlsStr.Split(",")
            if tag = versaoPref then
                for each c in candidates
                    rawPref.Push(c)
                end for
            else
                for each c in candidates
                    rawAlt.Push(c)
                end for
            end if
        end if
    end for

    return ordenarEResolverCandidatos(rawPref, rawAlt)
end function

function extrairBlocoSerie(chunkText as String, cleanTitle as String) as String
    if chunkText = "" or cleanTitle = "" then return ""
    lowerChunk = Chr(10) + LCase(chunkText)
    idxPos = Instr(1, lowerChunk, Chr(10) + "@" + cleanTitle + Chr(10))
    if idxPos = 0 then idxPos = Instr(1, lowerChunk, Chr(10) + "@" + cleanTitle + Chr(13))
    if idxPos = 0 then idxPos = Instr(1, lowerChunk, Chr(10) + "@" + cleanTitle)
    if idxPos = 0 and Instr(1, cleanTitle, " (") > 0 then
        openParen = Instr(1, cleanTitle, " (")
        baseTitle = Left(cleanTitle, openParen - 1).Trim()
        idxPos = Instr(1, lowerChunk, Chr(10) + "@" + baseTitle)
    end if
    if idxPos = 0 then return ""
    prox = Instr(idxPos + 2, lowerChunk, Chr(10) + "@")
    if prox > 0 then
        return Mid(chunkText, idxPos, prox - idxPos)
    end if
    return Mid(chunkText, idxPos)
end function

function extrairEpisodioDeBloco(bloco as String, season as Integer, episode as Integer, versaoPref as String) as Object
    rawPref = []
    rawAlt = []
    if bloco = "" then return []
    lines = bloco.Split(Chr(10))
    for each rawLine in lines
        line = rawLine.Trim()
        if line <> "" and Left(line, 1) <> "@" then
            epFields = line.Split(Chr(9))
            if epFields.Count() >= 4 then
                epSeason = Val(epFields[0].Trim())
                epNum = Val(epFields[1].Trim())
                if epSeason = season and epNum = episode then
                    tag = LCase(epFields[2].Trim())
                    urlsStr = epFields[3].Trim()
                    candidates = urlsStr.Split(",")
                    if tag = versaoPref then
                        for each c in candidates
                            rawPref.Push(c)
                        end for
                    else
                        for each c in candidates
                            rawAlt.Push(c)
                        end for
                    end if
                end if
            end if
        end if
    end for
    return ordenarEResolverCandidatos(rawPref, rawAlt)
end function

function resolveSeriesStream(title as String, letter as String, season as Integer, episode as Integer, versaoPref as String) as Object
    results = []

    ' 1. Busca índice de pedaços da série em series-<letra>.txt
    url = baseFilmes() + "series-" + letter + ".txt"
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.AddHeader("User-Agent", "SaimoTV/3.0.3 (RokuOS)")
    ut.RetainBodyOnError(true)
    text = ut.GetToString()

    pedaco = 0
    cleanTitle = LCase(title.Trim())
    linhaIndice = buscarLinhaPorTitulo(text, cleanTitle)
    if linhaIndice <> "" then
        fields = linhaIndice.Split(Chr(9))
        if fields.Count() >= 3 then
            pedaco = Val(fields[2].Trim())
        end if
    end if

    ' 2. Baixa o pedaço correspondente: series-<letra>-<pedaco>.txt
    chunkUrl = baseFilmes() + "series-" + letter + "-" + pedaco.ToStr() + ".txt"
    ut.SetUrl(chunkUrl)
    chunkText = ut.GetToString()

    bloco = extrairBlocoSerie(chunkText, cleanTitle)
    results = extrairEpisodioDeBloco(bloco, season, episode, versaoPref)
    if results.Count() > 0 then return results

    ' 3. Se não achou, tenta em animes e doramas
    animeUrl = baseFilmes() + "redeflix/links-animes.txt"
    resolvedAnime = findInRedeflix(animeUrl, cleanTitle, season, episode, versaoPref)
    if resolvedAnime.Count() > 0 then return resolvedAnime

    doramaUrl = baseFilmes() + "redeflix/links-doramas.txt"
    resolvedDorama = findInRedeflix(doramaUrl, cleanTitle, season, episode, versaoPref)
    if resolvedDorama.Count() > 0 then return resolvedDorama

    return results
end function

function buildCandidateUrl(cand as String) as String
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
        utJson.AddHeader("User-Agent", "SaimoTV/3.0.3 (RokuOS)")
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
        ' Se termina em .txt (playlist servida como texto), usa proxy Cloudflare para converter text/plain -> mpegurl
        if Instr(1, LCase(finalUrl), ".txt") > 0 and Instr(1, finalUrl, "api/proxy") = 0 then
            ut = CreateObject("roUrlTransfer")
            finalUrl = "https://saimo-tv.pages.dev/api/proxy?url=" + ut.Escape(finalUrl)
        end if
        return finalUrl
    end if

    colonIdx = Instr(1, cand, ":")
    if colonIdx > 1 then
        bases = getIndiceBases()
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

function findInRedeflix(url as String, cleanTitle as String, season as Integer, episode as Integer, versaoPref as String) as Object
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.AddHeader("User-Agent", "SaimoTV/3.0.3 (RokuOS)")
    ut.RetainBodyOnError(true)
    text = ut.GetToString()
    if text = "" then return []

    bloco = extrairBlocoSerie(text, cleanTitle)
    return extrairEpisodioDeBloco(bloco, season, episode, versaoPref)
end function

' O endereço (no formato do Saimo) da lista de filmes e séries que a pessoa informou.
' Sem endereço, os pedidos vão a um nome que nunca resolve e falham na hora.
function baseFilmes() as String
    base = LoadPreferences().urlFilmes
    if base = invalid or base = "" then return "https://sem-lista.invalid/"
    if Right(base, 1) <> "/" then base = base + "/"
    return base
end function
