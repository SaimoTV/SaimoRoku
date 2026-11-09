' ====================================================================
' Saimo TV - VodScreen (BrightScript)
' On Demand como na TV Box: cabeçalho que segue o foco, cartões de categoria
' na primeira fileira e, abaixo, os trilhos da categoria escolhida.
' ====================================================================

sub init()
    m.heroBanner = m.top.findNode("heroBanner")
    m.vodRowList = m.top.findNode("vodRowList")
    m.heroTimer = m.top.findNode("heroTimer")
    m.heroTimer.observeField("fire", "aplicarDestaque")
    m.vodRowList.observeField("rowItemSelected", "onRowItemSelected")
    m.vodRowList.observeField("rowItemFocused", "onRowItemFocused")

    m.currentCategoryIdx = 0
    m.categories = ["Filmes", "Séries", "Animes", "Doramas"]
    m.cores = ["#4FE3D0", "#7AA2FF", "#FFB454", "#FF7EB6"]
    m.icones = ["m_movie", "m_live_tv", "m_star", "m_more"]
    m.chaves = ["filmes", "series", "animes", "doramas"]
    m.indice = invalid
    m.linhas = {}
    m.geracao = 0
    m.tarefas = {}
    m.top.observeField("focusedChild", "onFocusedChildChange")
    ' Filtros: gênero, ano, idade, nota e ordem (FiltroTask, sobre o acervo inteiro).
    m.lista = m.top.findNode("lista")
    m.opcoes = m.top.findNode("opcoes")
    m.opcoes.observeField("itemSelected", "onOpcaoEscolhida")
    m.filtros = filtrosVazios()
    m.generos = []
    m.pedidoId = 0
    m.filtro = CreateObject("roSGNode", "FiltroTask")
    m.filtro.observeField("resultado", "onResultadoFiltro")
    m.filtro.observeField("generos", "onGeneros")
    m.filtro.control = "RUN"
    ' Índice de letras do acervo inteiro: as fileiras de cada letra chegam sob demanda.
    m.tarefaIndice = CreateObject("roSGNode", "AcervoTask")
    m.tarefaIndice.observeField("indice", "onIndice")
    m.tarefaIndice.control = "RUN"
end sub

sub onIndice()
    m.indice = m.tarefaIndice.indice
    m.tarefaIndice = invalid
    if m.grupos = invalid then separar()
    montar()
end sub

function totalDaCategoria(i as Integer) as Integer
    total = 0
    if m.indice <> invalid and m.indice.letras[m.chaves[i]] <> invalid then
        for each l in m.indice.letras[m.chaves[i]]
            total = total + l.total
        end for
    end if
    if total = 0 and m.grupos <> invalid then total = m.grupos[i].Count()
    return total
end function

sub onFocusedChildChange()
    ' Com a lista de opções aberta o foco é dela, não da grade.
    if m.lista.visible then
        if m.top.isInFocusChain() and not m.opcoes.isInFocusChain() then m.opcoes.setFocus(true)
        return
    end if
    if m.top.isInFocusChain() and not m.vodRowList.isInFocusChain() then m.vodRowList.setFocus(true)
end sub

sub onItemsChange()
    separar()
    montar()
end sub

sub onCategoryChange()
    for i = 0 to m.categories.Count() - 1
        if m.categories[i] = m.top.selectedCategory then m.currentCategoryIdx = i
    end for
    if m.grupos <> invalid then montar()
end sub

sub separar()
    m.grupos = [[], [], [], []]
    allItems = m.top.vodItems
    if allItems = invalid then return
    for each it in allItems
        itCat = ""
        if it.category <> invalid then itCat = LCase(it.category)
        itTitle = ""
        if it.title <> invalid then itTitle = LCase(it.title)
        if Instr(1, itCat, "anime") > 0 or Instr(1, itTitle, "anime") > 0 then
            m.grupos[2].Push(it)
        else if Instr(1, itCat, "dorama") > 0 or Instr(1, itTitle, "dorama") > 0 then
            m.grupos[3].Push(it)
        else if it.isSeries then
            m.grupos[1].Push(it)
        else
            m.grupos[0].Push(it)
        end if
    end for
end sub

function textoTitulos(n as Integer) as String
    if n = 1 then return "1 título"
    return n.ToStr() + " títulos"
end function

sub fileira(raiz as Object, titulo as String, itens as Object, de as Integer, ate as Integer)
    if ate >= itens.Count() then ate = itens.Count() - 1
    if de > ate then return
    linha = raiz.CreateChild("ContentNode")
    linha.title = titulo
    for i = de to ate
        it = itens[i]
        no = linha.CreateChild("ContentNode")
        no.title = it.title
        if it.poster <> invalid then no.hdPosterUrl = it.poster
        no.addFields({ itemType: "vod", rawItem: it })
    end for
end sub

sub montar()
    if m.grupos = invalid then return
    raiz = CreateObject("roSGNode", "ContentNode")
    cats = raiz.CreateChild("ContentNode")
    cats.title = "Categorias"
    for i = 0 to 3
        g = m.grupos[i]
        capas = []
        for c = 0 to 3
            if c < g.Count() and g[c].poster <> invalid then capas.Push(g[c].poster)
        end for
        no = cats.CreateChild("ContentNode")
        no.title = m.categories[i]
        no.addFields({ itemType: "categoria", indice: i, subTitulo: textoTitulos(totalDaCategoria(i)), cor: m.cores[i], icone: "pkg:/images/icons/" + m.icones[i] + ".png", capas: capas })
    end for

    filaDeFiltros(raiz)
    m.geracao = m.geracao + 1
    m.linhas = {}
    if filtrando() then
        ' Com filtro, o acervo inteiro filtrado chega da tarefa (onResultadoFiltro).
        espera = raiz.CreateChild("ContentNode")
        espera.title = "Filtrando…"
        esperar(espera)
        AjustarFileiras(m.vodRowList, raiz)
        m.vodRowList.content = raiz
        mostrarCategoria(m.currentCategoryIdx)
        pedirFiltro()
        return
    end if

    g = m.grupos[m.currentCategoryIdx]
    fileira(raiz, "Em alta", g, 0, 19)

    ' O acervo inteiro em páginas de até 50 títulos, uma fileira por página; só
    ' as páginas perto do foco ficam baixadas, para o Roku mais fraco aguentar.
    letras = invalid
    if m.indice <> invalid then letras = m.indice.letras[m.chaves[m.currentCategoryIdx]]
    if letras <> invalid then
        for each l in letras
            for pagina = 1 to l.paginas
                linha = raiz.CreateChild("ContentNode")
                linha.title = l.letra
                if l.paginas > 1 then linha.title = l.letra + " · " + pagina.ToStr() + " de " + l.paginas.ToStr()
                esperar(linha)
                m.linhas[(raiz.getChildCount() - 1).ToStr()] = { letra: l.letra, pagina: pagina, estado: "" }
            end for
        end for
    end if

    AjustarFileiras(m.vodRowList, raiz)
    m.vodRowList.content = raiz
    mostrarCategoria(m.currentCategoryIdx)
    carregarPerto(0)
end sub

sub esperar(linha as Object)
    espera = linha.CreateChild("ContentNode")
    espera.title = "Carregando…"
    espera.addFields({ itemType: "carregando" })
end sub

' Baixa a fileira focada e as duas seguintes; devolve à espera as que ficaram
' longe, para a memória não crescer enquanto a pessoa desce o acervo.
sub carregarPerto(r as Integer)
    raiz = m.vodRowList.content
    for each k in m.linhas
        info = m.linhas[k]
        i = Val(k)
        if info.estado = "pronto" and (i < r - 4 or i > r + 6) and raiz <> invalid then
            linha = raiz.getChild(i)
            if linha <> invalid then
                linha.removeChildrenIndex(linha.getChildCount(), 0)
                esperar(linha)
            end if
            info.estado = ""
        end if
    end for
    for i = r to r + 2
        info = m.linhas[i.ToStr()]
        if info <> invalid and info.estado = "" then
            info.estado = "baixando"
            t = CreateObject("roSGNode", "AcervoTask")
            t.id = i.ToStr() + ":" + m.geracao.ToStr()
            t.categoria = m.chaves[m.currentCategoryIdx]
            t.letra = info.letra
            t.pagina = info.pagina
            t.observeField("linha", "onLinha")
            m.tarefas[t.id] = t
            t.control = "RUN"
        end if
    end for
end sub

sub onLinha(evento as Object)
    t = evento.getRoSGNode()
    m.tarefas.Delete(t.id)
    partes = t.id.Split(":")
    ' Outra categoria foi montada enquanto a letra baixava.
    if Val(partes[1]) <> m.geracao then return
    raiz = m.vodRowList.content
    if raiz = invalid then return
    linha = raiz.getChild(Val(partes[0]))
    novos = t.linha
    if linha = invalid or novos = invalid then return
    info = m.linhas[partes[0]]
    if novos.getChildCount() = 0 then
        if info <> invalid then info.estado = ""
        return
    end if
    if info <> invalid then info.estado = "pronto"
    linha.removeChildrenIndex(linha.getChildCount(), 0)
    linha.appendChildren(novos.getChildren(-1, 0))
end sub

sub mostrarCategoria(i as Integer)
    m.heroBanner.featuredItem = { title: m.categories[i], genres: textoTitulos(totalDaCategoria(i)), overview: "Lançamentos, clássicos e tudo entre eles, dublados e legendados.", semFundo: true }
end sub

function noEm(coords as Dynamic) as Dynamic
    root = m.vodRowList.content
    if root = invalid or coords = invalid or coords.Count() < 2 then return invalid
    if coords[0] >= root.getChildCount() then return invalid
    linha = root.getChild(coords[0])
    if linha = invalid or coords[1] >= linha.getChildCount() then return invalid
    return linha.getChild(coords[1])
end function

sub onRowItemFocused()
    foco = m.vodRowList.rowItemFocused
    if foco <> invalid and foco.Count() >= 1 then carregarPerto(foco[0])
    m.heroTimer.control = "stop"
    m.heroTimer.control = "start"
end sub

sub aplicarDestaque()
    no = noEm(m.vodRowList.rowItemFocused)
    if no = invalid then return
    if no.itemType = "categoria" then
        mostrarCategoria(no.indice)
    else if no.rawItem <> invalid then
        m.heroBanner.featuredItem = no.rawItem
    end if
end sub

sub onRowItemSelected()
    if m.fechouLista <> invalid then
        if m.fechouLista.TotalMilliseconds() < 600 then return
    end if
    no = noEm(m.vodRowList.rowItemSelected)
    if no = invalid then return
    if no.itemType = "filtro" then
        abrirLista(no.campo)
        return
    end if
    if no.itemType = "categoria" then
        if no.indice <> m.currentCategoryIdx then
            m.currentCategoryIdx = no.indice
            montar()
            m.vodRowList.jumpToRowItem = [0, no.indice]
        end if
    else if no.rawItem <> invalid then
        m.top.itemSelected = no.rawItem
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if m.lista.visible then
        if key = "back" or key = "left" then fecharLista()
        return true
    end if
    if key = "up" then
        m.top.focusUpRequested = true
        return true
    end if
    return false
end function

sub cleanUp()
    ' A tarefa de filtros fica aberta esperando pedido: sai junto com a tela.
    if m.filtro <> invalid then m.filtro.control = "STOP"
end sub


' ===== Filtros =====

function filtrosVazios() as Object
    return { genero: -1, generoNome: "", anoDe: 0, anoAte: 0, rotuloAno: "", idade: -1, nota: 0, ordem: "" }
end function

function filtrando() as Boolean
    f = m.filtros
    return f.genero >= 0 or f.anoDe > 0 or f.idade >= 0 or f.nota > 0 or f.ordem <> ""
end function

sub filaDeFiltros(raiz as Object)
    f = m.filtros
    linha = raiz.CreateChild("ContentNode")
    linha.title = "Filtros"
    idade = "Todas"
    if f.idade = 0 then idade = "Livre"
    if f.idade > 0 then idade = "Até " + f.idade.ToStr() + " anos"
    nota = "Qualquer"
    if f.nota > 0 then nota = f.nota.ToStr() + " ou mais"
    ordens = { "": "Destaques", populares: "Mais populares", melhores: "Mais bem avaliados", novos: "Mais novos", az: "A–Z" }
    genero = "Todos"
    if f.genero >= 0 then genero = f.generoNome
    ano = "Todos"
    if f.anoDe > 0 then ano = f.rotuloAno
    itens = [
        ["genero", "Gênero", genero, f.genero >= 0],
        ["ano", "Ano", ano, f.anoDe > 0],
        ["idade", "Idade", idade, f.idade >= 0],
        ["nota", "Nota", nota, f.nota > 0],
        ["ordem", "Ordem", ordens[f.ordem], f.ordem <> ""]
    ]
    if filtrando() then itens.Push(["limpar", "Filtros", "Limpar", false])
    for each it in itens
        no = linha.CreateChild("ContentNode")
        no.title = it[1]
        no.addFields({ itemType: "filtro", campo: it[0], subTitulo: it[2], ativo: it[3] })
    end for
end sub

sub onGeneros()
    m.generos = m.filtro.generos
end sub

sub pedirFiltro()
    m.pedidoId = m.pedidoId + 1
    f = m.filtros
    m.filtro.pedido = { id: m.pedidoId, categoria: m.chaves[m.currentCategoryIdx], genero: f.genero,
        anoDe: f.anoDe, anoAte: f.anoAte, idade: f.idade, nota: f.nota, ordem: f.ordem }
end sub

sub onResultadoFiltro()
    if m.filtro.feito <> m.pedidoId or not filtrando() then return
    raiz = m.vodRowList.content
    if raiz = invalid then return
    ' Mantém categorias e filtros; troca o resto pelos resultados.
    while raiz.getChildCount() > 2
        raiz.removeChildIndex(2)
    end while
    novos = m.filtro.resultado
    if novos = invalid or novos.getChildCount() = 0 then
        vazio = raiz.CreateChild("ContentNode")
        vazio.title = "Nenhum título com esses filtros"
        esperar(vazio)
    else
        raiz.appendChildren(novos.getChildren(-1, 0))
    end if
    AjustarFileiras(m.vodRowList, raiz)
end sub

sub abrirLista(campo as String)
    if campo = "limpar" then
        m.filtros = filtrosVazios()
        montar()
        m.vodRowList.jumpToRowItem = [1, 0]
        return
    end if
    m.campoAberto = campo
    m.valores = []
    nomes = []
    if campo = "genero" then
        nomes.Push("Todos") : m.valores.Push(-1)
        for i = 0 to m.generos.Count() - 1
            nomes.Push(m.generos[i]) : m.valores.Push(i)
        end for
        titulo = "Gênero"
    else if campo = "ano" then
        atual = CreateObject("roDateTime").GetYear()
        nomes.Push("Todos") : m.valores.Push([0, 0, ""])
        for a = atual to atual - 2 step -1
            nomes.Push(a.ToStr()) : m.valores.Push([a, a, a.ToStr()])
        end for
        decada = Int(atual / 10) * 10
        if atual - 3 >= decada then
            r = decada.ToStr() + "–" + (atual - 3).ToStr()
            nomes.Push(r) : m.valores.Push([decada, atual - 3, r])
        end if
        for d = decada - 10 to 1990 step -10
            r = "Anos " + d.ToStr()
            nomes.Push(r) : m.valores.Push([d, d + 9, r])
        end for
        nomes.Push("Antes de 1990") : m.valores.Push([1, 1989, "Antes de 1990"])
        titulo = "Ano"
    else if campo = "idade" then
        nomes = ["Todas", "Livre", "Até 10 anos", "Até 12 anos", "Até 14 anos", "Até 16 anos"]
        m.valores = [-1, 0, 10, 12, 14, 16]
        titulo = "Classificação indicativa"
    else if campo = "nota" then
        nomes = ["Qualquer", "6 ou mais", "7 ou mais", "8 ou mais"]
        m.valores = [0, 6, 7, 8]
        titulo = "Nota mínima"
    else
        nomes = ["Destaques", "Mais populares", "Mais bem avaliados", "Mais novos", "A–Z"]
        m.valores = ["", "populares", "melhores", "novos", "az"]
        titulo = "Ordem"
    end if
    conteudo = CreateObject("roSGNode", "ContentNode")
    for each n in nomes
        conteudo.CreateChild("ContentNode").title = n
    end for
    m.top.findNode("listaTitulo").text = titulo
    m.opcoes.content = conteudo
    m.lista.visible = true
    m.opcoes.setFocus(true)
end sub

sub fecharLista()
    m.lista.visible = false
    ' O OK que escolheu a opção não pode abrir também o cartão de trás.
    m.fechouLista = CreateObject("roTimespan")
    m.vodRowList.setFocus(true)
end sub

sub onOpcaoEscolhida()
    i = m.opcoes.itemSelected
    if i < 0 or i >= m.valores.Count() then return
    v = m.valores[i]
    f = m.filtros
    c = m.campoAberto
    if c = "genero" then
        f.genero = v
        if v >= 0 then f.generoNome = m.generos[v] else f.generoNome = ""
    else if c = "ano" then
        f.anoDe = v[0] : f.anoAte = v[1] : f.rotuloAno = v[2]
    else if c = "idade" then
        f.idade = v
    else if c = "nota" then
        f.nota = v
    else
        f.ordem = v
    end if
    m.filtros = f
    fecharLista()
    montar()
    m.vodRowList.jumpToRowItem = [1, 0]
end sub
