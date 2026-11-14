' ====================================================================
' Saimo TV - SettingsScreen (BrightScript)
' ====================================================================

sub init()
    m.settingsList = m.top.findNode("settingsList")
    ' Versão do manifest: o número escrito à mão ficava para trás a cada release.
    m.top.findNode("versao").text = "Saimo TV " + CreateObject("roAppInfo").GetVersion()
    m.settingsList.observeField("itemSelected", "onSettingSelected")
    m.prefs = LoadPreferences()
    m.top.observeField("focusedChild", "onFocusedChildChange")
    populateSettings()
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() and not m.settingsList.isInFocusChain() then
        if m.settingsList <> invalid then m.settingsList.setFocus(true)
    end if
end sub

sub populateSettings()
    p = m.prefs
    root = CreateObject("roSGNode", "ContentNode")

    addSettingItem(root, "minhasListas", "Minhas listas", "Adicionar listas .m3u pelo link")
    addSettingItem(root, "urlCanais", "Endereço dos canais", enderecoResumo(p.urlCanais))
    addSettingItem(root, "urlFilmes", "Endereço de filmes e séries", enderecoResumo(p.urlFilmes))
    abrir = "Início"
    if p.abrirEm = "canal" then abrir = "Último canal"
    addSettingItem(root, "abrirEm", "Abrir o app em", abrir)
    zero = { off: "Desligado", equilibrado: "Equilibrado", agressivo: "Agressivo" }[p.zeroDelay]
    addSettingItem(root, "zeroDelay", "Modo Zero Delay", zero)
    addSettingItem(root, "audioInteligente", "Áudio inteligente (voz nítida)", formatBool(p.audioInteligente))
    audio = "Dublado"
    if p.versaoAudio = "leg" then audio = "Legendado"
    addSettingItem(root, "versaoAudio", "Áudio de filmes e séries", audio)
    addSettingItem(root, "pularAutomatico", "Pular aberturas de séries", formatBool(p.pularAutomatico))
    addSettingItem(root, "proximoAutomatico", "Próximo episódio automático", formatBool(p.proximoAutomatico))
    addSettingItem(root, "limparCache", "Limpar histórico", "Apaga o que você estava assistindo")

    m.settingsList.content = root
    if m.idxAtual <> invalid then m.settingsList.jumpToItem = m.idxAtual
end sub

sub addSettingItem(root as Object, key as String, label as String, val as String)
    node = root.CreateChild("ContentNode")
    node.title = label
    node.description = val
    node.addFields({ settingKey: key })
end sub

function enderecoResumo(url as Dynamic) as String
    if url = invalid or url = "" then return "Vazio. Aperte OK para digitar (formato Saimo)"
    return url
end function

' Teclado da TV para digitar o endereço (formato Saimo) de canais ou de filmes e séries.
sub abrirEditorEndereco(campo as String, titulo as String)
    m.campoEdicao = campo
    dlg = CreateObject("roSGNode", "StandardKeyboardDialog")
    dlg.title = titulo
    dlg.message = ["Cole ou digite o endereço da sua lista.", "Deixe em branco e salve para desligar."]
    atual = m.prefs[campo]
    if atual = invalid then atual = ""
    dlg.text = atual
    dlg.buttons = ["Salvar", "Apagar", "Cancelar"]
    dlg.observeField("buttonSelected", "onEnderecoBotao")
    dlg.observeField("wasClosed", "onEnderecoFechou")
    m.dlgEndereco = dlg
    m.top.getScene().dialog = dlg
end sub

sub onEnderecoBotao()
    dlg = m.dlgEndereco
    if dlg = invalid then return
    botao = dlg.buttonSelected
    if botao = 2 then
        dlg.close = true
        return
    end if
    novo = ""
    if botao = 0 then novo = dlg.text.Trim()
    novo = normalizarEndereco(novo)
    m.prefs[m.campoEdicao] = novo
    SavePreferences(m.prefs)
    dlg.close = true
    populateSettings()
    m.top.reloadRequested = true
end sub

sub onEnderecoFechou()
    m.dlgEndereco = invalid
    m.settingsList.setFocus(true)
    if m.idxAtual <> invalid then m.settingsList.jumpToItem = m.idxAtual
end sub

' Aceita o endereço com ou sem https://, com espaços, e até colado com o nome de um
' arquivo no fim (catalogo.txt, destaques.txt, indice.txt...): o app guarda só a
' pasta com "/" no fim. Links diretos .m3u / .m3u8 / get.php são preservados.
function normalizarEndereco(url as String) as String
    u = url.Trim()
    if u = "" then return ""
    if Left(LCase(u), 4) <> "http" then u = "https://" + u
    lu = LCase(u)
    if Instr(1, lu, ".m3u") > 0 or Instr(1, lu, "get.php") > 0 or Instr(1, lu, "type=m3u") > 0 then
        return u
    end if
    corte = Instr(1, u, "#")
    if corte > 0 then u = Left(u, corte - 1)
    corte = Instr(1, u, "?")
    if corte > 0 then u = Left(u, corte - 1)
    ultimo = 0
    for i = 1 to Len(u)
        if Mid(u, i, 1) = "/" then ultimo = i
    end for
    if ultimo > 8 and Instr(1, Mid(u, ultimo + 1), ".") > 0 and Right(u, 1) <> "/" then u = Left(u, ultimo)
    if Right(u, 1) <> "/" then u = u + "/"
    if Right(LCase(u), 6) = "/roku/" then u = Left(u, Len(u) - 5)
    return u
end function

function formatBool(val as Boolean) as String
    if val then return "Ligado"
    return "Desligado"
end function

sub onSettingSelected()
    idx = m.settingsList.itemSelected
    m.idxAtual = idx
    root = m.settingsList.content
    if root <> invalid and idx >= 0 and idx < root.getChildCount() then
        node = root.getChild(idx)
        key = node.settingKey

        if key = "minhasListas" then
            m.top.minhasListasRequested = true
            return
        else if key = "urlCanais" then
            abrirEditorEndereco("urlCanais", "Endereço dos canais")
            return
        else if key = "urlFilmes" then
            abrirEditorEndereco("urlFilmes", "Endereço de filmes e séries")
            return
        else if key = "abrirEm" then
            if m.prefs.abrirEm = "inicio" then
                m.prefs.abrirEm = "canal"
            else
                m.prefs.abrirEm = "inicio"
            end if
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
            if m.prefs.versaoAudio = "dub" then
                m.prefs.versaoAudio = "leg"
            else
                m.prefs.versaoAudio = "dub"
            end if
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
        populateSettings()
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if not m.settingsList.isInFocusChain() then
        if m.settingsList <> invalid then m.settingsList.setFocus(true)
    end if

    if key = "up" and m.settingsList.itemFocused <= 0 then
        m.top.focusUpRequested = true
        return true
    else if key = "left" then
        return true
    else if key = "back" then
        return false ' bubbles to MainScene
    end if

    return false
end function

sub cleanUp()
end sub
