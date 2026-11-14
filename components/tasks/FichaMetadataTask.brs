' ====================================================================
' Saimo TV - FichaMetadataTask (BrightScript)
' Carrega detalhes reais do TMDB (com external_ids -> imdbId),
' lista de temporadas e episódios reais da temporada selecionada,
' com fallback para rota /meta/ de Addons Stremio quando necessário.
' ====================================================================

sub init()
    m.top.functionName = "executar"
end sub

sub executar()
    item = m.top.item
    if item = invalid then return

    ids = ResolveIdsForItem(item)
    isSeries = ids.isSeries
    reqSeason = m.top.seasonNumber
    if reqSeason < 0 then reqSeason = 1

    out = {
        ok: false,
        tmdbId: ids.tmdbId,
        imdbId: ids.imdbId,
        rawId: ids.rawId,
        title: ids.title,
        overview: ids.overview,
        genres: ids.genres,
        year: ids.year,
        rating: ids.rating,
        poster: ids.poster,
        backdrop: ids.backdrop,
        isSeries: isSeries,
        seasons: [],
        seasonNumber: reqSeason,
        episodes: []
    }

    if ids.tmdbId <> "" then
        det = FetchTmdbDetails(ids.tmdbId, isSeries)
        if det <> invalid then
            out.ok = true
            if det.imdbId <> invalid and det.imdbId <> "" then out.imdbId = det.imdbId
            if det.title <> invalid and det.title <> "" then out.title = det.title
            if det.overview <> invalid and det.overview <> "" then out.overview = det.overview
            if det.genres <> invalid and det.genres <> "" then out.genres = det.genres
            if det.year <> invalid and det.year <> "" then out.year = det.year
            if det.rating <> invalid and det.rating <> "" then out.rating = det.rating
            if det.poster <> invalid and det.poster <> "" and out.poster = "" then out.poster = det.poster
            if det.backdrop <> invalid and det.backdrop <> "" and out.backdrop = "" then out.backdrop = det.backdrop
            if det.seasons <> invalid then out.seasons = det.seasons
        end if

        if isSeries then
            targetSeason = reqSeason
            if out.seasons.Count() > 0 then
                found = false
                for each s in out.seasons
                    if s.seasonNumber = targetSeason then
                        found = true
                        exit for
                    end if
                end for
                if not found then targetSeason = out.seasons[0].seasonNumber
            end if
            out.seasonNumber = targetSeason
            out.episodes = FetchTmdbSeasonEpisodes(ids.tmdbId, targetSeason)
        end if
    end if

    ' Fallback para rota /meta/{type}/{id}.json em Addons habilitados se faltam episódios ou detalhes
    if (isSeries and out.episodes.Count() = 0) or (not out.ok) then
        mediaType = "movie"
        if isSeries then mediaType = "series"
        addons = GetEnabledAddons()
        for each addon in addons
            qId = AddonResolveQueryId(addon, "meta", mediaType, ids, 1, 1)
            if qId <> "" then
                url = BuildAddonRouteUrl(addon, "meta/" + mediaType + "/" + EncodeUrlPathSegment(qId) + ".json")
                resp = HttpTransferAsync("GET", url, invalid, "", 7000)
                if resp.ok and resp.body <> "" then
                    parsed = ParseJson(resp.body)
                    if parsed <> invalid and parsed.meta <> invalid and Type(parsed.meta) = "roAssociativeArray" then
                        meta = parsed.meta
                        out.ok = true
                        if out.overview = "" and meta.description <> invalid then out.overview = meta.description.ToStr()
                        if out.poster = "" and meta.poster <> invalid then out.poster = meta.poster.ToStr()
                        if out.backdrop = "" and meta.background <> invalid then out.backdrop = meta.background.ToStr()
                        if isSeries and meta.videos <> invalid and Type(meta.videos) = "roArray" and meta.videos.Count() > 0 then
                            seasonMap = {}
                            seasonNums = []
                            epsBySeason = {}
                            for each v in meta.videos
                                if Type(v) = "roAssociativeArray" then
                                    sn = 1
                                    if v.season <> invalid then sn = Int(Val(v.season.ToStr()))
                                    en = 1
                                    if v.episode <> invalid then en = Int(Val(v.episode.ToStr()))
                                    if v.number <> invalid and v.episode = invalid then en = Int(Val(v.number.ToStr()))
                                    sk = sn.ToStr()
                                    if not seasonMap.DoesExist(sk) then
                                        seasonMap[sk] = true
                                        seasonNums.Push(sn)
                                        epsBySeason[sk] = []
                                    end if
                                    epTitle = "Episódio " + en.ToStr()
                                    if v.title <> invalid and v.title.ToStr().Trim() <> "" then epTitle = v.title.ToStr().Trim()
                                    if v.name <> invalid and v.name.ToStr().Trim() <> "" then epTitle = v.name.ToStr().Trim()
                                    thumb = ""
                                    if v.thumbnail <> invalid then thumb = v.thumbnail.ToStr().Trim()
                                    epOv = ""
                                    if v.overview <> invalid then epOv = v.overview.ToStr().Trim()
                                    epsBySeason[sk].Push({
                                        seasonNumber: sn,
                                        episodeNumber: en,
                                        name: epTitle,
                                        overview: epOv,
                                        stillUrl: thumb,
                                        rawVideoId: v.id
                                    })
                                end if
                            end for
                            if seasonNums.Count() > 0 then
                                seasonNums.Sort()
                                seasonsList = []
                                for each sn in seasonNums
                                    sk = sn.ToStr()
                                    if sn > 0 or seasonNums.Count() = 1 then
                                        seasonsList.Push({ seasonNumber: sn, name: "Temporada " + sn.ToStr(), episodeCount: epsBySeason[sk].Count() })
                                    end if
                                end for
                                out.seasons = seasonsList
                                targetSk = reqSeason.ToStr()
                                if not epsBySeason.DoesExist(targetSk) and seasonsList.Count() > 0 then
                                    out.seasonNumber = seasonsList[0].seasonNumber
                                    targetSk = out.seasonNumber.ToStr()
                                end if
                                if epsBySeason.DoesExist(targetSk) then
                                    epsArr = epsBySeason[targetSk]
                                    epsArr.SortBy("episodeNumber")
                                    out.episodes = epsArr
                                end if
                                exit for
                            end if
                        end if
                    end if
                end if
            end if
        end for
    end if

    m.top.metadataResult = out
end sub
