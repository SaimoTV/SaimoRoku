' ====================================================================
' Saimo TV - MinhasListasScreen (BrightScript)
' Lista > ações da lista; "Adicionar lista" abre o teclado (link, depois nome).
' ====================================================================

sub init()
    m.lista = m.top.findNode("lista")
    m.botoes = m.top.findNode("botoes")
    m.teclado = m.top.findNode("teclado")
    m.aviso = m.top.findNode("aviso")
    m.painelLista = m.top.findNode("painelLista")
    m.painelTeclado = m.top.findNode("painelTeclado")
    m.tituloCampo = m.top.findNode("tituloCampo")

    m.lista.observeField("itemSelected", "onItem")
    m.botoes.observeField("itemSelected", "onBotao")
    m.modo = "lista" ' lista | acoes | confirmar | link | nome
    m.link = ""
    m.ocupado = false
    m.top.observeField("focusedChild", "onFocusedChildChange")
    mostrarListas()
end sub

sub cleanUp()
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() and not m.lista.isInFocusChain() and not m.painelTeclado.isInFocusChain() then
        focar()
    end if
end sub

sub focar()
    if m.painelTeclado.visible then m.teclado.setFocus(true) else m.lista.setFocus(true)
end sub

sub preencher(textos as Object)
    raiz = CreateObject("roSGNode", "ContentNode")
    for each t in textos
        raiz.CreateChild("ContentNode").title = t
    end for
    m.lista.content = raiz
    m.lista.jumpToItem = 0
end sub

function haQuanto(segundos as Integer) as String
    d = CreateObject("roDateTime").AsSeconds() - segundos
    if d < 3600 then return "atualizada agora"
    if d < 86400 then return "atualizada há " + Int(d / 3600).ToStr() + " h"
    return "atualizada há " + Int(d / 86400).ToStr() + " d"
end function

sub mostrarListas()
    m.modo = "lista"
    m.listas = LoadMinhasListas()
    textos = ["Adicionar lista"]
    for each l in m.listas
        linha = l.nome + "  ·  " + l.total.ToStr() + " canais  ·  " + haQuanto(l.atualizadaEm)
        if not l.ativa then linha = linha + "  ·  desativada"
        textos.Push(linha)
    end for
    preencher(textos)
    m.painelTeclado.visible = false
    m.painelLista.visible = true
    if m.top.isInFocusChain() then m.lista.setFocus(true)
end sub

sub onItem()
    if m.ocupado then return
    i = m.lista.itemSelected
    if m.modo = "lista" then
        if i = 0 then
            abrirCampo("link")
        else
            m.atual = m.listas[i - 1]
            m.modo = "acoes"
            alternar = "Desativar"
            if not m.atual.ativa then alternar = "Ativar"
            preencher(["Atualizar", alternar, "Remover", "Voltar"])
        end if
    else if m.modo = "acoes" then
        if i = 0 then
            rodar("atualizar", "Atualizando a lista...")
        else if i = 1 then
            for each l in m.listas
                if l.id = m.atual.id then l.ativa = not l.ativa
            end for
            SaveMinhasListas(m.listas)
            rodar("carregar", "")
        else if i = 2 then
            m.modo = "confirmar"
            preencher(["Remover " + m.atual.nome, "Cancelar"])
        else
            mostrarListas()
        end if
    else if m.modo = "confirmar" then
        if i = 0 then
            restantes = []
            for each l in m.listas
                if l.id <> m.atual.id then restantes.Push(l)
            end for
            SaveMinhasListas(restantes)
            DeleteFile("cachefs:/minhas_" + m.atual.id + ".json")
            rodar("carregar", "")
        else
            mostrarListas()
        end if
    end if
end sub

sub abrirCampo(modo as String)
    m.modo = modo
    m.aviso.text = ""
    m.teclado.text = ""
    raiz = CreateObject("roSGNode", "ContentNode")
    if modo = "link" then
        m.tituloCampo.text = "Link da lista (.m3u)"
        raiz.CreateChild("ContentNode").title = "Continuar"
    else
        m.tituloCampo.text = "Nome (opcional)"
        raiz.CreateChild("ContentNode").title = "Adicionar lista"
    end if
    raiz.CreateChild("ContentNode").title = "Cancelar"
    m.botoes.content = raiz
    m.painelLista.visible = false
    m.painelTeclado.visible = true
    m.teclado.setFocus(true)
end sub

sub onBotao()
    if m.ocupado then return
    if m.botoes.itemSelected = 1 then
        mostrarListas()
    else if m.modo = "link" then
        m.link = m.teclado.text.Trim()
        abrirCampo("nome")
    else
        m.nome = m.teclado.text.Trim()
        mostrarListas()
        rodar("adicionar", "Baixando a lista...")
    end if
end sub

' Link enviado pelo celular (Saimo Connect) cai direto no campo.
sub onTextoRecebido()
    if m.modo = "link" or m.modo = "nome" then
        m.teclado.text = m.top.textoRecebido
        m.botoes.setFocus(true)
    end if
end sub

sub rodar(acao as String, mensagem as String)
    m.ocupado = true
    m.aviso.text = mensagem
    t = CreateObject("roSGNode", "MinhasListasTask")
    t.acao = acao
    t.link = m.link
    t.nome = m.nome
    if m.atual <> invalid then t.listaId = m.atual.id
    t.observeField("pronto", "onPronto")
    m.tarefaAtiva = t
    t.control = "run"
end sub

sub onPronto()
    m.ocupado = false
    t = m.tarefaAtiva
    m.aviso.text = t.erro
    if t.erro = "" then m.top.listasMudaram = { canais: t.canais }
    mostrarListas()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back" then
        if m.modo <> "lista" then
            mostrarListas()
            return true
        end if
        return false
    end if
    if m.painelTeclado.visible then
        if key = "down" and m.teclado.isInFocusChain() then
            m.botoes.setFocus(true)
            return true
        else if key = "up" and m.botoes.isInFocusChain() then
            m.teclado.setFocus(true)
            return true
        end if
    else if key = "up" then
        m.top.focusUpRequested = true
        return true
    end if
    return false
end function
