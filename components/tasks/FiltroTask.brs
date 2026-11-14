' ====================================================================
' Saimo TV - FiltroTask (BrightScript)
' Filtros do On Demand: gênero, ano, idade, nota e ordem. Baixa uma vez o
' arquivo da categoria (roku/filtros-<categoria>.txt), guarda em listas
' simples e responde cada pedido com até 6 fileiras de 50 títulos.
' ====================================================================

sub init()
    m.top.functionName = "rodar"
end sub

sub rodar()
    base = LoadPreferences().urlFilmes
    if base = invalid then base = ""
    base = base.Trim()
    if base <> "" and Right(base, 1) <> "/" then base = base + "/"
    m.base = base
    m.categoria = ""
    porta = CreateObject("roMessagePort")
    m.top.observeField("pedido", porta)
    if m.top.pedido <> invalid then atender(m.top.pedido)
    while true
        msg = wait(0, porta)
        if type(msg) = "roSGNodeEvent" then atender(msg.getData())
    end while
end sub

sub carregar(categoria as String)
    if categoria = m.categoria then return
    if m.base = "" then
        m.top.generos = []
        return
    end if
    m.categoria = categoria
    m.titulos = [] : m.anos = [] : m.capas = [] : m.gens = [] : m.idades = [] : m.notas = [] : m.pops = []
    porta = CreateObject("roMessagePort")
    ut = CreateObject("roUrlTransfer")
    ut.SetMessagePort(porta)
    ut.SetUrl(m.base + "roku/filtros-" + categoria + ".txt")
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.InitClientCertificates()
    ut.EnableEncodings(true)
    ut.AddHeader("User-Agent", "SaimoTV/3.0.3 (RokuOS)")
    texto = ""
    if ut.AsyncGetToString() then
        msg = Wait(30000, porta)
        if msg <> invalid then
            if msg.GetResponseCode() = 200 then texto = msg.GetString()
        else
            ut.AsyncCancel()
        end if
    end if
    generos = []
    for each linha in texto.Split(Chr(10))
        if Left(linha, 8) = "generos:" then
            for each g in Mid(linha, 9).Trim().Split(",")
                if g <> "" then generos.Push(g)
            end for
        else
            p = linha.Split(Chr(9))
            if p.Count() >= 7 and p[0] <> "" then
                m.titulos.Push(p[0])
                m.anos.Push(Val(p[1]))
                m.capas.Push(p[2])
                m.gens.Push("," + p[3] + ",")
                idade = -1
                if p[4] = "L" then
                    idade = 0
                else if p[4] <> "" then
                    idade = Val(p[4])
                end if
                m.idades.Push(idade)
                m.notas.Push(Val(p[5]))
                m.pops.Push(Val(p[6]))
            end if
        end if
    end for
    if m.titulos.Count() = 0 then m.categoria = ""
    m.top.generos = generos
end sub

' pedido: { id, categoria, genero (índice ou -1), anoDe, anoAte, idade (-1 = todas), nota, ordem }
sub atender(pedido as Object)
    if pedido = invalid or pedido.categoria = invalid then return
    carregar(pedido.categoria)
    if m.top.pedido <> invalid and m.top.pedido.id <> pedido.id then return

    genero = ""
    if pedido.genero <> invalid and pedido.genero >= 0 then genero = "," + pedido.genero.ToStr() + ","
    achados = []
    for i = 0 to m.titulos.Count() - 1
        ok = true
        if genero <> "" and Instr(1, m.gens[i], genero) = 0 then ok = false
        if ok and pedido.anoDe > 0 and (m.anos[i] < pedido.anoDe or m.anos[i] > pedido.anoAte) then ok = false
        if ok and pedido.idade >= 0 and (m.idades[i] < 0 or m.idades[i] > pedido.idade) then ok = false
        if ok and pedido.nota > 0 and m.notas[i] < pedido.nota then ok = false
        if ok then
            chave = m.pops[i]
            if pedido.ordem = "melhores" then chave = m.notas[i]
            if pedido.ordem = "novos" then chave = m.anos[i]
            achados.Push({ i: i, k: chave, t: LCase(m.titulos[i]) })
        end if
    end for
    if pedido.ordem = "az" then
        achados.SortBy("t")
    else
        achados.SortBy("k", "r")
    end if

    capa = "https://image.tmdb.org/t/p/w185"
    capaGrande = "https://image.tmdb.org/t/p/w780"
    serie = (pedido.categoria <> "filmes")
    raiz = CreateObject("roSGNode", "ContentNode")
    linha = invalid
    limite = achados.Count()
    if limite > 300 then limite = 300
    for n = 0 to limite - 1
        if n mod 50 = 0 then
            linha = raiz.CreateChild("ContentNode")
            if n = 0 then
                linha.title = "Resultados · " + achados.Count().ToStr() + " títulos"
            else
                linha.title = "Mais resultados"
            end if
        end if
        i = achados[n].i
        no = linha.CreateChild("ContentNode")
        no.title = m.titulos[i]
        no.hdPosterUrl = capa + m.capas[i]
        ano = ""
        if m.anos[i] > 0 then ano = m.anos[i].ToStr()
        no.addFields({ itemType: "vod", rawItem: {
            title: m.titulos[i], letter: "", isSeries: serie, year: ano,
            poster: capa + m.capas[i], backdrop: capaGrande + m.capas[i]
        } })
    end for
    m.top.total = achados.Count()
    m.top.feito = pedido.id
    m.top.resultado = raiz
end sub
