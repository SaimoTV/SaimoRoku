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
    buffer = CreateObject("roByteArray")
    buffer[4096] = 0

    while true
        msg = wait(500, msgPort)
        if type(msg) = "roSocketEvent" then
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
                            dataText = buffer.ToAsciiString()
                            handleClientData(conn, dataText)
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
    ' 1. Trata requisição HTTP GET /info (descoberta do Saimo Connect)
    if Instr(1, data, "GET /info") > 0 then
        infoJson = "{" + Chr(34) + "id" + Chr(34) + ":" + Chr(34) + "roku-saimo-tv" + Chr(34) + "," + Chr(34) + "name" + Chr(34) + ":" + Chr(34) + "Saimo TV - Roku" + Chr(34) + "," + Chr(34) + "version" + Chr(34) + ":" + Chr(34) + "2.6.0" + Chr(34) + "," + Chr(34) + "type" + Chr(34) + ":" + Chr(34) + "roku" + Chr(34) + "}"
        httpResp = "HTTP/1.1 200 OK" + Chr(13) + Chr(10) + "Content-Type: application/json" + Chr(13) + Chr(10) + "Access-Control-Allow-Origin: *" + Chr(13) + Chr(10) + "Content-Length: " + Len(infoJson).ToStr() + Chr(13) + Chr(10) + "Connection: close" + Chr(13) + Chr(10) + Chr(13) + Chr(10) + infoJson
        ba = CreateObject("roByteArray")
        ba.FromAsciiString(httpResp)
        conn.send(ba, 0, ba.Count())
        return
    end if

    ' 2. Trata comandos JSON (recebidos via HTTP POST ou WebSocket/TCP raw)
    jsonStart = Instr(1, data, "{")
    if jsonStart > 0 then
        jsonEnd = Instr(jsonStart, data, "}")
        if jsonEnd > jsonStart then
            jsonPayload = Mid(data, jsonStart, (jsonEnd - jsonStart) + 1)
            parsed = ParseJson(jsonPayload)
            if parsed <> invalid then
                ' Envia o comando recebido para a MainScene via observer
                m.top.receivedCommand = parsed

                ' Responde OK
                okResp = "HTTP/1.1 200 OK" + Chr(13) + Chr(10) + "Content-Type: application/json" + Chr(13) + Chr(10) + "Access-Control-Allow-Origin: *" + Chr(13) + Chr(10) + "Connection: close" + Chr(13) + Chr(10) + Chr(13) + Chr(10) + "{" + Chr(34) + "status" + Chr(34) + ":" + Chr(34) + "ok" + Chr(34) + "}"
                ba = CreateObject("roByteArray")
                ba.FromAsciiString(okResp)
                conn.send(ba, 0, ba.Count())
            end if
        end if
    end if
end sub
