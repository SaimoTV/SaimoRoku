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
    urlCanais = NormalizarEnderecoSaimo(prefs.urlCanais)
    urlFilmes = NormalizarEnderecoSaimo(prefs.urlFilmes)
    if m.top.requestUrl <> invalid and m.top.requestUrl.Trim() <> "" then
        if reqType = "destaques" then
            urlFilmes = NormalizarEnderecoSaimo(m.top.requestUrl)
        else
            urlCanais = NormalizarEnderecoSaimo(m.top.requestUrl)
        end if
    end if

    ' Sem endereço (o app não traz nenhum): nada é pedido. O catálogo sai vazio
    ' e a tela principal junta só as listas da própria pessoa.
    if reqType = "channels" then
        if urlCanais = "" then
            m.top.responseChannels = []
        else
            fetchChannels(urlCanais)
        end if
    else if reqType = "epg" then
        if urlCanais <> "" then fetchEpg(urlCanais)
    else if reqType = "destaques" then
        if urlFilmes = "" then
            m.top.responseDestaques = []
            m.top.responseVodItems = []
        else
            fetchDestaques(urlFilmes)
        end if
    else if reqType = "events" then
        fetchEvents()
    else if reqType = "radios" then
        if urlCanais <> "" then fetchRadios(urlCanais)
    end if
end sub

' ----- Requisição HTTP utilitária -----
function HttpGet(url as String) as String
    if url = "" or url = invalid then return ""
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.AddHeader("User-Agent", "SaimoTV/3.0.3 (RokuOS)")
    res = ut.GetToString()
    if res = invalid then return ""
    return res
end function

function ehUrlM3uDireta(u as String) as Boolean
    l = LCase(u.Trim())
    return Instr(1, l, ".m3u") > 0 or Instr(1, l, "get.php") > 0 or Instr(1, l, "type=m3u") > 0
end function

function fonteDesativada(url as String) as Boolean
    if url = invalid or url.Trim() = "" then return true
    u = LCase(url.Trim())
    mortos = ["146.0.32.89", "governosptx.org", "desativado.invalid", "playercdnx.workers.dev", "45.162.64.114", "123flmsfree.com", "cloutteam.com", "praia13.com", "megaembed.com", "clickhost.xyz"]
    for each h in mortos
        if Instr(1, u, h) > 0 then return true
    end for
    return false
end function

' Mesma prioridade do site (httpsFirst): fontes HTTPS .m3u8 primeiro, depois HTTPS .txt, HTTP e por último DASH/ClearKey.
function ordenarFontesCanal(fontes as Object) as Object
    if fontes = invalid or fontes.Count() = 0 then return []
    httpsM3u8 = []
    httpsTxt = []
    httpOutras = []
    dashDrm = []
    for each f in fontes
        if f <> invalid and f.url <> invalid and not fonteDesativada(f.url) then
            u = LCase(f.url.Trim())
            temChave = (f.clearKey <> invalid and f.clearKey <> "")
            if temChave or Instr(1, u, ".mpd") > 0 then
                dashDrm.Push(f)
            else if Left(u, 8) = "https://" then
                if Instr(1, u, ".txt") > 0 then
                    httpsTxt.Push(f)
                else
                    httpsM3u8.Push(f)
                end if
            else
                httpOutras.Push(f)
            end if
        end if
    end for
    saida = []
    saida.Append(httpsM3u8)
    saida.Append(httpsTxt)
    saida.Append(httpOutras)
    saida.Append(dashDrm)
    return saida
end function

' ----- Canais ao Vivo -----
sub fetchChannels(baseUrl as String)
    direta = ehUrlM3uDireta(baseUrl)
    if direta then
        url = baseUrl
    else
        url = baseUrl
        if Right(url, 1) <> "/" then url = url + "/"
        url = url + "catalogo.txt"
    end if
    text = HttpGet(url)
    if text = "" then
        m.top.error = "Erro ao baixar catálogo"
        m.top.responseChannels = []
        return
    end if

    if Left(text, 1) = Chr(65279) then text = Mid(text, 2)
    if direta or Left(UCase(text.Trim()), 7) = "#EXTM3U" or Instr(1, UCase(text), "#EXTINF") > 0 then
        lidos = LerM3u(text, 5000)
        channels = []
        chNumber = 1
        for each c in lidos
            if not EhRestrito(c) and c.fontes <> invalid and c.fontes.Count() > 0 then
                fontes = []
                for each f in c.fontes
                    v = { url: f.url, quality: "Auto" }
                    if f.qualidade <> invalid then v.quality = f.qualidade
                    if f.referer <> invalid then v.referer = f.referer
                    if f.ua <> invalid then v.userAgent = f.ua
                    fontes.Push(v)
                end for
                fontes = ordenarFontesCanal(fontes)
                if fontes.Count() > 0 then
                    cat = "Variedades"
                    if c.grupo <> invalid and c.grupo <> "" then cat = c.grupo
                    logo = ""
                    if c.logo <> invalid then logo = c.logo
                    channels.Push({
                        id: "ch_" + chNumber.ToStr(),
                        number: chNumber,
                        name: c.nome,
                        category: cat,
                        logo: logo,
                        variants: fontes
                    })
                    chNumber = chNumber + 1
                end if
            end if
        end for
        m.top.responseChannels = channels
        return
    end if

    lines = text.Split(Chr(10))
    channels = []
    current = invalid
    curVariant = invalid
    chNumber = 1

    for each rawLine in lines
        line = rawLine.Trim()
        colon = Instr(1, line, ":")
        if line <> "" and Left(line, 1) <> "#" and colon > 1 then
            key = LCase(Left(line, colon - 1).Trim())
            val = Mid(line, colon + 1).Trim()

            if key = "canal" then
                if current <> invalid then
                    current.variants = ordenarFontesCanal(current.variants)
                    if current.variants.Count() > 0 then channels.Push(current)
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
        end if
    end for

    if current <> invalid then
        current.variants = ordenarFontesCanal(current.variants)
        if current.variants.Count() > 0 then channels.Push(current)
    end if

    m.top.responseChannels = channels
end sub

' ----- EPG (Guia de Programação) -----
' guia.txt diz o código de cada canal no meuguia.tv; a página do canal traz a
' programação. O resultado fica 6 h no cachefs para abrir o app sem esperar.
sub fetchEpg(baseUrl as String)
    cache = "cachefs:/epg2.json"
    agora = CreateObject("roDateTime").AsSeconds()
    bruto = ""
    if CreateObject("roFileSystem").Exists(cache) then
        bruto = ReadAsciiFile(cache)
    end if
    if bruto <> "" then
        dados = ParseJson(bruto)
        if dados <> invalid and dados.quando <> invalid and agora - dados.quando < 21600 then
            m.top.responseEpg = dados.mapa
            return
        end if
    end if

    ' Abrir o app e o primeiro canal vêm antes do guia.
    sleep(4000)
    text = HttpGet(baseUrl + "guia.txt")
    if text = "" then return

    meuguia = []
    guiadetv = []
    for each rawLine in text.Split(Chr(10))
        parts = rawLine.Trim().Split(Chr(9))
        if parts.Count() >= 3 then
            if parts[0] = "meuguia" then meuguia.Push({ nome: parts[1], codigo: parts[2] })
            if parts[0] = "guiadetv" then guiadetv.Push({ nome: parts[1], codigo: parts[2] })
        end if
    end for

    epgMap = {}
    ' Guia central: um arquivo só, montado no servidor às 11h e às 18h. Antes
    ' eram 69 páginas de ~300 KB baixadas e lidas aqui a cada abertura.
    central = invalid
    texto = HttpGet(baseUrl + "epg-leve.json")
    if texto <> "" then central = ParseJson(texto)
    texto = ""
    if central <> invalid and central.m <> invalid and central.g <> invalid then
        ' guiadetv primeiro (horários exatos), pelo nome normalizado; meuguia
        ' pelo nome do catálogo, para quem o guiadetv não cobre.
        for each c in guiadetv
            lista = programasDoCentral(central.g[c.codigo], agora)
            if lista.Count() > 0 then epgMap[NormalizarNomeCanal(c.nome)] = lista
        end for
        for each c in meuguia
            if epgMap[NormalizarNomeCanal(c.nome)] = invalid then
                lista = programasDoCentral(central.m[c.codigo], agora)
                if lista.Count() > 0 then epgMap[c.nome] = lista
            end if
        end for
    else
        ' Endereço sem guia central (lista antiga): página por página.
        for i = 0 to meuguia.Count() - 1
            c = meuguia[i]
            ' A página traz a semana inteira (270 KB); o começo já tem hoje e amanhã.
            lista = lerMeuGuia(Left(HttpGet("https://meuguia.tv/programacao/canal/" + c.codigo), 60000), agora)
            if lista.Count() > 0 then epgMap[c.nome] = lista
            sleep(150)
        end for
    end if
    central = invalid
    m.top.responseEpg = epgMap
    WriteAsciiFile(cache, FormatJson({ quando: agora, mapa: epgMap }))
end sub

' [[inicio, fim, "título"], ...] do guia central: de agora em diante, até 12.
function programasDoCentral(lista as Dynamic, agora as Integer) as Object
    saida = []
    if lista = invalid then return saida
    for each p in lista
        if p.Count() >= 3 and p[1] > agora then
            saida.Push({ title: p[2], startSec: p[0], stopSec: p[1], durationMin: Int((p[1] - p[0]) / 60), remainingMin: Int((p[1] - agora) / 60), isCurrent: agora >= p[0] })
            if saida.Count() >= 12 then exit for
        end if
    end for
    return saida
end function

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
    if Right(baseUrl, 1) <> "/" then baseUrl = baseUrl + "/"
    url = baseUrl + "destaques.txt"
    text = HttpGet(url)
    rails = []
    allVodItems = []
    capaBase = "https://image.tmdb.org/t/p/w342"

    if text <> "" then
        lines = text.Split(Chr(10))
        currentRail = invalid

        for each rawLine in lines
            line = rawLine.Trim()
            if line <> "" and Left(line, 1) <> "#" then
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
            end if
        end for
    end if

    ' Fallback caso o servidor Saimo não possua destaques.txt
    if rails.Count() = 0 then
        amostra = HttpGet(baseUrl + "roku/filmes-A-1.txt")
        if amostra <> "" then
            trilho = { title: "Filmes", items: [] }
            for each bruta in amostra.Split(Chr(10))
                p = bruta.Trim().Split(Chr(9))
                if p.Count() >= 3 and p[0] <> "" then
                    posterUrl = p[2]
                    if Left(p[2], 1) = "/" then posterUrl = capaBase + p[2]
                    it = { title: p[0], letter: "A", poster: posterUrl, backdrop: posterUrl, isSeries: false, year: p[1], category: "Filmes" }
                    trilho.items.Push(it)
                    allVodItems.Push(it)
                    if trilho.items.Count() >= 25 then exit for
                end if
            end for
            if trilho.items.Count() > 0 then rails.Push(trilho)
        end if
    end if

    m.top.responseDestaques = rails
    m.top.responseVodItems = allVodItems
end sub

' ----- Eventos Esportivos -----
sub fetchEvents()
    events = []
    ' Agenda do Saimo (nenhum site de streaming de terceiros é consultado).
    texto = HttpGet("https://saimo-tv.pages.dev/eventos-extra.json")
    parsed = invalid
    if Left(texto.Trim(), 1) = "[" then parsed = ParseJson(texto)
    if parsed <> invalid and type(parsed) = "roArray" then
        d = CreateObject("roDateTime")
        agora = d.AsSeconds()
        for each ev in parsed
            jogo = lerJogo(ev, d, agora)
            if jogo <> invalid then events.Push(jogo)
        end for
    end if
    m.top.responseEvents = events
end sub

' Campo faltando só descarta o jogo: erro aqui derrubaria a tarefa.
function lerJogo(ev as Object, d as Object, agora as Integer) as Dynamic
    if ev.teams = invalid or ev.time_start = invalid then return invalid
    if ev.teams.home = invalid or ev.teams.away = invalid or ev.teams.home.name = invalid or ev.teams.away.name = invalid then return invalid
    d.FromISO8601String(Left(ev.time_start, 19) + "Z")
    inicio = d.AsSeconds() + 10800
    fim = inicio + 7200
    if ev.time_end <> invalid then
        d.FromISO8601String(Left(ev.time_end, 19) + "Z")
        fim = d.AsSeconds() + 10800
    end if
    if fim <= agora then return invalid
    casa = ""
    fora = ""
    if ev.teams.home.image <> invalid then casa = ev.teams.home.image.Replace("w_34,h_34", "w_256,h_256")
    if ev.teams.away.image <> invalid then fora = ev.teams.away.image.Replace("w_34,h_34", "w_256,h_256")
    liga = ""
    if ev.league <> invalid and ev.league.name <> invalid then liga = ev.league.name
    return { homeTeam: ev.teams.home.name, awayTeam: ev.teams.away.name, homeLogo: casa, awayLogo: fora, league: liga, timeStr: Mid(ev.time_start, 12, 5), aoVivo: agora >= inicio or ev.estado = "in", slugs: ev.players, estado: ev.estado, channelName: "", score: "" }
end function

' Mesmos estilos da TV Box: a ordem conta, rádio que cabe em dois fica no primeiro.
function estiloDaRadio(nome as String) as String
    n = LCase(nome) + " "
    estilos = [
        { t: "Rock", p: ["rock", "metal", "kiss", "punk"] },
        { t: "Notícias e esporte", p: ["news", "noticia", "cbn", "gaucha", "itatiaia", "tupi", "esporte", "jornal", "bandnews", "radio globo", "eldorado", "bandeirantes"] },
        { t: "Gospel e católicas", p: ["gospel", "evangel", "catolic", "crista", "louvor", "aleluia", "cancao nova", "novo tempo", "aparecida", "fe ", "deus", "jesus", "igreja", "biblia"] },
        { t: "Pop e hits", p: ["pop", "hits", "dance", "mix", "jovem pan", "transamerica", "energia", "eletro", "club", "pulse", "top"] },
        { t: "Sertanejo, MPB e samba", p: ["sertanej", "mpb", "samba", "pagode", "forro", "nativa", "caipira", "brega", "axe", "piseiro", "moda de viola"] },
        { t: "Clássica e jazz", p: ["classic", "jazz", "cultura", "educativa", "universit", "instrumental", "blues", "lounge"] }
    ]
    for each e in estilos
        for each palavra in e.p
            if Instr(1, n, palavra) > 0 then return e.t
        end for
    end for
    return "Outras"
end function

' ----- Rádios -----
sub fetchRadios(baseUrl as String)
    url = baseUrl + "radios.txt"
    text = HttpGet(url)
    if text = "" then return

    lines = text.Split(Chr(10))
    radios = []

    for each rawLine in lines
        line = rawLine.Trim()
        if line <> "" and Left(line, 1) <> "#" then
            parts = line.Split("|")
            if parts.Count() >= 2 then
                name = parts[0].Trim()
                streamUrl = parts[1].Trim()
                logo = ""
                if parts.Count() >= 3 then logo = parts[2].Trim()
                genre = estiloDaRadio(name)

                item = {
                    name: name,
                    url: streamUrl,
                    genre: genre,
                    logo: logo
                }
                radios.Push(item)
            end if
        end if
    end for

    m.top.responseRadios = radios
end sub

