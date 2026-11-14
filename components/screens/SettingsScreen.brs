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
end sub

sub onFocusChange()
    if m.top.isInFocusChain() then
        if m.painelTeclado.visible then
            if not m.teclado.isInFocusChain() and not m.botoes.isInFocusChain() then
                m.teclado.setFocus(true)
            end if
        else if not m.settingsList.isInFocusChain() then
            m.settingsList.setFocus(true)
        end if
    end if
end sub

sub buildSettingsList()
    m.prefs = LoadPreferences()
    content = CreateObject("roSGNode", "ContentNode")

    addSettingItem(content, "Minhas listas", "Adicionar ou gerenciar listas M3U e Xtream Codes", "minhasListas")

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

    addSettingItem(content, "Limpar histórico e progresso", "Remove todos os itens de Continuar Assistindo", "limparCache")

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

    if key = "minhasListas" then
        m.top.minhasListasRequested = true
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
        reg.Delete("vod_progress")
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
        if foco = 1 then
            abrirEditorUrl("urlCanais", "Endereço dos canais (ex: canais-saimo.pages.dev)", m.prefs.urlCanais)
        else if foco = 2 then
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
    if m.painelTeclado <> invalid and m.painelTeclado.visible then
        m.painelTeclado.visible = false
        m.settingsList.visible = true
        if m.lblSecao <> invalid then m.lblSecao.visible = true
        m.campoAtivo = ""
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

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
