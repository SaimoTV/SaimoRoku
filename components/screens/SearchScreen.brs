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
        m.resultados.content = invalid
        m.dica.visible = true
        return
    end if

    raiz = CreateObject("roSGNode", "ContentNode")
    canais = invalid
    if m.canais = invalid then m.canais = m.top.channels
    if m.titulos = invalid then m.titulos = m.top.vodItems
    if m.canais <> invalid then
        for each ch in m.canais
            if Instr(1, LCase(ch.name), consulta) > 0 then
                if canais = invalid then
                    canais = raiz.CreateChild("ContentNode")
                    canais.title = "Canais"
                end if
                no = canais.CreateChild("ContentNode")
                no.title = ch.name
                if ch.logo <> invalid then no.hdPosterUrl = ch.logo
                no.addFields({ itemType: "channel", item: ch })
                if canais.getChildCount() >= 30 then exit for
            end if
        end for
    end if

    titulos = invalid
    if m.titulos <> invalid then
        for each it in m.titulos
            if Instr(1, LCase(it.title), consulta) > 0 then
                if titulos = invalid then
                    titulos = raiz.CreateChild("ContentNode")
                    titulos.title = "Filmes e séries"
                end if
                no = titulos.CreateChild("ContentNode")
                no.title = it.title
                if it.poster <> invalid then no.hdPosterUrl = it.poster
                no.addFields({ itemType: "vod", item: it })
                if titulos.getChildCount() >= 30 then exit for
            end if
        end for
    end if

    m.dica.visible = raiz.getChildCount() = 0
    if m.dica.visible then m.dica.text = "Nada encontrado."
    AjustarFileiras(m.resultados, raiz)
    m.resultados.content = raiz
end sub

sub onResultado()
    c = m.resultados.rowItemSelected
    no = m.resultados.content.getChild(c[0]).getChild(c[1])
    if no.itemType = "channel" then
        m.top.tuneRequested = no.item
    else
        m.top.itemSelected = no.item
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

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
