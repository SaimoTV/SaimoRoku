' ====================================================================
' Saimo TV - SettingsScreen (BrightScript)
' ====================================================================

sub init()
    m.settingsList = m.top.findNode("settingsList")
    m.settingsList.observeField("itemSelected", "onSettingSelected")
    m.prefs = LoadPreferences()
    m.top.observeField("focused", "onFocusChange")
    populateSettings()
end sub

sub onFocusChange()
    if m.top.hasFocus() and m.settingsList <> invalid then
        m.settingsList.setFocus(true)
    end if
end sub

sub populateSettings()
    p = m.prefs
    root = CreateObject("roSGNode", "ContentNode")

    addSettingItem(root, "abrirEm", "Abrir o App em", p.abrirEm)
    addSettingItem(root, "zeroDelay", "Modo Buffer (Zero Delay)", p.zeroDelay)
    addSettingItem(root, "audioInteligente", "Áudio Inteligente (Voz nítida)", formatBool(p.audioInteligente))
    addSettingItem(root, "versaoAudio", "Preferência de Áudio VOD", p.versaoAudio)
    addSettingItem(root, "pularAutomatico", "Pular Aberturas de Séries (+85s)", formatBool(p.pularAutomatico))
    addSettingItem(root, "proximoAutomatico", "Próximo Episódio Automático", formatBool(p.proximoAutomatico))
    addSettingItem(root, "pinParental", "Bloqueio Parental (PIN)", "1010 (Ativo)")
    addSettingItem(root, "limparCache", "Limpar Cache e Histórico", "Pressione OK para limpar")

    m.settingsList.content = root
end sub

sub addSettingItem(root as Object, key as String, label as String, val as String)
    node = root.CreateChild("ContentNode")
    node.title = label + "  ▶  " + UCase(val)
    node.addFields({ settingKey: key })
end sub

function formatBool(val as Boolean) as String
    if val then return "Ativado"
    return "Desativado"
end function

sub onSettingSelected()
    idx = m.settingsList.itemSelected
    root = m.settingsList.content
    if root <> invalid and idx < root.getChildCount() then
        node = root.getChild(idx)
        key = node.settingKey

        if key = "abrirEm" then
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
