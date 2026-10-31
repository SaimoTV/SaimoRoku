' ====================================================================
' Saimo TV - Leitor de listas .m3u do usuário (Minhas listas)
' Mesma regra dos outros clientes. Sem nós SceneGraph: roda dentro de Task.
' ====================================================================

function ChaveDoNome(nome as String) as String
    tabela = {}
    tabela.SetModeCaseSensitive()
    grupos = { a: "áàâãäå", c: "ç", e: "éèêë", i: "íìîï", n: "ñ", o: "óòôõö", u: "úùûü", y: "ýÿ" }
    for each letra in grupos
        texto = grupos[letra]
        for p = 1 to Len(texto)
            tabela[Mid(texto, p, 1)] = letra
        end for
    end for
    baixo = LCase(nome)
    saida = ""
    for p = 1 to Len(baixo)
        c = Mid(baixo, p, 1)
        if tabela.DoesExist(c) then c = tabela[c]
        if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") then saida = saida + c
    end for
    return saida
end function

function EhRestrito(canal as Object) as Boolean
    texto = canal.nome
    if canal.grupo <> invalid then texto = texto + " " + canal.grupo
    texto = LCase(texto)
    ' "Adult Swim" é canal comum.
    texto = CreateObject("roRegex", "adult\s*swim", "i").ReplaceAll(texto, " ")
    regra = CreateObject("roRegex", "(^|[^a-z0-9])(adult|adulto|adultos|xxx|porn|porno|sexo|sex|erotic|erotico|erótico|hentai)([^a-z0-9]|$)|\+18|18\+", "i")
    return regra.IsMatch(texto)
end function

function m3uAtributo(linha as String, nome as String) as Dynamic
    m = CreateObject("roRegex", "(?:^|[\s:])" + nome + "=" + Chr(34) + "([^" + Chr(34) + "]*)" + Chr(34), "").Match(linha)
    if m.Count() > 1 then return m[1].Trim()
    return invalid
end function

function m3uExibido(linha as String) as String
    dentro = false
    for p = 1 to Len(linha)
        c = Mid(linha, p, 1)
        if c = Chr(34) then
            dentro = not dentro
        else if c = "," and not dentro then
            return Mid(linha, p + 1).Trim()
        end if
    end for
    return ""
end function

function m3uTirarTags(nome as String) as Object
    fim = CreateObject("roRegex", "^(.*?)\s*[\(\[]([^\)\]]*)[\)\]]\s*$", "")
    ruim = CreateObject("roRegex", "\d{3,4}[pi]|not 24/7|geo-?blocked|backup|vertical|\bsd\b|\bhd\b|fhd|\b4k\b", "i")
    res = CreateObject("roRegex", "(\d{3,4}[pi])", "i")
    qualidade = invalid
    while true
        m = fim.Match(nome)
        if m.Count() < 3 or not ruim.IsMatch(m[2]) then exit while
        r = res.Match(m[2])
        if r.Count() > 1 and qualidade = invalid then qualidade = LCase(r[1])
        nome = m[1]
    end while
    return { nome: nome.Trim(), qualidade: qualidade }
end function

function m3uEhHttp(url as String) as Boolean
    return CreateObject("roRegex", "^https?://", "i").IsMatch(url)
end function

function m3uDividir(texto as String, sep as String) as Object
    p = Instr(1, texto, sep)
    if p = 0 then return invalid
    return [Left(texto, p - 1), Mid(texto, p + Len(sep))]
end function

function LerM3u(texto as String, limite = 20000 as Integer) as Object
    canais = []
    indice = {}
    pend = invalid
    opts = {}
    if Left(texto, 1) = Chr(65279) then texto = Mid(texto, 2)
    linhas = CreateObject("roRegex", "\r\n|\r|\n", "").Split(texto)

    for each bruta in linhas
        linha = bruta.Trim()
        if linha = "" then continue for
        if UCase(Left(linha, 7)) = "#EXTM3U" then continue for

        if Left(linha, 7) = "#EXTINF" then
            pend = {
                exibido: m3uExibido(linha),
                tvgName: m3uAtributo(linha, "tvg-name"),
                tvgId: m3uAtributo(linha, "tvg-id"),
                logo: m3uAtributo(linha, "tvg-logo"),
                grupo: m3uAtributo(linha, "group-title")
            }
            opts = {}
        else if Left(linha, 8) = "#EXTGRP:" then
            opts.extgrp = Mid(linha, 9).Trim()
        else if Left(linha, 11) = "#EXTVLCOPT:" then
            kv = m3uDividir(Mid(linha, 12), "=")
            if kv <> invalid then
                k = LCase(kv[0].Trim())
                if k = "http-referrer" or k = "http-referer" then
                    opts.referer = kv[1].Trim()
                else if k = "http-user-agent" then
                    opts.ua = kv[1].Trim()
                end if
            end if
        else if Left(linha, 10) = "#KODIPROP:" then
            kv = m3uDividir(Mid(linha, 11), "=")
            if kv <> invalid then
                k = LCase(kv[0].Trim())
                if k = "inputstream.adaptive.license_type" then
                    opts.licTipo = LCase(kv[1].Trim())
                else if k = "inputstream.adaptive.license_key" then
                    opts.licChave = kv[1].Trim()
                end if
            end if
        else if Left(linha, 1) <> "#" then
            url = linha
            extra = {}
            partes = m3uDividir(linha, "|")
            if partes <> invalid and Instr(1, partes[1], "=") > 0 then
                url = partes[0].Trim()
                for each par in partes[1].Split("&")
                    kv = m3uDividir(par, "=")
                    if kv <> invalid then extra[LCase(kv[0].Trim())] = kv[1].Trim()
                end for
            end if

            if m3uEhHttp(url) then
                p = pend
                if p = invalid then p = { exibido: "" }
                bruto = p.exibido
                if bruto = "" and p.tvgName <> invalid then bruto = p.tvgName
                if bruto = "" and p.tvgId <> invalid then bruto = p.tvgId
                t = m3uTirarTags(bruto)
                nome = t.nome
                if nome = "" then nome = "Canal " + (canais.Count() + 1).ToStr()

                grupo = p.grupo
                if grupo = invalid or grupo = "" then grupo = opts.extgrp
                if grupo <> invalid then
                    pv = m3uDividir(grupo, ";")
                    if pv <> invalid then grupo = pv[0].Trim()
                    if grupo = "" then grupo = invalid
                end if

                logo = p.logo
                if logo = invalid or not m3uEhHttp(logo) then logo = invalid

                fonte = { url: url, referer: opts.referer, ua: opts.ua, keyId: invalid, key: invalid, qualidade: t.qualidade }
                if fonte.referer = invalid or fonte.referer = "" then fonte.referer = extra["referer"]
                if fonte.ua = invalid or fonte.ua = "" then fonte.ua = extra["user-agent"]
                if fonte.referer = "" then fonte.referer = invalid
                if fonte.ua = "" then fonte.ua = invalid
                if opts.licTipo <> invalid and opts.licChave <> invalid and Instr(1, opts.licTipo, "clearkey") > 0 then
                    if CreateObject("roRegex", "^[0-9a-fA-F]{32}:[0-9a-fA-F]{32}$", "").IsMatch(opts.licChave) then
                        kk = LCase(opts.licChave).Split(":")
                        fonte.keyId = kk[0]
                        fonte.key = kk[1]
                    end if
                end if

                k = ChaveDoNome(nome)
                if k = "" then k = "_" + nome
                c = indice[k]
                if c <> invalid then
                    repetida = false
                    for each f in c.fontes
                        if f.url = url then repetida = true
                    end for
                    if not repetida then c.fontes.Push(fonte)
                    if c.grupo = invalid then c.grupo = grupo
                    if c.logo = invalid then c.logo = logo
                else if canais.Count() < limite then
                    c = { nome: nome, grupo: grupo, logo: logo, fontes: [fonte] }
                    indice[k] = c
                    canais.Push(c)
                end if
            end if
            pend = invalid
            opts = {}
        end if
    end for
    return canais
end function
