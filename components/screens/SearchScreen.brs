' ====================================================================
' Saimo TV - SearchScreen (BrightScript)
' Teclado de letras à esquerda e resultados por fileira, como na TV Box.
' ====================================================================

sub init()
    m.campo = m.top.findNode("campo")
    m.teclas = m.top.findNode("teclas")
    m.resultados = m.top.findNode("resultados")
    m.dica = m.top.findNode("dica")
    m.texto = ""

    raiz = CreateObject("roSGNode", "ContentNode")
    for each t in "A B C D E F G H I J K L M N O P Q R S T U V W X Y Z 0 1 2 3 4 5 6 7 8 9".Split(" ")
        raiz.CreateChild("ContentNode").title = t
    end for
    for each t in ["espaço", "apagar", "limpar"]
        raiz.CreateChild("ContentNode").title = t
    end for
    m.teclas.content = raiz
    m.teclas.observeField("itemSelected", "onTecla")
    m.resultados.observeField("rowItemSelected", "onResultado")
    m.top.observeField("focusedChild", "onFocusedChildChange")
    ' A busca no acervo roda numa tarefa que fica aberta: a tela não trava.
    m.busca = CreateObject("roSGNode", "BuscaTask")
    m.busca.observeField("resultado", "onResultadoAcervo")
    m.busca.control = "RUN"
    m.acervo = invalid
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() and not m.teclas.isInFocusChain() and not m.resultados.isInFocusChain() then
        m.teclas.setFocus(true)
    end if
end sub

sub onTecla()
    t = m.teclas.content.getChild(m.teclas.itemSelected).title
    if t = "espaço" then
        m.texto = m.texto + " "
    else if t = "apagar" then
        if Len(m.texto) > 0 then m.texto = Left(m.texto, Len(m.texto) - 1)
    else if t = "limpar" then
        m.texto = ""
    else
        m.texto = m.texto + LCase(t)
    end if
    m.campo.text = m.texto
    buscar()
end sub

sub buscar()
    consulta = m.texto.Trim()
    if consulta = "" then
        m.acervo = invalid
        m.busca.consulta = ""
        m.resultados.content = invalid
        m.dica.text = "Digite o nome: os resultados aparecem enquanto você digita."
        m.dica.visible = true
        return
    end if
    m.acervo = invalid
    m.busca.consulta = consulta
    m.dica.text = "Procurando…"
    montarResultados()
end sub

sub onResultadoAcervo()
    if m.busca.feita <> m.texto.Trim() then return
    m.acervo = m.busca.resultado
    montarResultados()
end sub

' Canais (lista pequena, já na memória) em cima; o acervo vem da tarefa.
sub montarResultados()
    consulta = LCase(m.texto.Trim())
    if consulta = "" then return
    if m.canais = invalid and m.top.channels <> invalid then
        m.canais = []
        for each ch in m.top.channels
            m.canais.Push({ chave: LCase(ch.name), ch: ch })
        end for
    end if
    raiz = CreateObject("roSGNode", "ContentNode")
    if m.canais <> invalid then
        canais = invalid
        for each c in m.canais
            if Instr(1, c.chave, consulta) > 0 then
                if canais = invalid then
                    canais = raiz.CreateChild("ContentNode")
                    canais.title = "Canais"
                end if
                no = canais.CreateChild("ContentNode")
                no.title = c.ch.name
                if c.ch.logo <> invalid then no.hdPosterUrl = c.ch.logo
                no.addFields({ itemType: "channel", item: c.ch })
                if canais.getChildCount() >= 30 then exit for
            end if
        end for
    end if
    if m.acervo <> invalid then
        for each linha in m.acervo.getChildren(-1, 0)
            nova = raiz.CreateChild("ContentNode")
            nova.title = linha.title
            nova.appendChildren(linha.getChildren(-1, 0))
        end for
    end if
    vazio = raiz.getChildCount() = 0
    m.dica.visible = vazio
    if vazio and m.acervo <> invalid then m.dica.text = "Nada encontrado para " + Chr(34) + m.texto.Trim() + Chr(34) + "."
    if vazio then
        m.resultados.content = invalid
        return
    end if
    AjustarFileiras(m.resultados, raiz)
    m.resultados.content = raiz
end sub

sub onResultado()
    c = m.resultados.rowItemSelected
    if m.resultados.content = invalid then return
    no = m.resultados.content.getChild(c[0]).getChild(c[1])
    if no = invalid then return
    if no.itemType = "channel" then
        m.top.tuneRequested = no.item
    else
        m.top.itemSelected = no.item
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    ' Teclado do app Roku no celular: as letras chegam como Lit_x.
    if Left(key, 4) = "Lit_" then
        m.texto = m.texto + LCase(Mid(key, 5))
        m.campo.text = m.texto
        buscar()
        return true
    else if key = "backspace" then
        if Len(m.texto) > 0 then m.texto = Left(m.texto, Len(m.texto) - 1)
        m.campo.text = m.texto
        buscar()
        return true
    end if

    if m.resultados.isInFocusChain() then
        if key = "left" or key = "back" then
            m.teclas.setFocus(true)
            return true
        end if
        return false
    end if

    if key = "right" and m.resultados.content <> invalid then
        m.resultados.setFocus(true)
        return true
    else if key = "up" then
        m.top.focusUpRequested = true
        return true
    end if
    return false
end function

' A tarefa de busca fica aberta esperando consulta: sai junto com a tela.
sub cleanUp()
    if m.busca <> invalid then m.busca.control = "STOP"
end sub
