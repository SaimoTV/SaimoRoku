' Tamanhos das fileiras, iguais em todas as telas: cartão largo, categoria ou capa.
sub AjustarFileiras(rowList as Object, raiz as Object)
    alturas = []
    tamanhos = []
    for i = 0 to raiz.getChildCount() - 1
        linha = raiz.getChild(i)
        tipo = ""
        if linha.getChildCount() > 0 then tipo = linha.getChild(0).itemType
        if tipo = "channel" or tipo = "radio" then
            alturas.Push(424) : tamanhos.Push([528, 400])
        else if tipo = "categoria" then
            alturas.Push(434) : tamanhos.Push([720, 410])
        else
            alturas.Push(480) : tamanhos.Push([272, 460])
        end if
    end for
    rowList.rowHeights = alturas
    rowList.rowItemSize = tamanhos
end sub
