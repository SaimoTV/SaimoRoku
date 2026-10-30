' ====================================================================
' Saimo TV - RadiosScreen (BrightScript)
' ====================================================================

sub init()
    m.radiosList = m.top.findNode("radiosList")
    m.radioLogo = m.top.findNode("radioLogo")
    m.radioName = m.top.findNode("radioName")
    m.radioGenre = m.top.findNode("radioGenre")
    m.radioStatus = m.top.findNode("radioStatus")
    m.radioAudio = m.top.findNode("radioAudio")

    m.radiosList.observeField("itemSelected", "onRadioSelected")
    m.radioAudio.observeField("state", "onAudioState")
end sub

sub onRadiosChange()
    radios = m.top.radios
    if radios = invalid then return

    root = CreateObject("roSGNode", "ContentNode")
    for each r in radios
        node = root.CreateChild("ContentNode")
        node.title = r.name + " (" + r.genre + ")"
    end for
    m.radiosList.content = root
end sub

sub onRadioSelected()
    idx = m.radiosList.itemSelected
    radios = m.top.radios
    if radios = invalid or idx >= radios.Count() then return

    r = radios[idx]
    m.radioName.text = r.name
    m.radioGenre.text = r.genre
    m.radioStatus.text = "Conectando stream de áudio..."
    if r.logo <> "" then m.radioLogo.uri = r.logo

    content = CreateObject("roSGNode", "ContentNode")
    content.url = r.url
    content.streamFormat = "mp3"

    m.radioAudio.content = content
    m.radioAudio.control = "play"
end sub

sub onAudioState()
    state = m.radioAudio.state
    if state = "playing" then
        m.radioStatus.text = "● TRANSMITINDO AO VIVO"
    else if state = "buffering" then
        m.radioStatus.text = "Carregando áudio..."
    else if state = "error" then
        m.radioStatus.text = "Erro ao conectar à emissora"
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back" then
        m.radioAudio.control = "stop"
    end if
    return false
end function
