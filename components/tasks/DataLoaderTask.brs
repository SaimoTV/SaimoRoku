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

        colon = Instr(1, line, ":")
        if colon <= 1 then continue for

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
    capaBase = "https://image.tmdb.org/t/p/w342"
    allVodItems = []

    for each rawLine in lines
        line = rawLine.Trim()
        if line = "" or Left(line, 1) = "#" then continue for

        if Left(line, 5) = "capa:" then
            capaBase = Mid(line, 6).Trim()
        else if Left(line, 4) = "fila" then
            tabParts = line.Split(Chr(9))
            railTitle = "Em Destaque"
            if tabParts.Count() >= 2 then railTitle = tabParts[1].Trim()
            currentRail = {
                title: railTitle,
                items: []
            }
            rails.Push(currentRail)
        else if currentRail <> invalid then
            tabParts = line.Split(Chr(9))
            if tabParts.Count() >= 5 then
                tipo = tabParts[0].Trim()
                title = tabParts[1].Trim()
                year = tabParts[3].Trim()
                posterPath = tabParts[4].Trim()
                posterUrl = posterPath
                if Left(posterPath, 1) = "/" then
                    posterUrl = capaBase + posterPath
                end if

                item = {
                    title: title,
                    poster: posterUrl,
                    backdrop: posterUrl,
                    isSeries: (tipo = "s"),
                    year: year,
                    category: currentRail.title
                }
                currentRail.items.Push(item)
                allVodItems.Push(item)
            end if
        end if
    end for

    m.top.responseDestaques = rails
    m.top.responseVodItems = allVodItems
end sub

' ----- Eventos Esportivos -----
sub fetchEvents(baseUrl as String)
    url = "https://saimo-tv.pages.dev/eventos-extra.json"
    text = HttpGet(url)
    events = []

    if text <> "" and text <> "[]" then
        parsed = ParseJson(text)
        if parsed <> invalid and type(parsed) = "roArray" then
            for each ev in parsed
                home = ""
                away = ""
                if ev.mandante <> invalid then home = ev.mandante
                if ev.visitante <> invalid then away = ev.visitante
                league = ""
                if ev.campeonato <> invalid then league = ev.campeonato
                timeStr = ""
                if ev.hora <> invalid then timeStr = ev.hora
                channelName = ""
                if ev.canal <> invalid then channelName = ev.canal

                item = {
                    homeTeam: home,
                    awayTeam: away,
                    league: league,
                    timeStr: timeStr,
                    channelName: channelName,
                    score: ""
                }
                events.Push(item)
            end for
        end if
    end if

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
        if parts.Count() >= 2 then
            name = parts[0].Trim()
            streamUrl = parts[1].Trim()
            logo = ""
            if parts.Count() >= 3 then logo = parts[2].Trim()
            genre = "Ao Vivo"

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
