' ====================================================================
' Saimo TV - AddonCatalogTask (BrightScript)
' Busca paralela de catálogos Stremio (/catalog/{type}/{id}.json) e
' descoberta/busca TMDB para desbloquear Início, On Demand e Busca
' quando o usuário possui Addons ativos mesmo sem lista M3U/VOD local.
' ====================================================================

sub init()
    m.top.functionName = "executar"
end sub

sub executar()
    modo = LCase(m.top.mode.Trim())
    if modo = "search" then
        executarBusca()
    else
        executarDescoberta()
    end if
end sub

function CatalogHasRequiredExtra(cat as Object) as Boolean
    if cat.extra = invalid or Type(cat.extra) <> "roArray" then return false
    for each ex in cat.extra
        if Type(ex) = "roAssociativeArray" and ex.isRequired = true then
            return true
        end if
    end for
    return false
end function

function CatalogSupportsSearch(cat as Object) as Boolean
    if cat.extra = invalid or Type(cat.extra) <> "roArray" then return false
    for each ex in cat.extra
        if Type(ex) = "roAssociativeArray" and ex.name <> invalid and LCase(ex.name.ToStr()) = "search" then
            return true
        end if
    end for
    return false
end function

function StremioMetaToVodItem(meta as Object, addon as Object, defaultType as String, railTitle as String) as Dynamic
    if meta = invalid or Type(meta) <> "roAssociativeArray" then return invalid
    mId = ""
    if meta.id <> invalid then mId = meta.id.ToStr().Trim()
    mName = ""
    if meta.name <> invalid then mName = meta.name.ToStr().Trim()
    if mId = "" or mName = "" then return invalid

    mType = defaultType
    if meta["type"] <> invalid and meta["type"].ToStr().Trim() <> "" then
        mType = LCase(meta["type"].ToStr().Trim())
    end if
    isSeries = (mType = "series" or mType = "tv" or mType = "anime")

    imdbId = ""
    tmdbId = ""
    if Left(LCase(mId), 2) = "tt" then
        imdbId = mId
    else if Left(LCase(mId), 5) = "tmdb:" then
        tmdbId = Mid(mId, 6)
    end if

    poster = ""
    if meta.poster <> invalid then poster = meta.poster.ToStr().Trim()
    backdrop = poster
    if meta.background <> invalid and meta.background.ToStr().Trim() <> "" then
        backdrop = meta.background.ToStr().Trim()
    end if

    yr = ""
    if meta.releaseInfo <> invalid then yr = meta.releaseInfo.ToStr().Trim()
    if yr = "" and meta.year <> invalid then yr = meta.year.ToStr().Trim()
    if Len(yr) > 4 and Instr(1, yr, "-") > 0 then yr = Left(yr, 4)

    genres = ""
    if meta.genres <> invalid and Type(meta.genres) = "roArray" then
        gArr = []
        for each g in meta.genres
            if g <> invalid then gArr.Push(g.ToStr())
        end for
        genres = gArr.Join(", ")
    end if

    ov = ""
    if meta.description <> invalid then ov = meta.description.ToStr().Trim()
    rating = ""
    if meta.imdbRating <> invalid then rating = meta.imdbRating.ToStr().Trim()

    aId = ""
    if addon <> invalid and addon.id <> invalid then aId = addon.id
    catLabel = railTitle
    if mType = "anime" and Instr(1, LCase(catLabel), "anime") = 0 then
        catLabel = "Anime · " + catLabel
    end if

    return {
        id: mId,
        imdbId: imdbId,
        tmdbId: tmdbId,
        title: mName,
        isSeries: isSeries,
        year: yr,
        poster: poster,
        backdrop: backdrop,
        overview: ov,
        genres: genres,
        rating: rating,
        category: catLabel,
        letter: UCase(Left(mName, 1)),
        addonId: aId,
        sourceType: "addon"
    }
end function

sub executarDescoberta()
    addons = GetEnabledAddons()
    if addons.Count() = 0 then
        m.top.responseRails = []
        m.top.responseVodItems = []
        return
    end if

    rails = []
    vodItems = []
    seenKeys = {}

    ' 1. Coleta até 6 catálogos de addons habilitados
    reqs = []
    agora = CreateObject("roDateTime").AsSeconds()
    fs = CreateObject("roFileSystem")

    for each addon in addons
        if reqs.Count() >= 6 then exit for
        manifest = GetAddonManifestCached(addon, true)
        if manifest <> invalid and manifest.catalogs <> invalid and Type(manifest.catalogs) = "roArray" then
            for each cat in manifest.catalogs
                if reqs.Count() >= 6 then exit for
                if Type(cat) = "roAssociativeArray" and cat["type"] <> invalid and cat.id <> invalid and not CatalogHasRequiredExtra(cat) then
                    cType = cat["type"].ToStr().Trim()
                    cId = cat.id.ToStr().Trim()
                    if cType = "movie" or cType = "series" or cType = "anime" then
                        cTitle = addon.name
                        if cat.name <> invalid and cat.name.ToStr().Trim() <> "" then
                            cTitle = cat.name.ToStr().Trim() + " · " + addon.name
                        end if
                        route = "catalog/" + cType + "/" + EncodeUrlPathSegment(cId) + ".json"
                        url = BuildAddonRouteUrl(addon, route)
                        cacheFile = "tmp:/saimo_cat_" + AddonSha1Prefix(url) + ".json"
                        cachedUsed = false
                        if fs.Exists(cacheFile) then
                            raw = ReadAsciiFile(cacheFile)
                            if raw <> invalid and raw <> "" then
                                parsedCache = ParseJson(raw)
                                if parsedCache <> invalid and parsedCache.ts <> invalid and (agora - parsedCache.ts) < 900 and parsedCache.items <> invalid then
                                    rails.Push({ title: cTitle, isSeries: (cType <> "movie"), source: "addon", items: parsedCache.items })
                                    for each it in parsedCache.items
                                        dk = it.id + ":" + it.title
                                        if not seenKeys.DoesExist(dk) then
                                            seenKeys[dk] = true
                                            vodItems.Push(it)
                                        end if
                                    end for
                                    cachedUsed = true
                                end if
                            end if
                        end if
                        if not cachedUsed and url <> "" then
                            reqs.Push({ url: url, addon: addon, cType: cType, title: cTitle, cacheFile: cacheFile })
                        end if
                    end if
                end if
            end for
        end if
    end for

    ' Dispara pedidos paralelos para catálogos sem cache fresco
    if reqs.Count() > 0 then
        porta = CreateObject("roMessagePort")
        emVoo = {}
        for each r in reqs
            ut = CreateObject("roUrlTransfer")
            ut.SetMessagePort(porta)
            ut.SetUrl(r.url)
            ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
            ut.InitClientCertificates()
            ut.RetainBodyOnError(true)
            ut.AddHeader("User-Agent", "SaimoTV/3.0.5 (RokuOS)")
            if ut.AsyncGetToString() then
                r.ut = ut
                emVoo[ut.GetIdentity().ToStr()] = r
            end if
        end for

        timer = CreateObject("roTimespan")
        while emVoo.Count() > 0 and timer.TotalMilliseconds() < 7500
            restante = 7500 - timer.TotalMilliseconds()
            if restante <= 0 then exit while
            msg = Wait(restante, porta)
            if msg = invalid then exit while
            if Type(msg) = "roUrlEvent" then
                sid = msg.GetSourceIdentity().ToStr()
                reqObj = emVoo[sid]
                if reqObj <> invalid then
                    emVoo.Delete(sid)
                    if msg.GetResponseCode() >= 200 and msg.GetResponseCode() < 300 then
                        parsed = ParseJson(msg.GetString())
                        if parsed <> invalid and parsed.metas <> invalid and Type(parsed.metas) = "roArray" then
                            rItems = []
                            for each meta in parsed.metas
                                vod = StremioMetaToVodItem(meta, reqObj.addon, reqObj.cType, reqObj.title)
                                if vod <> invalid then
                                    rItems.Push(vod)
                                    dk = vod.id + ":" + vod.title
                                    if not seenKeys.DoesExist(dk) then
                                        seenKeys[dk] = true
                                        vodItems.Push(vod)
                                    end if
                                    if rItems.Count() >= 25 then exit for
                                end if
                            end for
                            if rItems.Count() > 0 then
                                rails.Push({ title: reqObj.title, isSeries: (reqObj.cType <> "movie"), source: "addon", items: rItems })
                                WriteAsciiFile(reqObj.cacheFile, FormatJson({ ts: agora, items: rItems }))
                            end if
                        end if
                    end if
                end if
            end if
        end while
        for each sid in emVoo
            emVoo[sid].ut.AsyncCancel()
        end for
    end if

    ' 2. Descoberta TMDB (desbloqueia Filmes/Séries quando não há lista VOD local)
    if m.top.includeTmdbDiscovery = true or rails.Count() = 0 then
        tmdbRes = FetchTmdbDiscoveryRails()
        if tmdbRes <> invalid then
            if tmdbRes.rails <> invalid then
                for each tr in tmdbRes.rails
                    rails.Push(tr)
                end for
            end if
            if tmdbRes.vodItems <> invalid then
                for each it in tmdbRes.vodItems
                    dk = it.id + ":" + it.title
                    if not seenKeys.DoesExist(dk) then
                        seenKeys[dk] = true
                        vodItems.Push(it)
                    end if
                end for
            end if
        end if
    end if

    m.top.responseRails = rails
    m.top.responseVodItems = vodItems
end sub

sub executarBusca()
    q = m.top.searchQuery.Trim()
    raiz = CreateObject("roSGNode", "ContentNode")
    if q = "" or GetEnabledAddons().Count() = 0 then
        m.top.searchResults = raiz
        return
    end if

    utEsc = CreateObject("roUrlTransfer")
    escapedQ = utEsc.Escape(q)

    ' Busca TMDB filmes e séries
    tmdbFilmes = []
    tmdbSeries = []
    fData = TmdbGetJson("/search/movie?language=pt-BR&query=" + escapedQ)
    if fData <> invalid and fData.results <> invalid and Type(fData.results) = "roArray" then
        for each r in fData.results
            it = TmdbEntryToVodItem(r, false, "Filmes")
            if it <> invalid then tmdbFilmes.Push(it)
            if tmdbFilmes.Count() >= 20 then exit for
        end for
    end if
    sData = TmdbGetJson("/search/tv?language=pt-BR&query=" + escapedQ)
    if sData <> invalid and sData.results <> invalid and Type(sData.results) = "roArray" then
        for each r in sData.results
            it = TmdbEntryToVodItem(r, true, "Séries")
            if it <> invalid then tmdbSeries.Push(it)
            if tmdbSeries.Count() >= 20 then exit for
        end for
    end if

    ' Busca nos catálogos de addons que declaram extra "search"
    addonHits = []
    addons = GetEnabledAddons()
    searchReqs = []
    for each addon in addons
        if searchReqs.Count() >= 4 then exit for
        manifest = GetAddonManifestCached(addon, false)
        if manifest <> invalid and manifest.catalogs <> invalid and Type(manifest.catalogs) = "roArray" then
            for each cat in manifest.catalogs
                if searchReqs.Count() >= 4 then exit for
                if Type(cat) = "roAssociativeArray" and cat["type"] <> invalid and cat.id <> invalid and CatalogSupportsSearch(cat) then
                    cType = cat["type"].ToStr().Trim()
                    cId = cat.id.ToStr().Trim()
                    route = "catalog/" + cType + "/" + EncodeUrlPathSegment(cId) + "/search=" + EncodeUrlPathSegment(q) + ".json"
                    url = BuildAddonRouteUrl(addon, route)
                    if url <> "" then searchReqs.Push({ url: url, addon: addon, cType: cType })
                end if
            end for
        end if
    end for

    if searchReqs.Count() > 0 then
        porta = CreateObject("roMessagePort")
        emVoo = {}
        for each r in searchReqs
            ut = CreateObject("roUrlTransfer")
            ut.SetMessagePort(porta)
            ut.SetUrl(r.url)
            ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
            ut.InitClientCertificates()
            ut.AddHeader("User-Agent", "SaimoTV/3.0.5 (RokuOS)")
            if ut.AsyncGetToString() then
                r.ut = ut
                emVoo[ut.GetIdentity().ToStr()] = r
            end if
        end for
        timer = CreateObject("roTimespan")
        while emVoo.Count() > 0 and timer.TotalMilliseconds() < 5000
            restante = 5000 - timer.TotalMilliseconds()
            if restante <= 0 then exit while
            msg = Wait(restante, porta)
            if msg = invalid then exit while
            if Type(msg) = "roUrlEvent" then
                sid = msg.GetSourceIdentity().ToStr()
                reqObj = emVoo[sid]
                if reqObj <> invalid then
                    emVoo.Delete(sid)
                    if msg.GetResponseCode() >= 200 and msg.GetResponseCode() < 300 then
                        parsed = ParseJson(msg.GetString())
                        if parsed <> invalid and parsed.metas <> invalid and Type(parsed.metas) = "roArray" then
                            for each meta in parsed.metas
                                vod = StremioMetaToVodItem(meta, reqObj.addon, reqObj.cType, reqObj.addon.name)
                                if vod <> invalid then addonHits.Push(vod)
                                if addonHits.Count() >= 25 then exit for
                            end for
                        end if
                    end if
                end if
            end if
        end while
        for each sid in emVoo
            emVoo[sid].ut.AsyncCancel()
        end for
    end if

    gruposBusca = [
        { titulo: "Filmes (TMDB)", itens: tmdbFilmes },
        { titulo: "Séries (TMDB)", itens: tmdbSeries },
        { titulo: "Catálogos de Addons", itens: addonHits }
    ]
    for each gb in gruposBusca
        if gb.itens.Count() > 0 then
            linha = raiz.CreateChild("ContentNode")
            linha.title = gb.titulo
            for each it in gb.itens
                no = linha.CreateChild("ContentNode")
                no.title = it.title
                if it.poster <> invalid and it.poster <> "" then no.hdPosterUrl = it.poster
                no.addFields({ itemType: "vod", item: it })
            end for
        end if
    end for

    m.top.searchResults = raiz
end sub
