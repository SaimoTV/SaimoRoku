' ====================================================================
' Saimo TV - ContaTask: a parte de rede da Conta Saimo (QR, senha e
' sincronia). Cada execução faz uma ação e devolve em `resultado`.
' ====================================================================

sub init()
    m.top.functionName = "executar"
end sub

function ContaNomeDoAparelho() as String
    info = CreateObject("roDeviceInfo")
    nome = info.GetFriendlyName()
    if nome = invalid or nome = "" then nome = info.GetModelDisplayName()
    return Left("Saimo no Roku (" + nome + ")", 60)
end function

' Chamada ao servidor da conta: { status, json } (status 0 = sem rede).
function ContaChamar(metodo as String, rota as String, corpo as Dynamic, token as String) as Object
    ut = CreateObject("roUrlTransfer")
    porta = CreateObject("roMessagePort")
    ut.SetMessagePort(porta)
    ut.SetUrl(ContaApi() + rota)
    ut.SetCertificatesFile("common:/certs/ca-bundle.crt")
    ut.RetainBodyOnError(true)
    ut.AddHeader("Content-Type", "application/json")
    if token <> "" then ut.AddHeader("Authorization", "Bearer " + token)
    ok = false
    if metodo = "GET" then
        ok = ut.AsyncGetToString()
    else
        ut.SetRequest(metodo)
        texto = ""
        if corpo <> invalid then texto = FormatJson(corpo)
        ok = ut.AsyncPostFromString(texto)
    end if
    if not ok then return { status: 0, json: invalid }
    msg = Wait(20000, porta)
    if type(msg) <> "roUrlEvent" then
        ut.AsyncCancel()
        return { status: 0, json: invalid }
    end if
    return { status: msg.GetResponseCode(), json: ParseJson(msg.GetString()) }
end function

function ContaMensagem(r as Object) as String
    if r.status <= 0 then return "Sem conexão com a conta Saimo agora"
    if r.json <> invalid and r.json.mensagem <> invalid then return r.json.mensagem
    return "Não deu certo: tente de novo"
end function

sub ContaEntrou(j as Object)
    reg = GetRegistry()
    reg.Delete("conta_ultimo_enviado")
    reg.Flush()
    email = ""
    if j.conta <> invalid and j.conta.email <> invalid then email = j.conta.email
    ContaGravarSessao({ token: j.token, email: email, sincronizadaEm: 0 })
end sub

' Com mudança aqui desde o último envio: manda (PUT) e o servidor devolve tudo
' já juntado, que é aplicado aqui. Sem mudança: só baixa (GET). Um pedido por
' sincronia (cada pedido ao servidor é cobrado).
function ContaSincronizar() as Object
    s = ContaSessao()
    if s.token = "" then return { ok: false, erro: "Entre na sua conta primeiro" }
    reg = GetRegistry()
    pacote = ContaPacote()
    texto = FormatJson(pacote)
    ultimo = reg.Read("conta_ultimo_enviado")
    if ultimo = invalid then ultimo = ""
    if texto <> ultimo then
        r = ContaChamar("PUT", "/v1/dados", { dados: pacote }, s.token)
    else
        r = ContaChamar("GET", "/v1/dados", invalid, s.token)
    end if
    if r.status = 401 then
        ContaGravarSessao(invalid)
        return { ok: false, erro: "Sessão encerrada: entre de novo", saiu: true }
    end if
    if r.status < 200 or r.status >= 300 then return { ok: false, erro: ContaMensagem(r) }
    if r.json <> invalid and r.json.dados <> invalid then ContaAplicar(r.json.dados)
    ' O servidor já tem tudo o que ficou aqui depois de juntar.
    reg.Write("conta_ultimo_enviado", FormatJson(ContaPacote()))
    reg.Flush()
    s = ContaSessao()
    s.sincronizadaEm = CreateObject("roDateTime").AsSeconds()
    ContaGravarSessao(s)
    return { ok: true }
end function

sub executar()
    acao = m.top.acao
    res = { acao: acao, ok: false }
    if acao = "pedir" then
        r = ContaChamar("POST", "/v1/tv/pedir", { aparelho: ContaNomeDoAparelho() }, "")
        if r.status = 200 and r.json <> invalid and r.json.codigo <> invalid then
            res = { acao: acao, ok: true, codigo: r.json.codigo, url: r.json.url, aparelhoCodigo: r.json.aparelhoCodigo }
        else
            res.erro = ContaMensagem(r)
        end if
    else if acao = "estado" then
        r = ContaChamar("POST", "/v1/tv/estado", { aparelhoCodigo: m.top.aparelhoCodigo }, "")
        if r.status = 200 and r.json <> invalid then
            res.estado = r.json.estado
            if r.json.estado = "aprovado" and r.json.token <> invalid then
                ContaEntrou(r.json)
                res.ok = true
                sinc = ContaSincronizar()
                res.sincronizou = sinc.ok
            end if
        else
            res.erro = ContaMensagem(r)
        end if
    else if acao = "senha" then
        rota = "/v1/senha/entrar"
        if m.top.criar = true then rota = "/v1/senha/cadastrar"
        r = ContaChamar("POST", rota, { email: m.top.email, senha: m.top.senha, aparelho: ContaNomeDoAparelho() }, "")
        if r.status = 200 and r.json <> invalid and r.json.token <> invalid then
            ContaEntrou(r.json)
            res.ok = true
            sinc = ContaSincronizar()
            res.sincronizou = sinc.ok
        else
            res.erro = ContaMensagem(r)
        end if
    else if acao = "sincronizar" then
        sinc = ContaSincronizar()
        res.ok = sinc.ok
        res.erro = sinc.erro
    else if acao = "sair" then
        s = ContaSessao()
        if s.token <> "" then ContaChamar("POST", "/v1/sair", invalid, s.token)
        ContaGravarSessao(invalid)
        res.ok = true
    end if
    m.top.senha = ""
    m.top.resultado = res
end sub
