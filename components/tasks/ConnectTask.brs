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

    listenSock.setPort(port)
    listenSock.setAddress("0.0.0.0:" + port.ToStr())
    if not listenSock.listen(5) then
        m.top.status = "Erro ao vincular porta " + port.ToStr()
        return
    end if

    msgPort = CreateObject("roMessagePort")
    listenSock.setMessagePort(msgPort)
    listenSock.notifyOnStatus(true)
    m.top.status = "Pronto em 0.0.0.0:" + port.ToStr()

    connections = []

    while true
        msg = wait(200, msgPort)
        if type(msg) = "roSocketEvent" then
            if msg.getSocketID() = listenSock.getID() then
                ' Nova conexão de cliente chegando
                clientSock = listenSock.accept()
                if clientSock <> invalid then
                    clientSock.setMessagePort(msgPort)
                    clientSock.notifyOnStatus(true)
                    connections.Push({ sock: clientSock, id: clientSock.getID(), buffer: "" })
                    m.top.activeClients = connections.Count()
                end if
            else
                ' Dados recebidos de um cliente existente
                for i = connections.Count() - 1 to 0 step -1
                    conn = connections[i]
                    if conn.id = msg.getSocketID() then
                        ba = CreateObject("roByteArray")
                        bytesRead = conn.sock.receive(ba, 0, 4096)
                        if bytesRead > 0 then
                            receivedText = ba.ToAsciiString()
                            handleClientData(conn, receivedText)
                        else if conn.sock.eIsEOF() or bytesRead < 0 then
                            conn.sock.close()
                            connections.Delete(i)
                            m.top.activeClients = connections.Count()
                        end if
                        exit for
                    end if
                end for
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
        conn.sock.send(ba, 0, ba.Count())
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
                conn.sock.send(ba, 0, ba.Count())
            end if
        end if
    end if
end sub
