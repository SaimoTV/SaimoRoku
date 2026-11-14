' ====================================================================
' Saimo TV - AcervoTask (BrightScript)
' O acervo inteiro do On Demand, em pedaços: o índice de letras de cada
' categoria e, quando uma letra entra em foco, os títulos dela já como
' ContentNode (vai por referência). Uma página tem no máximo 50 títulos.
' ====================================================================

sub init()
    m.top.functionName = "executar"
end sub

function baixar(url as String) as String
    if url = "" or url = invalid then return ""
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.InitClientCertificates()
    ut.AddHeader("User-Agent", "SaimoTV/3.0.3 (RokuOS)")
    res = ut.GetToString()
    if res = invalid then return ""
    return res
end function

sub executar()
    base = LoadPreferences().urlFilmes
    if base = invalid then base = ""
    base = NormalizarEnderecoSaimo(base)
    if base = "" then
        if m.top.categoria = "" then
            m.top.indice = { capa: "https://image.tmdb.org/t/p/w185", letras: {} }
        else
            m.top.linha = CreateObject("roSGNode", "ContentNode")
        end if
        return
    end if
    if m.top.categoria = "" then
        lerIndice(base)
    else
        lerPagina(base, m.top.categoria, m.top.letra, m.top.pagina)
    end if
end sub

sub lerIndice(base as String)
    texto = baixar(base + "roku/indice.txt")
    if texto.Trim() = "" then
        texto = baixar(base + "indice.txt")
    end if
    capa = "https://image.tmdb.org/t/p/w185"
    letras = {}
    for each bruta in texto.Split(Chr(10))
        linha = bruta.Trim()
        if Left(linha, 5) = "capa:" then
            capa = Mid(linha, 6).Trim()
        else if linha <> "" and Left(linha, 1) <> "#" then
            p = linha.Split(Chr(9))
            if p.Count() >= 4 then
                if letras[p[0]] = invalid then letras[p[0]] = []
                letras[p[0]].Push({ letra: p[1], paginas: Val(p[2]), total: Val(p[3]) })
            else if p.Count() = 3 then
                if letras[p[0]] = invalid then letras[p[0]] = []
                tot = Val(p[2])
                pags = Int((tot + 49) / 50)
                if pags < 1 then pags = 1
                letras[p[0]].Push({ letra: p[1], paginas: pags, total: tot })
            end if
        end if
    end for
    m.top.indice = { capa: capa, letras: letras }
end sub

sub lerPagina(base as String, categoria as String, letra as String, pagina as Integer)
    arquivo = letra
    if letra = "#" then arquivo = "0"
    texto = baixar(base + "roku/" + categoria + "-" + arquivo + "-" + pagina.ToStr() + ".txt")
    modoCompleto = false
    if texto.Trim() = "" then
        texto = baixar(base + categoria + "-" + arquivo + ".txt")
        modoCompleto = true
    end if
    capa = "https://image.tmdb.org/t/p/w185"
    capaGrande = "https://image.tmdb.org/t/p/w780"
    serie = (categoria <> "filmes")
    linha = CreateObject("roSGNode", "ContentNode")
    idxTitulo = 0
    inicio = (pagina - 1) * 50
    fim = inicio + 50
    for each bruta in texto.Split(Chr(10))
        if Left(bruta, 1) <> Chr(9) then
            p = bruta.Trim().Split(Chr(9))
            if modoCompleto then
                if p.Count() >= 2 and p[0] = "titulo" then
                    if idxTitulo >= inicio and idxTitulo < fim then
                        t = p[1]
                        ano = ""
                        if p.Count() >= 3 then ano = p[2]
                        c = ""
                        if p.Count() >= 6 then c = p[5]
                        posterUrl = c
                        backdropUrl = c
                        if Left(c, 1) = "/" then
                            posterUrl = capa + c
                            backdropUrl = capaGrande + c
                        end if
                        no = linha.CreateChild("ContentNode")
                        no.title = t
                        no.hdPosterUrl = posterUrl
                        no.addFields({ itemType: "vod", rawItem: {
                            title: t, letter: letra, isSeries: serie, year: ano,
                            poster: posterUrl, backdrop: backdropUrl
                        } })
                    end if
                    idxTitulo = idxTitulo + 1
                end if
            else if p.Count() >= 3 and p[0] <> "" then
                posterUrl = p[2]
                backdropUrl = p[2]
                if Left(p[2], 1) = "/" then
                    posterUrl = capa + p[2]
                    backdropUrl = capaGrande + p[2]
                end if
                no = linha.CreateChild("ContentNode")
                no.title = p[0]
                no.hdPosterUrl = posterUrl
                no.addFields({ itemType: "vod", rawItem: {
                    title: p[0], letter: letra, isSeries: serie, year: p[1],
                    poster: posterUrl, backdrop: backdropUrl
                } })
            end if
        end if
    end for
    m.top.linha = linha
end sub
