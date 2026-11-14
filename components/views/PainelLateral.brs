sub init()
    m.painel = m.top.findNode("painel")
    m.lista = m.top.findNode("lista")
    m.lista.observeField("itemSelected", "onItem")
    m.top.findNode("focoTimer").observeField("fire", "aplicarFoco")
end sub

sub onOpcoes()
    raiz = CreateObject("roSGNode", "ContentNode")
    for each o in m.top.opcoes
        n = raiz.CreateChild("ContentNode")
        n.title = o.titulo
        if o.detalhe <> invalid then n.description = o.detalhe
    end for
    m.lista.content = raiz
end sub

sub onAberto()
    m.top.findNode("tituloLabel").text = m.top.titulo
    m.top.findNode("ajudaLabel").text = m.top.ajuda
    m.painel.visible = m.top.aberto
    if m.top.aberto then
        t = m.top.findNode("focoTimer")
        t.control = "start"
    else
        ' Devolve o foco à tela: lista escondida com foco prende todas as teclas.
        m.top.getParent().setFocus(true)
    end if
end sub

sub aplicarFoco()
    m.lista.setFocus(true)
end sub

sub onItem()
    m.top.escolhido = m.lista.itemSelected
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press or not m.top.aberto then return false
    if key = "back" or key = "left" then
        m.top.aberto = false
        return true
    end if
    return true
end function
