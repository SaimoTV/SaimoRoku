' ====================================================================
' Saimo TV - Lista com usuário e senha (Xtream Codes)
' Uma conta é guardada como um link M3U comum
' (http://servidor:porta/get.php?username=...&password=...): assim ela
' viaja pelo Saimo Connect e entra em "Minhas listas" como qualquer outra.
' A senha nunca é mostrada de volta nem entra em mensagem de erro.
' Sem nós SceneGraph: roda dentro de Task e de componentes.
' ====================================================================

function xtCod(s as String) as String
    return CreateObject("roUrlTransfer").Escape(s)
end function

function xtLinkM3u(base as String, usuario as String, senha as String) as String
    return base + "/get.php?username=" + xtCod(usuario) + "&password=" + xtCod(senha) + "&type=m3u_plus&output=ts"
end function

function xtUrlApi(conta as Object, acao as String) as String
    u = conta.base + "/player_api.php?username=" + xtCod(conta.usuario) + "&password=" + xtCod(conta.senha)
    if acao <> "" then u = u + "&action=" + acao
    return u
end function

function xtUrlCanal(conta as Object, id as String, ext as String) as String
    return conta.base + "/live/" + xtCod(conta.usuario) + "/" + xtCod(conta.senha) + "/" + id + "." + ext
end function

function xtHostValido(host as String) as Boolean
    re = CreateObject("roRegex", "^([A-Za-z0-9]([A-Za-z0-9.\-]*[A-Za-z0-9])?|\[[0-9A-Fa-f:.]+\])(:[0-9]{1,5})?$", "")
    return re.IsMatch(host)
end function

' Servidor digitado -> base sem barra no fim (http://host:porta, com o
' caminho do painel, se houver). Sem esquema ganha http://. invalid se
' não parece um endereço.
function xtNormalizarServidor(texto as String) as Dynamic
    t = texto.Trim()
    if t = "" then return invalid
    if Instr(1, t, " ") > 0 then return invalid
    if Instr(1, t, "://") = 0 then t = "http://" + t
    posicao = Instr(1, t, "://")
    esquema = LCase(Left(t, posicao - 1))
    if esquema <> "http" and esquema <> "https" then return invalid
    resto = Mid(t, posicao + 3)
    p = Instr(1, resto, "?")
    if p > 0 then resto = Left(resto, p - 1)
    p = Instr(1, resto, "#")
    if p > 0 then resto = Left(resto, p - 1)
    barra = Instr(1, resto, "/")
    host = resto
    caminho = ""
    if barra > 0 then
        host = Left(resto, barra - 1)
        caminho = Mid(resto, barra)
    end if
    if not xtHostValido(host) then return invalid
    baixo = LCase(caminho)
    if baixo = "/get.php" or baixo = "/player_api.php" or baixo = "/panel_api.php" or baixo = "/c" or baixo = "/c/" then caminho = ""
    while Len(caminho) > 0 and Right(caminho, 1) = "/"
        caminho = Left(caminho, Len(caminho) - 1)
    end while
    return esquema + "://" + LCase(host) + caminho
end function

' Reconhece o link de uma conta (get.php ou player_api.php com usuário e senha).
function xtDeLink(link as String) as Dynamic
    t = link.Trim()
    baixo = LCase(t)
    marca = "/get.php?"
    i = Instr(1, baixo, marca)
    if i = 0 then
        marca = "/player_api.php?"
        i = Instr(1, baixo, marca)
    end if
    if i = 0 then return invalid
    if Left(baixo, 7) <> "http://" and Left(baixo, 8) <> "https://" then return invalid
    consulta = Mid(t, i + Len(marca))
    h = Instr(1, consulta, "#")
    if h > 0 then consulta = Left(consulta, h - 1)
    ut = CreateObject("roUrlTransfer")
    usuario = ""
    senha = ""
    for each par in consulta.Split("&")
        e = Instr(1, par, "=")
        if e > 0 then
            k = LCase(Left(par, e - 1))
            v = ut.Unescape(Mid(par, e + 1).Replace("+", " "))
            if k = "username" then usuario = v
            if k = "password" then senha = v
        end if
    end for
    if usuario = "" or senha = "" then return invalid
    base = xtNormalizarServidor(Left(t, i - 1))
    if base = invalid then return invalid
    return { base: base, usuario: usuario, senha: senha }
end function

' O link a guardar a partir do que a pessoa digitou. Com usuário e senha o
' primeiro campo é o servidor; sem eles, é o link da lista.
' Devolve { link: "..." } ou { erro: "..." }.
function xtLinkDoFormulario(digitado as String, usuario as String, senha as String) as Object
    u = usuario.Trim()
    if (u = "") <> (senha = "") then
        return { erro: "Usuário e senha andam juntos: preencha os dois, ou deixe os dois em branco se a lista é só um link" }
    end if
    if u = "" then return { link: digitado.Trim() }
    base = xtNormalizarServidor(digitado)
    if base = invalid then return { erro: "Esse servidor não parece um endereço válido" }
    return { link: xtLinkM3u(base, u, senha) }
end function

function xtTexto(v as Dynamic) as String
    if v = invalid then return ""
    t = Type(v)
    if t = "roString" or t = "String" then return v.Trim()
    return v.ToStr()
end function

' "" se a conta vale; "sem-api"; ou o motivo da recusa.
function xtEntrada(json as String) as String
    raiz = ParseJson(json)
    if raiz = invalid then return "sem-api"
    if Type(raiz) <> "roAssociativeArray" then return "sem-api"
    info = raiz.user_info
    if info = invalid then return "sem-api"
    if Type(info) <> "roAssociativeArray" then return "sem-api"
    auth = LCase(xtTexto(info.auth))
    if auth <> "1" and auth <> "true" then return "Usuário ou senha incorretos"
    status = xtTexto(info.status)
    if status <> "" and LCase(status) <> "active" then return "Essa conta não está ativa"
    validade = Val(xtTexto(info.exp_date))
    if validade > 0 and validade <= CreateObject("roDateTime").AsSeconds() then return "Essa conta venceu"
    return ""
end function

' get_live_streams + categorias -> canais (mesma forma do LerM3u), com
' .m3u8 e .ts como duas fontes.
function xtCanaisDaApi(conta as Object, streams as Dynamic, categorias as Dynamic, limite as Integer) as Object
    mapa = {}
    if categorias <> invalid and Type(categorias) = "roArray" then
        for each c in categorias
            if Type(c) = "roAssociativeArray" then mapa[xtTexto(c.category_id)] = xtTexto(c.category_name)
        end for
    end if
    ordem = []
    porNome = {}
    if streams = invalid or Type(streams) <> "roArray" then return ordem
    for each o in streams
        if ordem.Count() >= limite then exit for
        if Type(o) = "roAssociativeArray" then
            id = xtTexto(o.stream_id)
            if id <> "" then
                nome = xtTexto(o.name)
                if nome = "" then nome = "Canal " + (ordem.Count() + 1).ToStr()
                grupo = invalid
                cat = xtTexto(o.category_id)
                if mapa.DoesExist(cat) and mapa[cat] <> "" then grupo = mapa[cat]
                logo = invalid
                icone = xtTexto(o.stream_icon)
                if LCase(Left(icone, 4)) = "http" then logo = icone
                fontes = [
                    { url: xtUrlCanal(conta, id, "m3u8"), referer: invalid, ua: invalid, qualidade: invalid }
                    { url: xtUrlCanal(conta, id, "ts"), referer: invalid, ua: invalid, qualidade: invalid }
                ]
                chave = ChaveDoNome(nome)
                if porNome.DoesExist(chave) then
                    antigo = porNome[chave]
                    if antigo.grupo = invalid then antigo.grupo = grupo
                    if antigo.logo = invalid then antigo.logo = logo
                    antigo.fontes.Append(fontes)
                else
                    canal = { nome: nome, grupo: grupo, logo: logo, fontes: fontes }
                    porNome[chave] = canal
                    ordem.Push(canal)
                end if
            end if
        end if
    end for
    return ordem
end function
