' ====================================================================
' Saimo TV - BoasVindasScreen: entrar ou criar conta (esquerda) ou entrar
' sem login (direita). A conta é opcional.
' ====================================================================

sub init()
    m.esquerda = m.top.findNode("esquerda")
    m.direita = m.top.findNode("direita")
    c1 = CreateObject("roSGNode", "ContentNode")
    c1.CreateChild("ContentNode").title = "Entrar ou criar conta"
    m.esquerda.content = c1
    c2 = CreateObject("roSGNode", "ContentNode")
    c2.CreateChild("ContentNode").title = "Entrar sem login"
    m.direita.content = c2
    m.esquerda.observeField("itemSelected", "onEntrar")
    m.direita.observeField("itemSelected", "onSemLogin")
    m.top.observeField("focusedChild", "onFoco")
end sub

sub onFoco()
    if m.top.isInFocusChain() and not m.esquerda.isInFocusChain() and not m.direita.isInFocusChain() then m.esquerda.setFocus(true)
end sub

sub onEntrar()
    m.top.entrarConta = true
end sub

sub onSemLogin()
    m.top.semLogin = true
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "right" and m.esquerda.isInFocusChain() then
        m.direita.setFocus(true)
        return true
    else if key = "left" and m.direita.isInFocusChain() then
        m.esquerda.setFocus(true)
        return true
    else if key = "back" then
        ' Sem conta e sem escolha, voltar não sai do app por engano.
        return true
    end if
    return false
end function
