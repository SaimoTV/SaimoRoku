' ====================================================================
' Saimo TV - PerfisScreen: "Quem está assistindo?", gerenciar e editar.
' Perfil Kids: sair dele, gerenciar estando nele e editar um Kids pedem o
' código de 4 dígitos. Contrato em SaimoPlayer/docs/perfis.md.
' ====================================================================

sub init()
    m.titulo = m.top.findNode("titulo")
    m.subtitulo = m.top.findNode("sub")
    m.grade = m.top.findNode("grade")
    m.acoes = m.top.findNode("acoes")
    m.grade.observeField("itemSelected", "onGrade")
    m.acoes.observeField("itemSelected", "onAcao")
    m.top.observeField("focusedChild", "onFoco")
    m.destrancado = false
    m.editando = invalid
    desenhar()
end sub

sub onModoChange()
    desenhar()
end sub

sub onFoco()
    if m.top.isInFocusChain() and not m.grade.isInFocusChain() and not m.acoes.isInFocusChain() then m.grade.setFocus(true)
end sub

sub desenhar()
    modo = m.top.modo
    m.perfis = PerfisEstado().lista
    conteudo = CreateObject("roSGNode", "ContentNode")
    if modo = "editar" then
        m.titulo.text = "Escolha um avatar"
        m.subtitulo.text = m.ed.nome
        for each a in PerfisAvatares()
            item = conteudo.createChild("ContentNode")
            item.title = ""
            item.HDPosterUrl = "pkg:/images/avatares/" + a + ".png"
            if a = m.ed.avatar then item.shortDescriptionLine2 = "escolhido"
        end for
        m.grade.numRows = 4
    else
        if modo = "gerenciar" then
            m.titulo.text = "Gerenciar perfis"
            m.subtitulo.text = "Escolha um perfil para mudar o nome, o avatar ou o Kids."
        else
            m.titulo.text = "Quem está assistindo?"
            m.subtitulo.text = ""
        end if
        for each p in m.perfis
            item = conteudo.createChild("ContentNode")
            item.title = p.nome
            item.HDPosterUrl = "pkg:/images/avatares/" + p.avatar + ".png"
            if p.kids = true then item.shortDescriptionLine2 = "kids"
        end for
        if m.perfis.Count() < 10 and (modo = "gerenciar" or not KidsAtivo()) then
            item = conteudo.createChild("ContentNode")
            item.title = "Adicionar perfil"
        end if
        m.grade.numRows = 2
    end if
    m.grade.content = conteudo

    acoes = CreateObject("roSGNode", "ContentNode")
    m.listaAcoes = []
    if modo = "editar" then
        kids = "não"
        if m.ed.kids then kids = "sim"
        m.listaAcoes = ["nome", "kids", "salvar", "cancelar"]
        rotulos = ["Nome: " + m.ed.nome, "Perfil Kids: " + kids, "Salvar", "Cancelar"]
        if m.editando <> invalid and m.editando.id <> "principal" then
            m.listaAcoes.Push("apagar")
            rotulos.Push("Apagar perfil")
        end if
        for each r in rotulos
            linha = acoes.createChild("ContentNode")
            linha.title = r
        end for
        m.acoes.translation = [660, 860]
    else if modo = "gerenciar" then
        m.listaAcoes = ["pronto"]
        linha = acoes.createChild("ContentNode")
        linha.title = "Pronto"
        m.acoes.translation = [660, 900]
    else
        m.listaAcoes = ["gerenciar"]
        linha = acoes.createChild("ContentNode")
        linha.title = "Gerenciar perfis"
        if not m.top.obrigatoria then
            m.listaAcoes.Push("fechar")
            linha = acoes.createChild("ContentNode")
            linha.title = "Fechar"
        end if
        m.acoes.translation = [660, 900]
    end if
    m.acoes.content = acoes
    m.grade.setFocus(true)
end sub

' Pede o código do perfil Kids p; certo, roda a ação guardada em m.depois.
sub comCodigo(p as Object, motivo as String, depois as Object)
    if not PerfisPedeCodigo(p) or (m.destrancado and p.id = PerfisEstado().ativo) then
        executar(depois)
        return
    end if
    m.pedidoPerfil = p
    m.depois = depois
    d = CreateObject("roSGNode", "StandardPinPadDialog")
    d.title = "Código do perfil " + p.nome
    d.message = [motivo]
    d.buttons = ["Confirmar", "Cancelar"]
    d.observeField("buttonSelected", "onCodigo")
    m.top.getScene().dialog = d
end sub

sub onCodigo(evt as Object)
    d = evt.getRoSGNode()
    botao = evt.getData()
    pin = d.pin
    d.close = true
    if botao <> 0 then return
    if PerfisConferirCodigo(m.pedidoPerfil, pin) then
        if m.pedidoPerfil.id = PerfisEstado().ativo then m.destrancado = true
        executar(m.depois)
    else
        aviso("Código errado", "O código não confere. Tente de novo.")
    end if
end sub

sub aviso(titulo as String, texto as String)
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = titulo
    d.message = [texto]
    d.buttons = ["OK"]
    d.observeField("buttonSelected", "onFecharDialogo")
    m.top.getScene().dialog = d
end sub

sub onFecharDialogo(evt as Object)
    evt.getRoSGNode().close = true
end sub

sub executar(a as Object)
    if a.tipo = "entrar" then
        m.top.perfilEscolhido = a.id
    else if a.tipo = "gerenciar" then
        m.top.modo = "gerenciar"
    else if a.tipo = "editar" then
        abrirEdicao(a.perfil)
    end if
end sub

sub abrirEdicao(p as Dynamic)
    m.editando = p
    if p = invalid then
        avatar = PerfisAvatares()[0]
        usados = {}
        for each x in m.perfis
            usados[x.avatar] = true
        end for
        for each a in PerfisAvatares()
            if not usados.DoesExist(a) then
                avatar = a
                exit for
            end if
        end for
        m.ed = { nome: "Novo perfil", avatar: avatar, kids: false, codigo: invalid }
    else
        m.ed = { nome: p.nome, avatar: p.avatar, kids: p.kids = true, codigo: invalid }
    end if
    m.top.modo = "editar"
end sub

sub onGrade(evt as Object)
    i = evt.getData()
    modo = m.top.modo
    if modo = "editar" then
        m.ed.avatar = PerfisAvatares()[i]
        desenhar()
        m.grade.jumpToItem = i
        return
    end if
    atual = PerfilAtivo()
    if i >= m.perfis.Count() then
        if modo = "gerenciar" then
            abrirEdicao(invalid)
        else
            comCodigo(atual, "Para criar um perfil, digite o código deste perfil Kids.", { tipo: "editar", perfil: invalid })
        end if
        return
    end if
    p = m.perfis[i]
    if modo = "gerenciar" then
        comCodigo(p, "Para editar o perfil " + p.nome + ", digite o código dele.", { tipo: "editar", perfil: p })
    else if p.id = atual.id then
        m.top.perfilEscolhido = p.id
    else
        comCodigo(atual, "Para sair do perfil " + atual.nome + ", digite o código.", { tipo: "entrar", id: p.id })
    end if
end sub

sub onAcao(evt as Object)
    a = m.listaAcoes[evt.getData()]
    if a = "gerenciar" then
        comCodigo(PerfilAtivo(), "Para gerenciar os perfis, digite o código deste perfil Kids.", { tipo: "gerenciar" })
    else if a = "fechar" then
        m.top.fechar = true
    else if a = "pronto" then
        m.top.modo = "escolher"
    else if a = "nome" then
        d = CreateObject("roSGNode", "StandardKeyboardDialog")
        d.title = "Nome do perfil"
        d.text = m.ed.nome
        d.buttons = ["OK", "Cancelar"]
        d.observeField("buttonSelected", "onNome")
        m.top.getScene().dialog = d
    else if a = "kids" then
        if m.ed.kids then
            m.ed.kids = false
            desenhar()
            m.acoes.setFocus(true)
        else
            d = CreateObject("roSGNode", "StandardPinPadDialog")
            d.title = "Código do perfil Kids"
            d.message = ["Escolha um código de 4 números. Ele será pedido para sair do Kids e abrir os Ajustes."]
            d.buttons = ["Confirmar", "Cancelar"]
            d.observeField("buttonSelected", "onCodigoNovo")
            m.top.getScene().dialog = d
        end if
    else if a = "salvar" then
        salvar()
    else if a = "cancelar" then
        m.top.modo = "gerenciar"
    else if a = "apagar" then
        d = CreateObject("roSGNode", "StandardMessageDialog")
        d.title = "Apagar perfil"
        d.message = ["Apagar o perfil " + m.editando.nome + "? Os favoritos e o progresso dele somem."]
        d.buttons = ["Apagar", "Cancelar"]
        d.observeField("buttonSelected", "onApagar")
        m.top.getScene().dialog = d
    end if
end sub

sub onNome(evt as Object)
    d = evt.getRoSGNode()
    if evt.getData() = 0 and d.text.Trim() <> "" then m.ed.nome = Left(d.text.Trim(), 20)
    d.close = true
    desenhar()
    m.acoes.setFocus(true)
end sub

sub onCodigoNovo(evt as Object)
    d = evt.getRoSGNode()
    pin = d.pin
    d.close = true
    if evt.getData() <> 0 then return
    if Len(pin) <> 4 then
        aviso("Código", "O código do Kids tem 4 números.")
        return
    end if
    m.ed.kids = true
    m.ed.codigo = pin
    desenhar()
    m.acoes.setFocus(true)
end sub

sub onApagar(evt as Object)
    d = evt.getRoSGNode()
    d.close = true
    if evt.getData() = 0 then
        PerfisApagar(m.editando.id)
        m.top.modo = "gerenciar"
    end if
end sub

sub salvar()
    if m.ed.kids and m.ed.codigo = invalid and not (m.editando <> invalid and PerfisPedeCodigo(m.editando)) then
        aviso("Código", "Escolha o código do perfil Kids.")
        return
    end if
    kidsCodigo = invalid
    if m.ed.kids then
        if m.ed.codigo <> invalid then kidsCodigo = m.ed.codigo
    else if m.editando <> invalid and m.editando.kids = true then
        kidsCodigo = ""
    end if
    if m.editando = invalid then
        cod = ""
        if kidsCodigo <> invalid then cod = kidsCodigo
        PerfisCriar(m.ed.nome, m.ed.avatar, cod)
    else
        PerfisEditar(m.editando.id, m.ed.nome, m.ed.avatar, kidsCodigo)
    end if
    m.top.modo = "gerenciar"
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if not m.grade.hasFocus() and not m.acoes.hasFocus() and key <> "back" then
        m.grade.setFocus(true)
        return true
    end if
    if key = "down" and m.grade.hasFocus() then
        m.acoes.setFocus(true)
        return true
    else if key = "up" and m.acoes.hasFocus() then
        m.grade.setFocus(true)
        return true
    else if key = "back" then
        modo = m.top.modo
        if modo = "editar" then
            m.top.modo = "gerenciar"
        else if modo = "gerenciar" then
            m.top.modo = "escolher"
        else if not m.top.obrigatoria then
            m.top.fechar = true
        end if
        return true
    end if
    return false
end function
