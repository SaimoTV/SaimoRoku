' ====================================================================
' Saimo TV - Stremio Protocol Addons Helper (BrightScript)
' Normalização de transportUrl, parser de manifest.json, detecção de
' plugins Nuvio JS, persistência compacta em "saimo_addons" (< 16 KB),
' cache de manifestos em cachefs:/tmp:/ e classificação/ranking de streams.
' Implementação 100% limpa do protocolo aberto Stremio.
' ====================================================================

function GetAddonsRegistry() as Object
    return CreateObject("roRegistrySection", "saimo_addons")
end function

function AddonSha1Prefix(texto as String) as String
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(texto)
    sha = CreateObject("roEVPDigest")
    sha.Setup("sha1")
    h = sha.Process(ba)
    if h = invalid or h = "" then return "00000000"
    return Left(LCase(h), 16)
end function

function AddonCacheRead(fileName as String) as String
    fs = CreateObject("roFileSystem")
    pCache = "cachefs:/" + fileName
    if fs.Exists(pCache) then
        txt = ReadAsciiFile(pCache)
        if txt <> invalid and txt <> "" then return txt
    end if
    pTmp = "tmp:/" + fileName
    if fs.Exists(pTmp) then
        txt = ReadAsciiFile(pTmp)
        if txt <> invalid and txt <> "" then return txt
    end if
    return ""
end function

sub AddonCacheWrite(fileName as String, content as String)
    ok = WriteAsciiFile("cachefs:/" + fileName, content)
    if not ok then
        WriteAsciiFile("tmp:/" + fileName, content)
    end if
end sub

sub AddonCacheDelete(fileName as String)
    fs = CreateObject("roFileSystem")
    if fs.Exists("cachefs:/" + fileName) then DeleteFile("cachefs:/" + fileName)
    if fs.Exists("tmp:/" + fileName) then DeleteFile("tmp:/" + fileName)
end sub

function AddonManifestCacheName(baseUrl as String) as String
    return "saimo_addon_m_" + AddonSha1Prefix(baseUrl) + ".json"
end function

function GetLocalDeviceIp() as String
    di = CreateObject("roDeviceInfo")
    if di = invalid then return ""
    addrs = di.GetIPAddrs()
    if addrs = invalid or Type(addrs) <> "roAssociativeArray" then return ""
    for each iface in addrs
        ip = addrs[iface]
        if ip <> invalid then
            s = ip.ToStr().Trim()
            if s <> "" and s <> "127.0.0.1" and Left(s, 4) <> "169." and Instr(1, s, ".") > 0 then
                return s
            end if
        end if
    end for
    return ""
end function

function IsHexDigit(c as String) as Boolean
    if Len(c) <> 1 then return false
    code = Asc(c)
    return (code >= 48 and code <= 57) or (code >= 65 and code <= 70) or (code >= 97 and code <= 102)
end function

function EncodeUrlPathSegment(seg as String) as String
    if seg = "" then return ""
    safeChars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~!$&'()*+,;=:@"
    ut = CreateObject("roUrlTransfer")
    out = ""
    n = Len(seg)
    i = 1
    while i <= n
        ch = Mid(seg, i, 1)
        if ch = "%" and i + 2 <= n and IsHexDigit(Mid(seg, i + 1, 1)) and IsHexDigit(Mid(seg, i + 2, 1)) then
            out = out + Mid(seg, i, 3)
            i = i + 3
        else
            if Instr(1, safeChars, ch) > 0 then
                out = out + ch
            else
                out = out + ut.Escape(ch)
            end if
            i = i + 1
        end if
    end while
    return out
end function

function NormalizeAddonUrl(rawUrl as Dynamic) as Object
    if rawUrl = invalid then
        return { ok: false, url: "", baseUrl: "", query: "", error: "Endereço do addon vazio." }
    end if
    u = rawUrl.ToStr().Trim()
    if u = "" then
        return { ok: false, url: "", baseUrl: "", query: "", error: "Endereço do addon vazio." }
    end if

    lower = LCase(u)
    scheme = ""
    rest = ""
    if Left(lower, 10) = "stremio://" then
        scheme = "https://"
        rest = Mid(u, 11)
    else if Left(lower, 8) = "https://" then
        scheme = "https://"
        rest = Mid(u, 9)
    else if Left(lower, 7) = "http://" then
        scheme = "http://"
        rest = Mid(u, 8)
    else if Instr(1, u, "://") > 0 then
        return { ok: false, url: "", baseUrl: "", query: "", error: "Protocolo não suportado. Use https://, http:// ou stremio://." }
    else
        scheme = "https://"
        rest = u
    end if

    ' Remove fragmento #...
    hashPos = Instr(1, rest, "#")
    if hashPos > 0 then rest = Left(rest, hashPos - 1)

    ' Preserva ?query
    query = ""
    qPos = Instr(1, rest, "?")
    if qPos > 0 then
        query = Mid(rest, qPos).Trim()
        rest = Left(rest, qPos - 1)
    end if

    rest = rest.Trim()
    while Len(rest) > 0 and Right(rest, 1) = "/"
        rest = Left(rest, Len(rest) - 1)
    end while

    if rest = "" then
        return { ok: false, url: "", baseUrl: "", query: "", error: "Endereço de addon inválido." }
    end if

    slashIdx = Instr(1, rest, "/")
    host = rest
    path = ""
    if slashIdx > 0 then
        host = Left(rest, slashIdx - 1)
        path = Mid(rest, slashIdx)
    end if

    host = LCase(host.Trim())
    if host = "" or Instr(1, host, " ") > 0 or Instr(1, host, Chr(9)) > 0 then
        return { ok: false, url: "", baseUrl: "", query: "", error: "Host do addon inválido." }
    end if

    ' Remove sufixo /manifest.json (preservando segmentos de configuração no path)
    while Len(path) > 0 and Right(path, 1) = "/"
        path = Left(path, Len(path) - 1)
    end while

    lowerPath = LCase(path)
    if Right(lowerPath, 14) = "/manifest.json" then
        path = Left(path, Len(path) - 14)
    else if lowerPath = "manifest.json" then
        path = ""
    end if

    while Len(path) > 0 and Right(path, 1) = "/"
        path = Left(path, Len(path) - 1)
    end while

    encodedPath = ""
    if path <> "" then
        segs = path.Split("/")
        for each seg in segs
            if seg <> "" then
                encodedPath = encodedPath + "/" + EncodeUrlPathSegment(seg)
            end if
        end for
    end if

    baseUrl = scheme + host + encodedPath
    manifestUrl = baseUrl + "/manifest.json" + query
    return {
        ok: true,
        url: manifestUrl,
        baseUrl: baseUrl,
        query: query,
        error: ""
    }
end function

function BuildAddonRouteUrl(addon as Object, routePath as String) as String
    if addon = invalid then return ""
    base = ""
    if addon.baseUrl <> invalid then base = addon.baseUrl.ToStr().Trim()
    if base = "" and addon.url <> invalid then
        norm = NormalizeAddonUrl(addon.url)
        if norm.ok then base = norm.baseUrl
    end if
    if base = "" then return ""

    while Len(base) > 0 and Right(base, 1) = "/"
        base = Left(base, Len(base) - 1)
    end while

    cleanRoute = routePath.Trim()
    while Len(cleanRoute) > 0 and Left(cleanRoute, 1) = "/"
        cleanRoute = Mid(cleanRoute, 2)
    end while

    q = ""
    if addon.query <> invalid and addon.query.ToStr() <> "" then
        q = addon.query.ToStr()
        if Left(q, 1) <> "?" then q = "?" + q
    end if

    return base + "/" + cleanRoute + q
end function

function SanitizeHttpHeaders(headersRaw as Dynamic) as Object
    arr = []
    aa = {}
    aa.SetModeCaseSensitive()
    hasUa = false

    if headersRaw <> invalid and Type(headersRaw) = "roAssociativeArray" then
        for each rawKey in headersRaw
            rawVal = headersRaw[rawKey]
            if rawVal <> invalid then
                k = rawKey.ToStr().Replace(Chr(13), "").Replace(Chr(10), "").Replace(Chr(0), "").Trim()
                v = rawVal.ToStr().Replace(Chr(13), "").Replace(Chr(10), "").Replace(Chr(0), "").Trim()
                lk = LCase(k)
                if k <> "" and v <> "" and Instr(1, k, ":") = 0 then
                    if lk <> "host" and lk <> "content-length" and lk <> "connection" and lk <> "transfer-encoding" then
                        if lk = "user-agent" then hasUa = true
                        aa[k] = v
                        arr.Push(k + ": " + v)
                    end if
                end if
            end if
        end for
    end if

    if not hasUa then
        aa["User-Agent"] = "SaimoTV/3.0.5 (RokuOS)"
        arr.Push("User-Agent: SaimoTV/3.0.5 (RokuOS)")
    end if

    return { headersArray: arr, headersAA: aa }
end function

function HttpTransferAsync(method as String, url as String, headersRaw = invalid as Dynamic, body = "" as String, timeoutMs = 10000 as Integer) as Object
    if url = "" or (Left(LCase(url), 7) <> "http://" and Left(LCase(url), 8) <> "https://") then
        return { ok: false, status: 0, body: "", error: "URL inválida" }
    end if

    ut = CreateObject("roUrlTransfer")
    porta = CreateObject("roMessagePort")
    ut.SetMessagePort(porta)
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.InitClientCertificates()
    ut.RetainBodyOnError(true)

    san = SanitizeHttpHeaders(headersRaw)
    for each hk in san.headersAA
        ut.AddHeader(hk, san.headersAA[hk])
    end for

    upperM = UCase(method)
    started = false
    if upperM = "POST" then
        ut.SetRequest("POST")
        started = ut.AsyncPostFromString(body)
    else
        ut.SetRequest("GET")
        started = ut.AsyncGetToString()
    end if

    if not started then
        return { ok: false, status: 0, body: "", error: "Não foi possível iniciar a conexão" }
    end if

    msg = Wait(timeoutMs, porta)
    if msg = invalid then
        ut.AsyncCancel()
        return { ok: false, status: 0, body: "", error: "Tempo esgotado na conexão (" + url + ")" }
    end if

    code = msg.GetResponseCode()
    respBody = msg.GetString()
    if respBody = invalid then respBody = ""
    return { ok: (code >= 200 and code < 300), status: code, body: respBody, error: "" }
end function

function DetectNuvioPluginManifest(parsed as Dynamic) as Boolean
    if parsed = invalid or Type(parsed) <> "roAssociativeArray" then return false
    hasScrapers = parsed.DoesExist("scrapers") and parsed.scrapers <> invalid and Type(parsed.scrapers) = "roArray"
    hasResources = parsed.DoesExist("resources") and parsed.resources <> invalid and Type(parsed.resources) = "roArray" and parsed.resources.Count() > 0
    return hasScrapers and (not hasResources)
end function

function StringArrayFromDynamic(val as Dynamic) as Object
    out = []
    if val = invalid or Type(val) <> "roArray" then return out
    for each el in val
        if el <> invalid then
            s = el.ToStr().Trim()
            if s <> "" then out.Push(s)
        end if
    end for
    return out
end function

function CompactResourcesFromManifest(rawResources as Dynamic, topTypes as Object, topPrefixes as Object) as Object
    out = []
    if rawResources = invalid or Type(rawResources) <> "roArray" then return out
    for each r in rawResources
        if Type(r) = "String" or Type(r) = "roString" then
            rn = r.ToStr().Trim()
            if rn <> "" then out.Push(rn)
        else if Type(r) = "roAssociativeArray" then
            rn = ""
            if r.DoesExist("name") and r.name <> invalid then rn = r.name.ToStr().Trim()
            if rn <> "" then
                rTypes = StringArrayFromDynamic(r.types)
                rPrefixes = StringArrayFromDynamic(r.idPrefixes)
                if rTypes.Count() = 0 and rPrefixes.Count() = 0 then
                    out.Push(rn)
                else
                    obj = { name: rn }
                    if rTypes.Count() > 0 then obj.types = rTypes
                    if rPrefixes.Count() > 0 then obj.idPrefixes = rPrefixes
                    out.Push(obj)
                end if
            end if
        end if
    end for
    return out
end function

function ParseAddonManifest(parsed as Dynamic, norm as Object, orderIdx = 0 as Integer, enabled = true as Boolean) as Object
    if parsed = invalid or Type(parsed) <> "roAssociativeArray" then
        return { ok: false, error: "Resposta não é um JSON válido de manifesto Stremio." }
    end if

    if DetectNuvioPluginManifest(parsed) then
        addonName = "Nuvio Plugin"
        if parsed.DoesExist("name") and parsed.name <> invalid and parsed.name.ToStr().Trim() <> "" then
            addonName = parsed.name.ToStr().Trim()
        end if
        addonId = "nuvio." + LCase(addonName).Replace(" ", "-")
        if parsed.DoesExist("id") and parsed.id <> invalid and parsed.id.ToStr().Trim() <> "" then
            addonId = parsed.id.ToStr().Trim()
        end if
        version = "1.0.0"
        if parsed.DoesExist("version") and parsed.version <> invalid and parsed.version.ToStr().Trim() <> "" then
            version = parsed.version.ToStr().Trim()
        end if
        scrapersCount = 0
        if parsed.scrapers <> invalid and Type(parsed.scrapers) = "roArray" then
            scrapersCount = parsed.scrapers.Count()
        end if
        addonDesc = "Repositório Nuvio (" + scrapersCount.ToStr() + " scrapers)"
        if parsed.DoesExist("description") and parsed.description <> invalid and parsed.description.ToStr().Trim() <> "" then
            addonDesc = parsed.description.ToStr().Trim()
        end if

        compact = {
            transportUrl: norm.transportUrl,
            baseUrl: norm.baseUrl,
            query: norm.query,
            id: addonId,
            name: addonName,
            version: version,
            enabled: enabled,
            order: orderIdx,
            types: ["movie", "series"],
            idPrefixes: ["tt", "tmdb:"],
            resources: ["stream"]
        }
        full = {
            id: addonId,
            name: addonName,
            version: version,
            description: addonDesc,
            logo: "",
            background: "",
            types: ["movie", "series"],
            idPrefixes: ["tt", "tmdb:"],
            resources: ["stream"],
            catalogs: [],
            behaviorHints: {}
        }
        return { ok: true, compact: compact, full: full, error: "" }
    end if

    addonId = ""
    if parsed.DoesExist("id") and parsed.id <> invalid then addonId = parsed.id.ToStr().Trim()
    addonName = ""
    if parsed.DoesExist("name") and parsed.name <> invalid then addonName = parsed.name.ToStr().Trim()

    if addonId = "" or addonName = "" or not parsed.DoesExist("resources") or parsed.resources = invalid or Type(parsed.resources) <> "roArray" then
        return { ok: false, error: "Manifesto inválido: não segue o padrão Stremio (faltam id, name ou resources)." }
    end if

    if parsed.DoesExist("behaviorHints") and Type(parsed.behaviorHints) = "roAssociativeArray" then
        bh = parsed.behaviorHints
        if bh.DoesExist("configurationRequired") and bh.configurationRequired = true then
            return {
                ok: false,
                error: "Este addon exige configuração prévia no navegador (/configure) antes de instalar no Roku."
            }
        end if
    end if

    version = ""
    if parsed.DoesExist("version") and parsed.version <> invalid then version = parsed.version.ToStr().Trim()
    types = StringArrayFromDynamic(parsed.types)
    idPrefixes = StringArrayFromDynamic(parsed.idPrefixes)
    resources = CompactResourcesFromManifest(parsed.resources, types, idPrefixes)

    if resources.Count() = 0 then
        return { ok: false, error: "Manifesto sem nenhum recurso compatível (resources vazio)." }
    end if

    compact = {
        url: norm.url,
        baseUrl: norm.baseUrl,
        query: norm.query,
        id: addonId,
        name: addonName,
        version: version,
        enabled: enabled,
        order: orderIdx,
        types: types,
        idPrefixes: idPrefixes,
        resources: resources
    }

    full = {
        id: addonId,
        name: addonName,
        version: version,
        description: "",
        logo: "",
        background: "",
        types: types,
        idPrefixes: idPrefixes,
        resources: parsed.resources,
        catalogs: [],
        behaviorHints: {}
    }
    if parsed.DoesExist("description") and parsed.description <> invalid then full.description = parsed.description.ToStr()
    if parsed.DoesExist("logo") and parsed.logo <> invalid then full.logo = parsed.logo.ToStr()
    if parsed.DoesExist("background") and parsed.background <> invalid then full.background = parsed.background.ToStr()
    if parsed.DoesExist("catalogs") and Type(parsed.catalogs) = "roArray" then full.catalogs = parsed.catalogs
    if parsed.DoesExist("behaviorHints") and Type(parsed.behaviorHints) = "roAssociativeArray" then full.behaviorHints = parsed.behaviorHints

    return { ok: true, compact: compact, full: full, error: "" }
end function

function SanitizeCompactAddonRecord(raw as Dynamic, fallbackOrder = 0 as Integer) as Dynamic
    if raw = invalid or Type(raw) <> "roAssociativeArray" then return invalid
    rawUrl = ""
    if raw.DoesExist("url") and raw.url <> invalid then rawUrl = raw.url.ToStr().Trim()
    if rawUrl = "" and raw.DoesExist("transportUrl") and raw.transportUrl <> invalid then rawUrl = raw.transportUrl.ToStr().Trim()
    if rawUrl = "" and raw.DoesExist("baseUrl") and raw.baseUrl <> invalid then rawUrl = raw.baseUrl.ToStr().Trim()
    if rawUrl = "" then return invalid

    norm = NormalizeAddonUrl(rawUrl)
    if not norm.ok then return invalid

    addonId = ""
    if raw.DoesExist("id") and raw.id <> invalid then addonId = raw.id.ToStr().Trim()
    if addonId = "" and raw.DoesExist("cachedId") and raw.cachedId <> invalid then addonId = raw.cachedId.ToStr().Trim()

    addonName = ""
    if raw.DoesExist("name") and raw.name <> invalid then addonName = raw.name.ToStr().Trim()
    if addonName = "" and raw.DoesExist("cachedName") and raw.cachedName <> invalid then addonName = raw.cachedName.ToStr().Trim()
    if addonName = "" then addonName = addonId
    if addonName = "" then addonName = norm.baseUrl

    version = ""
    if raw.DoesExist("version") and raw.version <> invalid then version = raw.version.ToStr().Trim()
    if version = "" and raw.DoesExist("cachedVersion") and raw.cachedVersion <> invalid then version = raw.cachedVersion.ToStr().Trim()

    enabled = true
    if raw.DoesExist("enabled") and raw.enabled <> invalid then enabled = (raw.enabled = true)

    orderIdx = fallbackOrder
    if raw.DoesExist("order") and raw.order <> invalid then orderIdx = Int(Val(raw.order.ToStr()))

    types = StringArrayFromDynamic(raw.types)
    idPrefixes = StringArrayFromDynamic(raw.idPrefixes)
    resources = CompactResourcesFromManifest(raw.resources, types, idPrefixes)

    return {
        url: norm.url,
        baseUrl: norm.baseUrl,
        query: norm.query,
        id: addonId,
        name: addonName,
        version: version,
        enabled: enabled,
        order: orderIdx,
        types: types,
        idPrefixes: idPrefixes,
        resources: resources
    }
end function

function LoadAddons() as Object
    reg = GetAddonsRegistry()
    raw = reg.Read("addons")
    if raw = invalid or raw = "" then return []
    parsed = ParseJson(raw)
    if parsed = invalid or Type(parsed) <> "roArray" then return []

    list = []
    for i = 0 to parsed.Count() - 1
        rec = SanitizeCompactAddonRecord(parsed[i], i)
        if rec <> invalid then list.Push(rec)
    end for
    list.SortBy("order")
    return list
end function

function SaveAddons(addons as Object) as Object
    if addons = invalid or Type(addons) <> "roArray" then
        return { ok: false, error: "Lista de addons inválida." }
    end if

    cleanList = []
    for i = 0 to addons.Count() - 1
        rec = SanitizeCompactAddonRecord(addons[i], i)
        if rec <> invalid then
            rec.order = cleanList.Count()
            cleanList.Push(rec)
        end if
    end for

    json = FormatJson(cleanList)
    ' Proteção explícita contra o limite rígido de 16 KB do roRegistrySection no Roku
    if Len(json) > 15400 then
        return { ok: false, error: "Limite de armazenamento (16 KB) do Roku atingido. Remova um addon antes de adicionar outro." }
    end if

    reg = GetAddonsRegistry()
    reg.Write("addons", json)
    reg.Flush()
    return { ok: true, addons: cleanList, error: "" }
end function

function GetEnabledAddons() as Object
    all = LoadAddons()
    enabled = []
    for each a in all
        if a.enabled = true then enabled.Push(a)
    end for
    return enabled
end function

function GetAddonManifestCached(addon as Object, allowFetch = false as Boolean) as Dynamic
    if addon = invalid or addon.baseUrl = invalid or addon.baseUrl = "" then return invalid
    fname = AddonManifestCacheName(addon.baseUrl)
    raw = AddonCacheRead(fname)
    if raw <> "" then
        parsed = ParseJson(raw)
        if parsed <> invalid and Type(parsed) = "roAssociativeArray" then return parsed
    end if

    if not allowFetch or addon.url = invalid or addon.url = "" then return invalid
    resp = HttpTransferAsync("GET", addon.url, invalid, "", 8000)
    if not resp.ok or resp.body = "" then return invalid
    parsedManifest = ParseJson(resp.body)
    if parsedManifest = invalid then return invalid
    norm = NormalizeAddonUrl(addon.url)
    res = ParseAddonManifest(parsedManifest, norm, addon.order, addon.enabled)
    if res.ok then
        AddonCacheWrite(fname, FormatJson(res.full))
        return res.full
    end if
    return invalid
end function

function AddOrUpdateAddon(rawUrl as String) as Object
    norm = NormalizeAddonUrl(rawUrl)
    if not norm.ok then
        return { ok: false, error: norm.error }
    end if

    resp = HttpTransferAsync("GET", norm.url, invalid, "", 10000)
    if not resp.ok then
        errTxt = "Não foi possível baixar o manifesto do addon (" + norm.url + ")."
        if resp.status > 0 then errTxt = "O servidor do addon respondeu HTTP " + resp.status.ToStr() + "."
        return { ok: false, error: errTxt }
    end if

    parsed = ParseJson(resp.body)
    if parsed = invalid then
        return { ok: false, error: "O endereço não retornou um arquivo manifest.json válido." }
    end if

    addons = LoadAddons()
    existingIdx = -1
    for i = 0 to addons.Count() - 1
        if addons[i].baseUrl = norm.baseUrl and addons[i].query = norm.query then
            existingIdx = i
            exit for
        end if
    end for

    orderVal = addons.Count()
    enabledVal = true
    if existingIdx >= 0 then
        orderVal = addons[existingIdx].order
        enabledVal = addons[existingIdx].enabled
    end if

    res = ParseAddonManifest(parsed, norm, orderVal, enabledVal)
    if not res.ok then
        return { ok: false, error: res.error }
    end if

    if existingIdx >= 0 then
        addons[existingIdx] = res.compact
    else
        addons.Push(res.compact)
    end if

    saveRes = SaveAddons(addons)
    if not saveRes.ok then
        return { ok: false, error: saveRes.error }
    end if

    AddonCacheWrite(AddonManifestCacheName(norm.baseUrl), FormatJson(res.full))
    return { ok: true, addon: res.compact, addons: saveRes.addons, error: "" }
end function

function ToggleAddonAtIndex(idx as Integer) as Object
    addons = LoadAddons()
    if idx < 0 or idx >= addons.Count() then return { ok: false, error: "Addon inválido." }
    addons[idx].enabled = not (addons[idx].enabled = true)
    return SaveAddons(addons)
end function

function MoveAddonAtIndex(idx as Integer, delta as Integer) as Object
    addons = LoadAddons()
    target = idx + delta
    if idx < 0 or idx >= addons.Count() or target < 0 or target >= addons.Count() then
        return { ok: false, addons: addons, error: "" }
    end if
    tmp = addons[idx]
    addons[idx] = addons[target]
    addons[target] = tmp
    return SaveAddons(addons)
end function

function RemoveAddonAtIndex(idx as Integer) as Object
    addons = LoadAddons()
    if idx < 0 or idx >= addons.Count() then return { ok: false, error: "Addon inválido." }
    removed = addons[idx]
    addons.Delete(idx)
    saveRes = SaveAddons(addons)
    if saveRes.ok and removed.baseUrl <> invalid and removed.baseUrl <> "" then
        AddonCacheDelete(AddonManifestCacheName(removed.baseUrl))
    end if
    return saveRes
end function

function AddonMatchesType(allowedTypes as Object, mediaType as String) as Boolean
    if mediaType = "" then return true
    if allowedTypes = invalid or allowedTypes.Count() = 0 then return true
    lm = LCase(mediaType)
    for each t in allowedTypes
        if LCase(t.ToStr()) = lm then return true
    end for
    return false
end function

function AddonEffectiveResourceSpec(addon as Object, resourceName as String) as Dynamic
    if addon = invalid or addon.resources = invalid then return invalid
    target = LCase(resourceName)
    for each r in addon.resources
        if Type(r) = "String" or Type(r) = "roString" then
            if LCase(r.ToStr()) = target then
                return { name: target, types: addon.types, idPrefixes: addon.idPrefixes }
            end if
        else if Type(r) = "roAssociativeArray" then
            rn = ""
            if r.name <> invalid then rn = LCase(r.name.ToStr())
            if rn = target then
                rTypes = addon.types
                if r.types <> invalid and Type(r.types) = "roArray" and r.types.Count() > 0 then rTypes = r.types
                rPrefixes = addon.idPrefixes
                if r.idPrefixes <> invalid and Type(r.idPrefixes) = "roArray" and r.idPrefixes.Count() > 0 then rPrefixes = r.idPrefixes
                return { name: target, types: rTypes, idPrefixes: rPrefixes }
            end if
        end if
    end for
    return invalid
end function

function AddonPrefixAllows(prefixes as Dynamic, candidateId as String) as Boolean
    if candidateId = "" then return false
    if prefixes = invalid or Type(prefixes) <> "roArray" or prefixes.Count() = 0 then return true
    lcId = LCase(candidateId)
    for each p in prefixes
        if p <> invalid then
            lp = LCase(p.ToStr().Trim())
            if lp <> "" then
                if Left(lcId, Len(lp)) = lp then return true
                ' Suporta prefixos declarados sem ":" como "tmdb" para "tmdb:123"
                if Right(lp, 1) <> ":" and Left(lcId, Len(lp) + 1) = lp + ":" then return true
            end if
        end if
    end for
    return false
end function

function AddonSupportsResource(addon as Object, resourceName as String, mediaType as String, candidateId = "" as String) as Boolean
    spec = AddonEffectiveResourceSpec(addon, resourceName)
    if spec = invalid then return false
    if not AddonMatchesType(spec.types, mediaType) then return false
    if candidateId <> "" then
        return AddonPrefixAllows(spec.idPrefixes, candidateId)
    end if
    return true
end function

function AddonResolveQueryId(addon as Object, resourceName as String, mediaType as String, ids as Object, season = 1 as Integer, episode = 1 as Integer) as String
    spec = AddonEffectiveResourceSpec(addon, resourceName)
    if spec = invalid then return ""
    if not AddonMatchesType(spec.types, mediaType) then return ""

    baseId = ""
    imdbId = ""
    tmdbId = ""
    rawId = ""
    if ids <> invalid then
        if ids.imdbId <> invalid then imdbId = ids.imdbId.ToStr().Trim()
        if ids.tmdbId <> invalid then tmdbId = ids.tmdbId.ToStr().Trim()
        if ids.rawId <> invalid then rawId = ids.rawId.ToStr().Trim()
    end if

    if imdbId <> "" and AddonPrefixAllows(spec.idPrefixes, imdbId) then
        baseId = imdbId
    else if tmdbId <> "" and AddonPrefixAllows(spec.idPrefixes, "tmdb:" + tmdbId) then
        baseId = "tmdb:" + tmdbId
    else if rawId <> "" and AddonPrefixAllows(spec.idPrefixes, rawId) then
        baseId = rawId
    end if

    if baseId = "" then return ""

    if LCase(mediaType) = "series" and (LCase(resourceName) = "stream" or LCase(resourceName) = "subtitles") then
        ' Evita duplicar :season:episode se rawId já vier completo
        partes = baseId.Split(":")
        if partes.Count() >= 3 and Val(partes[partes.Count() - 1]) > 0 then
            return baseId
        end if
        return baseId + ":" + season.ToStr() + ":" + episode.ToStr()
    end if

    return baseId
end function

function DetectStreamFormatFromHint(urlStr as String, fileName as String) as String
    u = LCase(urlStr.Trim())
    qPos = Instr(1, u, "?")
    if qPos > 0 then u = Left(u, qPos - 1)
    fn = LCase(fileName.Trim())

    target = u + " " + fn
    if Instr(1, target, ".m3u8") > 0 or Instr(1, target, "/hls/") > 0 or Instr(1, target, "master.txt") > 0 then return "hls"
    if Instr(1, target, ".mp4") > 0 or Instr(1, target, ".m4v") > 0 or Instr(1, target, ".mov") > 0 then return "mp4"
    if Instr(1, target, ".mpd") > 0 then return "dash"
    if Instr(1, target, ".mkv") > 0 then return "mkv"
    return "other"
end function

function NormalizeSubtitleLang(langRaw as String) as Object
    l = LCase(langRaw.Trim())
    if l = "pob" or l = "pt-br" or l = "pt_br" or l = "pb" then return { code: "por", label: "Português (BR)", prio: 100 }
    if l = "por" or l = "pt" or l = "pt-pt" or l = "portuguese" then return { code: "por", label: "Português", prio: 90 }
    if l = "eng" or l = "en" or l = "en-us" or l = "english" then return { code: "eng", label: "Inglês", prio: 60 }
    if l = "spa" or l = "es" or l = "spanish" then return { code: "spa", label: "Espanhol", prio: 40 }
    if l = "" then return { code: "und", label: "Legenda", prio: 10 }
    return { code: l, label: UCase(l), prio: 20 }
end function

function NormalizeSubtitleEntry(rawSub as Dynamic, sourceLabel = "" as String) as Dynamic
    if rawSub = invalid or Type(rawSub) <> "roAssociativeArray" then return invalid
    subUrl = ""
    if rawSub.url <> invalid then subUrl = rawSub.url.ToStr().Trim()
    if subUrl = "" or (Left(LCase(subUrl), 7) <> "http://" and Left(LCase(subUrl), 8) <> "https://") then return invalid

    langRaw = ""
    if rawSub.lang <> invalid then langRaw = rawSub.lang.ToStr().Trim()
    if langRaw = "" and rawSub.language <> invalid then langRaw = rawSub.language.ToStr().Trim()
    langInfo = NormalizeSubtitleLang(langRaw)

    desc = langInfo.label
    if sourceLabel <> "" then desc = desc + " · " + sourceLabel
    if rawSub.id <> invalid and rawSub.id.ToStr().Trim() <> "" and sourceLabel = "" then
        desc = langInfo.label
    end if

    return {
        TrackName: subUrl,
        Language: langInfo.code,
        Description: desc,
        priority: langInfo.prio
    }
end function

function ClassifyRokuStream(addon as Object, rawStream as Dynamic, preferredBingeGroup = "" as String) as Dynamic
    if rawStream = invalid or Type(rawStream) <> "roAssociativeArray" then return invalid

    urlStr = ""
    if rawStream.url <> invalid then urlStr = rawStream.url.ToStr().Trim()
    infoHash = ""
    if rawStream.infoHash <> invalid then infoHash = rawStream.infoHash.ToStr().Trim()

    ' Ignora streams puramente ytId/externalUrl que não tocam no Video nativo do Roku
    if urlStr = "" and infoHash = "" then return invalid
    if urlStr <> "" and Left(LCase(urlStr), 7) <> "http://" and Left(LCase(urlStr), 8) <> "https://" then
        if infoHash = "" then return invalid
        urlStr = ""
    end if

    isTorrent = (urlStr = "" and infoHash <> "")

    sName = ""
    if rawStream.name <> invalid then sName = rawStream.name.ToStr().Trim()
    sTitle = ""
    if rawStream.title <> invalid then sTitle = rawStream.title.ToStr().Trim()
    if sTitle = "" and rawStream.description <> invalid then sTitle = rawStream.description.ToStr().Trim()

    bh = {}
    if rawStream.DoesExist("behaviorHints") and Type(rawStream.behaviorHints) = "roAssociativeArray" then
        bh = rawStream.behaviorHints
    end if

    fileName = ""
    if bh.DoesExist("filename") and bh.filename <> invalid then fileName = bh.filename.ToStr().Trim()

    notWebReady = false
    if bh.DoesExist("notWebReady") and bh.notWebReady = true then notWebReady = true

    bingeGroup = ""
    if bh.DoesExist("bingeGroup") and bh.bingeGroup <> invalid then bingeGroup = bh.bingeGroup.ToStr().Trim()

    proxyHeadersRaw = invalid
    if bh.DoesExist("proxyHeaders") and Type(bh.proxyHeaders) = "roAssociativeArray" then
        ph = bh.proxyHeaders
        if ph.DoesExist("request") and Type(ph.request) = "roAssociativeArray" then
            proxyHeadersRaw = ph.request
        end if
    end if
    sanHeaders = SanitizeHttpHeaders(proxyHeadersRaw)

    fmt = DetectStreamFormatFromHint(urlStr, fileName + " " + sTitle)
    comboText = LCase(sName + " " + sTitle + " " + fileName)

    avisoRoku = ""
    if Instr(1, comboText, "dts") > 0 or Instr(1, comboText, "truehd") > 0 or Instr(1, comboText, "10bit") > 0 or Instr(1, comboText, "10-bit") > 0 or Instr(1, comboText, "hi10") > 0 then
        avisoRoku = "Áudio/perfil pode não tocar no Roku"
    end if

    tag = ""
    if isTorrent then
        tag = "[Torrent/Debrid]"
    else if fmt = "hls" then
        tag = "[HLS]"
    else if fmt = "mp4" then
        tag = "[MP4]"
    else if fmt = "mkv" then
        tag = "[MKV]"
    else if fmt = "dash" then
        tag = "[DASH]"
    else
        tag = "[HTTP]"
    end if

    score = 0
    if not isTorrent then
        if fmt = "hls" or fmt = "mp4" then
            score = 1000
        else if fmt = "dash" or fmt = "other" then
            score = 800
        else if fmt = "mkv" then
            score = 500
        end if
        if notWebReady and fmt <> "hls" and fmt <> "mp4" then score = score - 50
    else
        if fmt = "mp4" or fmt = "hls" then
            score = 350
        else if fmt = "mkv" then
            score = 220
        else
            score = 260
        end if
    end if

    if avisoRoku <> "" then score = score - 80

    if preferredBingeGroup <> "" and bingeGroup <> "" and bingeGroup = preferredBingeGroup then
        score = score + 5000
    end if

    subList = []
    if rawStream.DoesExist("subtitles") and Type(rawStream.subtitles) = "roArray" then
        aLabel = ""
        if addon <> invalid and addon.name <> invalid then aLabel = addon.name
        for each s in rawStream.subtitles
            normSub = NormalizeSubtitleEntry(s, aLabel)
            if normSub <> invalid then subList.Push(normSub)
        end for
    end if

    addonName = "Addon"
    addonId = ""
    addonOrder = 0
    if addon <> invalid then
        if addon.name <> invalid and addon.name <> "" then addonName = addon.name
        if addon.id <> invalid then addonId = addon.id
        if addon.order <> invalid then addonOrder = addon.order
    end if

    displayTitle = tag + " " + addonName
    if sName <> "" then
        cleanSName = sName.Replace(Chr(10), " · ").Trim()
        if LCase(cleanSName) <> LCase(addonName) then displayTitle = tag + " " + cleanSName
    end if

    displayDetail = sTitle.Replace(Chr(10), " · ").Trim()
    if avisoRoku <> "" then
        if displayDetail <> "" then
            displayDetail = avisoRoku + " · " + displayDetail
        else
            displayDetail = avisoRoku
        end if
    end if

    return {
        sourceKind: "addon",
        addonId: addonId,
        addonName: addonName,
        addonOrder: addonOrder,
        title: displayTitle,
        detail: displayDetail,
        url: urlStr,
        infoHash: infoHash,
        fileIdx: rawStream.fileIdx,
        sources: rawStream.sources,
        isTorrent: isTorrent,
        streamFormat: fmt,
        notWebReady: notWebReady,
        bingeGroup: bingeGroup,
        proxyHeaders: sanHeaders.headersAA,
        httpHeadersArray: sanHeaders.headersArray,
        subtitles: subList,
        filename: fileName,
        score: score
    }
end function

function RankRokuStreams(streams as Object, debridConfigured as Boolean, preferredBingeGroup = "" as String) as Object
    if streams = invalid or streams.Count() = 0 then return []
    ranked = []
    for i = 0 to streams.Count() - 1
        s = streams[i]
        if s <> invalid then
            effScore = 0
            if s.score <> invalid then effScore = s.score
            if s.isTorrent = true and not debridConfigured then
                effScore = effScore - 200
                if Instr(1, s.title, "Requer Debrid") = 0 then
                    s.title = s.title + " · Requer Debrid"
                end if
            end if
            if preferredBingeGroup <> "" and s.bingeGroup <> invalid and s.bingeGroup = preferredBingeGroup then
                effScore = effScore + 5000
            end if
            ' Preserva ordem original dentro da mesma pontuação
            s._rankKey = effScore * 10000 - i
            ranked.Push(s)
        end if
    end for
    ranked.SortBy("_rankKey", "r")
    return ranked
end function
