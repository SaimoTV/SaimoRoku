sub init()
    m.moldura = m.top.findNode("moldura")
    m.grupo = m.top.findNode("grupo")
end sub

sub onConteudo()
    c = m.top.itemContent
    if c = invalid then return
    m.top.findNode("numero").text = c.numero
    m.top.findNode("nome").text = c.title
    m.grupo.text = c.grupoTexto
    m.top.findNode("programa").text = c.programa
    m.top.findNode("logo").uri = c.hdPosterUrl
    tem = c.progresso > 0
    m.top.findNode("trilho").visible = tem
    b = m.top.findNode("barra")
    b.visible = tem
    b.width = Int(450 * c.progresso)
end sub

sub onFoco()
    f = m.top.focusPercent > 0.5 and m.top.listHasFocus
    m.moldura.visible = f
    m.grupo.visible = f
end sub
