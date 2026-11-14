sub init()
    m.fundo = m.top.findNode("fundo")
    m.titulo = m.top.findNode("titulo")
    m.valor = m.top.findNode("valor")
end sub

sub onConteudo()
    c = m.top.itemContent
    if c = invalid then return
    m.titulo.text = c.title
    m.valor.text = c.description
end sub

sub onFoco()
    f = m.top.focusPercent > 0.5 and m.top.listHasFocus
    m.fundo.visible = f
    if f then
        m.titulo.color = "#0b0e14" : m.valor.color = "#334155"
    else
        m.titulo.color = "#FFFFFF" : m.valor.color = "#A8B4C0"
    end if
end sub
