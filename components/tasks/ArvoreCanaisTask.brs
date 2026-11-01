' ====================================================================
' Saimo TV - ArvoreCanaisTask (BrightScript)
' Monta, fora do thread da tela, a árvore seção > canal do Ao vivo.
' Campo de lista é copiado inteiro a cada passagem; nó vai por referência.
' Com a árvore pronta, abrir o Ao vivo só aponta para ela: num stick de 512 MB
' copiar os canais e a programação na hora do clique congelava a tela.
' ====================================================================

sub init()
    m.top.functionName = "montar"
end sub

sub montar()
    canais = m.top.canais
    epg = m.top.epg
    agora = CreateObject("roDateTime").AsSeconds()
    raiz = CreateObject("roSGNode", "ContentNode")
    secoes = {}
    for each c in canais
        g = c.category
        if g = invalid or g = "" then g = "Outros"
        secao = secoes[g]
        if secao = invalid then
            secao = raiz.CreateChild("ContentNode")
            secao.title = g
            secoes[g] = secao
        end if
        no = secao.CreateChild("ContentNode")
        no.title = c.name
        logo = ""
        if c.logo <> invalid then
            logo = c.logo
            no.hdPosterUrl = logo
        end if
        campos = { name: c.name, number: c.number, category: g, logo: logo, variants: c.variants, numero: c.number.ToStr(), grupoTexto: UCase(g), programa: "", progresso: 0.0, ini: 0, fim: 0, seguinte: "" }
        if epg <> invalid and epg[c.name] <> invalid then
            lista = epg[c.name]
            for i = 0 to lista.Count() - 1
                p = lista[i]
                if agora >= p.startSec and agora < p.stopSec then
                    campos.programa = p.title
                    campos.ini = p.startSec
                    campos.fim = p.stopSec
                    if p.stopSec > p.startSec then campos.progresso = (agora - p.startSec) / (p.stopSec - p.startSec)
                    if i + 1 < lista.Count() then campos.seguinte = lista[i + 1].title
                    exit for
                end if
            end for
        end if
        no.addFields(campos)
    end for
    m.top.arvore = raiz
end sub
