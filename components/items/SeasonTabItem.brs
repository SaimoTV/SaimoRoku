sub init()
    m.bg = m.top.findNode("bg")
    m.focusBorder = m.top.findNode("focusBorder")
    m.rotulo = m.top.findNode("rotulo")
end sub

sub onConteudo()
    c = m.top.itemContent
    if c = invalid then return
    if c.title <> invalid then m.rotulo.text = c.title
    atualizar()
end sub

sub onFoco()
    atualizar()
end sub

sub atualizar()
    c = m.top.itemContent
    sel = (c <> invalid and c.selecionada = true)
    foc = (m.top.focusPercent > 0.5 and m.top.rowListHasFocus)

    m.focusBorder.visible = foc

    if foc and sel then
        ' Focada e Selecionada: Destaque turquesa vibrante com texto escuro
        m.bg.blendColor = "#4FE3D0"
        m.rotulo.color = "#0b0e14"
    else if foc then
        ' Focada pelo controle remoto (navegando entre abas)
        m.bg.blendColor = "#FFFFFF"
        m.rotulo.color = "#0b0e14"
    else if sel then
        ' Selecionada (ativa), mas sem foco do controle
        m.bg.blendColor = "#0FA89A"
        m.rotulo.color = "#FFFFFF"
    else
        ' Inativa e sem foco
        m.bg.blendColor = "#FFFFFF24"
        m.rotulo.color = "#D5DCE5"
    end if
end sub
