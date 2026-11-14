sub init()
    m.fundo = m.top.findNode("fundo")
    m.letra = m.top.findNode("letra")
end sub

sub onConteudo()
    m.letra.text = m.top.itemContent.title
end sub

sub onFoco()
    f = m.top.focusPercent > 0.5 and m.top.gridHasFocus
    m.fundo.visible = f
    if f then m.letra.color = "#0b0e14" else m.letra.color = "#FFFFFF"
end sub
