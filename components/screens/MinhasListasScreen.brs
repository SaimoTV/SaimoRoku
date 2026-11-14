' ====================================================================
' Saimo TV - MinhasListasScreen (BrightScript)
' Permite configurar Endereço dos canais, Endereço de filmes e séries
' e gerenciar listas .m3u / Xtream.
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
    m.modo = "lista" ' lista | acoes | confirmar | urlCanais | urlFilmes | link | usuario | senha | nome
    m.link = ""
    m.usuario = ""
    m.senha = ""
    m.nome = ""
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
    t = m.top.findNode("focoTimer")
    t.observeField("fire", "aplicarFoco")
    t.control = "start"
end sub

sub aplicarFoco()
    if m.painelTeclado.visible then m.teclado.setFocus(true) else m.lista.setFocus(true)
end sub

sub preencher(textos as Object)
    raiz = CreateObject("roSGNode", "ContentNode")
    for each t in textos
        no = raiz.CreateChild("ContentNode")
        if Type(t) = "roArray" then
            no.title = t[0] : no.description = t[1]
        else
            no.title = t
        end if
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
    prefs = LoadPreferences()

    descCanais = "Não configurado · clique para definir"
    if prefs.urlCanais <> invalid and prefs.urlCanais.Trim() <> "" then
        descCanais = prefs.urlCanais
    end if

    descFilmes = "Não configurado · clique para definir"
    if prefs.urlFilmes <> invalid and prefs.urlFilmes.Trim() <> "" then
        descFilmes = prefs.urlFilmes
    end if

    textos = [
        ["Endereço dos canais", descCanais],
        ["Endereço de filmes e séries", descFilmes],
        ["Adicionar lista M3U", "Adicionar lista externa .m3u ou servidor Xtream"]
    ]
    for each l in m.listas
        linha = l.total.ToStr() + " canais  ·  " + haQuanto(l.atualizadaEm)
        if not l.ativa then linha = linha + "  ·  desativada"
        textos.Push([l.nome, linha])
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
            abrirCampo("urlCanais")
        else if i = 1 then
            abrirCampo("urlFilmes")
        else if i = 2 then
            abrirCampo("link")
        else
            m.atual = m.listas[i - 3]
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
    if m.teclado.textEditBox <> invalid then m.teclado.textEditBox.secureMode = (modo = "senha")
    raiz = CreateObject("roSGNode", "ContentNode")
    if modo = "urlCanais" or modo = "urlFilmes" then
        prefs = LoadPreferences()
        atual = ""
        if prefs[modo] <> invalid then atual = prefs[modo]
        m.teclado.text = atual
        if m.teclado.textEditBox <> invalid then m.teclado.textEditBox.text = atual
        if modo = "urlCanais" then
            m.tituloCampo.text = "Endereço dos canais (ex: canais-saimo.pages.dev)"
        else
            m.tituloCampo.text = "Endereço de filmes e séries (ex: filmes-saimo.pages.dev)"
        end if
        raiz.CreateChild("ContentNode").title = "Salvar"
        raiz.CreateChild("ContentNode").title = "Apagar endereço"
        raiz.CreateChild("ContentNode").title = "Cancelar"
    else if modo = "link" then
        m.tituloCampo.text = "Link da lista (M3U) ou servidor"
        raiz.CreateChild("ContentNode").title = "Continuar"
        raiz.CreateChild("ContentNode").title = "Cancelar"
    else if modo = "usuario" then
        m.tituloCampo.text = "Usuário (opcional): deixe em branco se a lista é só um link"
        raiz.CreateChild("ContentNode").title = "Continuar"
        raiz.CreateChild("ContentNode").title = "Cancelar"
    else if modo = "senha" then
        m.tituloCampo.text = "Senha"
        raiz.CreateChild("ContentNode").title = "Continuar"
        raiz.CreateChild("ContentNode").title = "Cancelar"
    else
        m.tituloCampo.text = "Nome (opcional)"
        raiz.CreateChild("ContentNode").title = "Adicionar lista"
        raiz.CreateChild("ContentNode").title = "Cancelar"
    end if
    m.botoes.content = raiz
    m.botoes.jumpToItem = 0
    m.painelLista.visible = false
    m.painelTeclado.visible = true
    m.teclado.setFocus(true)
end sub

function lerTextoTeclado() as String
    t = ""
    if m.teclado <> invalid and m.teclado.text <> invalid then
        t = m.teclado.text
    end if
    if t = "" and m.teclado <> invalid and m.teclado.textEditBox <> invalid and m.teclado.textEditBox.text <> invalid then
        t = m.teclado.textEditBox.text
    end if
    return t.Trim()
end function

sub salvarEnderecoCatalogo(chave as String, limpar as Boolean)
    prefs = LoadPreferences()
    novo = ""
    if not limpar then
        novo = NormalizarEnderecoSaimo(lerTextoTeclado())
    end if
    if chave = "urlCanais" then
        prefs.urlCanais = novo
    else if chave = "urlFilmes" then
        prefs.urlFilmes = novo
    else
        prefs[chave] = novo
    end if
    if limpar then
        m.aviso.text = "Endereço removido."
    else
        m.aviso.text = "Endereço salvo! Carregando catálogo..."
    end if
    SavePreferences(prefs)
    mostrarListas()
    m.top.reloadRequested = true
end sub

sub onBotao()
    if m.ocupado then return
    idx = m.botoes.itemSelected
    if m.modo = "urlCanais" or m.modo = "urlFilmes" then
        if idx = 0 then
            salvarEnderecoCatalogo(m.modo, false)
        else if idx = 1 then
            salvarEnderecoCatalogo(m.modo, true)
        else
            mostrarListas()
        end if
        return
    end if

    if idx = 1 then
        mostrarListas()
    else if m.modo = "link" then
        m.link = lerTextoTeclado()
        m.usuario = ""
        m.senha = ""
        abrirCampo("usuario")
    else if m.modo = "usuario" then
        m.usuario = lerTextoTeclado()
        ' Sem usuário: a lista é só o link, e a senha não se aplica.
        if m.usuario = "" then abrirCampo("nome") else abrirCampo("senha")
    else if m.modo = "senha" then
        m.senha = lerTextoTeclado()
        if m.senha = "" then
            abrirCampo("senha")
            m.aviso.text = "Usuário e senha andam juntos: preencha a senha ou volte e deixe o usuário em branco"
        else
            abrirCampo("nome")
        end if
    else
        m.nome = lerTextoTeclado()
        f = xtLinkDoFormulario(m.link, m.usuario, m.senha)
        if f.erro <> invalid then
            abrirCampo("link")
            m.aviso.text = f.erro
        else
            m.link = f.link
            mostrarListas()
            rodar("adicionar", "Baixando a lista...")
        end if
    end if
end sub

' Link enviado pelo celular (Saimo Connect) cai direto no campo.
sub onTextoRecebido()
    t = m.top.textoRecebido
    if t = invalid or t.Trim() = "" then return
    if m.modo = "lista" then
        foco = m.lista.itemFocused
        if foco = 0 then
            abrirCampo("urlCanais")
        else if foco = 1 then
            abrirCampo("urlFilmes")
        else
            abrirCampo("link")
        end if
    end if
    if m.modo = "urlCanais" or m.modo = "urlFilmes" or m.modo = "link" or m.modo = "usuario" or m.modo = "senha" or m.modo = "nome" then
        m.teclado.text = t.Trim()
        if m.teclado.textEditBox <> invalid then m.teclado.textEditBox.text = t.Trim()
        m.botoes.jumpToItem = 0
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
    if t.erro = "CATALOGO_SAIMO" then
        m.aviso.text = "Catálogo salvo! Carregando..."
        mostrarListas()
        m.top.reloadRequested = true
        return
    end if
    m.aviso.text = t.erro
    if t.listas <> invalid then SaveMinhasListas(t.listas)
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
        if key = "play" and (m.modo = "urlCanais" or m.modo = "urlFilmes") then
            salvarEnderecoCatalogo(m.modo, false)
            return true
        else if key = "down" and m.teclado.isInFocusChain() then
            m.botoes.jumpToItem = 0
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
