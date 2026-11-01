' ====================================================================
' Saimo TV - ConnectTask (BrightScript)
' Servidor de controle remoto e descoberta Saimo Connect (Porta 8999)
' ====================================================================

sub init()
    m.top.functionName = "runServer"
end sub

sub runServer()
    port = m.top.port
    listenSock = CreateObject("roStreamSocket")
    if listenSock = invalid then
        m.top.status = "roStreamSocket indisponivel"
        return
    end if

    msgPort = CreateObject("roMessagePort")
    listenSock.setMessagePort(msgPort)

    addr = CreateObject("roSocketAddress")
    if addr = invalid then return
    addr.setPort(port)
    listenSock.setAddress(addr)

    listenSock.notifyReadable(true)
    if not listenSock.listen(4) then
        m.top.status = "Erro ao iniciar escuta"
        return
    end if

    if not listenSock.eOK() then
        m.top.status = "Erro de socket"
        return
    end if

    m.top.status = "Pronto na porta " + port.ToStr()
    connections = {}
    m.sessoes = {}
    m.autenticados = {}
    m.top.observeField("saida", msgPort)
    buffer = CreateObject("roByteArray")
    buffer[4096] = 0

    while true
        msg = wait(500, msgPort)
        if type(msg) = "roSGNodeEvent" then
            ' Estado novo vai para todos os celulares conectados.
            for each k in m.sessoes
                if m.autenticados.DoesExist(k) then enviarQuadro(m.sessoes[k], msg.getData())
            end for
        else if type(msg) = "roSocketEvent" then
            changedID = msg.getSocketID()
            if changedID = listenSock.getID() and listenSock.isReadable() then
                newConn = listenSock.accept()
                if newConn <> invalid then
                    newConn.notifyReadable(true)
                    newConn.setMessagePort(msgPort)
                    connections[Stri(newConn.getID())] = newConn
                    m.top.activeClients = connections.Count()
                end if
            else
                conn = connections[Stri(changedID)]
                if conn <> invalid then
                    closed = false
                    if conn.isReadable() then
                        received = conn.receive(buffer, 0, 4096)
                        if received > 0 then
                            if m.sessoes.DoesExist(Stri(changedID)) then
                                lerQuadros(conn, buffer, received)
                            else
                                ' O buffer é reaproveitado: só o que chegou agora conta.
                                buffer[received] = 0
                                handleClientData(conn, buffer.ToAsciiString())
                            end if
                        else if received = 0 then
                            closed = true
                        end if
                    end if
                    if closed then
                        conn.close()
                        connections.Delete(Stri(changedID))
                        m.top.activeClients = connections.Count()
                    end if
                end if
            end if
        end if
    end while
end sub

sub handleClientData(conn as Object, data as String)
    ' Descoberta: o celular só aceita quem responde app = saimo-tv
    if Instr(1, data, "GET /info") > 0 then
        info = { app: "saimo-tv", id: idDaTv(), name: nomeDaTv(), version: "2.6.3", port: m.top.port, multi: false }
        corpo = FormatJson(info)
        q = Chr(13) + Chr(10)
        enviar(conn, "HTTP/1.1 200 OK" + q + "Content-Type: application/json" + q + "Access-Control-Allow-Origin: *" + q + "Content-Length: " + Len(corpo).ToStr() + q + "Connection: close" + q + q + corpo)
        return
    end if

    ' Abertura do WebSocket (GET /ws)
    if Instr(1, data, "Upgrade: websocket") > 0 or Instr(1, LCase(data), "sec-websocket-key:") > 0 then
        chave = CreateObject("roRegex", "Sec-WebSocket-Key:\s*([^\r\n]+)", "i").Match(data)
        if chave.Count() < 2 then return
        guid = CreateObject("roByteArray")
        guid.FromAsciiString(chave[1].Trim() + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
        sha = CreateObject("roEVPDigest")
        sha.Setup("sha1")
        resumo = CreateObject("roByteArray")
        resumo.FromHexString(sha.Process(guid))
        q = Chr(13) + Chr(10)
        enviar(conn, "HTTP/1.1 101 Switching Protocols" + q + "Upgrade: websocket" + q + "Connection: Upgrade" + q + "Sec-WebSocket-Accept: " + resumo.ToBase64String() + q + q)
        m.sessoes[Stri(conn.getID())] = conn
    end if
end sub

sub enviar(conn as Object, texto as String)
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(texto)
    conn.send(ba, 0, ba.Count())
end sub

function idDaTv() as String
    return "roku-" + CreateObject("roDeviceInfo").GetChannelClientId()
end function

function nomeDaTv() as String
    return "Saimo TV - Roku"
end function

' Quadro de texto do servidor: sem máscara.
sub enviarQuadro(conn as Object, texto as String)
    corpo = CreateObject("roByteArray")
    corpo.FromAsciiString(texto)
    q = CreateObject("roByteArray")
    q.Push(&h81)
    n = corpo.Count()
    if n < 126 then
        q.Push(n)
    else
        q.Push(126)
        q.Push(Int(n / 256))
        q.Push(n mod 256)
    end if
    q.Append(corpo)
    conn.send(q, 0, q.Count())
end sub

' Quadros do celular: sempre mascarados. Mensagens curtas chegam inteiras.
sub lerQuadros(conn as Object, b as Object, total as Integer)
    p = 0
    while p + 2 <= total
        op = b[p] and &h0F
        n = b[p + 1] and &h7F
        p = p + 2
        if n = 126 then
            n = b[p] * 256 + b[p + 1]
            p = p + 2
        end if
        if p + 4 + n > total then return
        chave = [b[p], b[p + 1], b[p + 2], b[p + 3]]
        p = p + 4
        carga = CreateObject("roByteArray")
        for i = 0 to n - 1
            x = b[p + i]
            y = chave[i mod 4]
            carga.Push((x or y) and not (x and y))
        end for
        p = p + n
        if op = 1 then
            mensagem(conn, carga.ToAsciiString())
        else if op = 8 then
            conn.close()
            m.sessoes.Delete(Stri(conn.getID()))
            return
        end if
    end while
end sub

sub mensagem(conn as Object, texto as String)
    cmd = ParseJson(texto)
    if cmd = invalid or cmd.t = invalid then return
    if cmd.t = "hello" then
        m.autenticados[Stri(conn.getID())] = true
        enviarQuadro(conn, FormatJson({ t: "welcome", tv: { id: idDaTv(), name: nomeDaTv() } }))
        if m.top.saida <> "" then enviarQuadro(conn, m.top.saida)
    else if cmd.t = "ping" then
        c0 = "0"
        if cmd.c0 <> invalid then c0 = cmd.c0.ToStr()
        agora = CreateObject("roDateTime").AsSeconds().ToStr() + "000"
        enviarQuadro(conn, "{" + Chr(34) + "t" + Chr(34) + ":" + Chr(34) + "pong" + Chr(34) + "," + Chr(34) + "c0" + Chr(34) + ":" + c0 + "," + Chr(34) + "tv" + Chr(34) + ":" + agora + "}")
    else if m.autenticados.DoesExist(Stri(conn.getID())) then
        if cmd.t = "key" and cmd.code <> invalid then
            apertar(cmd.code)
        else
            m.top.receivedCommand = cmd
        end if
    end if
end sub

' Teclas do celular entram pelo controle externo do próprio Roku: assim chegam a
' qualquer tela, como as do controle remoto.
sub apertar(codigo as String)
    mapa = { UP: "Up", DOWN: "Down", LEFT: "Left", RIGHT: "Right", OK: "Select", BACK: "Back", HOME: "Home", MENU: "Info" }
    tecla = mapa[UCase(codigo)]
    if tecla = invalid then return
    ut = CreateObject("roUrlTransfer")
    ut.SetUrl("http://127.0.0.1:8060/keypress/" + tecla)
    ut.PostFromString("")
end sub
