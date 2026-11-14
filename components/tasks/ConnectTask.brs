' ====================================================================
' Saimo TV - ConnectTask (BrightScript)
' Servidor LAN (Porta 8999):
'   - Descoberta /info e WebSocket RFC 6455 Saimo Connect
'   - Portal HTML /addons e API REST /api/addons + POST /addons
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
    if not listenSock.listen(8) then
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
    m.httpBuffers = {}
    m.wsBuffers = {}
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
                sid = Stri(changedID)
                conn = connections[sid]
                if conn <> invalid then
                    closed = false
                    if conn.isReadable() then
                        received = conn.receive(buffer, 0, 4096)
                        if received > 0 then
                            if m.sessoes.DoesExist(sid) then
                                lerQuadros(conn, sid, buffer, received)
                            else
                                closed = processHttpChunk(conn, sid, buffer, received)
                            end if
                        else if received = 0 then
                            closed = true
                        end if
                    end if
                    if closed then
                        cleanupSocket(conn, sid, connections)
                    end if
                end if
            end if
        end if
    end while
end sub

sub cleanupSocket(conn as Object, sid as String, connections as Object)
    if conn <> invalid then conn.close()
    connections.Delete(sid)
    m.sessoes.Delete(sid)
    m.autenticados.Delete(sid)
    m.httpBuffers.Delete(sid)
    m.wsBuffers.Delete(sid)
    m.top.activeClients = connections.Count()
end sub

function extractSliceBytes(src as Object, startIdx as Integer, count as Integer) as Object
    out = CreateObject("roByteArray")
    if count <= 0 or startIdx < 0 then return out
    maxEnd = startIdx + count - 1
    if maxEnd >= src.Count() then maxEnd = src.Count() - 1
    for i = startIdx to maxEnd
        out.Push(src[i])
    end for
    return out
end function

function findHeaderEndIndex(ba as Object) as Integer
    n = ba.Count()
    if n < 4 then return -1
    for i = 0 to n - 4
        if ba[i] = 13 and ba[i + 1] = 10 and ba[i + 2] = 13 and ba[i + 3] = 10 then
            return i
        end if
    end for
    return -1
end function

function parseContentLength(headersText as String) as Integer
    mMatch = CreateObject("roRegex", "Content-Length:\s*([0-9]+)", "i").Match(headersText)
    if mMatch <> invalid and mMatch.Count() >= 2 then
        return Int(Val(mMatch[1].Trim()))
    end if
    return 0
end function

' Retorna true quando a resposta HTTP foi encerrada e o socket deve fechar.
function processHttpChunk(conn as Object, sid as String, chunk as Object, received as Integer) as Boolean
    acc = m.httpBuffers[sid]
    if acc = invalid then
        acc = CreateObject("roByteArray")
    end if
    for i = 0 to received - 1
        acc.Push(chunk[i])
    end for

    if acc.Count() > 131072 then
        m.httpBuffers.Delete(sid)
        sendHttpText(conn, "413 Payload Too Large", "application/json; charset=utf-8", FormatJson({ ok: false, error: "Payload muito grande." }))
        return true
    end if

    m.httpBuffers[sid] = acc
    hdrEnd = findHeaderEndIndex(acc)
    if hdrEnd < 0 then return false

    hdrBytes = extractSliceBytes(acc, 0, hdrEnd)
    headersText = hdrBytes.ToAsciiString()

    ' Checa upgrade WebSocket imediatamente
    if Instr(1, headersText, "Upgrade: websocket") > 0 or Instr(1, LCase(headersText), "sec-websocket-key:") > 0 then
        m.httpBuffers.Delete(sid)
        handleWebSocketUpgrade(conn, sid, headersText)
        return false
    end if

    bodyStart = hdrEnd + 4
    contentLen = parseContentLength(headersText)
    availableBody = acc.Count() - bodyStart
    if contentLen > 0 and availableBody < contentLen then
        return false
    end if

    bodyText = ""
    if contentLen > 0 then
        bodyBytes = extractSliceBytes(acc, bodyStart, contentLen)
        bodyText = bodyBytes.ToAsciiString()
    else if availableBody > 0 then
        bodyBytes = extractSliceBytes(acc, bodyStart, availableBody)
        bodyText = bodyBytes.ToAsciiString()
    end if

    m.httpBuffers.Delete(sid)
    handleHttpRequest(conn, headersText, bodyText)
    return true
end function

sub handleWebSocketUpgrade(conn as Object, sid as String, headersText as String)
    chave = CreateObject("roRegex", "Sec-WebSocket-Key:\s*([^\r\n]+)", "i").Match(headersText)
    if chave = invalid or chave.Count() < 2 then return
    guid = CreateObject("roByteArray")
    guid.FromAsciiString(chave[1].Trim() + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
    sha = CreateObject("roEVPDigest")
    sha.Setup("sha1")
    resumo = CreateObject("roByteArray")
    resumo.FromHexString(sha.Process(guid))
    q = Chr(13) + Chr(10)
    enviar(conn, "HTTP/1.1 101 Switching Protocols" + q + "Upgrade: websocket" + q + "Connection: Upgrade" + q + "Sec-WebSocket-Accept: " + resumo.ToBase64String() + q + q)
    m.sessoes[sid] = conn
end sub

sub handleHttpRequest(conn as Object, headersText as String, bodyText as String)
    firstLine = headersText
    crlfIdx = Instr(1, headersText, Chr(13))
    if crlfIdx > 0 then firstLine = Left(headersText, crlfIdx - 1)
    parts = firstLine.Trim().Split(" ")
    method = "GET"
    reqPath = "/"
    if parts.Count() >= 2 then
        method = UCase(parts[0].Trim())
        reqPath = parts[1].Trim()
    end if

    qPos = Instr(1, reqPath, "?")
    cleanPath = reqPath
    if qPos > 0 then cleanPath = Left(reqPath, qPos - 1)

    if method = "OPTIONS" then
        q = Chr(13) + Chr(10)
        enviar(conn, "HTTP/1.1 204 No Content" + q + "Access-Control-Allow-Origin: *" + q + "Access-Control-Allow-Methods: GET, POST, OPTIONS" + q + "Access-Control-Allow-Headers: Content-Type" + q + "Connection: close" + q + q)
        return
    end if

    ' Descoberta: o celular só aceita quem responde app = saimo-tv
    if method = "GET" and cleanPath = "/info" then
        info = {
            app: "saimo-tv",
            id: idDaTv(),
            name: nomeDaTv(),
            version: "2.6.4",
            port: m.top.port,
            multi: false,
            addonsEnabled: true
        }
        sendHttpText(conn, "200 OK", "application/json; charset=utf-8", FormatJson(info))
        return
    end if

    if method = "GET" and (cleanPath = "/addons" or cleanPath = "/addons/") then
        sendHttpText(conn, "200 OK", "text/html; charset=utf-8", buildAddonsPortalHtml())
        return
    end if

    if method = "GET" and cleanPath = "/api/addons" then
        payload = buildAddonsApiState(true, "")
        sendHttpText(conn, "200 OK", "application/json; charset=utf-8", FormatJson(payload))
        return
    end if

    if method = "POST" and (cleanPath = "/addons" or cleanPath = "/api/addons") then
        handlePostAddons(conn, bodyText)
        return
    end if

    sendHttpText(conn, "404 Not Found", "application/json; charset=utf-8", FormatJson({ ok: false, error: "Rota não encontrada." }))
end sub

function buildDebridMaskedState() as Object
    cfg = LoadDebridConfig()
    out = { sincronizarConnect: (cfg.sincronizarConnect = true) }
    keys = ["torbox", "realDebrid", "allDebrid", "premiumize"]
    for each k in keys
        p = cfg[k]
        hasKey = (p <> invalid and p.apiKey <> invalid and p.apiKey.Trim() <> "")
        en = (p <> invalid and p.enabled = true and hasKey)
        masked = ""
        if hasKey then masked = DebridMaskKey(p.apiKey)
        out[k] = {
            enabled: en,
            hasKey: hasKey,
            maskedKey: masked
        }
    end for
    return out
end function

function buildAddonsApiState(okFlag as Boolean, errMsg as String) as Object
    return {
        ok: okFlag,
        error: errMsg,
        tvName: nomeDaTv(),
        addons: LoadAddons(),
        debrid: buildDebridMaskedState()
    }
end function

sub handlePostAddons(conn as Object, bodyText as String)
    req = ParseJson(bodyText)
    if req = invalid or Type(req) <> "roAssociativeArray" then
        sendHttpText(conn, "400 Bad Request", "application/json; charset=utf-8", FormatJson(buildAddonsApiState(false, "JSON inválido.")))
        return
    end if

    acao = ""
    if req.action <> invalid then acao = LCase(req.action.ToStr().Trim())

    if acao = "add" then
        u = ""
        if req.url <> invalid then u = req.url.ToStr()
        if u = "" and req.transportUrl <> invalid then u = req.transportUrl.ToStr()
        res = AddOrUpdateAddon(u)
        if res.ok then
            notifyAddonsMutated()
            sendHttpText(conn, "200 OK", "application/json; charset=utf-8", FormatJson(buildAddonsApiState(true, "")))
        else
            sendHttpText(conn, "400 Bad Request", "application/json; charset=utf-8", FormatJson(buildAddonsApiState(false, res.error)))
        end if
        return
    else if acao = "toggle" then
        idx = -1
        if req.index <> invalid then idx = Int(Val(req.index.ToStr()))
        res = ToggleAddonAtIndex(idx)
        if res.ok then notifyAddonsMutated()
        sendHttpText(conn, "200 OK", "application/json; charset=utf-8", FormatJson(buildAddonsApiState(res.ok, res.error)))
        return
    else if acao = "moveup" then
        idx = -1
        if req.index <> invalid then idx = Int(Val(req.index.ToStr()))
        res = MoveAddonAtIndex(idx, -1)
        if res.ok then notifyAddonsMutated()
        sendHttpText(conn, "200 OK", "application/json; charset=utf-8", FormatJson(buildAddonsApiState(res.ok, res.error)))
        return
    else if acao = "movedown" then
        idx = -1
        if req.index <> invalid then idx = Int(Val(req.index.ToStr()))
        res = MoveAddonAtIndex(idx, 1)
        if res.ok then notifyAddonsMutated()
        sendHttpText(conn, "200 OK", "application/json; charset=utf-8", FormatJson(buildAddonsApiState(res.ok, res.error)))
        return
    else if acao = "revalidate" then
        idx = -1
        if req.index <> invalid then idx = Int(Val(req.index.ToStr()))
        addons = LoadAddons()
        if idx < 0 or idx >= addons.Count() then
            sendHttpText(conn, "400 Bad Request", "application/json; charset=utf-8", FormatJson(buildAddonsApiState(false, "Addon inválido.")))
            return
        end if
        res = AddOrUpdateAddon(addons[idx].url)
        if res.ok then notifyAddonsMutated()
        sendHttpText(conn, "200 OK", "application/json; charset=utf-8", FormatJson(buildAddonsApiState(res.ok, res.error)))
        return
    else if acao = "remove" then
        idx = -1
        if req.index <> invalid then idx = Int(Val(req.index.ToStr()))
        res = RemoveAddonAtIndex(idx)
        if res.ok then notifyAddonsMutated()
        sendHttpText(conn, "200 OK", "application/json; charset=utf-8", FormatJson(buildAddonsApiState(res.ok, res.error)))
        return
    else if acao = "savedebrid" then
        cfg = LoadDebridConfig()
        dReq = req.debrid
        if dReq <> invalid and Type(dReq) = "roAssociativeArray" then
            if dReq.DoesExist("sincronizarConnect") then
                cfg.sincronizarConnect = (dReq.sincronizarConnect = true)
            end if
            keys = ["torbox", "realDebrid", "allDebrid", "premiumize"]
            for each k in keys
                if dReq.DoesExist(k) and Type(dReq[k]) = "roAssociativeArray" then
                    inc = dReq[k]
                    cur = cfg[k]
                    if cur = invalid then cur = { apiKey: "", enabled: false }
                    if inc.clear = true then
                        cur.apiKey = ""
                        cur.enabled = false
                    else if inc.apiKey <> invalid and inc.apiKey.ToStr().Trim() <> "" then
                        cur.apiKey = inc.apiKey.ToStr().Trim()
                        cur.enabled = true
                        if inc.DoesExist("enabled") then cur.enabled = (inc.enabled = true)
                    else if inc.DoesExist("enabled") then
                        cur.enabled = (inc.enabled = true and cur.apiKey <> "")
                    end if
                    cfg[k] = cur
                end if
            end for
            SaveDebridConfig(cfg)
            notifyAddonsMutated()
            sendHttpText(conn, "200 OK", "application/json; charset=utf-8", FormatJson(buildAddonsApiState(true, "")))
            return
        end if
    end if

    sendHttpText(conn, "400 Bad Request", "application/json; charset=utf-8", FormatJson(buildAddonsApiState(false, "Ação não suportada.")))
end sub

sub notifyAddonsMutated()
    m.top.addonsUpdated = m.top.addonsUpdated + 1
end sub

sub sendHttpText(conn as Object, statusLine as String, contentType as String, body as String)
    bodyBytes = CreateObject("roByteArray")
    bodyBytes.FromAsciiString(body)
    q = Chr(13) + Chr(10)
    hdr = "HTTP/1.1 " + statusLine + q + "Content-Type: " + contentType + q + "Access-Control-Allow-Origin: *" + q + "Cache-Control: no-store" + q + "Content-Length: " + bodyBytes.Count().ToStr() + q + "Connection: close" + q + q
    hdrBytes = CreateObject("roByteArray")
    hdrBytes.FromAsciiString(hdr)
    hdrBytes.Append(bodyBytes)
    enviarBytes(conn, hdrBytes)
end sub

sub enviarBytes(conn as Object, ba as Object)
    total = ba.Count()
    sentTotal = 0
    tentativas = 0
    while sentTotal < total and tentativas < 80
        sent = conn.send(ba, sentTotal, total - sentTotal)
        if sent > 0 then
            sentTotal = sentTotal + sent
            tentativas = 0
        else if sent = 0 then
            tentativas = tentativas + 1
            Sleep(15)
        else
            exit while
        end if
    end while
end sub

sub enviar(conn as Object, texto as String)
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(texto)
    enviarBytes(conn, ba)
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
    enviarBytes(conn, q)
end sub

' Quadros do celular: sempre mascarados; acumula fragmentos TCP em m.wsBuffers.
sub lerQuadros(conn as Object, sid as String, chunk as Object, totalChunk as Integer)
    b = m.wsBuffers[sid]
    if b = invalid then b = CreateObject("roByteArray")
    for i = 0 to totalChunk - 1
        b.Push(chunk[i])
    end for

    total = b.Count()
    p = 0
    while p + 2 <= total
        frameStart = p
        op = b[p] and &h0F
        masked = ((b[p + 1] and &h80) <> 0)
        n = b[p + 1] and &h7F
        p = p + 2
        if n = 126 then
            if p + 2 > total then
                p = frameStart
                exit while
            end if
            n = b[p] * 256 + b[p + 1]
            p = p + 2
        else if n = 127 then
            if p + 8 > total then
                p = frameStart
                exit while
            end if
            ' Tamanhos 64-bit: usa os 32 bits inferiores
            n = b[p + 4] * 16777216 + b[p + 5] * 65536 + b[p + 6] * 256 + b[p + 7]
            p = p + 8
        end if

        maskSize = 0
        if masked then maskSize = 4
        if p + maskSize + n > total then
            p = frameStart
            exit while
        end if

        chave = [0, 0, 0, 0]
        if masked then
            chave = [b[p], b[p + 1], b[p + 2], b[p + 3]]
            p = p + 4
        end if

        carga = CreateObject("roByteArray")
        for i = 0 to n - 1
            x = b[p + i]
            if masked then
                y = chave[i mod 4]
                carga.Push((x or y) and not (x and y))
            else
                carga.Push(x)
            end if
        end for
        p = p + n

        if op = 1 then
            mensagem(conn, carga.ToAsciiString())
        else if op = 8 then
            conn.close()
            m.sessoes.Delete(sid)
            m.autenticados.Delete(sid)
            m.wsBuffers.Delete(sid)
            return
        end if
    end while

    if p >= total then
        m.wsBuffers.Delete(sid)
    else
        m.wsBuffers[sid] = extractSliceBytes(b, p, total - p)
    end if
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

function buildAddonsPortalHtml() as String
    q = Chr(10)
    html = "<!DOCTYPE html><html lang='pt-BR'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>" + q
    html = html + "<title>Saimo TV — Addons Stremio e Debrid</title>" + q
    html = html + "<style>" + q
    html = html + "body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#0b0e14;color:#e2e8f0;margin:0;padding:18px;}" + q
    html = html + ".wrap{max-width:740px;margin:0 auto;}h1{color:#4fe3d0;font-size:24px;margin:0 0 6px;}p.sub{color:#94a3b8;font-size:14px;margin:0 0 18px;}" + q
    html = html + ".card{background:#111827;border:1px solid #1f2937;border-radius:12px;padding:16px;margin-bottom:16px;}" + q
    html = html + "h2{font-size:17px;margin:0 0 12px;color:#fff;}label{display:block;font-size:13px;color:#cbd5e1;margin:8px 0 4px;}" + q
    html = html + "input[type=text],input[type=password]{width:100%;box-sizing:border-box;padding:11px 12px;border-radius:8px;border:1px solid #334155;background:#0b0e14;color:#fff;font-size:14px;}" + q
    html = html + ".row{display:flex;gap:8px;flex-wrap:wrap;align-items:center;margin-top:10px;}" + q
    html = html + "button{background:#4fe3d0;color:#0b0e14;border:none;border-radius:8px;padding:10px 14px;font-weight:700;cursor:pointer;font-size:13px;}" + q
    html = html + "button.sec{background:#1e293b;color:#e2e8f0;}button.warn{background:#7f1d1d;color:#fecaca;}" + q
    html = html + ".addon{display:flex;justify-content:space-between;align-items:center;gap:10px;border-top:1px solid #1f2937;padding:12px 0;}" + q
    html = html + ".addon:first-child{border-top:none;}.meta{font-size:12px;color:#94a3b8;word-break:break-all;margin-top:3px;}" + q
    html = html + ".badge{display:inline-block;font-size:11px;padding:2px 7px;border-radius:99px;background:#064e3b;color:#6ee7b7;margin-right:6px;}" + q
    html = html + ".badge.off{background:#374151;color:#d1d5db;}" + q
    html = html + "#msg{display:none;padding:11px 14px;border-radius:8px;margin-bottom:14px;font-size:14px;}" + q
    html = html + "#msg.ok{display:block;background:#064e3b;color:#d1fae5;}#msg.err{display:block;background:#7f1d1d;color:#fee2e2;}" + q
    html = html + ".prov{border-top:1px solid #1f2937;padding:10px 0;}.prov:first-child{border-top:none;}" + q
    html = html + "</style></head><body><div class='wrap'>" + q
    html = html + "<h1>Saimo TV — Addons e Debrid</h1><p class='sub'>Protocolo oficial Stremio (/manifest.json) com resolução Debrid direta nesta TV Roku.</p>" + q
    html = html + "<div id='msg'></div>" + q
    html = html + "<div class='card'><h2>Instalar Addon Stremio</h2>" + q
    html = html + "<label for='addonUrl'>URL do manifesto (aceita stremio:// ou https://...)</label>" + q
    html = html + "<input id='addonUrl' type='text' placeholder='https://seu-addon.exemplo/manifest.json' />" + q
    html = html + "<div class='row'><button onclick='addAddon()'>Validar e Adicionar</button><button class='sec' onclick='loadState()'>Atualizar</button></div></div>" + q
    html = html + "<div class='card'><h2>Addons Instalados (<span id='cnt'>0</span>)</h2><div id='addonsList'>Carregando...</div></div>" + q
    html = html + "<div class='card'><h2>Provedores Debrid (Torrents no Roku)</h2><div id='debridList'></div>" + q
    html = html + "<div class='row' style='margin-top:12px;'><label style='display:flex;align-items:center;gap:8px;margin:0;cursor:pointer;'><input id='syncChk' type='checkbox'> Sincronizar chaves Debrid com Saimo Connect (opcional)</label></div>" + q
    html = html + "<div class='row'><button onclick='saveDebrid()'>Salvar Configurações Debrid</button></div></div>" + q
    html = html + "</div><script>" + q
    html = html + "const PROVS=[['torbox','TorBox'],['realDebrid','Real-Debrid'],['allDebrid','AllDebrid'],['premiumize','Premiumize']];" + q
    html = html + "function showMsg(t,ok){const e=document.getElementById('msg');e.textContent=t;e.className=ok?'ok':'err';}" + q
    html = html + "async function api(body){const r=await fetch('/addons',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(body)});return await r.json();}" + q
    html = html + "function esc(s){return String(s||'').replace(/[&<>""']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','""':'&quot;',""'"":'&#39;'}[c]));}" + q
    html = html + "function render(d){document.getElementById('cnt').textContent=(d.addons||[]).length;" + q
    html = html + "const al=document.getElementById('addonsList');" + q
    html = html + "if(!d.addons||!d.addons.length){al.innerHTML='<p class=""meta"">Nenhum addon instalado. Cole a URL de um manifesto Stremio acima.</p>';}else{" + q
    html = html + "al.innerHTML=d.addons.map((a,i)=>`<div class='addon'><div><div><span class='badge ${a.enabled?'':'off'}'>${a.enabled?'Ativo':'Pausado'}</span><b>${esc(a.name)}</b></div><div class='meta'>${esc((a.types||[]).join(', '))} · ${esc(a.url)}</div></div><div class='row'><button class='sec' onclick='act(""toggle"",${i})'>${a.enabled?'Pausar':'Ativar'}</button><button class='sec' onclick='act(""moveUp"",${i})'>↑</button><button class='sec' onclick='act(""moveDown"",${i})'>↓</button><button class='sec' onclick='act(""revalidate"",${i})'>↻</button><button class='warn' onclick='act(""remove"",${i})'>Excluir</button></div></div>`).join('');}" + q
    html = html + "const deb=d.debrid||{};document.getElementById('syncChk').checked=!!deb.sincronizarConnect;" + q
    html = html + "document.getElementById('debridList').innerHTML=PROVS.map(([k,n])=>{const p=deb[k]||{};return `<div class='prov'><div style='display:flex;justify-content:space-between;align-items:center;'><b>${n}</b><label style='margin:0;'><input type='checkbox' id='en_${k}' ${p.enabled?'checked':''}> Ativo ${p.hasKey?'('+esc(p.maskedKey)+')':''}</label></div><input type='password' id='key_${k}' placeholder='${p.hasKey?'Deixe vazio para manter ('+esc(p.maskedKey)+')':'Cole a API Key de '+n}' style='margin-top:6px;'/><div class='row'><button class='sec' onclick='clearProv(""${k}"")'>Limpar chave ${n}</button></div></div>`;}).join('');}" + q
    html = html + "async function loadState(){try{const r=await fetch('/api/addons');const d=await r.json();render(d);}catch(e){showMsg('Erro ao conectar na TV',false);}}" + q
    html = html + "async function addAddon(){try{const u=document.getElementById('addonUrl').value.trim();if(!u){showMsg('Digite a URL do addon.',false);return;}showMsg('Validando manifest.json na TV...',true);const d=await api({action:'add',url:u});render(d);if(d.ok){document.getElementById('addonUrl').value='';showMsg('Addon instalado com sucesso!',true);}else{showMsg(d.error||'Falha ao validar manifesto.',false);}}catch(e){showMsg('Falha de comunicação com a TV.',false);}}" + q
    html = html + "async function act(action,index){try{const d=await api({action,index});render(d);showMsg(d.ok?'Atualizado!':(d.error||'Erro'),d.ok);}catch(e){showMsg('Falha de comunicação com a TV.',false);}}" + q
    html = html + "async function saveDebrid(){try{const debrid={sincronizarConnect:document.getElementById('syncChk').checked};for(const [k] of PROVS){debrid[k]={enabled:document.getElementById('en_'+k).checked,apiKey:document.getElementById('key_'+k).value.trim()};}const d=await api({action:'saveDebrid',debrid});render(d);showMsg(d.ok?'Debrid salvo na TV!':(d.error||'Erro'),d.ok);}catch(e){showMsg('Falha de comunicação com a TV.',false);}}" + q
    html = html + "async function clearProv(k){try{const d=await api({action:'saveDebrid',debrid:{[k]:{clear:true}}});render(d);showMsg('Chave removida.',true);}catch(e){showMsg('Falha de comunicação com a TV.',false);}}" + q
    html = html + "loadState();</script></body></html>"
    return html
end function
