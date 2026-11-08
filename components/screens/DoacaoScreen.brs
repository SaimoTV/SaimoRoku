' ====================================================================
' Saimo TV - DoacaoScreen (BrightScript)
' Apoie o Saimo TV: texto, QR code para abrir no celular, o link escrito e
' quem já apoiou (lista publicada no site).
' ====================================================================

sub init()
    m.apoiadores = m.top.findNode("apoiadores")
    m.tarefa = CreateObject("roSGNode", "DataLoaderTask")
    m.tarefa.observeField("responseRadios", "onApoiadores")
    m.tarefa.requestType = "apoiadores"
    m.tarefa.control = "RUN"
end sub

sub onApoiadores()
    nomes = m.tarefa.responseRadios
    if nomes = invalid or nomes.Count() = 0 then return
    texto = ""
    for each n in nomes
        if texto <> "" then texto = texto + "   ·   "
        texto = texto + n
    end for
    m.apoiadores.text = texto
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "up" then
        m.top.focusUpRequested = true
        return true
    end if
    return false
end function

sub cleanUp()
end sub
