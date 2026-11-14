' ====================================================================
' Saimo TV - RadiosScreen (BrightScript)
' Fileiras por gênero; OK toca em tela cheia, cima e baixo trocam a estação.
' ====================================================================

sub init()
    m.grade = m.top.findNode("grade")
    m.tocando = m.top.findNode("tocando")
    m.heroBanner = m.top.findNode("heroBanner")
    m.rows = m.top.findNode("radiosRows")
    m.radioLogo = m.top.findNode("radioLogo")
    m.radioName = m.top.findNode("radioName")
    m.radioGenre = m.top.findNode("radioGenre")
    m.radioAudio = m.top.findNode("radioAudio")
    m.heroTimer = m.top.findNode("heroTimer")
    m.barrasTimer = m.top.findNode("barrasTimer")

    m.heroTimer.observeField("fire", "aplicarDestaque")
    m.barrasTimer.observeField("fire", "animarBarras")
    m.rows.observeField("rowItemSelected", "onRadioSelected")
    m.rows.observeField("rowItemFocused", "onRowItemFocused")
    m.top.observeField("focusedChild", "onFocusedChildChange")
    m.atual = -1
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() and not m.rows.isInFocusChain() and not m.tocando.visible then m.rows.setFocus(true)
end sub

sub onRadiosChange()
    radios = m.top.radios
    if radios = invalid or radios.Count() = 0 then return
    m.estacoes = radios

    ordem = []
    grupos = {}
    for i = 0 to radios.Count() - 1
        g = radios[i].genre
        if g = invalid or g = "" then g = "Outras"
        if grupos[g] = invalid then
            grupos[g] = []
            ordem.Push(g)
        end if
        grupos[g].Push(i)
    end for

    root = CreateObject("roSGNode", "ContentNode")
    ' "Outras" sempre por último.
    if grupos["Outras"] <> invalid then
        semOutras = []
        for each g in ordem
            if g <> "Outras" then semOutras.Push(g)
        end for
        semOutras.Push("Outras")
        ordem = semOutras
    end if
    for each g in ordem
        linha = root.CreateChild("ContentNode")
        linha.title = g
        for each i in grupos[g]
            r = radios[i]
            no = linha.CreateChild("ContentNode")
            no.title = r.name
            if r.logo <> invalid then no.hdPosterUrl = r.logo
            no.addFields({ itemType: "radio", indice: i })
        end for
    end for
    AjustarFileiras(m.rows, root)
    m.rows.content = root
end sub

function noEm(coords as Dynamic) as Dynamic
    root = m.rows.content
    if root = invalid or coords = invalid or coords.Count() < 2 then return invalid
    return root.getChild(coords[0]).getChild(coords[1])
end function

sub onRowItemFocused()
    m.heroTimer.control = "stop"
    m.heroTimer.control = "start"
end sub

sub aplicarDestaque()
    no = noEm(m.rows.rowItemFocused)
    if no = invalid then return
    r = m.estacoes[no.indice]
    m.heroBanner.featuredItem = { title: r.name, genres: "Rádio ao vivo  ·  " + r.genre, overview: "OK toca  ·  na rádio, cima e baixo trocam de estação", semFundo: true }
end sub

sub onRadioSelected()
    no = noEm(m.rows.rowItemSelected)
    if no <> invalid then tocar(no.indice)
end sub

sub tocar(i as Integer)
    radios = m.estacoes
    m.atual = i
    r = radios[i]
    m.radioName.text = r.name
    m.radioGenre.text = r.genre + "  ·  Estação " + (i + 1).ToStr() + " de " + radios.Count().ToStr()
    m.radioLogo.uri = ""
    if r.logo <> invalid then m.radioLogo.uri = r.logo

    content = CreateObject("roSGNode", "ContentNode")
    content.url = r.url
    content.streamFormat = "mp3"
    m.radioAudio.control = "stop"
    m.radioAudio.content = content
    m.radioAudio.control = "play"

    m.grade.visible = false
    m.tocando.visible = true
    m.top.telaCheia = true
    m.barrasTimer.control = "start"
    m.top.setFocus(true)
end sub

sub animarBarras()
    for i = 0 to 35
        b = m.top.findNode("barra_" + i.ToStr())
        h = 30 + Rnd(130)
        b.height = h
        b.translation = [i * 20, 160 - h]
    end for
end sub

sub fechar()
    m.radioAudio.control = "stop"
    m.barrasTimer.control = "stop"
    m.tocando.visible = false
    m.grade.visible = true
    m.top.telaCheia = false
    m.rows.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.tocando.visible then
        total = m.estacoes.Count()
        if key = "up" then
            tocar((m.atual + total - 1) mod total)
        else if key = "down" then
            tocar((m.atual + 1) mod total)
        else if key = "back" or key = "left" then
            fechar()
        end if
        return true
    end if

    if key = "up" then
        m.top.focusUpRequested = true
        return true
    end if
    return false
end function

sub cleanUp()
    if m.radioAudio <> invalid then
        m.radioAudio.control = "stop"
        m.radioAudio.content = invalid
    end if
    if m.barrasTimer <> invalid then m.barrasTimer.control = "stop"
end sub
