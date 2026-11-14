sub init()
    m.moldura = m.top.findNode("moldura")
end sub

sub onConteudo()
    c = m.top.itemContent
    if c = invalid then return
    m.top.findNode("hora").text = c.hora
    m.top.findNode("titulo").text = c.title
    m.top.findNode("detalhe").text = c.description
    tem = c.progresso > 0
    m.top.findNode("trilho").visible = tem
    b = m.top.findNode("barra")
    b.visible = tem
    b.width = Int(640 * c.progresso)
end sub

sub onFoco()
    m.moldura.visible = m.top.focusPercent > 0.5 and m.top.listHasFocus
end sub
