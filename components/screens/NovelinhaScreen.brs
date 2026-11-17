' ====================================================================
' Saimo TV - NovelinhaScreen (BrightScript)
' Player das novelinhas: todos os episódios numa playlist do Video. No fim de
' um, o seguinte entra sozinho; cima/baixo trocam de episódio, OK pausa e
' voltar sai. Onde parou fica guardado (episódio) no registro, só os
' últimos 20, para não pesar nos 16 KB do app.
' ====================================================================

sub init()
    m.video = m.top.findNode("video")
    m.titulo = m.top.findNode("titulo")
    m.episodio = m.top.findNode("episodio")
    m.topo = m.top.findNode("topo")
    m.esconder = m.top.findNode("esconder")
    m.esconder.observeField("fire", "onEsconder")
    m.video.observeField("contentIndex", "onEpisodio")
    m.video.observeField("state", "onEstado")
end sub

sub onItem()
    it = m.top.item
    if it = invalid then return
    m.titulo.text = it.title
    lista = CreateObject("roSGNode", "ContentNode")
    for ep = 1 to it.episodios
        no = lista.CreateChild("ContentNode")
        numero = ep.ToStr()
        while Len(numero) < 3
            numero = "0" + numero
        end while
        no.url = it.base + it.pasta + "/episode-" + numero + ".mp4"
        no.streamFormat = "mp4"
        no.title = it.title + " · Episódio " + ep.ToStr()
    end for
    m.video.contentIsPlaylist = true
    m.video.content = lista
    inicio = paradaDe(it.id)
    if inicio > 0 and inicio < it.episodios then m.video.nextContentIndex = inicio
    m.video.control = "play"
    if inicio > 0 and inicio < it.episodios then m.video.control = "skipcontent"
    m.top.setFocus(true)
    mostrar()
end sub

sub onEpisodio()
    it = m.top.item
    if it = invalid then return
    guardar(it.id, m.video.contentIndex)
    mostrar()
end sub

sub onEstado()
    if m.video.state = "finished" then m.top.exitRequested = true
end sub

sub mostrar()
    it = m.top.item
    if it = invalid then return
    audio = "Legendado"
    if it.dublada then audio = "Dublado"
    m.episodio.text = "Episódio " + (m.video.contentIndex + 1).ToStr() + " de " + it.episodios.ToStr() + " · " + audio
    m.topo.visible = true
    m.esconder.control = "stop"
    m.esconder.control = "start"
end sub

sub onEsconder()
    m.topo.visible = false
end sub

sub irPara(indice as Integer)
    it = m.top.item
    if it = invalid or indice < 0 or indice >= it.episodios then return
    m.video.nextContentIndex = indice
    m.video.control = "skipcontent"
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "down" or key = "fastforward" then
        irPara(m.video.contentIndex + 1)
        return true
    else if key = "up" or key = "rewind" then
        irPara(m.video.contentIndex - 1)
        return true
    else if key = "OK" or key = "play" then
        if m.video.state = "paused" then
            m.video.control = "resume"
        else
            m.video.control = "pause"
        end if
        mostrar()
        return true
    else if key = "back" then
        m.top.exitRequested = true
        return true
    end if
    return false
end function

' ----- Onde parou: "id:indice" separados por vírgula, os 20 mais recentes -----
function paradaDe(id as String) as Integer
    sec = CreateObject("roRegistrySection", "novelinhas")
    if not sec.Exists("paradas") then return 0
    for each par in sec.Read("paradas").Split(",")
        p = par.Split(":")
        if p.Count() = 2 and p[0] = id then return Int(Val(p[1]))
    end for
    return 0
end function

sub guardar(id as String, indice as Integer)
    sec = CreateObject("roRegistrySection", "novelinhas")
    novas = [id + ":" + indice.ToStr()]
    if sec.Exists("paradas") then
        for each par in sec.Read("paradas").Split(",")
            p = par.Split(":")
            if p.Count() = 2 and p[0] <> id and novas.Count() < 20 then novas.Push(par)
        end for
    end if
    texto = ""
    for each n in novas
        if texto <> "" then texto = texto + ","
        texto = texto + n
    end for
    sec.Write("paradas", texto)
    sec.Flush()
end sub

sub cleanUp()
    m.video.control = "stop"
    m.video.content = invalid
end sub
