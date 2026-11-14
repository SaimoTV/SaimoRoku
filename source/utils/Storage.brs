' ====================================================================
' Saimo TV - Storage & Preferences (Roku Registry Section)
' Persistência nativa de configurações, progresso e favoritos
' ====================================================================

function GetRegistry() as Object
    return CreateObject("roRegistrySection", "saimo_tv")
end function

function NormalizarEnderecoSaimo(url as Dynamic) as String
    if url = invalid then return ""
    u = url.ToStr().Trim()
    if u = "" then return ""
    l = LCase(u)
    esquema = "https://"
    resto = u
    if Left(l, 7) = "http://" then
        esquema = "http://"
        resto = Mid(u, 8)
    else if Left(l, 8) = "https://" then
        esquema = "https://"
        resto = Mid(u, 9)
    end if
    u = esquema + resto
    l = LCase(u)
    if Instr(1, l, ".m3u") > 0 or Instr(1, l, "get.php") > 0 or Instr(1, l, "type=m3u") > 0 then
        return u
    end if

    hashPos = Instr(1, resto, "#")
    if hashPos > 0 then resto = Left(resto, hashPos - 1).Trim()
    queryPos = Instr(1, resto, "?")
    if queryPos > 0 then resto = Left(resto, queryPos - 1).Trim()
    while Len(resto) > 0 and Right(resto, 1) = "/"
        resto = Left(resto, Len(resto) - 1)
    end while
    if resto = "" then return ""

    barra = Instr(1, resto, "/")
    host = resto
    rota = ""
    if barra > 0 then
        host = Left(resto, barra - 1)
        rota = Mid(resto, barra)
    end if
    host = LCase(host.Trim())
    if host = "" then return ""

    if rota <> "" then
        partes = rota.Split("/")
        if partes.Count() > 0 then
            ultimo = LCase(partes[partes.Count() - 1])
            if Right(ultimo, 4) = ".txt" or Right(ultimo, 5) = ".json" or ultimo = "catalogo" or ultimo = "destaques" or ultimo = "indice" then
                partes.Pop()
            end if
        end if
        if partes.Count() > 0 and LCase(partes[partes.Count() - 1]) = "roku" then
            partes.Pop()
        end if
        novaRota = ""
        for each seg in partes
            if seg <> "" then novaRota = novaRota + "/" + seg
        end for
        rota = novaRota
    end if

    return esquema + host + rota + "/"
end function

function GetDefaultPreferences() as Object
    return {
        abrirEm: "inicio",
        zeroDelay: "equilibrado",
        audioInteligente: true,
        versaoAudio: "dub",
        proximoAutomatico: true,
        pularAutomatico: true,
        pinParental: "1010",
        ultimoCanal: "",
        urlCanais: "",
        urlFilmes: ""
    }
end function

function LoadPreferences() as Object
    reg = GetRegistry()
    raw = reg.Read("prefs")
    defaults = GetDefaultPreferences()
    if raw <> "" then
        parsed = ParseJson(raw)
        if parsed <> invalid then
            for each key in parsed
                val = parsed[key]
                lk = LCase(key)
                if val <> invalid then
                    if defaults[lk] = invalid or defaults[lk].ToStr() = "" or val.ToStr() <> "" then
                        defaults[lk] = val
                    end if
                end if
            end for
        end if
    end if
    if defaults.urlCanais <> invalid and defaults.urlCanais <> "" then
        defaults.urlCanais = NormalizarEnderecoSaimo(defaults.urlCanais)
    end if
    if defaults.urlFilmes <> invalid and defaults.urlFilmes <> "" then
        defaults.urlFilmes = NormalizarEnderecoSaimo(defaults.urlFilmes)
    end if
    return defaults
end function

sub SavePreferences(prefs as Object)
    if prefs = invalid then return
    limpo = GetDefaultPreferences()
    for each key in prefs
        val = prefs[key]
        lk = LCase(key)
        if val <> invalid then
            if limpo[lk] = invalid or limpo[lk].ToStr() = "" or val.ToStr() <> "" then
                limpo[lk] = val
            end if
        end if
    end for
    if limpo.urlCanais <> invalid and limpo.urlCanais <> "" then
        limpo.urlCanais = NormalizarEnderecoSaimo(limpo.urlCanais)
    end if
    if limpo.urlFilmes <> invalid and limpo.urlFilmes <> "" then
        limpo.urlFilmes = NormalizarEnderecoSaimo(limpo.urlFilmes)
    end if
    reg = GetRegistry()
    json = FormatJson(limpo)
    reg.Write("prefs", json)
    reg.Flush()
end sub

' ----- Progresso VOD ("Continuar Assistindo") -----

function LoadAllProgress() as Object
    reg = GetRegistry()
    raw = reg.Read("vod_progress")
    if raw <> "" then
        parsed = ParseJson(raw)
        if parsed <> invalid then return parsed
    end if
    return {}
end function

function GetVODProgress(title as String) as Dynamic
    all = LoadAllProgress()
    if all[title] <> invalid then return all[title]
    return invalid
end function

sub SaveVODProgress(title as String, posSec as Integer, durSec as Integer, season = 0 as Integer, episode = 0 as Integer, epTitle = "" as String, url = "" as String, extra = invalid as Dynamic)
    if title = "" or durSec <= 0 then return
    all = LoadAllProgress()
    percent = Int((posSec / durSec) * 100)
    
    ' Se assistiu mais de 92%, marca como concluído
    if percent >= 92 then
        if all[title] <> invalid then
            all.Delete(title)
            reg = GetRegistry()
            reg.Write("vod_progress", FormatJson(all))
            reg.Flush()
        end if
        return
    end if

    ' Capa, tipo e letra do título: o Continuar assistindo mostra a capa e
    ' reabre o título sem procurar de novo. Sem eles, mantém os já guardados.
    anterior = all[title]
    if extra = invalid then extra = {}
    poster = extra.poster
    if (poster = invalid or poster = "") and anterior <> invalid then poster = anterior.poster
    serie = extra.isSeries
    if serie = invalid and anterior <> invalid then serie = anterior.isSeries
    if serie = invalid then serie = (season > 0)
    letra = extra.letter
    if (letra = invalid or letra = "") and anterior <> invalid then letra = anterior.letter

    all[title] = {
        poster: poster,
        isSeries: serie,
        letter: letra,
        title: title,
        position: posSec,
        duration: durSec,
        percent: percent,
        season: season,
        episode: episode,
        episodeTitle: epTitle,
        url: url,
        updatedAt: CreateObject("roDateTime").AsSeconds()
    }

    reg = GetRegistry()
    reg.Write("vod_progress", FormatJson(all))
    reg.Flush()
end sub

' ----- Favoritos -----

function LoadFavoriteChannels() as Object
    reg = GetRegistry()
    raw = reg.Read("fav_channels")
    if raw <> "" then
        parsed = ParseJson(raw)
        if parsed <> invalid then return parsed
    end if
    return []
end function

sub ToggleFavoriteChannel(channelName as String)
    favs = LoadFavoriteChannels()
    idx = -1
    for i = 0 to favs.Count() - 1
        if favs[i] = channelName then
            idx = i
            exit for
        end if
    end for
    if idx >= 0 then
        favs.Delete(idx)
    else
        favs.Push(channelName)
    end if
    reg = GetRegistry()
    reg.Write("fav_channels", FormatJson(favs))
    reg.Flush()
end sub

function IsChannelFavorite(channelName as String) as Boolean
    favs = LoadFavoriteChannels()
    for each f in favs
        if f = channelName then return true
    end for
    return false
end function

' ----- VOD Favoritos (Filmes e Séries) -----

function LoadFavoriteVOD() as Object
    reg = GetRegistry()
    raw = reg.Read("fav_vod")
    if raw <> "" then
        parsed = ParseJson(raw)
        if parsed <> invalid then return parsed
    end if
    return []
end function

sub ToggleFavoriteVOD(item as Object)
    if item = invalid or item.title = invalid or item.title = "" then return
    favs = LoadFavoriteVOD()
    idx = -1
    for i = 0 to favs.Count() - 1
        if favs[i].title = item.title then
            idx = i
            exit for
        end if
    end for
    if idx >= 0 then
        favs.Delete(idx)
    else
        clean = {
            title: item.title,
            isSeries: (item.isSeries = true),
            letter: item.letter,
            poster: item.poster,
            backdrop: item.backdrop,
            year: item.year,
            genres: item.genres,
            overview: item.overview,
            category: item.category
        }
        favs.Push(clean)
    end if
    reg = GetRegistry()
    reg.Write("fav_vod", FormatJson(favs))
    reg.Flush()
end sub

function IsVODFavorite(title as String) as Boolean
    if title = "" then return false
    favs = LoadFavoriteVOD()
    for each f in favs
        if f.title = title then return true
    end for
    return false
end function

function GetInProgressList() as Object
    all = LoadAllProgress()
    list = []
    for each key in all
        it = all[key]
        if it <> invalid and it.percent <> invalid and it.percent > 2 and it.percent < 92 then
            list.Push(it)
        end if
    end for
    return list
end function

sub RemoveInProgress(title as String)
    if title = "" then return
    all = LoadAllProgress()
    changed = false
    for each key in all
        it = all[key]
        if key = title or (it <> invalid and it.title = title) then
            all.Delete(key)
            changed = true
        end if
    end for
    if changed then
        reg = GetRegistry()
        reg.Write("vod_progress", FormatJson(all))
        reg.Flush()
    end if
end sub

' ----- Minhas listas (só os dados de cada lista; os canais ficam no cachefs) -----
function LoadMinhasListas() as Object
    bruto = GetRegistry().Read("minhas_listas")
    if bruto <> "" then
        dados = ParseJson(bruto)
        if dados <> invalid then return dados
    end if
    return []
end function

sub SaveMinhasListas(listas as Object)
    reg = GetRegistry()
    reg.Write("minhas_listas", FormatJson(listas))
    reg.Flush()
end sub
