' ====================================================================
' Saimo TV - TMDB <-> IMDb Bridge & Discovery Helper (BrightScript)
' Cache local em tmp:/saimo_id_cache.json, consultas a /external_ids,
' /find/{imdb_id} e /search para casar tt e tmdb: mesmo sem listas M3U.
' Requer Addons.brs carregado no escopo (HttpTransferAsync).
' ====================================================================

function TmdbApiKey() as String
    return "15d2ea6d0dc1d476efbca3eba2b9bbfb"
end function

function TmdbBaseUrl() as String
    return "https://api.themoviedb.org/3"
end function

function IdCachePath() as String
    return "tmp:/saimo_id_cache.json"
end function

function LoadIdCache() as Object
    empty = { tmdbToImdb: {}, imdbToTmdb: {}, titleToIds: {} }
    fs = CreateObject("roFileSystem")
    p = IdCachePath()
    if not fs.Exists(p) then return empty
    raw = ReadAsciiFile(p)
    if raw = invalid or raw = "" then return empty
    parsed = ParseJson(raw)
    if parsed = invalid or Type(parsed) <> "roAssociativeArray" then return empty
    if parsed.tmdbToImdb = invalid or Type(parsed.tmdbToImdb) <> "roAssociativeArray" then parsed.tmdbToImdb = {}
    if parsed.imdbToTmdb = invalid or Type(parsed.imdbToTmdb) <> "roAssociativeArray" then parsed.imdbToTmdb = {}
    if parsed.titleToIds = invalid or Type(parsed.titleToIds) <> "roAssociativeArray" then parsed.titleToIds = {}
    return parsed
end function

sub PruneMapIfNeeded(mapa as Object, maxEntries as Integer)
    if mapa = invalid or mapa.Count() <= maxEntries then return
    chaves = mapa.Keys()
    remover = Int(chaves.Count() / 2)
    for i = 0 to remover - 1
        mapa.Delete(chaves[i])
    end for
end sub

sub SaveIdCache(cache as Object)
    if cache = invalid then return
    PruneMapIfNeeded(cache.tmdbToImdb, 400)
    PruneMapIfNeeded(cache.imdbToTmdb, 400)
    PruneMapIfNeeded(cache.titleToIds, 300)
    WriteAsciiFile(IdCachePath(), FormatJson(cache))
end sub

function TmdbGetJson(endpointPath as String) as Dynamic
    sep = "?"
    if Instr(1, endpointPath, "?") > 0 then sep = "&"
    url = TmdbBaseUrl() + endpointPath + sep + "api_key=" + TmdbApiKey()
    resp = HttpTransferAsync("GET", url, invalid, "", 8000)
    if not resp.ok or resp.body = "" then return invalid
    parsed = ParseJson(resp.body)
    if parsed = invalid or Type(parsed) <> "roAssociativeArray" then return invalid
    return parsed
end function

function IsPureDigits(s as String) as Boolean
    if s = "" then return false
    for i = 1 to Len(s)
        c = Asc(Mid(s, i, 1))
        if c < 48 or c > 57 then return false
    end for
    return true
end function

function CleanTitleForTmdbSearch(title as String) as String
    t = title.Trim()
    reParen = CreateObject("roRegex", "\s*[\(\[]\s*(19|20)\d{2}\s*[\)\]]", "")
    t = reParen.ReplaceAll(t, "")
    reTags = CreateObject("roRegex", "\s*[\(\[]\s*(dub|leg|dublado|legendado|dual|4k|uhd|fhd|hd)\s*[\)\]]", "i")
    t = reTags.ReplaceAll(t, "")
    return t.Trim()
end function

function TmdbGenreIdMap() as Object
    return {
        "28": "Ação", "12": "Aventura", "16": "Animação", "35": "Comédia",
        "80": "Crime", "99": "Documentário", "18": "Drama", "10751": "Família",
        "14": "Fantasia", "36": "História", "27": "Terror", "10402": "Música",
        "9648": "Mistério", "10749": "Romance", "878": "Ficção Científica",
        "10770": "Cinema TV", "53": "Suspense", "10752": "Guerra", "37": "Faroeste",
        "10759": "Ação e Aventura", "10762": "Infantil", "10765": "Sci-Fi & Fantasia",
        "10768": "Guerra e Política"
    }
end function

function TmdbGenresFromEntry(entry as Object) as String
    nomes = []
    if entry.genres <> invalid and Type(entry.genres) = "roArray" then
        for each g in entry.genres
            if Type(g) = "roAssociativeArray" and g.name <> invalid then nomes.Push(g.name.ToStr())
        end for
    else if entry.genre_ids <> invalid and Type(entry.genre_ids) = "roArray" then
        mapa = TmdbGenreIdMap()
        for each gid in entry.genre_ids
            if gid <> invalid and mapa.DoesExist(gid.ToStr()) then
                nomes.Push(mapa[gid.ToStr()])
            end if
        end for
    end if
    return nomes.Join(", ")
end function

function TmdbEntryToVodItem(entry as Object, isSeries as Boolean, categoryLabel = "" as String) as Dynamic
    if entry = invalid or Type(entry) <> "roAssociativeArray" then return invalid
    tmdbId = ""
    if entry.id <> invalid then tmdbId = entry.id.ToStr().Trim()
    if tmdbId = "" then return invalid

    title = ""
    if isSeries then
        if entry.name <> invalid then title = entry.name.ToStr().Trim()
        if title = "" and entry.original_name <> invalid then title = entry.original_name.ToStr().Trim()
    else
        if entry.title <> invalid then title = entry.title.ToStr().Trim()
        if title = "" and entry.original_title <> invalid then title = entry.original_title.ToStr().Trim()
    end if
    if title = "" then return invalid

    dateStr = ""
    if isSeries and entry.first_air_date <> invalid then dateStr = entry.first_air_date.ToStr()
    if not isSeries and entry.release_date <> invalid then dateStr = entry.release_date.ToStr()
    yr = ""
    if Len(dateStr) >= 4 then yr = Left(dateStr, 4)

    poster = ""
    if entry.poster_path <> invalid and entry.poster_path.ToStr() <> "" then
        poster = "https://image.tmdb.org/t/p/w342" + entry.poster_path.ToStr()
    end if
    backdrop = poster
    if entry.backdrop_path <> invalid and entry.backdrop_path.ToStr() <> "" then
        backdrop = "https://image.tmdb.org/t/p/w780" + entry.backdrop_path.ToStr()
    end if

    overview = ""
    if entry.overview <> invalid then overview = entry.overview.ToStr().Trim()
    rating = ""
    if entry.vote_average <> invalid and Val(entry.vote_average.ToStr()) > 0 then
        rating = Left(entry.vote_average.ToStr(), 3)
    end if

    return {
        id: tmdbId,
        tmdbId: tmdbId,
        imdbId: "",
        title: title,
        isSeries: isSeries,
        year: yr,
        poster: poster,
        backdrop: backdrop,
        overview: overview,
        genres: TmdbGenresFromEntry(entry),
        rating: rating,
        category: categoryLabel,
        letter: UCase(Left(title, 1)),
        sourceType: "tmdb"
    }
end function

function ResolveIdsForItem(item as Dynamic) as Object
    res = {
        tmdbId: "",
        imdbId: "",
        rawId: "",
        isSeries: false,
        title: "",
        year: "",
        poster: "",
        backdrop: "",
        overview: "",
        genres: "",
        rating: ""
    }
    if item = invalid or Type(item) <> "roAssociativeArray" then return res

    if item.isSeries <> invalid then res.isSeries = (item.isSeries = true)
    if item.title <> invalid then res.title = item.title.ToStr().Trim()
    if item.year <> invalid then res.year = item.year.ToStr().Trim()
    if item.poster <> invalid then res.poster = item.poster.ToStr().Trim()
    if item.backdrop <> invalid then res.backdrop = item.backdrop.ToStr().Trim()
    if item.overview <> invalid then res.overview = item.overview.ToStr().Trim()
    if item.genres <> invalid then res.genres = item.genres.ToStr().Trim()
    if item.rating <> invalid then res.rating = item.rating.ToStr().Trim()

    if item.imdbId <> invalid and item.imdbId.ToStr().Trim() <> "" then
        res.imdbId = item.imdbId.ToStr().Trim()
    end if
    if item.tmdbId <> invalid and IsPureDigits(item.tmdbId.ToStr().Trim()) then
        res.tmdbId = item.tmdbId.ToStr().Trim()
    end if

    if item.id <> invalid then
        idStr = item.id.ToStr().Trim()
        if idStr <> "" then
            res.rawId = idStr
            if Left(LCase(idStr), 2) = "tt" and res.imdbId = "" then
                res.imdbId = idStr
            else if Left(LCase(idStr), 5) = "tmdb:" and res.tmdbId = "" then
                cand = Mid(idStr, 6)
                if IsPureDigits(cand) then res.tmdbId = cand
            else if IsPureDigits(idStr) and idStr <> "0" and res.tmdbId = "" then
                res.tmdbId = idStr
            end if
        end if
    end if

    cache = LoadIdCache()
    cacheDirty = false
    tipoPref = "movie"
    if res.isSeries then tipoPref = "tv"

    ' 1. Tem IMDb ID -> encontra TMDB ID via /find/{imdbId}?external_source=imdb_id
    if res.imdbId <> "" and res.tmdbId = "" then
        cached = cache.imdbToTmdb[res.imdbId]
        if cached <> invalid and Type(cached) = "roAssociativeArray" and cached.tmdbId <> invalid then
            res.tmdbId = cached.tmdbId.ToStr()
            if cached.isSeries <> invalid then res.isSeries = (cached.isSeries = true)
        else
            ut = CreateObject("roUrlTransfer")
            findData = TmdbGetJson("/find/" + ut.Escape(res.imdbId) + "?external_source=imdb_id&language=pt-BR")
            if findData <> invalid then
                matched = invalid
                matchedSeries = res.isSeries
                movies = findData.movie_results
                tvs = findData.tv_results
                if not res.isSeries and movies <> invalid and Type(movies) = "roArray" and movies.Count() > 0 then
                    matched = movies[0]
                    matchedSeries = false
                else if tvs <> invalid and Type(tvs) = "roArray" and tvs.Count() > 0 then
                    matched = tvs[0]
                    matchedSeries = true
                else if movies <> invalid and Type(movies) = "roArray" and movies.Count() > 0 then
                    matched = movies[0]
                    matchedSeries = false
                end if

                if matched <> invalid and matched.id <> invalid then
                    res.tmdbId = matched.id.ToStr()
                    res.isSeries = matchedSeries
                    vodConv = TmdbEntryToVodItem(matched, matchedSeries, "")
                    if vodConv <> invalid then
                        if res.title = "" then res.title = vodConv.title
                        if res.year = "" then res.year = vodConv.year
                        if res.poster = "" then res.poster = vodConv.poster
                        if res.backdrop = "" then res.backdrop = vodConv.backdrop
                        if res.overview = "" then res.overview = vodConv.overview
                        if res.genres = "" then res.genres = vodConv.genres
                        if res.rating = "" then res.rating = vodConv.rating
                    end if
                    tipoMatch = "movie"
                    if matchedSeries then tipoMatch = "tv"
                    cache.imdbToTmdb[res.imdbId] = { tmdbId: res.tmdbId, isSeries: matchedSeries }
                    cache.tmdbToImdb[tipoMatch + ":" + res.tmdbId] = res.imdbId
                    cacheDirty = true
                end if
            end if
        end if
    end if

    ' 2. Tem TMDB ID -> encontra IMDb ID via external_ids
    if res.tmdbId <> "" and res.imdbId = "" then
        tKey = "movie:" + res.tmdbId
        if res.isSeries then tKey = "tv:" + res.tmdbId
        cachedImdb = cache.tmdbToImdb[tKey]
        if cachedImdb <> invalid and cachedImdb.ToStr() <> "" then
            res.imdbId = cachedImdb.ToStr()
        else
            tipoReq = "movie"
            if res.isSeries then tipoReq = "tv"
            ext = TmdbGetJson("/" + tipoReq + "/" + res.tmdbId + "/external_ids")
            if ext <> invalid and ext.imdb_id <> invalid then
                imdbFound = ext.imdb_id.ToStr().Trim()
                if Left(LCase(imdbFound), 2) = "tt" then
                    res.imdbId = imdbFound
                    cache.tmdbToImdb[tKey] = imdbFound
                    cache.imdbToTmdb[imdbFound] = { tmdbId: res.tmdbId, isSeries: res.isSeries }
                    cacheDirty = true
                end if
            end if
        end if
    end if

    ' 3. Item do catálogo local (só título/ano) -> busca no TMDB para obter tmdbId + imdbId
    if res.tmdbId = "" and res.imdbId = "" and res.title <> "" then
        cleanTitle = CleanTitleForTmdbSearch(res.title)
        titleKey = LCase(tipoPref + ":" + cleanTitle + ":" + res.year)
        cachedPair = cache.titleToIds[titleKey]
        if cachedPair <> invalid and Type(cachedPair) = "roAssociativeArray" then
            if cachedPair.tmdbId <> invalid then res.tmdbId = cachedPair.tmdbId.ToStr()
            if cachedPair.imdbId <> invalid then res.imdbId = cachedPair.imdbId.ToStr()
        else if cleanTitle <> "" then
            ut = CreateObject("roUrlTransfer")
            searchPath = "/search/" + tipoPref + "?language=pt-BR&query=" + ut.Escape(cleanTitle)
            if Len(res.year) = 4 and IsPureDigits(res.year) then
                if res.isSeries then
                    searchPath = searchPath + "&first_air_date_year=" + res.year
                else
                    searchPath = searchPath + "&year=" + res.year
                end if
            end if
            sData = TmdbGetJson(searchPath)
            if (sData = invalid or sData.results = invalid or sData.results.Count() = 0) and Len(res.year) = 4 then
                sData = TmdbGetJson("/search/" + tipoPref + "?language=pt-BR&query=" + ut.Escape(cleanTitle))
            end if
            if sData <> invalid and sData.results <> invalid and Type(sData.results) = "roArray" and sData.results.Count() > 0 then
                best = sData.results[0]
                if best <> invalid and best.id <> invalid then
                    res.tmdbId = best.id.ToStr()
                    ext = TmdbGetJson("/" + tipoPref + "/" + res.tmdbId + "/external_ids")
                    if ext <> invalid and ext.imdb_id <> invalid then
                        imdbFound = ext.imdb_id.ToStr().Trim()
                        if Left(LCase(imdbFound), 2) = "tt" then res.imdbId = imdbFound
                    end if
                    cache.titleToIds[titleKey] = { tmdbId: res.tmdbId, imdbId: res.imdbId }
                    if res.imdbId <> "" then
                        cache.tmdbToImdb[tipoPref + ":" + res.tmdbId] = res.imdbId
                        cache.imdbToTmdb[res.imdbId] = { tmdbId: res.tmdbId, isSeries: res.isSeries }
                    end if
                    cacheDirty = true
                end if
            end if
        end if
    end if

    if cacheDirty then SaveIdCache(cache)
    return res
end function

function FetchTmdbDetails(tmdbId as String, isSeries as Boolean) as Dynamic
    if tmdbId = "" then return invalid
    tipo = "movie"
    if isSeries then tipo = "tv"
    data = TmdbGetJson("/" + tipo + "/" + tmdbId + "?language=pt-BR&append_to_response=external_ids")
    if data = invalid then return invalid

    imdbId = ""
    if data.external_ids <> invalid and Type(data.external_ids) = "roAssociativeArray" and data.external_ids.imdb_id <> invalid then
        imdbStr = data.external_ids.imdb_id.ToStr().Trim()
        if Left(LCase(imdbStr), 2) = "tt" then imdbId = imdbStr
    end if

    if imdbId <> "" then
        cache = LoadIdCache()
        cache.tmdbToImdb[tipo + ":" + tmdbId] = imdbId
        cache.imdbToTmdb[imdbId] = { tmdbId: tmdbId, isSeries: isSeries }
        SaveIdCache(cache)
    end if

    conv = TmdbEntryToVodItem(data, isSeries, "")
    if conv = invalid then conv = { id: tmdbId, tmdbId: tmdbId, isSeries: isSeries }
    conv.imdbId = imdbId

    seasons = []
    if isSeries and data.seasons <> invalid and Type(data.seasons) = "roArray" then
        especiais = []
        for each s in data.seasons
            if Type(s) = "roAssociativeArray" and s.season_number <> invalid then
                sn = Int(Val(s.season_number.ToStr()))
                epCnt = 0
                if s.episode_count <> invalid then epCnt = Int(Val(s.episode_count.ToStr()))
                if epCnt > 0 or sn >= 1 then
                    sName = "Temporada " + sn.ToStr()
                    if s.name <> invalid and s.name.ToStr().Trim() <> "" then sName = s.name.ToStr().Trim()
                    if sn = 0 then
                        especiais.Push({ seasonNumber: 0, name: sName, episodeCount: epCnt })
                    else
                        seasons.Push({ seasonNumber: sn, name: sName, episodeCount: epCnt })
                    end if
                end if
            end if
        end for
        if seasons.Count() = 0 and especiais.Count() > 0 then
            seasons.Append(especiais)
        end if
    end if
    conv.seasons = seasons
    return conv
end function

function FetchTmdbSeasonEpisodes(tmdbId as String, seasonNum as Integer) as Object
    if tmdbId = "" then return []
    data = TmdbGetJson("/tv/" + tmdbId + "/season/" + seasonNum.ToStr() + "?language=pt-BR")
    if data = invalid or data.episodes = invalid or Type(data.episodes) <> "roArray" then return []

    eps = []
    for each ep in data.episodes
        if Type(ep) = "roAssociativeArray" and ep.episode_number <> invalid then
            epNum = Int(Val(ep.episode_number.ToStr()))
            epName = "Episódio " + epNum.ToStr()
            if ep.name <> invalid and ep.name.ToStr().Trim() <> "" then epName = ep.name.ToStr().Trim()
            stillUrl = ""
            if ep.still_path <> invalid and ep.still_path.ToStr() <> "" then
                stillUrl = "https://image.tmdb.org/t/p/w300" + ep.still_path.ToStr()
            end if
            ov = ""
            if ep.overview <> invalid then ov = ep.overview.ToStr().Trim()
            air = ""
            if ep.air_date <> invalid then air = ep.air_date.ToStr().Trim()
            eps.Push({
                seasonNumber: seasonNum,
                episodeNumber: epNum,
                name: epName,
                overview: ov,
                stillUrl: stillUrl,
                airDate: air
            })
        end if
    end for
    return eps
end function

function FetchTmdbDiscoveryRails() as Object
    cacheFile = "tmp:/saimo_tmdb_discovery.json"
    agora = CreateObject("roDateTime").AsSeconds()
    fs = CreateObject("roFileSystem")
    if fs.Exists(cacheFile) then
        raw = ReadAsciiFile(cacheFile)
        if raw <> invalid and raw <> "" then
            cached = ParseJson(raw)
            if cached <> invalid and cached.ts <> invalid and (agora - cached.ts) < 1800 and cached.rails <> invalid and cached.vodItems <> invalid then
                return { rails: cached.rails, vodItems: cached.vodItems }
            end if
        end if
    end if

    endpoints = [
        { title: "Filmes em alta (TMDB)", path: "/trending/movie/week?language=pt-BR", isSeries: false, cat: "Filmes" },
        { title: "Séries em alta (TMDB)", path: "/trending/tv/week?language=pt-BR", isSeries: true, cat: "Séries" },
        { title: "Filmes populares (TMDB)", path: "/movie/popular?language=pt-BR", isSeries: false, cat: "Filmes" },
        { title: "Séries populares (TMDB)", path: "/tv/popular?language=pt-BR", isSeries: true, cat: "Séries" }
    ]

    rails = []
    vodItems = []
    seen = {}

    for each ep in endpoints
        data = TmdbGetJson(ep.path)
        if data <> invalid and data.results <> invalid and Type(data.results) = "roArray" then
            railItems = []
            for each r in data.results
                it = TmdbEntryToVodItem(r, ep.isSeries, ep.cat)
                if it <> invalid then
                    railItems.Push(it)
                    k = ep.cat + ":" + it.tmdbId
                    if not seen.DoesExist(k) then
                        seen[k] = true
                        vodItems.Push(it)
                    end if
                    if railItems.Count() >= 20 then exit for
                end if
            end for
            if railItems.Count() > 0 then
                rails.Push({ title: ep.title, isSeries: ep.isSeries, source: "tmdb", items: railItems })
            end if
        end if
    end for

    if rails.Count() > 0 then
        WriteAsciiFile(cacheFile, FormatJson({ ts: agora, rails: rails, vodItems: vodItems }))
    end if
    return { rails: rails, vodItems: vodItems }
end function
