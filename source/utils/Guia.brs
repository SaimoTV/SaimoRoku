' ====================================================================
' Saimo TV - Guia (BrightScript)
' Nome do canal no formato das chaves do guia: o guia central (epg-leve.json)
' entra no mapa pelo nome do catálogo (meuguia) e pelo nome normalizado
' (guiadetv), e o normalizado é o que casa os canais das listas da pessoa.
' Mesma regra do site (src/utils/nomes.ts): sem acento, minúsculas, só letras e
' números, sem "BR - " na frente e sem HD/FHD/4K/BR no fim.
' ====================================================================

function NormalizarNomeCanal(texto as String) as String
    t = texto.Trim()
    ' Prefixo de país em maiúsculas, como nos feeds: "BR - SporTV 2", "BR|SporTV".
    if Len(t) > 3 and maiuscula(Mid(t, 1, 1)) and maiuscula(Mid(t, 2, 1)) then
        resto = Mid(t, 3).Trim()
        if Left(resto, 1) = "-" or Left(resto, 1) = "|" then t = Mid(resto, 2)
    end if
    t = LCase(t)
    trocas = { "á": "a", "à": "a", "â": "a", "ã": "a", "ä": "a", "é": "e", "è": "e", "ê": "e", "ë": "e", "í": "i", "ì": "i", "î": "i", "ï": "i", "ó": "o", "ò": "o", "ô": "o", "õ": "o", "ö": "o", "ú": "u", "ù": "u", "û": "u", "ü": "u", "ç": "c", "ñ": "n" }
    saida = ""
    for i = 1 to Len(t)
        c = Mid(t, i, 1)
        if trocas.DoesExist(c) then c = trocas[c]
        a = Asc(c)
        if (a >= 97 and a <= 122) or (a >= 48 and a <= 57) then
            saida = saida + c
        else
            saida = saida + " "
        end if
    end for
    palavras = []
    for each p in saida.Split(" ")
        if p <> "" then palavras.Push(p)
    end for
    ruido = { hd: true, sd: true, fhd: true, uhd: true, "4k": true, br: true }
    while palavras.Count() > 1 and ruido.DoesExist(palavras[palavras.Count() - 1])
        palavras.Pop()
    end while
    return palavras.Join(" ")
end function

function maiuscula(c as String) as Boolean
    a = Asc(c)
    return a >= 65 and a <= 90
end function

' Programação de um canal: pelo nome exato e, sem ele, pelo nome normalizado.
function GuiaDoCanal(epg as Dynamic, nome as Dynamic) as Dynamic
    if epg = invalid or nome = invalid or nome = "" then return invalid
    lista = epg[nome]
    if lista <> invalid then return lista
    return epg[NormalizarNomeCanal(nome)]
end function
