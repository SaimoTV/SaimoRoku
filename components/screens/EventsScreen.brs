' ====================================================================
' Saimo TV - EventsScreen (BrightScript)
' Jogos de hoje em cartões, com o cabeçalho acompanhando o foco.
' ====================================================================

sub init()
    m.heroBanner = m.top.findNode("heroBanner")
    m.rows = m.top.findNode("eventsRows")
    m.rows.observeField("rowItemSelected", "onEventSelected")
    m.rows.observeField("rowItemFocused", "onEventFocused")
    m.top.observeField("focusedChild", "onFocusedChildChange")
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() and not m.rows.isInFocusChain() then m.rows.setFocus(true)
end sub

sub onEventsChange()
    events = m.top.events
    if events = invalid then return
    m.top.findNode("vazio").visible = events.Count() = 0
    root = CreateObject("roSGNode", "ContentNode")
    vivos = invalid
    breve = invalid
    for each ev in events
        if ev.aoVivo then
            if vivos = invalid then
                vivos = root.CreateChild("ContentNode")
                vivos.title = "Ao vivo agora"
            end if
            linha = vivos
        else
            if breve = invalid then
                breve = CreateObject("roSGNode", "ContentNode")
                breve.title = "Começa em breve"
            end if
            linha = breve
        end if
        no = linha.CreateChild("ContentNode")
        no.title = ev.homeTeam + " x " + ev.awayTeam
        selo = ev.timeStr
        if ev.aoVivo then selo = "AO VIVO"
        no.addFields({ itemType: "evento", hora: selo, casa: ev.homeLogo, fora: ev.awayLogo, subTitulo: ev.channelName + "  ·  " + ev.league, rawEvent: ev })
    end for
    if breve <> invalid then root.appendChild(breve)
    m.rows.content = root
end sub

function noEm(c as Dynamic) as Dynamic
    root = m.rows.content
    if root = invalid or c = invalid or c.Count() < 2 then return invalid
    return root.getChild(c[0]).getChild(c[1])
end function

sub onEventFocused()
    no = noEm(m.rows.rowItemFocused)
    if no = invalid then return
    ev = no.rawEvent
    m.heroBanner.featuredItem = { title: no.title, genres: ev.league + "  ·  " + ev.timeStr, overview: "No canal " + ev.channelName + "  ·  OK assiste", semFundo: true }
end sub

sub onEventSelected()
    no = noEm(m.rows.rowItemSelected)
    if no <> invalid then m.top.tuneRequested = no.rawEvent.channelName
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "up" then
        m.top.focusUpRequested = true
        return true
    end if
    return false
end function

sub cleanUp()
end sub
