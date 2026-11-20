' ====================================================================
' Saimo TV - SettingsScreen Logic
' ====================================================================

sub init()
    m.settingsList = m.top.findNode("settingsList")
    m.lblSecao = m.top.findNode("lblSecao")
    m.versao = m.top.findNode("versao")
    m.painelTeclado = m.top.findNode("painelTeclado")
    m.tituloCampo = m.top.findNode("tituloCampo")
    m.teclado = m.top.findNode("teclado")
    ' O campo do teclado: caixa branca e texto escuro. O padrão do Roku deixava,
    ' em alguns aparelhos, letra branca sobre a caixa clara (não se via o que se digitava).
    if m.teclado.textEditBox <> invalid then
        m.teclado.textEditBox.backgroundUri = "pkg:/images/p_branca.9.png"
        m.teclado.textEditBox.textColor = "0x11161EFF"
        m.teclado.textEditBox.hintTextColor = "0x6B7280FF"
    end if
    m.botoes = m.top.findNode("botoes")
    m.campoAtivo = ""

    appInfo = CreateObject("roAppInfo")
    m.versao.text = "Saimo TV v" + appInfo.GetVersion()

    opcoesBotoes = CreateObject("roSGNode", "ContentNode")
    for each txt in ["Salvar", "Limpar", "Cancelar"]
        item = opcoesBotoes.createChild("ContentNode")
        item.title = txt
    end for
    m.botoes.content = opcoesBotoes
    m.botoes.observeField("itemSelected", "onBotaoTeclado")

    m.settingsList.observeField("itemSelected", "onItemSelected")
    m.top.observeField("focusedChild", "onFocusChange")

    buildSettingsList()
    m.liberado = not PerfisPedeCodigo(PerfilAtivo())
end sub

' No perfil Kids os Ajustes pedem o código: a criança não mexe nas listas nem nos ajustes.
sub pedirCodigoDosAjustes()
    m.settingsList.visible = false
    p = PerfilAtivo()
    d = CreateObject("roSGNode", "StandardPinPadDialog")
    d.title = "Código do perfil " + p.nome
    d.message = ["Os Ajustes ficam trancados no perfil Kids. Digite o código para abrir."]
    d.buttons = ["Confirmar", "Cancelar"]
    d.observeField("buttonSelected", "onCodigoDosAjustes")
    m.top.getScene().dialog = d
end sub

sub onCodigoDosAjustes(evt as Object)
    d = evt.getRoSGNode()
    pin = d.pin
    d.close = true
    if evt.getData() = 0 and PerfisConferirCodigo(PerfilAtivo(), pin) then
        m.liberado = true
        m.settingsList.visible = true
        m.settingsList.setFocus(true)
    else
        m.top.focusUpRequested = true
    end if
end sub

sub onFocusChange()
    if m.top.isInFocusChain() and not m.liberado then
        if m.top.getScene().dialog = invalid then pedirCodigoDosAjustes()
        return
    end if
    if m.top.isInFocusChain() then
        if m.painelTeclado.visible then
            if not m.teclado.isInFocusChain() and not m.botoes.isInFocusChain() then
                m.teclado.setFocus(true)
            end if
        else if not m.settingsList.isInFocusChain() then
            buildSettingsList()
            m.settingsList.setFocus(true)
        end if
    end if
end sub

sub buildSettingsList()
    m.prefs = LoadPreferences()
    content = CreateObject("roSGNode", "ContentNode")

    if not KidsAtivo() then
        if ContaLogado() then
            addSettingItem(content, "Conta Saimo", ContaResumo(), "conta")
        else
            ' Sem conta: a primeira opção, em destaque.
            addSettingItem(content, "★ Entrar ou criar conta (opcional)", ContaResumo(), "conta")
        end if
    end if

    addSettingItem(content, "Estatísticas", EstatResumo(), "estatisticas")

    perfil = PerfilAtivo()
    descPerfil = perfil.nome
    if perfil.kids = true then descPerfil = descPerfil + " (Kids)"
    addSettingItem(content, "Perfis", descPerfil + " · trocar, criar, avatares e perfil Kids", "perfis")
    addSettingItem(content, "Minhas listas", "Adicionar ou gerenciar listas M3U e Xtream Codes", "minhasListas")

    addonsCount = LoadAddons().Count()
    enabledCount = GetEnabledAddons().Count()
    debridAtivos = GetEnabledDebridProviders()
    descAddons = "Instalar Addons Stremio e Debrid (QR Code na TV)"
    if addonsCount > 0 or debridAtivos.Count() > 0 then
        descAddons = enabledCount.ToStr() + "/" + addonsCount.ToStr() + " addon(s) ativo(s)"
        if debridAtivos.Count() > 0 then descAddons = descAddons + " · Debrid: " + debridAtivos.Join(", ")
    end if
    addSettingItem(content, "Addons e Debrid", descAddons, "addonsDebrid")

    valCanais = m.prefs.urlCanais
    if valCanais = invalid or valCanais = "" then valCanais = "Não configurado · aperte OK para digitar"
    addSettingItem(content, "Endereço dos canais", valCanais, "urlCanais")

    valFilmes = m.prefs.urlFilmes
    if valFilmes = invalid or valFilmes = "" then valFilmes = "Não configurado · aperte OK para digitar"
    addSettingItem(content, "Endereço de filmes e séries", valFilmes, "urlFilmes")

    valAbrir = "Tela inicial"
    if m.prefs.abrirEm = "canal" or m.prefs.abrirEm = "canais" then valAbrir = "Último canal ao vivo"
    addSettingItem(content, "Ao abrir o Saimo", valAbrir, "abrirEm")

    valDelay = "Equilibrado"
    if m.prefs.zeroDelay = "off" then valDelay = "Desligado"
    if m.prefs.zeroDelay = "agressivo" or m.prefs.zeroDelay = "rapido" then valDelay = "Agressivo"
    addSettingItem(content, "Modo Zero Delay", valDelay, "zeroDelay")

    valAudioInt = "Ativado"
    if not m.prefs.audioInteligente then valAudioInt = "Desativado"
    addSettingItem(content, "Áudio Inteligente", valAudioInt, "audioInteligente")

    valVersao = "Dublado"
    if m.prefs.versaoAudio = "leg" then valVersao = "Legendado (Original)"
    addSettingItem(content, "Versão preferida", valVersao, "versaoAudio")

    valPular = "Ativado"
    if not m.prefs.pularAutomatico then valPular = "Desativado"
    addSettingItem(content, "Pular abertura automaticamente", valPular, "pularAutomatico")

    valProximo = "Ativado"
    if not m.prefs.proximoAutomatico then valProximo = "Desativado"
    addSettingItem(content, "Próximo episódio automático", valProximo, "proximoAutomatico")

    brilho = 100
    b = GetRegistry().Read("brilho_app")
    if b <> invalid and b <> "" then brilho = b.ToInt()
    descBrilho = brilho.ToStr() + "% · OK diminui 25% (em 0% a tela apaga; qualquer botão volta)"
    if brilho >= 100 then descBrilho = "100% (normal) · OK diminui 25%"
    addSettingItem(content, "Brilho do app", descBrilho, "brilho")

    addSettingItem(content, "Limpar histórico e progresso", "Remove todos os itens de Continuar Assistindo", "limparCache")
    ' Controle parental: no fim, discreto. No Roku o conteúdo adulto fica sempre de fora.
    if not KidsAtivo() then
        senha = "senha própria"
        h = GetRegistry().Read("parental_senha")
        if h = invalid or h = "" then senha = "senha de fábrica"
        addSettingItem(content, "Controle parental", "No Roku o conteúdo adulto fica sempre de fora · trocar a senha (" + senha + ")", "parental")
    end if

    idx = m.settingsList.itemFocused
    m.settingsList.content = content
    if idx >= 0 and idx < content.getChildCount() then
        m.settingsList.jumpToItem = idx
    end if
end sub

sub addSettingItem(parent as Object, title as String, value as String, key as String)
    item = parent.createChild("ContentNode")
    item.title = title
    item.description = value
    item.addFields({
        key: key,
        settingKey: key
    })
end sub

sub onItemSelected()
    idx = m.settingsList.itemSelected
    item = m.settingsList.content.getChild(idx)
    if item = invalid then return

    key = item.key
    m.prefs = LoadPreferences()

    if key = "conta" then
        abrirConta()
        return
    else if key = "perfis" then
        m.top.perfisRequested = true
        return
    else if key = "brilho" then
        ' 100 -> 75 -> 50 -> 25 -> 0 -> 100. Em 0 qualquer botão traz de volta.
        atual = 100
        b = GetRegistry().Read("brilho_app")
        if b <> invalid and b <> "" then atual = b.ToInt()
        novo = atual - 25
        if atual <= 0 then novo = 100
        if novo < 0 then novo = 0
        m.top.getScene().brilho = novo
        buildSettingsList()
        return
    else if key = "parental" then
        d = CreateObject("roSGNode", "StandardPinPadDialog")
        d.title = "Controle parental"
        d.message = ["Digite a senha atual."]
        d.buttons = ["Confirmar", "Cancelar"]
        d.observeField("buttonSelected", "onSenhaAtual")
        m.top.getScene().dialog = d
        return
    else if key = "minhasListas" then
        m.top.minhasListasRequested = true
        return
    else if key = "addonsDebrid" then
        m.top.addonsRequested = true
        return
    else if key = "urlCanais" then
        abrirEditorUrl("urlCanais", "Endereço dos canais (ex: canais-saimo.pages.dev)", m.prefs.urlCanais)
        return
    else if key = "urlFilmes" then
        abrirEditorUrl("urlFilmes", "Endereço de filmes e séries (ex: filmes-saimo.pages.dev)", m.prefs.urlFilmes)
        return
    else if key = "abrirEm" then
        if m.prefs.abrirEm = "inicio" then m.prefs.abrirEm = "canal" else m.prefs.abrirEm = "inicio"
    else if key = "zeroDelay" then
        if m.prefs.zeroDelay = "off" then
            m.prefs.zeroDelay = "equilibrado"
        else if m.prefs.zeroDelay = "equilibrado" then
            m.prefs.zeroDelay = "agressivo"
        else
            m.prefs.zeroDelay = "off"
        end if
    else if key = "audioInteligente" then
        m.prefs.audioInteligente = not m.prefs.audioInteligente
    else if key = "versaoAudio" then
        if m.prefs.versaoAudio = "dub" then m.prefs.versaoAudio = "leg" else m.prefs.versaoAudio = "dub"
    else if key = "pularAutomatico" then
        m.prefs.pularAutomatico = not m.prefs.pularAutomatico
    else if key = "proximoAutomatico" then
        m.prefs.proximoAutomatico = not m.prefs.proximoAutomatico
    else if key = "limparCache" then
        reg = GetRegistry()
        reg.Delete(ChavePerfil("vod_progress"))
        reg.Flush()
        m.top.reloadRequested = true
    end if

    SavePreferences(m.prefs)
    buildSettingsList()
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

sub abrirEditorUrl(campo as String, titulo as String, valorAtual as Dynamic)
    m.campoAtivo = campo
    m.tituloCampo.text = titulo
    textoInicial = ""
    if valorAtual <> invalid and valorAtual.ToStr().Trim() <> "" then
        textoInicial = valorAtual.ToStr().Trim()
    end if
    m.teclado.text = textoInicial
    if m.teclado.textEditBox <> invalid then m.teclado.textEditBox.text = textoInicial
    m.botoes.jumpToItem = 0
    m.settingsList.visible = false
    if m.lblSecao <> invalid then m.lblSecao.visible = false
    m.painelTeclado.visible = true
    m.teclado.setFocus(true)
end sub

sub fecharEditorUrl()
    m.painelTeclado.visible = false
    m.settingsList.visible = true
    if m.lblSecao <> invalid then m.lblSecao.visible = true
    m.campoAtivo = ""
    m.settingsList.setFocus(true)
end sub

sub salvarUrlAtiva()
    if m.campoAtivo = "" then return
    m.prefs = LoadPreferences()
    novoValor = NormalizarEnderecoSaimo(lerTextoTeclado())
    if m.campoAtivo = "urlCanais" then
        m.prefs.urlCanais = novoValor
    else if m.campoAtivo = "urlFilmes" then
        m.prefs.urlFilmes = novoValor
    end if
    SavePreferences(m.prefs)
    fecharEditorUrl()
    buildSettingsList()
    m.top.reloadRequested = true
end sub

sub onBotaoTeclado()
    idx = m.botoes.itemSelected
    if idx = 0 then
        salvarUrlAtiva()
    else if idx = 1 then
        ' Limpar
        m.teclado.text = ""
        if m.teclado.textEditBox <> invalid then m.teclado.textEditBox.text = ""
        m.teclado.setFocus(true)
    else
        ' Cancelar
        fecharEditorUrl()
    end if
end sub

sub onTextoRecebido()
    txt = m.top.textoRecebido
    if txt = invalid or txt.Trim() = "" then return
    if not m.painelTeclado.visible then
        foco = m.settingsList.itemFocused
        focoItem = invalid
        if m.settingsList.content <> invalid and foco >= 0 and foco < m.settingsList.content.getChildCount() then
            focoItem = m.settingsList.content.getChild(foco)
        end if
        if focoItem <> invalid and focoItem.key = "urlCanais" then
            abrirEditorUrl("urlCanais", "Endereço dos canais (ex: canais-saimo.pages.dev)", m.prefs.urlCanais)
        else if focoItem <> invalid and focoItem.key = "urlFilmes" then
            abrirEditorUrl("urlFilmes", "Endereço de filmes e séries (ex: filmes-saimo.pages.dev)", m.prefs.urlFilmes)
        end if
    end if
    if m.painelTeclado.visible then
        m.teclado.text = txt.Trim()
        if m.teclado.textEditBox <> invalid then m.teclado.textEditBox.text = txt.Trim()
        m.botoes.jumpToItem = 0
        m.botoes.setFocus(true)
    end if
end sub

sub cleanUp()
    if m.contaTimer <> invalid then m.contaTimer.control = "stop"
    if m.contaTask <> invalid then m.contaTask.unobserveField("resultado")
    if m.painelTeclado <> invalid and m.painelTeclado.visible then
        m.painelTeclado.visible = false
        m.settingsList.visible = true
        if m.lblSecao <> invalid then m.lblSecao.visible = true
        m.campoAtivo = ""
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.painelConta <> invalid and m.painelConta.visible then
        if key = "back" then fecharConta()
        return true
    end if

    if m.painelTeclado.visible then
        if key = "back" then
            fecharEditorUrl()
            return true
        else if key = "play" then
            salvarUrlAtiva()
            return true
        else if key = "down" and m.teclado.isInFocusChain() then
            m.botoes.jumpToItem = 0
            m.botoes.setFocus(true)
            return true
        else if key = "up" and m.botoes.isInFocusChain() then
            m.teclado.setFocus(true)
            return true
        end if
        return true
    end if

    if not m.settingsList.isInFocusChain() then
        if m.settingsList <> invalid then m.settingsList.setFocus(true)
    end if

    if key = "up" and m.settingsList.itemFocused <= 0 then
        m.top.focusUpRequested = true
        return true
    else if key = "left" then
        return true
    else if key = "back" then
        return false
    end if
    return false
end function

sub onSenhaAtual(evt as Object)
    d = evt.getRoSGNode()
    m.senhaAtual = d.pin
    d.close = true
    if evt.getData() <> 0 then return
    if not ParentalConferir(m.senhaAtual) then
        mensagem("Senha errada.")
        return
    end if
    n = CreateObject("roSGNode", "StandardPinPadDialog")
    n.title = "Controle parental"
    n.message = ["Digite a senha nova (4 números)."]
    n.buttons = ["Confirmar", "Cancelar"]
    n.observeField("buttonSelected", "onSenhaNova")
    m.top.getScene().dialog = n
end sub

sub onSenhaNova(evt as Object)
    d = evt.getRoSGNode()
    nova = d.pin
    d.close = true
    if evt.getData() <> 0 then return
    if ParentalTrocar(m.senhaAtual, nova) then mensagem("Senha trocada.") else mensagem("A senha nova tem 4 números.")
    buildSettingsList()
end sub

sub mensagem(texto as String)
    d = CreateObject("roSGNode", "StandardMessageDialog")
    d.title = "Controle parental"
    d.message = [texto]
    d.buttons = ["OK"]
    d.observeField("buttonSelected", "onFecharMensagem")
    m.top.getScene().dialog = d
end sub

sub onFecharMensagem(evt as Object)
    evt.getRoSGNode().close = true
end sub


' ===================== Conta Saimo =====================
' Sem conta: QR e código curto (o celular logado aprova) e, se a pessoa
' quiser, e-mail e senha. A rede fica no ContaTask; aqui só a tela.

sub onAbrirConta()
    if m.top.abrirConta then abrirConta()
end sub

sub abrirConta()
    if m.painelConta = invalid then
        m.painelConta = m.top.findNode("painelConta")
        m.contaQr = m.top.findNode("contaQr")
        m.contaQrFundo = m.top.findNode("contaQrFundo")
        m.contaTitulo = m.top.findNode("contaTitulo")
        m.contaTexto = m.top.findNode("contaTexto")
        m.contaCodigo = m.top.findNode("contaCodigo")
        m.contaSituacao = m.top.findNode("contaSituacao")
        m.contaBotoes = m.top.findNode("contaBotoes")
        m.contaBotoes.observeField("itemSelected", "onContaBotao")
        m.contaTimer = m.top.findNode("contaTimer")
        m.contaTimer.observeField("fire", "onContaTimer")
    end if
    m.settingsList.visible = false
    m.painelConta.visible = true
    desenharConta()
end sub

sub fecharConta()
    m.contaTimer.control = "stop"
    m.contaPedido = invalid
    m.painelConta.visible = false
    m.settingsList.visible = true
    buildSettingsList()
    m.settingsList.setFocus(true)
end sub

sub contaBotoes(rotulos as Object)
    c = CreateObject("roSGNode", "ContentNode")
    for each r in rotulos
        c.CreateChild("ContentNode").title = r
    end for
    m.contaBotoes.content = c
    m.contaBotoes.jumpToItem = 0
    m.contaBotoes.setFocus(true)
end sub

sub desenharConta()
    while m.contaQr.getChildCount() > 0
        m.contaQr.removeChildIndex(0)
    end while
    if ContaLogado() then
        m.contaTimer.control = "stop"
        m.contaQrFundo.visible = false
        m.contaTitulo.text = "Conta Saimo"
        s = ContaSessao()
        m.contaTexto.text = s.email
        m.contaCodigo.text = ""
        m.contaSituacao.text = ContaResumo() + ". Perfis, onde parou e favoritos. Sair mantém os dados nesta TV."
        m.contaBotoes.translation = [520, 300]
        contaBotoes(["Sincronizar agora", "Sair da conta", "Voltar"])
    else
        m.contaQrFundo.visible = true
        m.contaTitulo.text = "Entrar na Conta Saimo"
        m.contaTexto.text = "No celular com o Saimo e a sua conta, leia o QR com a câmera. Ou abra Ajustes > Conta Saimo > Entrar numa TV e digite o código:"
        m.contaCodigo.text = "…"
        m.contaSituacao.text = "Pedindo um código…"
        m.contaBotoes.translation = [520, 420]
        contaBotoes(["Entrar com e-mail e senha", "Voltar"])
        contaRodar("pedir", {})
    end if
end sub

sub contaRodar(acao as String, campos as Object)
    if m.contaTask <> invalid then m.contaTask.unobserveField("resultado")
    t = CreateObject("roSGNode", "ContaTask")
    for each k in campos
        t[k] = campos[k]
    end for
    t.acao = acao
    t.observeField("resultado", "onContaResultado")
    m.contaTask = t
    t.control = "run"
end sub

' Um código por vez: venceu (10 min) ou não deu para pedir, para de perguntar
' e mostra "Gerar novo código" (cada pergunta ao servidor é cobrada).
sub contaVenceu(texto as String)
    m.contaTimer.control = "stop"
    m.contaPedido = invalid
    while m.contaQr.getChildCount() > 0
        m.contaQr.removeChildIndex(0)
    end while
    m.contaCodigo.text = ""
    m.contaSituacao.text = texto
    contaBotoes(["Gerar novo código", "Entrar com e-mail e senha", "Voltar"])
    m.contaBotoes.setFocus(true)
end sub

sub onContaTimer()
    if m.contaPedido = invalid then return
    if CreateObject("roDateTime").AsSeconds() > m.contaPedido.vence then
        contaVenceu("O código venceu.")
        return
    end if
    ' 8 s nos 2 primeiros minutos, então 15 s, e 20 s depois de 5 min (cada pergunta é cobrada).
    passou = 590 - (m.contaPedido.vence - CreateObject("roDateTime").AsSeconds())
    novo = 8
    if passou >= 300 then
        novo = 20
    else if passou >= 120 then
        novo = 15
    end if
    if m.contaTimer.duration <> novo then m.contaTimer.duration = novo
    contaRodar("estado", { aparelhoCodigo: m.contaPedido.aparelhoCodigo })
end sub

sub onContaResultado(evt as Object)
    r = evt.getData()
    if r = invalid or not m.painelConta.visible then return
    if r.acao = "pedir" then
        if r.ok then
            m.contaPedido = { aparelhoCodigo: r.aparelhoCodigo, vence: CreateObject("roDateTime").AsSeconds() + 590 }
            m.contaCodigo.text = r.codigo
            m.contaSituacao.text = "Esperando o celular…"
            while m.contaQr.getChildCount() > 0
                m.contaQr.removeChildIndex(0)
            end while
            QrRenderToGroup(m.contaQr, r.url, 380)
            m.contaTimer.duration = 8
            m.contaTimer.control = "start"
        else
            contaVenceu(r.erro)
        end if
    else if r.acao = "estado" then
        if r.ok then
            m.contaTimer.control = "stop"
            m.contaPedido = invalid
            desenharConta()
        else if r.estado = "vencido" then
            m.contaPedido.vence = 0
        end if
    else if r.acao = "senha" then
        if r.ok then
            desenharConta()
        else
            m.contaSituacao.text = r.erro
        end if
    else if r.acao = "sincronizar" then
        if r.ok then m.contaSituacao.text = "Sincronizado. Perfis, onde parou e favoritos." else m.contaSituacao.text = r.erro
        if not ContaLogado() then desenharConta()
    else if r.acao = "sair" then
        desenharConta()
    end if
end sub

sub onContaBotao()
    rotulo = m.contaBotoes.content.getChild(m.contaBotoes.itemSelected).title
    if rotulo = "Voltar" then
        fecharConta()
    else if rotulo = "Gerar novo código" then
        m.contaCodigo.text = "…"
        m.contaSituacao.text = "Pedindo um código…"
        contaBotoes(["Entrar com e-mail e senha", "Voltar"])
        contaRodar("pedir", {})
    else if rotulo = "Sincronizar agora" then
        m.contaSituacao.text = "Sincronizando…"
        contaRodar("sincronizar", {})
    else if rotulo = "Sair da conta" then
        contaRodar("sair", {})
    else if rotulo = "Entrar com e-mail e senha" then
        d = CreateObject("roSGNode", "StandardKeyboardDialog")
        d.title = "Seu e-mail"
        d.message = ["Entre com a sua conta ou crie uma agora."]
        d.buttons = ["Continuar", "Cancelar"]
        d.observeField("buttonSelected", "onContaEmail")
        m.top.getScene().dialog = d
    end if
end sub

sub onContaEmail(evt as Object)
    d = evt.getRoSGNode()
    m.contaEmail = d.text.Trim()
    d.close = true
    if evt.getData() <> 0 or Instr(1, m.contaEmail, "@") = 0 then
        m.contaBotoes.setFocus(true)
        return
    end if
    s = CreateObject("roSGNode", "StandardKeyboardDialog")
    s.title = "Senha"
    s.message = [m.contaEmail]
    s.buttons = ["Entrar", "Criar conta", "Cancelar"]
    if s.textEditBox <> invalid then s.textEditBox.secureMode = true
    s.observeField("buttonSelected", "onContaSenha")
    m.top.getScene().dialog = s
end sub

sub onContaSenha(evt as Object)
    d = evt.getRoSGNode()
    senha = d.text
    d.close = true
    m.contaBotoes.setFocus(true)
    botao = evt.getData()
    if botao = 2 or senha = "" then return
    criar = (botao = 1)
    if criar and Len(senha) < 8 then
        m.contaSituacao.text = "A senha precisa ter 8 ou mais caracteres"
        return
    end if
    if criar then m.contaSituacao.text = "Criando a conta…" else m.contaSituacao.text = "Entrando…"
    contaRodar("senha", { email: m.contaEmail, senha: senha, criar: criar })
end sub
