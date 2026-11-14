' ====================================================================
' Saimo TV - DoacaoScreen (BrightScript)
' Apoie o Saimo TV: texto, QR code para abrir no celular e o link escrito.
' ====================================================================

sub init()
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
