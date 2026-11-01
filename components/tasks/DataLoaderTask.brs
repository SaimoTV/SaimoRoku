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
' guia.txt diz o código de cada canal no meuguia.tv; a página do canal traz a
' programação. O resultado fica 6 h no cachefs para abrir o app sem esperar.
sub fetchEpg(baseUrl as String)
    cache = "cachefs:/epg.json"
    agora = CreateObject("roDateTime").AsSeconds()
    bruto = ReadAsciiFile(cache)
    if bruto <> "" then
        dados = ParseJson(bruto)
        if dados <> invalid and dados.quando <> invalid and agora - dados.quando < 21600 then
            m.top.responseEpg = dados.mapa
            return
        end if
    end if

    text = HttpGet(baseUrl + "guia.txt")
    if text = "" then return

    fila = []
    for each rawLine in text.Split(Chr(10))
        parts = rawLine.Trim().Split(Chr(9))
        if parts.Count() >= 3 and parts[0] = "meuguia" then fila.Push({ nome: parts[1], codigo: parts[2] })
    end for

    epgMap = {}
    for i = 0 to fila.Count() - 1
        c = fila[i]
        lista = lerMeuGuia(HttpGet("https://meuguia.tv/programacao/canal/" + c.codigo), agora)
        if lista.Count() > 0 then epgMap[c.nome] = lista
        ' Mostra aos poucos: quem abre o painel já vê os primeiros canais.
        if (i + 1) mod 15 = 0 then m.top.responseEpg = epgMap
    end for
    m.top.responseEpg = epgMap
    WriteAsciiFile(cache, FormatJson({ quando: agora, mapa: epgMap }))
end sub

function entre(texto as String, abre as String, fecha as String) as Dynamic
    p = Instr(1, texto, abre)
    if p = 0 then return invalid
    p = p + Len(abre)
    q = Instr(p, texto, fecha)
    if q = 0 then return invalid
    return Mid(texto, p, q - p)
end function

function doisDigitos(n as Integer) as String
    t = n.ToStr()
    if Len(t) < 2 then t = "0" + t
    return t
end function

' Itens <li>: cabeçalho do dia e programas com hora e título. O fim de cada um é
' o início do seguinte. Hora de Brasília (UTC-3).
function lerMeuGuia(html as String, agora as Integer) as Object
    if html = "" then return []
    hoje = CreateObject("roDateTime")
    hoje.FromSeconds(agora - 10800)
    ano = hoje.GetYear()
    mes = hoje.GetMonth()
    dia = hoje.GetDayOfMonth()
    programas = []
    conversor = CreateObject("roDateTime")

    for each item in html.Split("<li")
        if Instr(1, item, "subheader") > 0 then
            t = entre(Mid(item, Instr(1, item, "subheader")), ">", "<")
            if t <> invalid and Instr(1, t, ",") > 0 then
                d = Mid(t, Instr(1, t, ",") + 1).Trim().Split("/")
                if d.Count() = 2 then
                    dia = Val(d[0])
                    mes = Val(d[1])
                end if
            end if
        else
            relogio = entre(item, "lileft time'>", "<")
            if relogio = invalid then relogio = entre(item, "lileft time" + Chr(34) + ">", "<")
            titulo = entre(item, "<h2>", "</h2>")
            if relogio <> invalid and titulo <> invalid then
                hm = relogio.Trim().Split(":")
                if hm.Count() = 2 then
                    conversor.FromISO8601String(ano.ToStr() + "-" + doisDigitos(mes) + "-" + doisDigitos(dia) + "T" + doisDigitos(Val(hm[0])) + ":" + doisDigitos(Val(hm[1])) + ":00Z")
                    inicio = conversor.AsSeconds() + 10800
                    titulo = titulo.Replace("&amp;", "&").Replace("&#39;", "'").Replace("&quot;", Chr(34)).Trim()
                    if titulo <> "" then programas.Push({ title: titulo, startSec: inicio })
                end if
            end if
        end if
    end for

    saida = []
    for i = 0 to programas.Count() - 1
        p = programas[i]
        fim = p.startSec + 3600
        if i + 1 < programas.Count() then fim = programas[i + 1].startSec
        ' Só de agora em diante: o resto só ocuparia memória.
        if fim > agora then
            dur = Int((fim - p.startSec) / 60)
            resta = Int((fim - agora) / 60)
            saida.Push({ title: p.title, startSec: p.startSec, stopSec: fim, durationMin: dur, remainingMin: resta, isCurrent: agora >= p.startSec })
            if saida.Count() >= 12 then exit for
        end if
    end for
    return saida
end function

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
                letter = tabParts[2].Trim()
                year = tabParts[3].Trim()
                posterPath = tabParts[4].Trim()
                posterUrl = posterPath
                if Left(posterPath, 1) = "/" then
                    posterUrl = capaBase + posterPath
                end if

                item = {
                    title: title,
                    letter: letter,
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
