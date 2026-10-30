' ====================================================================
' Saimo TV - PinModal (BrightScript)
' ====================================================================

sub init()
    m.modalContainer = m.top.findNode("modalContainer")
    m.errorLabel = m.top.findNode("errorLabel")
    m.enteredPin = ""
end sub

sub onOpenChange()
    isOpen = m.top.isOpen
    m.modalContainer.visible = isOpen
    if isOpen then
        m.enteredPin = ""
        m.errorLabel.visible = false
        updateDots()
        m.top.setFocus(true)
    end if
end sub

sub updateDots()
    pinLen = Len(m.enteredPin)
    for i = 0 to 3
        dotNode = m.top.findNode("dot_" + i.ToStr())
        if dotNode <> invalid then
            if i < pinLen then
                dotNode.color = "#4FE3D0"
            else
                dotNode.color = "#374151"
            end if
        end if
    end for
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back" then
        m.top.isOpen = false
        return true
    end if

    ' Dígitos 0 a 9 do controle remoto
    validDigits = "0123456789"
    if Instr(1, validDigits, key) > 0 then
        m.enteredPin = m.enteredPin + key
        m.errorLabel.visible = false
        updateDots()

        if Len(m.enteredPin) = 4 then
            if m.enteredPin = "1010" then
                m.top.isUnlocked = true
                m.top.isOpen = false
            else
                m.errorLabel.visible = true
                m.enteredPin = ""
                updateDots()
            end if
        end if
        return true
    end if

    return false
end function
