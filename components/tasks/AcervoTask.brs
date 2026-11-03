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
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(url)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.AddHeader("User-Agent", "SaimoTV (RokuOS)")
    return ut.GetToString()
end function

sub executar()
    base = LoadPreferences().urlFilmes
    if base = invalid or base = "" then base = "https://filmes-saimo.pages.dev/"
    if Right(base, 1) <> "/" then base = base + "/"
    if m.top.categoria = "" then
        lerIndice(base)
    else
        lerPagina(base, m.top.categoria, m.top.letra, m.top.pagina)
    end if
end sub

sub lerIndice(base as String)
    texto = baixar(base + "roku/indice.txt")
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
            end if
        end if
    end for
    m.top.indice = { capa: capa, letras: letras }
end sub

sub lerPagina(base as String, categoria as String, letra as String, pagina as Integer)
    arquivo = letra
    if letra = "#" then arquivo = "0"
    texto = baixar(base + "roku/" + categoria + "-" + arquivo + "-" + pagina.ToStr() + ".txt")
    capa = "https://image.tmdb.org/t/p/w185"
    capaGrande = "https://image.tmdb.org/t/p/w780"
    serie = (categoria <> "filmes")
    linha = CreateObject("roSGNode", "ContentNode")
    for each bruta in texto.Split(Chr(10))
        p = bruta.Split(Chr(9))
        if p.Count() >= 3 and p[0] <> "" then
            no = linha.CreateChild("ContentNode")
            no.title = p[0]
            no.hdPosterUrl = capa + p[2]
            no.addFields({ itemType: "vod", rawItem: {
                title: p[0], letter: letra, isSeries: serie, year: p[1],
                poster: capa + p[2], backdrop: capaGrande + p[2]
            } })
        end if
    end for
    m.top.linha = linha
end sub
