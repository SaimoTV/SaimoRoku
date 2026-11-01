' ====================================================================
' Saimo TV - ChannelDrawer (BrightScript)
' Painel "Canais" da TV Box: seções em pílulas, lista à esquerda e, à
' direita, a prévia do vídeo com a programação do canal em foco.
' ====================================================================

sub init()
    m.painel = m.top.findNode("painel")
    m.chips = m.top.findNode("chips")
    m.lista = m.top.findNode("channelList")
    m.contaGrupo = m.top.findNode("contaGrupo")
    m.contaTotal = m.top.findNode("contaTotal")
    m.infoCanal = m.top.findNode("infoCanal")
    m.infoPrograma = m.top.findNode("infoPrograma")
    m.infoHora = m.top.findNode("infoHora")
    m.infoSeguir = m.top.findNode("infoSeguir")

    m.secoes = []
    m.secao = 0
    m.area = "lista"
    m.lista.observeField("itemSelected", "onCanal")
    m.lista.observeField("itemFocused", "onFocoCanal")
    m.top.observeField("focusedChild", "onFocusedChildChange")
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() and m.area = "lista" and not m.lista.isInFocusChain() then m.lista.setFocus(true)
end sub

sub onChannelsChange()
    canais = m.top.channels
    if canais = invalid then return
    vistos = {}
    ordem = []
    for each c in canais
        g = c.category
        if g = invalid or g = "" then g = "Outros"
        if not vistos.DoesExist(g) then
            vistos[g] = true
            ordem.Push(g)
        end if
    end for
    if LoadFavoriteChannels().Count() > 0 then ordem.Unshift("Favoritos")
    m.secoes = ordem
    if m.secao >= ordem.Count() then m.secao = 0
    desenharChips()
    preencher()
end sub

function atual(canal as Object) as Dynamic
    mapa = m.top.epgMap
    if mapa = invalid or mapa[canal.name] = invalid then return invalid
    agora = CreateObject("roDateTime").AsSeconds()
    programas = mapa[canal.name]
    for i = 0 to programas.Count() - 1
        p = programas[i]
        if agora >= p.startSec and agora < p.stopSec then
            r = { titulo: p.title, ini: p.startSec, fim: p.stopSec, seguinte: "" }
            if i + 1 < programas.Count() then r.seguinte = programas[i + 1].title
            return r
        end if
    end for
    return invalid
end function

sub desenharChips()
    m.chips.removeChildrenIndex(m.chips.getChildCount(), 0)
    x = 0
    m.posChip = []
    for i = 0 to m.secoes.Count() - 1
        t = m.secoes[i]
        w = Len(t) * 15 + 52
        g = m.chips.createChild("Group")
        g.id = "chip" + i.ToStr()
        g.translation = [x, 0]
        f = g.createChild("Poster")
        f.uri = "pkg:/images/p_chip.9.png"
        f.width = w : f.height = 68
        r = g.createChild("Label")
        r.width = w : r.height = 68
        r.horizAlign = "center" : r.vertAlign = "center"
        r.font.uri = "pkg:/fonts/Roboto-Medium.ttf"
        r.font.size = 28
        r.color = "#FFFFFF"
        r.text = t
        m.posChip.Push({ x: x, w: w })
        x = x + w + 12
    end for
    marcarChips()
end sub

sub marcarChips()
    for i = 0 to m.secoes.Count() - 1
        g = m.chips.findNode("chip" + i.ToStr())
        if g <> invalid then
            f = g.getChild(0)
            r = g.getChild(1)
            if i = m.secao and m.area = "chips" then
                f.uri = "pkg:/images/p_branca.9.png" : r.color = "#0b0e14"
            else if i = m.secao then
                f.uri = "pkg:/images/p_sel.9.png" : r.color = "#4FE3D0"
            else
                f.uri = "pkg:/images/p_chip.9.png" : r.color = "#FFFFFF"
            end if
        end if
    end for
    if m.posChip <> invalid and m.secao < m.posChip.Count() then
        p = m.posChip[m.secao]
        desloca = 0
        if p.x + p.w > 760 then desloca = 760 - (p.x + p.w)
        m.chips.translation = [32 + desloca, 0]
    end if
end sub

sub preencher()
    canais = m.top.channels
    if canais = invalid or m.secoes.Count() = 0 then return
    nome = m.secoes[m.secao]
    m.filtrados = []
    raiz = CreateObject("roSGNode", "ContentNode")
    for each c in canais
        if nome = "Favoritos" then
            entra = IsChannelFavorite(c.name)
        else
            entra = c.category = nome
        end if
        if entra then
            m.filtrados.Push(c)
            no = raiz.CreateChild("ContentNode")
            no.title = c.name
            if c.logo <> invalid then no.hdPosterUrl = c.logo
            prog = ""
            pct = 0.0
            a = atual(c)
            if a <> invalid then
                prog = a.titulo
                d = CreateObject("roDateTime").AsSeconds()
                if a.fim > a.ini then pct = (d - a.ini) / (a.fim - a.ini)
            end if
            no.addFields({ numero: c.number.ToStr(), grupoTexto: UCase(nome), programa: prog, progresso: pct })
        end if
    end for
    m.lista.content = raiz
    m.contaGrupo.text = m.filtrados.Count().ToStr()
    m.contaTotal.text = canais.Count().ToStr()
    if m.filtrados.Count() > 0 then mostrarInfo(m.filtrados[0])
end sub

function hora(seg as Integer) as String
    d = CreateObject("roDateTime")
    d.FromSeconds(seg)
    d.ToLocalTime()
    h = d.GetHours().ToStr()
    if Len(h) < 2 then h = "0" + h
    mi = d.GetMinutes().ToStr()
    if Len(mi) < 2 then mi = "0" + mi
    return h + ":" + mi
end function

sub mostrarInfo(c as Object)
    m.infoCanal.text = c.number.ToStr() + "  " + c.name
    a = atual(c)
    if a = invalid then
        m.infoPrograma.text = "Ao vivo"
        m.infoHora.text = ""
        m.infoSeguir.text = ""
        return
    end if
    m.infoPrograma.text = a.titulo
    faltam = Int((a.fim - CreateObject("roDateTime").AsSeconds()) / 60)
    m.infoHora.text = hora(a.ini) + " – " + hora(a.fim) + "  ·  faltam " + faltam.ToStr() + " min"
    m.infoSeguir.text = ""
    if a.seguinte <> "" then m.infoSeguir.text = "A seguir: " + a.seguinte
end sub

sub onFocoCanal()
    i = m.lista.itemFocused
    if m.filtrados <> invalid and i >= 0 and i < m.filtrados.Count() then mostrarInfo(m.filtrados[i])
end sub

sub onOpenChange()
    m.painel.visible = m.top.isOpen
    if m.top.isOpen then
        m.area = "lista"
        marcarChips()
        canais = m.top.channels
        if canais <> invalid and m.top.selectedIndex < canais.Count() and m.secoes.Count() > 0 then
            c = canais[m.top.selectedIndex]
            for i = 0 to m.secoes.Count() - 1
                if m.secoes[i] = c.category and i <> m.secao then
                    m.secao = i
                    preencher()
                    marcarChips()
                end if
            end for
            if m.filtrados <> invalid then
                for i = 0 to m.filtrados.Count() - 1
                    if m.filtrados[i].name = c.name then m.lista.jumpToItem = i
                end for
            end if
        end if
        m.lista.setFocus(true)
    end if
end sub

sub onCanal()
    i = m.lista.itemSelected
    if m.filtrados <> invalid and i >= 0 and i < m.filtrados.Count() then
        m.top.channelSelected = m.filtrados[i]
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.area = "chips" then
        if key = "left" and m.secao > 0 then
            m.secao = m.secao - 1
        else if key = "right" and m.secao < m.secoes.Count() - 1 then
            m.secao = m.secao + 1
        else if key = "down" or key = "OK" then
            m.area = "lista"
            marcarChips()
            m.lista.setFocus(true)
            return true
        else if key = "up" then
            m.top.focusUpRequested = true
            return true
        else if key = "back" then
            m.area = "lista"
            marcarChips()
            m.lista.setFocus(true)
            return true
        else
            return true
        end if
        marcarChips()
        preencher()
        return true
    end if

    if key = "left" or key = "up" then
        m.area = "chips"
        marcarChips()
        m.top.setFocus(true)
        return true
    else if key = "right" then
        i = m.lista.itemFocused
        if m.filtrados <> invalid and i >= 0 and i < m.filtrados.Count() then m.top.fontesRequested = m.filtrados[i]
        return true
    else if key = "options" or key = "replay" then
        i = m.lista.itemFocused
        if m.filtrados <> invalid and i >= 0 and i < m.filtrados.Count() then
            ToggleFavoriteChannel(m.filtrados[i].name)
            onChannelsChange()
        end if
        return true
    end if
    return false
end function
