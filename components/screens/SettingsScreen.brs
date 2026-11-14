sub init()
    m.settingsList = m.top.findNode("settingsList")
    m.lblSecao = m.top.findNode("lblSecao")
    m.painelTeclado = m.top.findNode("painelTeclado")
    m.tituloCampo = m.top.findNode("tituloCampo")
    m.subtituloCampo = m.top.findNode("subtituloCampo")
    m.teclado = m.top.findNode("teclado")
    m.botoes = m.top.findNode("botoes")
    m.chaveEditando = ""

    info = CreateObject("roAppInfo")
    v = m.top.findNode("versao")
    if v <> invalid then v.text = "Saimo TV v" + info.GetVersion()

    opcoesBotoes = CreateObject("roSGNode", "ContentNode")
    for each t in ["Salvar", "Apagar endereço", "Cancelar"]
        it = opcoesBotoes.createChild("ContentNode")
        it.title = t
    end for
    m.botoes.content = opcoesBotoes

    m.prefs = LoadPreferences()
    populateSettings()

    m.settingsList.observeField("itemSelected", "onSettingSelected")
    m.botoes.observeField("itemSelected", "onBotaoTeclado")
    m.top.observeField("focusedChild", "onFocusChange")
end sub

sub onFocusChange()
    if m.top.hasFocus() then
        if m.painelTeclado.visible then
            if not m.teclado.hasFocus() and not m.botoes.hasFocus() then
                m.teclado.setFocus(true)
            end if
        else if not m.settingsList.hasFocus() then
            m.prefs = LoadPreferences()
            populateSettings()
            m.settingsList.setFocus(true)
        end if
    end if
end sub

sub populateSettings()
    m.prefs = LoadPreferences()
    content = CreateObject("roSGNode", "ContentNode")

    item1 = content.createChild("ContentNode")
    resText = "Desativado"
    if m.prefs.autoResume then resText = "Ativado"
    item1.title = "Continuar de onde parei"
    item1.description = resText
    item1.HDPosterUrl = "autoResume"

    item2 = content.createChild("ContentNode")
    item2.title = "Qualidade preferida"
    item2.description = m.prefs.preferredQuality
    item2.HDPosterUrl = "preferredQuality"

    item3 = content.createChild("ContentNode")
    subText = "Desativado"
    if m.prefs.enableSubtitles then subText = "Ativado"
    item3.title = "Legendas por padrão"
    item3.description = subText
    item3.HDPosterUrl = "enableSubtitles"

    listas = LoadMinhasListas()
    item4 = content.createChild("ContentNode")
    item4.title = "Minhas listas"
    if listas.Count() = 0 then
        item4.description = "Nenhuma lista adicionada · abrir"
    else if listas.Count() = 1 then
        item4.description = "1 lista adicionada · gerenciar"
    else
        item4.description = listas.Count().ToStr() + " listas adicionadas · gerenciar"
    end if
    item4.HDPosterUrl = "minhasListas"

    item5 = content.createChild("ContentNode")
    item5.title = "Endereço dos canais"
    if m.prefs.urlCanais <> invalid and m.prefs.urlCanais.Trim() <> "" then
        item5.description = m.prefs.urlCanais
    else
        item5.description = "Não configurado · clique para definir"
    end if
    item5.HDPosterUrl = "urlCanais"

    item6 = content.createChild("ContentNode")
    item6.title = "Endereço de filmes e séries"
    if m.prefs.urlFilmes <> invalid and m.prefs.urlFilmes.Trim() <> "" then
        item6.description = m.prefs.urlFilmes
    else
        item6.description = "Não configurado · clique para definir"
    end if
    item6.HDPosterUrl = "urlFilmes"

    item7 = content.createChild("ContentNode")
    item7.title = "Atualizar catálogo agora"
    item7.description = "Recarregar canais e filmes"
    item7.HDPosterUrl = "reload"

    foco = m.settingsList.itemFocused
    m.settingsList.content = content
    if foco >= 0 and foco < content.getChildCount() then
        m.settingsList.jumpToItem = foco
    end if
end sub

sub onSettingSelected()
    idx = m.settingsList.itemSelected
    m.prefs = LoadPreferences()
    if idx = 0 then
        m.prefs.autoResume = not m.prefs.autoResume
        SavePreferences(m.prefs)
        populateSettings()
    else if idx = 1 then
        if m.prefs.preferredQuality = "Auto" then
            m.prefs.preferredQuality = "FHD"
        else if m.prefs.preferredQuality = "FHD" then
            m.prefs.preferredQuality = "HD"
        else if m.prefs.preferredQuality = "HD" then
            m.prefs.preferredQuality = "SD"
        else
            m.prefs.preferredQuality = "Auto"
        end if
        SavePreferences(m.prefs)
        populateSettings()
    else if idx = 2 then
        m.prefs.enableSubtitles = not m.prefs.enableSubtitles
        SavePreferences(m.prefs)
        populateSettings()
    else if idx = 3 then
        m.top.minhasListasRequested = true
    else if idx = 4 then
        abrirEditorUrl("urlCanais", "Endereço dos canais")
    else if idx = 5 then
        abrirEditorUrl("urlFilmes", "Endereço de filmes e séries")
    else if idx = 6 then
        m.top.reloadRequested = true
    end if
end sub

sub abrirEditorUrl(chave as String, titulo as String)
    m.prefs = LoadPreferences()
    m.chaveEditando = chave
    atual = ""
    if m.prefs[chave] <> invalid then atual = m.prefs[chave]
    m.tituloCampo.text = titulo
    m.subtituloCampo.text = "Digite o endereço (ex: canais-saimo.pages.dev), depois desça até Salvar"
    m.teclado.text = atual
    if m.teclado.textEditBox <> invalid then
        m.teclado.textEditBox.text = atual
        m.teclado.textEditBox.hintText = "https://..."
    end if
    m.settingsList.visible = false
    if m.lblSecao <> invalid then m.lblSecao.visible = false
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

sub salvarEdicaoAtual(limpar as Boolean)
    if m.chaveEditando = "" then
        fecharEditorUrl()
        return
    end if
    m.prefs = LoadPreferences()
    if limpar then
        m.prefs[m.chaveEditando] = ""
    else
        novo = NormalizarEnderecoSaimo(lerTextoTeclado())
        m.prefs[m.chaveEditando] = novo
    end if
    SavePreferences(m.prefs)
    fecharEditorUrl()
    populateSettings()
    m.top.reloadRequested = true
end sub

sub fecharEditorUrl()
    m.chaveEditando = ""
    m.painelTeclado.visible = false
    m.settingsList.visible = true
    if m.lblSecao <> invalid then m.lblSecao.visible = true
    m.settingsList.setFocus(true)
end sub

sub onBotaoTeclado()
    idx = m.botoes.itemSelected
    if idx = 0 then
        salvarEdicaoAtual(false)
    else if idx = 1 then
        salvarEdicaoAtual(true)
    else
        fecharEditorUrl()
    end if
end sub

sub onTextoRecebido()
    t = m.top.textoRecebido
    if t = invalid or t.Trim() = "" then return
    if not m.painelTeclado.visible then
        foco = m.settingsList.itemFocused
        if foco = 4 then
            abrirEditorUrl("urlCanais", "Endereço dos canais")
        else if foco = 5 then
            abrirEditorUrl("urlFilmes", "Endereço de filmes e séries")
        else
            return
        end if
    end if
    m.teclado.text = t.Trim()
    if m.teclado.textEditBox <> invalid then
        m.teclado.textEditBox.text = t.Trim()
    end if
    m.botoes.jumpToItem = 0
    m.botoes.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if m.painelTeclado.visible then
        if key = "back" then
            fecharEditorUrl()
            return true
        else if key = "play" then
            salvarEdicaoAtual(false)
            return true
        else if key = "down" then
            if not m.botoes.hasFocus() then
                m.botoes.jumpToItem = 0
                m.botoes.setFocus(true)
                return true
            end if
        else if key = "up" then
            if m.botoes.hasFocus() then
                m.teclado.setFocus(true)
                return true
            end if
        end if
        return false
    end if
    if key = "up" or key = "left" then
        m.top.focusUpRequested = true
        return true
    end if
    return false
end function

sub cleanUp()
end sub
