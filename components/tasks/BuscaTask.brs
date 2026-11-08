' ====================================================================
' Saimo TV - BuscaTask (BrightScript)
' Busca no acervo inteiro sem travar a tela. O índice vem em pedaços pela
' inicial de cada palavra (roku/busca-<letra>.txt): baixa só o da primeira
' palavra digitada e guarda enquanto a pessoa continua digitando.
' ====================================================================

sub init()
    m.top.functionName = "rodar"
end sub

sub rodar()
    base = LoadPreferences().urlFilmes
    if base = invalid or base = "" then base = "https://filmes-saimo.pages.dev/"
    if Right(base, 1) <> "/" then base = base + "/"
    m.base = base
    m.inicial = ""
    m.chaves = []
    m.linhas = []
    m.vazias = { a: 1, o: 1, as: 1, os: 1, de: 1, da: 1, do: 1, das: 1, dos: 1, e: 1, em: 1, no: 1, na: 1, um: 1, uma: 1, the: 1, of: 1, and: 1, to: 1, in: 1, on: 1 }
    m.acentos = {}
    m.acentos.SetModeCaseSensitive()
    grupos = { a: "áàâãäå", c: "ç", e: "éèêë", i: "íìîï", n: "ñ", o: "óòôõö", u: "úùûü", y: "ýÿ" }
    for each letra in grupos
        texto = grupos[letra]
        for p = 1 to Len(texto)
            m.acentos[Mid(texto, p, 1)] = letra
        end for
    end for

    porta = CreateObject("roMessagePort")
    m.top.observeField("consulta", porta)
    if m.top.consulta <> "" then buscar(m.top.consulta)
    while true
        msg = wait(0, porta)
        if type(msg) = "roSGNodeEvent" then buscar(msg.getData())
    end while
end sub

function normalizar(texto as String) as String
    baixo = LCase(texto)
    saida = ""
    for p = 1 to Len(baixo)
        c = Mid(baixo, p, 1)
        if m.acentos.DoesExist(c) then c = m.acentos[c]
        if (c >= "a" and c <= "z") or (c >= "0" and c <= "9") then
            saida = saida + c
        else if Right(saida, 1) <> " " then
            saida = saida + " "
        end if
    end for
    return saida.Trim()
end function

sub carregar(inicial as String)
    if inicial = m.inicial then return
    m.inicial = inicial
    m.chaves = []
    m.linhas = []
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl(m.base + "roku/busca-" + inicial + ".txt")
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.AddHeader("User-Agent", "SaimoTV (RokuOS)")
    texto = ut.GetToString()
    for each linha in texto.Split(Chr(10))
        t = Instr(1, linha, Chr(9))
        if t > 1 then
            m.chaves.Push(" " + Left(linha, t - 1))
            m.linhas.Push(Mid(linha, t + 1))
        end if
    end for
    if m.chaves.Count() = 0 then m.inicial = ""
end sub

sub buscar(consulta as String)
    palavras = []
    for each w in normalizar(consulta).Split(" ")
        if w <> "" then palavras.Push(w)
    end for
    principal = ""
    for each w in palavras
        if not m.vazias.DoesExist(w) then
            principal = w
            exit for
        end if
    end for
    ' Só artigo digitado ("na", "o"): procura por ele mesmo, como começo de palavra.
    if principal = "" and palavras.Count() > 0 then principal = palavras[0]
    raiz = CreateObject("roSGNode", "ContentNode")
    if principal = "" then
        entregar(consulta, raiz)
        return
    end if
    carregar(Left(principal, 1))
    ' Chegou outra consulta enquanto baixava: ela é que vale.
    if m.top.consulta <> consulta then return

    nomes = { filmes: "Filmes", series: "Séries", animes: "Animes", doramas: "Doramas" }
    ordem = ["filmes", "series", "animes", "doramas"]
    fileiras = {}
    capa = "https://image.tmdb.org/t/p/w185"
    capaGrande = "https://image.tmdb.org/t/p/w780"
    total = 0
    for i = 0 to m.chaves.Count() - 1
        chave = m.chaves[i]
        bate = true
        for each w in palavras
            if Instr(1, chave, " " + w) = 0 then
                bate = false
                exit for
            end if
        end for
        if bate then
            p = m.linhas[i].Split(Chr(9))
            if p.Count() >= 5 then
                cat = p[1]
                if fileiras[cat] = invalid then fileiras[cat] = []
                if fileiras[cat].Count() < 40 then
                    fileiras[cat].Push(p)
                    total = total + 1
                end if
            end if
        end if
        if total >= 120 then exit for
    end for

    for each cat in ordem
        lista = fileiras[cat]
        if lista <> invalid then
            linha = raiz.CreateChild("ContentNode")
            linha.title = nomes[cat]
            for each p in lista
                no = linha.CreateChild("ContentNode")
                no.title = p[0]
                no.hdPosterUrl = capa + p[4]
                no.addFields({ itemType: "vod", item: {
                    title: p[0], letter: p[2], isSeries: (cat <> "filmes"), year: p[3],
                    poster: capa + p[4], backdrop: capaGrande + p[4]
                } })
            end for
        end if
    end for
    entregar(consulta, raiz)
end sub

sub entregar(consulta as String, raiz as Object)
    if m.top.consulta <> consulta then return
    ' "feita" antes: a tela confere qual consulta veio ao receber o resultado.
    m.top.feita = consulta
    m.top.resultado = raiz
end sub
