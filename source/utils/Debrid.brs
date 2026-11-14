' ====================================================================
' Saimo TV - Debrid Helpers & Client-Side REST Resolver (BrightScript)
' Suporte limpo via REST HTTPS para TorBox, Real-Debrid, AllDebrid e Premiumize.
' Armazenado em secao dedicada "saimo_debrid" (< 16 KB). Zero P2P local.
' ====================================================================

function GetDebridRegistry() as Object
    return CreateObject("roRegistrySection", "saimo_debrid")
end function

function GetDefaultDebridConfig() as Object
    return {
        sincronizarConnect: false,
        providers: {
            torbox: { apiKey: "", enabled: false },
            realDebrid: { apiKey: "", enabled: false },
            allDebrid: { apiKey: "", enabled: false },
            premiumize: { apiKey: "", enabled: false }
        }
    }
end function

function DebridCanonicalProviderKey(rawKey as String) as String
    k = LCase(rawKey.Trim()).Replace("-", "").Replace("_", "")
    if k = "torbox" then return "torbox"
    if k = "realdebrid" or k = "rd" then return "realDebrid"
    if k = "alldebrid" or k = "ad" then return "allDebrid"
    if k = "premiumize" or k = "pm" then return "premiumize"
    return ""
end function

function DebridProviderDisplayName(key as String) as String
    if key = "torbox" then return "TorBox"
    if key = "realDebrid" then return "Real-Debrid"
    if key = "allDebrid" then return "AllDebrid"
    if key = "premiumize" then return "Premiumize"
    return key
end function

function SanitizeDebridConfig(rawCfg as Dynamic) as Object
    cfg = GetDefaultDebridConfig()
    if rawCfg = invalid or Type(rawCfg) <> "roAssociativeArray" then return cfg

    if rawCfg.DoesExist("sincronizarConnect") and rawCfg.sincronizarConnect <> invalid then
        cfg.sincronizarConnect = (rawCfg.sincronizarConnect = true)
    else if rawCfg.DoesExist("syncWithConnect") and rawCfg.syncWithConnect <> invalid then
        cfg.sincronizarConnect = (rawCfg.syncWithConnect = true)
    end if

    rawProviders = invalid
    if rawCfg.DoesExist("providers") and rawCfg.providers <> invalid and Type(rawCfg.providers) = "roAssociativeArray" then
        rawProviders = rawCfg.providers
    end if

    if rawProviders <> invalid then
        for each k in rawProviders
            canon = DebridCanonicalProviderKey(k)
            if canon <> "" then
                src = rawProviders[k]
                if src <> invalid and Type(src) = "roAssociativeArray" then
                    apiKey = ""
                    if src.DoesExist("apiKey") and src.apiKey <> invalid then apiKey = src.apiKey.ToStr().Trim()
                    if apiKey = "" and src.DoesExist("key") and src.key <> invalid then apiKey = src.key.ToStr().Trim()
                    enabled = false
                    if src.DoesExist("enabled") and src.enabled <> invalid then enabled = (src.enabled = true)
                    if apiKey = "" then enabled = false
                    cfg.providers[canon] = {
                        apiKey: apiKey,
                        enabled: enabled
                    }
                end if
            end if
        end for
    end if

    return cfg
end function

function LoadDebridConfig() as Object
    reg = GetDebridRegistry()
    raw = reg.Read("config")
    if raw = "" then return GetDefaultDebridConfig()
    parsed = ParseJson(raw)
    return SanitizeDebridConfig(parsed)
end function

sub SaveDebridConfig(cfg as Object)
    clean = SanitizeDebridConfig(cfg)
    reg = GetDebridRegistry()
    reg.Write("config", FormatJson(clean))
    reg.Flush()
end sub

function GetEnabledDebridProviders() as Object
    cfg = LoadDebridConfig()
    order = ["torbox", "realDebrid", "allDebrid", "premiumize"]
    active = []
    for each k in order
        p = cfg.providers[k]
        if p <> invalid and p.enabled = true and p.apiKey <> invalid and p.apiKey.Trim() <> "" then
            active.Push({ id: k, name: DebridProviderDisplayName(k), apiKey: p.apiKey.Trim() })
        end if
    end for
    return active
end function

function HasAnyDebridConfigured() as Boolean
    return GetEnabledDebridProviders().Count() > 0
end function

function DebridMaskKey(apiKey as String) as String
    k = apiKey.Trim()
    if k = "" then return ""
    if Len(k) <= 6 then return "***"
    return Left(k, 3) + "..." + Right(k, 3)
end function

function BuildMagnetUri(infoHash as String, displayName = "" as String, sources = invalid as Dynamic) as String
    h = infoHash.Trim()
    if h = "" then return ""
    ut = CreateObject("roUrlTransfer")
    magnet = "magnet:?xt=urn:btih:" + h
    if displayName <> "" then
        magnet = magnet + "&dn=" + ut.Escape(displayName.Trim())
    end if
    if sources <> invalid and Type(sources) = "roArray" then
        added = 0
        for each src in sources
            if src <> invalid then
                s = src.ToStr().Trim()
                tr = ""
                if Left(LCase(s), 8) = "tracker:" then
                    tr = Mid(s, 9).Trim()
                else if Left(LCase(s), 7) = "http://" or Left(LCase(s), 8) = "https://" or Left(LCase(s), 6) = "udp://" then
                    tr = s
                end if
                if tr <> "" then
                    magnet = magnet + "&tr=" + ut.Escape(tr)
                    added = added + 1
                    if added >= 8 then exit for
                end if
            end if
        end for
    end if
    return magnet
end function

function DebridHttpRequest(method as String, url as String, headers = invalid as Dynamic, body = "" as String, timeoutMs = 12000 as Integer) as Object
    ut = CreateObject("roUrlTransfer")
    porta = CreateObject("roMessagePort")
    ut.SetMessagePort(porta)
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.InitClientCertificates()
    ut.RetainBodyOnError(true)
    ut.AddHeader("User-Agent", "SaimoTV/3.0.5 (RokuOS)")

    if headers <> invalid and Type(headers) = "roAssociativeArray" then
        for each hk in headers
            hv = headers[hk]
            if hv <> invalid then
                cleanKey = hk.ToStr().Replace(Chr(13), "").Replace(Chr(10), "").Trim()
                cleanVal = hv.ToStr().Replace(Chr(13), "").Replace(Chr(10), "").Trim()
                if cleanKey <> "" and cleanVal <> "" then
                    ut.AddHeader(cleanKey, cleanVal)
                end if
            end if
        end for
    end if

    upperMethod = UCase(method)
    started = false
    if upperMethod = "POST" then
        ut.SetRequest("POST")
        started = ut.AsyncPostFromString(body)
    else if upperMethod = "DELETE" then
        ut.SetRequest("DELETE")
        started = ut.AsyncGetToString()
    else
        ut.SetRequest("GET")
        started = ut.AsyncGetToString()
    end if

    if not started then
        return { ok: false, status: 0, body: "", json: invalid, error: "Falha ao iniciar requisição HTTPS" }
    end if

    msg = Wait(timeoutMs, porta)
    if msg = invalid then
        ut.AsyncCancel()
        return { ok: false, status: 0, body: "", json: invalid, error: "Tempo esgotado na conexão com o servidor Debrid" }
    end if

    code = msg.GetResponseCode()
    respBody = msg.GetString()
    if respBody = invalid then respBody = ""
    parsed = invalid
    if respBody.Trim() <> "" then
        parsed = ParseJson(respBody)
    end if
    return { ok: (code >= 200 and code < 300), status: code, body: respBody, json: parsed, error: "" }
end function

function DebridIsVideoFile(filePath as String) as Boolean
    l = LCase(filePath.Trim())
    exts = [".mp4", ".mkv", ".m4v", ".mov", ".m3u8", ".ts", ".avi", ".webm"]
    for each e in exts
        if Right(l, Len(e)) = e then return true
    end for
    return false
end function

function DebridPickVideoFile(files as Object, fileIdx = invalid as Dynamic) as Dynamic
    if files = invalid or Type(files) <> "roArray" or files.Count() = 0 then return invalid

    if fileIdx <> invalid then
        idx = Val(fileIdx.ToStr())
        if idx >= 0 and idx < files.Count() then
            cand = files[idx]
            if cand <> invalid then
                p = ""
                if cand.name <> invalid then p = cand.name.ToStr()
                if p = "" and cand.path <> invalid then p = cand.path.ToStr()
                if p = "" and cand.short_name <> invalid then p = cand.short_name.ToStr()
                if p = "" or DebridIsVideoFile(p) then return { index: idx, file: cand }
            end if
        end if
    end if

    bestIdx = -1
    bestSize = -1
    for i = 0 to files.Count() - 1
        f = files[i]
        if f <> invalid then
            p = ""
            if f.name <> invalid then p = f.name.ToStr()
            if p = "" and f.path <> invalid then p = f.path.ToStr()
            if p = "" and f.short_name <> invalid then p = f.short_name.ToStr()
            sz = 0
            if f.size <> invalid then sz = Val(f.size.ToStr())
            if sz = 0 and f.bytes <> invalid then sz = Val(f.bytes.ToStr())
            if DebridIsVideoFile(p) and Instr(1, LCase(p), "sample") = 0 then
                if sz >= bestSize then
                    bestSize = sz
                    bestIdx = i
                end if
            end if
        end if
    end for

    if bestIdx >= 0 then return { index: bestIdx, file: files[bestIdx] }

    ' Fallback: maior arquivo qualquer
    for i = 0 to files.Count() - 1
        f = files[i]
        if f <> invalid then
            sz = 0
            if f.size <> invalid then sz = Val(f.size.ToStr())
            if sz = 0 and f.bytes <> invalid then sz = Val(f.bytes.ToStr())
            if sz >= bestSize then
                bestSize = sz
                bestIdx = i
            end if
        end if
    end for

    if bestIdx >= 0 then return { index: bestIdx, file: files[bestIdx] }
    return invalid
end function

function ResolveTorBoxTorrent(apiKey as String, infoHash as String, fileIdx as Dynamic, magnet as String) as Object
    base = "https://api.torbox.app/v1/api"
    headers = {
        "Authorization": "Bearer " + apiKey,
        "Content-Type": "application/x-www-form-urlencoded"
    }
    ut = CreateObject("roUrlTransfer")
    body = "magnet=" + ut.Escape(magnet) + "&seed=1&allow_zip=false"
    resp = DebridHttpRequest("POST", base + "/torrents/createtorrent", headers, body, 12000)
    if not resp.ok or resp.json = invalid or resp.json.success <> true then
        errMsg = "TorBox recusou o torrent."
        if resp.json <> invalid and resp.json.detail <> invalid then errMsg = "TorBox: " + resp.json.detail.ToStr()
        return { ok: false, url: "", error: errMsg }
    end if

    data = resp.json.data
    if data = invalid or data.torrent_id = invalid then
        return { ok: false, url: "", error: "TorBox não retornou torrent_id." }
    end if
    tid = data.torrent_id.ToStr()

    ' Consulta detalhes (até 3 tentativas curtas para torrents em cache)
    getHeaders = { "Authorization": "Bearer " + apiKey }
    torrentObj = invalid
    for tentativa = 1 to 3
        infoResp = DebridHttpRequest("GET", base + "/torrents/mylist?id=" + ut.Escape(tid), getHeaders, "", 10000)
        if infoResp.ok and infoResp.json <> invalid and infoResp.json.data <> invalid then
            d = infoResp.json.data
            if Type(d) = "roArray" and d.Count() > 0 then d = d[0]
            if Type(d) = "roAssociativeArray" and d.files <> invalid and Type(d.files) = "roArray" and d.files.Count() > 0 then
                if d.download_present = true or d.cached = true or d.download_finished = true then
                    torrentObj = d
                    exit for
                end if
                torrentObj = d
            end if
        end if
        if tentativa < 3 then Sleep(1200)
    end for

    if torrentObj = invalid or torrentObj.files = invalid or torrentObj.files.Count() = 0 then
        return { ok: false, url: "", error: "TorBox: torrent ainda sem arquivos prontos (não está em cache)." }
    end if

    if torrentObj.download_present <> true and torrentObj.download_finished <> true and torrentObj.cached <> true then
        return { ok: false, url: "", error: "TorBox: este torrent ainda está baixando no servidor e não está pronto." }
    end if

    picked = DebridPickVideoFile(torrentObj.files, fileIdx)
    if picked = invalid or picked.file = invalid or picked.file.id = invalid then
        return { ok: false, url: "", error: "TorBox: nenhum arquivo de vídeo compatível encontrado." }
    end if
    fid = picked.file.id.ToStr()

    dlUrl = base + "/torrents/requestdl?token=" + ut.Escape(apiKey) + "&torrent_id=" + ut.Escape(tid) + "&file_id=" + ut.Escape(fid) + "&zip_link=false"
    dlResp = DebridHttpRequest("GET", dlUrl, getHeaders, "", 10000)
    if dlResp.ok and dlResp.json <> invalid and dlResp.json.success = true and dlResp.json.data <> invalid then
        finalUrl = dlResp.json.data.ToStr().Trim()
        if finalUrl <> "" then return { ok: true, url: finalUrl, provider: "TorBox", error: "" }
    end if

    return { ok: false, url: "", error: "TorBox: não foi possível gerar o link de reprodução." }
end function

function ResolveRealDebridTorrent(apiKey as String, infoHash as String, fileIdx as Dynamic, magnet as String) as Object
    base = "https://api.real-debrid.com/rest/1.0"
    headers = {
        "Authorization": "Bearer " + apiKey,
        "Content-Type": "application/x-www-form-urlencoded"
    }
    getHeaders = { "Authorization": "Bearer " + apiKey }
    ut = CreateObject("roUrlTransfer")

    addResp = DebridHttpRequest("POST", base + "/torrents/addMagnet", headers, "magnet=" + ut.Escape(magnet), 12000)
    if not addResp.ok or addResp.json = invalid or addResp.json.id = invalid then
        errMsg = "Real-Debrid: falha ao enviar magnet."
        if addResp.status = 401 then errMsg = "Real-Debrid: chave de API inválida ou expirada."
        if addResp.json <> invalid and addResp.json.error <> invalid then errMsg = "Real-Debrid: " + addResp.json.error.ToStr()
        return { ok: false, url: "", error: errMsg }
    end if
    tid = addResp.json.id.ToStr()

    info = invalid
    for tentativa = 1 to 4
        ir = DebridHttpRequest("GET", base + "/torrents/info/" + ut.Escape(tid), getHeaders, "", 10000)
        if ir.ok and ir.json <> invalid then
            info = ir.json
            st = ""
            if info.status <> invalid then st = LCase(info.status.ToStr())
            if st <> "magnet_conversion" and st <> "queued" then exit for
        end if
        if tentativa < 4 then Sleep(1000)
    end for

    if info = invalid then
        return { ok: false, url: "", error: "Real-Debrid: falha ao consultar informações do torrent." }
    end if

    st = ""
    if info.status <> invalid then st = LCase(info.status.ToStr())
    if st = "waiting_files_selection" then
        files = info.files
        if files = invalid or Type(files) <> "roArray" or files.Count() = 0 then
            return { ok: false, url: "", error: "Real-Debrid: torrent sem lista de arquivos." }
        end if
        picked = DebridPickVideoFile(files, fileIdx)
        if picked = invalid or picked.file = invalid or picked.file.id = invalid then
            return { ok: false, url: "", error: "Real-Debrid: arquivo de vídeo não encontrado." }
        end if
        selId = picked.file.id.ToStr()
        selResp = DebridHttpRequest("POST", base + "/torrents/selectFiles/" + ut.Escape(tid), headers, "files=" + ut.Escape(selId), 10000)
        if not selResp.ok then
            return { ok: false, url: "", error: "Real-Debrid: falha ao selecionar arquivo." }
        end if
        for tentativa = 1 to 3
            ir2 = DebridHttpRequest("GET", base + "/torrents/info/" + ut.Escape(tid), getHeaders, "", 10000)
            if ir2.ok and ir2.json <> invalid then
                info = ir2.json
                st = ""
                if info.status <> invalid then st = LCase(info.status.ToStr())
                if st = "downloaded" then exit for
            end if
            if tentativa < 3 then Sleep(1000)
        end for
    end if

    if st <> "downloaded" or info.links = invalid or Type(info.links) <> "roArray" or info.links.Count() = 0 then
        return { ok: false, url: "", error: "Real-Debrid: torrent não está em cache instantâneo no servidor." }
    end if

    rawLink = info.links[0].ToStr().Trim()
    unResp = DebridHttpRequest("POST", base + "/unrestrict/link", headers, "link=" + ut.Escape(rawLink), 10000)
    if unResp.ok and unResp.json <> invalid and unResp.json.download <> invalid then
        dl = unResp.json.download.ToStr().Trim()
        if dl <> "" then return { ok: true, url: dl, provider: "Real-Debrid", error: "" }
    end if

    return { ok: false, url: "", error: "Real-Debrid: falha ao desbloquear link de download." }
end function

sub DebridCollectAllDebridFiles(nodes as Dynamic, outFiles as Object)
    if nodes = invalid or Type(nodes) <> "roArray" then return
    for each n in nodes
        if Type(n) = "roAssociativeArray" then
            if n.l <> invalid and n.l.ToStr() <> "" then
                outFiles.Push({ name: n.n, size: n.s, link: n.l })
            else if n.link <> invalid and n.link.ToStr() <> "" then
                outFiles.Push({ name: n.filename, size: n.size, link: n.link })
            else if n.e <> invalid and Type(n.e) = "roArray" then
                DebridCollectAllDebridFiles(n.e, outFiles)
            end if
        end if
    end for
end sub

function ResolveAllDebridTorrent(apiKey as String, infoHash as String, fileIdx as Dynamic, magnet as String) as Object
    base = "https://api.alldebrid.com/v4"
    ut = CreateObject("roUrlTransfer")
    headers = {
        "Authorization": "Bearer " + apiKey,
        "Content-Type": "application/x-www-form-urlencoded"
    }
    getHeaders = { "Authorization": "Bearer " + apiKey }

    upUrl = base + "/magnet/upload?agent=SaimoRoku"
    upResp = DebridHttpRequest("POST", upUrl, headers, "magnets[]=" + ut.Escape(magnet), 12000)
    if not upResp.ok or upResp.json = invalid or upResp.json.status <> "success" then
        errMsg = "AllDebrid: falha ao enviar torrent."
        if upResp.json <> invalid and upResp.json.error <> invalid and upResp.json.error.message <> invalid then
            errMsg = "AllDebrid: " + upResp.json.error.message.ToStr()
        end if
        return { ok: false, url: "", error: errMsg }
    end if

    if upResp.json.data = invalid or upResp.json.data.magnets = invalid or Type(upResp.json.data.magnets) <> "roArray" or upResp.json.data.magnets.Count() = 0 then
        return { ok: false, url: "", error: "AllDebrid não retornou identificador do magnet." }
    end if
    mag = upResp.json.data.magnets[0]
    if mag.id = invalid then return { ok: false, url: "", error: "AllDebrid: ID ausente." }
    mid = mag.id.ToStr()

    magData = mag
    for tentativa = 1 to 3
        if magData.ready = true then exit for
        Sleep(1000)
        stUrl = base + "/magnet/status?agent=SaimoRoku&id=" + ut.Escape(mid)
        stResp = DebridHttpRequest("GET", stUrl, getHeaders, "", 10000)
        if stResp.ok and stResp.json <> invalid and stResp.json.status = "success" and stResp.json.data <> invalid and stResp.json.data.magnets <> invalid then
            mObj = stResp.json.data.magnets
            if Type(mObj) = "roArray" and mObj.Count() > 0 then mObj = mObj[0]
            if Type(mObj) = "roAssociativeArray" then magData = mObj
        end if
    end for

    if magData.ready <> true then
        return { ok: false, url: "", error: "AllDebrid: torrent ainda não está pronto em cache." }
    end if

    files = []
    if magData.links <> invalid and Type(magData.links) = "roArray" then
        for each lk in magData.links
            if Type(lk) = "roAssociativeArray" and lk.link <> invalid then
                files.Push({ name: lk.filename, size: lk.size, link: lk.link })
            end if
        end for
    end if

    ' Suporte à árvore v4.1 /magnet/files se links não veio populado
    if files.Count() = 0 then
        fUrl = "https://api.alldebrid.com/v4.1/magnet/files?agent=SaimoRoku&id[]=" + ut.Escape(mid)
        fResp = DebridHttpRequest("GET", fUrl, getHeaders, "", 10000)
        if fResp.ok and fResp.json <> invalid and fResp.json.status = "success" and fResp.json.data <> invalid and fResp.json.data.magnets <> invalid then
            mArr = fResp.json.data.magnets
            if Type(mArr) = "roArray" and mArr.Count() > 0 and mArr[0].files <> invalid then
                DebridCollectAllDebridFiles(mArr[0].files, files)
            end if
        end if
    end if

    picked = DebridPickVideoFile(files, fileIdx)
    if picked = invalid or picked.file = invalid or picked.file.link = invalid then
        return { ok: false, url: "", error: "AllDebrid: nenhum arquivo de vídeo encontrado." }
    end if

    unUrl = base + "/link/unlock?agent=SaimoRoku&link=" + ut.Escape(picked.file.link.ToStr())
    unResp = DebridHttpRequest("GET", unUrl, getHeaders, "", 10000)
    if unResp.ok and unResp.json <> invalid and unResp.json.status = "success" and unResp.json.data <> invalid and unResp.json.data.link <> invalid then
        finalUrl = unResp.json.data.link.ToStr().Trim()
        if finalUrl <> "" then return { ok: true, url: finalUrl, provider: "AllDebrid", error: "" }
    end if

    return { ok: false, url: "", error: "AllDebrid: falha ao desbloquear link." }
end function

function ResolvePremiumizeTorrent(apiKey as String, infoHash as String, fileIdx as Dynamic, magnet as String) as Object
    base = "https://www.premiumize.me/api"
    ut = CreateObject("roUrlTransfer")
    headers = { "Content-Type": "application/x-www-form-urlencoded" }
    body = "apikey=" + ut.Escape(apiKey) + "&src=" + ut.Escape(magnet)
    resp = DebridHttpRequest("POST", base + "/transfer/directdl", headers, body, 15000)
    if not resp.ok or resp.json = invalid or resp.json.status <> "success" then
        errMsg = "Premiumize: torrent não disponível em cache."
        if resp.json <> invalid and resp.json.message <> invalid then errMsg = "Premiumize: " + resp.json.message.ToStr()
        return { ok: false, url: "", error: errMsg }
    end if

    files = resp.json.content
    if files = invalid or Type(files) <> "roArray" or files.Count() = 0 then
        return { ok: false, url: "", error: "Premiumize: nenhum arquivo retornado." }
    end if

    picked = DebridPickVideoFile(files, fileIdx)
    if picked = invalid or picked.file = invalid then
        return { ok: false, url: "", error: "Premiumize: arquivo de vídeo não encontrado." }
    end if

    f = picked.file
    finalUrl = ""
    if f.link <> invalid and f.link.ToStr().Trim() <> "" then
        finalUrl = f.link.ToStr().Trim()
    else if f.stream_link <> invalid and f.stream_link.ToStr().Trim() <> "" then
        finalUrl = f.stream_link.ToStr().Trim()
    end if

    if finalUrl <> "" then return { ok: true, url: finalUrl, provider: "Premiumize", error: "" }
    return { ok: false, url: "", error: "Premiumize: link vazio." }
end function

function ResolveTorrentViaDebrid(streamInfo as Object) as Object
    if streamInfo = invalid or streamInfo.infoHash = invalid or streamInfo.infoHash.ToStr().Trim() = "" then
        return { ok: false, url: "", error: "Stream torrent inválido (sem infoHash)." }
    end if

    providers = GetEnabledDebridProviders()
    if providers.Count() = 0 then
        return {
            ok: false,
            needsConfig: true,
            url: "",
            error: "Nenhuma chave Debrid configurada. Configure TorBox, Real-Debrid, AllDebrid ou Premiumize em Ajustes > Addons e Debrid."
        }
    end if

    infoHash = streamInfo.infoHash.ToStr().Trim()
    displayName = ""
    if streamInfo.title <> invalid then displayName = streamInfo.title.ToStr()
    magnet = BuildMagnetUri(infoHash, displayName, streamInfo.sources)
    fileIdx = streamInfo.fileIdx

    lastErr = "Não foi possível resolver este torrent via Debrid."
    for each prov in providers
        res = invalid
        if prov.id = "torbox" then
            res = ResolveTorBoxTorrent(prov.apiKey, infoHash, fileIdx, magnet)
        else if prov.id = "realDebrid" then
            res = ResolveRealDebridTorrent(prov.apiKey, infoHash, fileIdx, magnet)
        else if prov.id = "allDebrid" then
            res = ResolveAllDebridTorrent(prov.apiKey, infoHash, fileIdx, magnet)
        else if prov.id = "premiumize" then
            res = ResolvePremiumizeTorrent(prov.apiKey, infoHash, fileIdx, magnet)
        end if

        if res <> invalid then
            if res.ok = true and res.url <> "" then return res
            if res.error <> invalid and res.error <> "" then lastErr = res.error
        end if
    end for

    return { ok: false, needsConfig: false, url: "", error: lastErr }
end function
