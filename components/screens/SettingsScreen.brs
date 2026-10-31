' ====================================================================
' Saimo TV - SettingsScreen (BrightScript)
' ====================================================================

sub init()
    m.settingsList = m.top.findNode("settingsList")
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
end sub

sub addSettingItem(root as Object, key as String, label as String, val as String)
    node = root.CreateChild("ContentNode")
    node.title = label
    node.description = val
    node.addFields({ settingKey: key })
end sub

function formatBool(val as Boolean) as String
    if val then return "Ligado"
    return "Desligado"
end function

sub onSettingSelected()
    idx = m.settingsList.itemSelected
    root = m.settingsList.content
    if root <> invalid and idx >= 0 and idx < root.getChildCount() then
        node = root.getChild(idx)
        key = node.settingKey

        if key = "minhasListas" then
            m.top.minhasListasRequested = true
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
        m.settingsList.jumpToItem = idx
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
