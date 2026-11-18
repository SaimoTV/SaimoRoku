' ====================================================================
' Saimo TV - NovelinhasTask (BrightScript)
' As minisséries em pé da RedeFlix, da lista compacta roku/novelinhas.txt
' (sem sinopse nem gêneros: leve para o Roku mais fraco).
' ====================================================================

sub init()
    m.top.functionName = "executar"
end sub

sub executar()
    base = LoadPreferences().urlFilmes
    if base = invalid then base = ""
    base = NormalizarEnderecoSaimo(base)
    if base = "" then
        m.top.lista = []
        return
    end if
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(base + "roku/novelinhas.txt")
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    texto = ut.GetToString()
    lista = []
    if texto = invalid or texto = "" then
        m.top.lista = lista
        return
    end if
    endereco = ""
    for each bruta in texto.Split(Chr(10))
        linha = bruta.Trim()
        if Left(linha, 5) = "base:" then
            endereco = Mid(linha, 6).Trim()
        else if linha <> "" and Left(linha, 1) <> "#" then
            p = linha.Split(Chr(9))
            if p.Count() >= 6 and endereco <> "" then
                eps = Int(Val(p[3]))
                if eps > 0 then
                    lista.Push({ novelinha: true, id: p[0], title: p[1], base: endereco, pasta: p[2],
                        episodios: eps, dublada: (p[4] = "dub"), poster: p[5], isSeries: true })
                end if
            end if
        end if
    end for
    m.top.lista = lista
end sub
