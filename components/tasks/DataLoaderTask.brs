' ====================================================================
' Saimo TV - DataLoaderTask (BrightScript)
' Download assíncrono e parsing de catálogos, EPG, VOD e eventos
' ====================================================================

sub init()
    m.top.functionName = "executeRequest"
end sub

sub executeRequest()
    reqType = m.top.requestType
    prefs = LoadPreferences()
    urlCanais = prefs.urlCanais
    urlFilmes = prefs.urlFilmes

    if reqType = "channels" then
        fetchChannels(urlCanais)
    else if reqType = "epg" then
        fetchEpg(urlCanais)
    else if reqType = "destaques" then
        fetchDestaques(urlFilmes)
    else if reqType = "vod" then
        fetchVod(urlFilmes)
    else if reqType = "events" then
        fetchEvents(urlCanais)
    else if reqType = "radios" then
        fetchRadios(urlCanais)
    end if
end sub

' ----- Requisição HTTP utilitária -----
function HttpGet(url as String) as String
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.InitClientCertificates()
    ut.AddHeader("User-Agent", "SaimoTV/2.6.0 (RokuOS)")
    ut.RetainBodyOnError(true)
    return ut.GetToString()
end function

' ----- Canais ao Vivo -----
sub fetchChannels(baseUrl as String)
    url = baseUrl + "catalogo.txt"
    text = HttpGet(url)
    if text = "" then
        m.top.error = "Erro ao baixar catálogo"
        return
    end if

    lines = text.Split(Chr(10))
    channels = []
    current = invalid
    curVariant = invalid
    chNumber = 1

    for each rawLine in lines
        line = rawLine.Trim()
        if line = "" or Left(line, 1) = "#" then continue for

        colon = line.Instr(":")
        if colon <= 0 then continue for

        key = LCase(Left(line, colon - 1).Trim())
        val = Mid(line, colon + 1).Trim()

        if key = "canal" then
            if current <> invalid and current.variants.Count() > 0 then
                channels.Push(current)
            end if
            current = {
                id: "ch_" + chNumber.ToStr(),
                number: chNumber,
                name: val,
                category: "Variedades",
                logo: "",
                variants: []
            }
            chNumber = chNumber + 1
            curVariant = invalid
        else if current <> invalid then
            if key = "categoria" then
                current.category = val
            else if key = "logo" then
                current.logo = val
            else if key = "fonte" then
                curVariant = { url: val, quality: "Auto" }
                current.variants.Push(curVariant)
            else if curVariant <> invalid then
                if key = "qualidade" then
                    curVariant.quality = val
                else if key = "referer" then
                    curVariant.referer = val
                else if key = "agente" then
                    curVariant.userAgent = val
                else if key = "chave" then
                    curVariant.clearKey = val
                end if
            end if
        end if
    end for

    if current <> invalid and current.variants.Count() > 0 then
        channels.Push(current)
    end if

    m.top.responseChannels = channels
end sub

' ----- EPG (Guia de Programação) -----
sub fetchEpg(baseUrl as String)
    url = baseUrl + "guia.txt"
    text = HttpGet(url)
    if text = "" then return

    lines = text.Split(Chr(10))
    epgMap = {}
    nowSec = CreateObject("roDateTime").AsSeconds()

    for each rawLine in lines
        line = rawLine.Trim()
        if line = "" then continue for
        parts = line.Split(Chr(9)) ' separado por tab
        if parts.Count() < 4 then continue for

        channelName = parts[0].Trim()
        startSec = Val(parts[1])
        stopSec = Val(parts[2])
        title = parts[3].Trim()

        if epgMap[channelName] = invalid then
            epgMap[channelName] = []
        end if

        durMin = Int((stopSec - startSec) / 60)
        remMin = Int((stopSec - nowSec) / 60)
        if remMin < 0 then remMin = 0

        prog = {
            title: title,
            startSec: startSec,
            stopSec: stopSec,
            durationMin: durMin,
            remainingMin: remMin,
            isCurrent: (nowSec >= startSec and nowSec < stopSec)
        }
        epgMap[channelName].Push(prog)
    end for

    m.top.responseEpg = epgMap
end sub

' ----- Destaques e Trilhos da Home -----
sub fetchDestaques(baseUrl as String)
    url = baseUrl + "destaques.txt"
    text = HttpGet(url)
    if text = "" then return

    lines = text.Split(Chr(10))
    rails = []
    currentRail = invalid

    for each rawLine in lines
        line = rawLine.Trim()
        if line = "" then continue for

        if Left(line, 1) = "[" and Right(line, 1) = "]" then
            railTitle = Mid(line, 2, Len(line) - 2)
            currentRail = {
                title: railTitle,
                items: []
            }
            rails.Push(currentRail)
        else if currentRail <> invalid then
            parts = line.Split("|")
            if parts.Count() >= 2 then
                title = parts[0].Trim()
                poster = parts[1].Trim()
                isSeries = false
                if parts.Count() >= 3 and parts[2].Trim() = "serie" then isSeries = true
                
                item = {
                    title: title,
                    poster: poster,
                    isSeries: isSeries
                }
                currentRail.items.Push(item)
            end if
        end if
    end for

    m.top.responseDestaques = rails
end sub

' ----- Catálogo VOD (Filmes e Séries) -----
sub fetchVod(baseUrl as String)
    url = baseUrl + "indice.txt"
    text = HttpGet(url)
    if text = "" then return

    lines = text.Split(Chr(10))
    vodItems = []

    for each rawLine in lines
        line = rawLine.Trim()
        if line = "" or Left(line, 1) = "#" then continue for
        parts = line.Split("|")
        if parts.Count() >= 3 then
            title = parts[0].Trim()
            category = parts[1].Trim()
            poster = parts[2].Trim()
            isSeries = (category = "Séries" or category = "Animes" or category = "Doramas")
            year = ""
            if parts.Count() >= 4 then year = parts[3].Trim()

            item = {
                title: title,
                category: category,
                poster: poster,
                isSeries: isSeries,
                year: year
            }
            vodItems.Push(item)
        end if
    end for

    m.top.responseVodItems = vodItems
end sub

' ----- Eventos Esportivos -----
sub fetchEvents(baseUrl as String)
    url = baseUrl + "eventos.txt"
    text = HttpGet(url)
    if text = "" then return

    lines = text.Split(Chr(10))
    events = []

    for each rawLine in lines
        line = rawLine.Trim()
        if line = "" or Left(line, 1) = "#" then continue for
        parts = line.Split("|")
        if parts.Count() >= 5 then
            homeTeam = parts[0].Trim()
            awayTeam = parts[1].Trim()
            league = parts[2].Trim()
            timeStr = parts[3].Trim()
            channelName = parts[4].Trim()
            score = ""
            if parts.Count() >= 6 then score = parts[5].Trim()

            item = {
                homeTeam: homeTeam,
                awayTeam: awayTeam,
                league: league,
                timeStr: timeStr,
                channelName: channelName,
                score: score
            }
            events.Push(item)
        end if
    end for

    m.top.responseEvents = events
end sub

' ----- Rádios -----
sub fetchRadios(baseUrl as String)
    url = baseUrl + "radios.txt"
    text = HttpGet(url)
    if text = "" then return

    lines = text.Split(Chr(10))
    radios = []

    for each rawLine in lines
        line = rawLine.Trim()
        if line = "" or Left(line, 1) = "#" then continue for
        parts = line.Split("|")
        if parts.Count() >= 3 then
            name = parts[0].Trim()
            streamUrl = parts[1].Trim()
            genre = parts[2].Trim()
            logo = ""
            if parts.Count() >= 4 then logo = parts[3].Trim()

            item = {
                name: name,
                url: streamUrl,
                genre: genre,
                logo: logo
            }
            radios.Push(item)
        end if
    end for

    m.top.responseRadios = radios
end sub
