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

' Nova árvore (a programação chegou): troca sem tirar a pessoa do lugar.
sub onArvore()
    m.arvore = m.top.arvore
    if m.arvore = invalid then return
    foco = m.lista.itemFocused
    atualizarSecoes()
    preencher()
    if foco > 0 then m.lista.jumpToItem = foco
end sub

sub atualizarSecoes()
    ordem = []
    for i = 0 to m.arvore.getChildCount() - 1
        ordem.Push(m.arvore.getChild(i).title)
    end for
    m.temFavoritos = LoadFavoriteChannels().Count() > 0
    if m.temFavoritos then ordem.Unshift("Favoritos")
    m.secoes = ordem
    if m.secao >= ordem.Count() then m.secao = 0
    desenharChips()
end sub

function totalDeCanais() as Integer
    n = 0
    for i = 0 to m.arvore.getChildCount() - 1
        n = n + m.arvore.getChild(i).getChildCount()
    end for
    return n
end function

' Favoritos é a única seção montada na hora: são poucos.
function noDosFavoritos() as Object
    nomes = {}
    for each f in LoadFavoriteChannels()
        nomes[f] = true
    end for
    raiz = CreateObject("roSGNode", "ContentNode")
    for i = 0 to m.arvore.getChildCount() - 1
        secao = m.arvore.getChild(i)
        for j = 0 to secao.getChildCount() - 1
            c = secao.getChild(j)
            if nomes.DoesExist(c.title) then
                no = raiz.CreateChild("ContentNode")
                no.title = c.title
                no.hdPosterUrl = c.hdPosterUrl
                no.addFields({ name: c.name, number: c.number, category: c.category, logo: c.logo, variants: c.variants, numero: c.numero, grupoTexto: c.grupoTexto, programa: c.programa, progresso: c.progresso, ini: c.ini, fim: c.fim, seguinte: c.seguinte })
            end if
        end for
    end for
    return raiz
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
    if m.arvore = invalid or m.secoes.Count() = 0 then return
    nome = m.secoes[m.secao]
    if nome = "Favoritos" then
        conteudo = noDosFavoritos()
    else
        indice = m.secao
        if m.temFavoritos then indice = indice - 1
        conteudo = m.arvore.getChild(indice)
    end if
    m.conteudo = conteudo
    m.lista.content = conteudo
    m.contaGrupo.text = conteudo.getChildCount().ToStr()
    m.contaTotal.text = totalDeCanais().ToStr()
    if conteudo.getChildCount() > 0 then mostrarInfo(conteudo.getChild(0))
end sub

function canalEm(i as Integer) as Dynamic
    if m.conteudo = invalid or i < 0 or i >= m.conteudo.getChildCount() then return invalid
    return m.conteudo.getChild(i)
end function

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
    m.infoCanal.text = c.numero + "  " + c.title
    if c.programa = "" then
        m.infoPrograma.text = "Ao vivo"
        m.infoHora.text = ""
        m.infoSeguir.text = ""
        return
    end if
    m.infoPrograma.text = c.programa
    faltam = Int((c.fim - CreateObject("roDateTime").AsSeconds()) / 60)
    m.infoHora.text = hora(c.ini) + " – " + hora(c.fim) + "  ·  faltam " + faltam.ToStr() + " min"
    m.infoSeguir.text = ""
    if c.seguinte <> "" then m.infoSeguir.text = "A seguir: " + c.seguinte
end sub

sub onFocoCanal()
    c = canalEm(m.lista.itemFocused)
    if c <> invalid then mostrarInfo(c)
end sub

sub onOpenChange()
    m.painel.visible = m.top.isOpen
    if m.top.isOpen then
        m.area = "lista"
        marcarChips()
        if m.arvore <> invalid and m.secoes.Count() > 0 then
            ' Abre na seção e no canal que estão tocando.
            n = m.top.selectedIndex
            base = 0
            if m.temFavoritos then base = 1
            for i = 0 to m.arvore.getChildCount() - 1
                secao = m.arvore.getChild(i)
                for j = 0 to secao.getChildCount() - 1
                    if secao.getChild(j).number = n + 1 then
                        if m.secao <> i + base then
                            m.secao = i + base
                            preencher()
                            marcarChips()
                        end if
                        m.lista.jumpToItem = j
                        exit for
                    end if
                end for
            end for
        end if
        m.lista.setFocus(true)
    end if
end sub

sub onCanal()
    c = canalEm(m.lista.itemSelected)
    if c <> invalid then m.top.channelSelected = c
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
        c = canalEm(m.lista.itemFocused)
        if c <> invalid then m.top.fontesRequested = c
        return true
    else if key = "options" then
        c = canalEm(m.lista.itemFocused)
        if c <> invalid then m.top.menuRequested = c
        return true
    else if key = "replay" then
        c = canalEm(m.lista.itemFocused)
        if c <> invalid then
            ToggleFavoriteChannel(c.title)
            atualizarSecoes()
            preencher()
        end if
        return true
    end if
    return false
end function
