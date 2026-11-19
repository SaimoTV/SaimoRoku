' ====================================================================
' Saimo TV - Storage & Preferences (Roku Registry Section)
' Persistência nativa de configurações, progresso e favoritos
' ====================================================================

function GetRegistry() as Object
    return CreateObject("roRegistrySection", "saimo_tv")
end function

function NormalizarEnderecoSaimo(url as Dynamic) as String
    if url = invalid then return ""
    u = url.ToStr().Trim()
    if u = "" then return ""
    l = LCase(u)
    esquema = "https://"
    resto = u
    if Left(l, 7) = "http://" then
        esquema = "http://"
        resto = Mid(u, 8)
    else if Left(l, 8) = "https://" then
        esquema = "https://"
        resto = Mid(u, 9)
    end if
    u = esquema + resto
    l = LCase(u)
    if Instr(1, l, ".m3u") > 0 or Instr(1, l, "get.php") > 0 or Instr(1, l, "type=m3u") > 0 then
        return u
    end if

    hashPos = Instr(1, resto, "#")
    if hashPos > 0 then resto = Left(resto, hashPos - 1).Trim()
    queryPos = Instr(1, resto, "?")
    if queryPos > 0 then resto = Left(resto, queryPos - 1).Trim()
    while Len(resto) > 0 and Right(resto, 1) = "/"
        resto = Left(resto, Len(resto) - 1)
    end while
    if resto = "" then return ""

    barra = Instr(1, resto, "/")
    host = resto
    rota = ""
    if barra > 0 then
        host = Left(resto, barra - 1)
        rota = Mid(resto, barra)
    end if
    host = LCase(host.Trim())
    if host = "" then return ""

    if rota <> "" then
        partes = rota.Split("/")
        if partes.Count() > 0 then
            ultimo = LCase(partes[partes.Count() - 1])
            if Right(ultimo, 4) = ".txt" or Right(ultimo, 5) = ".json" or ultimo = "catalogo" or ultimo = "destaques" or ultimo = "indice" then
                partes.Pop()
            end if
        end if
        if partes.Count() > 0 and LCase(partes[partes.Count() - 1]) = "roku" then
            partes.Pop()
        end if
        novaRota = ""
        for each seg in partes
            if seg <> "" then novaRota = novaRota + "/" + seg
        end for
        rota = novaRota
    end if

    return esquema + host + rota + "/"
end function

function GetDefaultPreferences() as Object
    return {
        abrirEm: "inicio",
        zeroDelay: "equilibrado",
        audioInteligente: true,
        versaoAudio: "dub",
        proximoAutomatico: true,
        pularAutomatico: true,
        pinParental: "1010",
        ultimoCanal: "",
        urlCanais: "",
        urlFilmes: ""
    }
end function

function LoadPreferences() as Object
    reg = GetRegistry()
    raw = reg.Read("prefs")
    defaults = GetDefaultPreferences()
    if raw <> "" then
        parsed = ParseJson(raw)
        if parsed <> invalid then
            for each key in parsed
                val = parsed[key]
                lk = LCase(key)
                if val <> invalid then
                    if defaults[lk] = invalid or defaults[lk].ToStr() = "" or val.ToStr() <> "" then
                        defaults[lk] = val
                    end if
                end if
            end for
        end if
    end if
    if defaults.urlCanais <> invalid and defaults.urlCanais <> "" then
        defaults.urlCanais = NormalizarEnderecoSaimo(defaults.urlCanais)
    end if
    if defaults.urlFilmes <> invalid and defaults.urlFilmes <> "" then
        defaults.urlFilmes = NormalizarEnderecoSaimo(defaults.urlFilmes)
    end if
    return defaults
end function

sub SavePreferences(prefs as Object)
    if prefs = invalid then return
    limpo = GetDefaultPreferences()
    for each key in prefs
        val = prefs[key]
        lk = LCase(key)
        if val <> invalid then
            if limpo[lk] = invalid or limpo[lk].ToStr() = "" or val.ToStr() <> "" then
                limpo[lk] = val
            end if
        end if
    end for
    if limpo.urlCanais <> invalid and limpo.urlCanais <> "" then
        limpo.urlCanais = NormalizarEnderecoSaimo(limpo.urlCanais)
    end if
    if limpo.urlFilmes <> invalid and limpo.urlFilmes <> "" then
        limpo.urlFilmes = NormalizarEnderecoSaimo(limpo.urlFilmes)
    end if
    reg = GetRegistry()
    json = FormatJson(limpo)
    reg.Write("prefs", json)
    reg.Flush()
end sub

' ----- Progresso VOD ("Continuar Assistindo") -----

function LoadAllProgress() as Object
    reg = GetRegistry()
    raw = reg.Read(ChavePerfil("vod_progress"))
    if raw <> "" then
        parsed = ParseJson(raw)
        if parsed <> invalid then return parsed
    end if
    return {}
end function

function GetVODProgress(title as String) as Dynamic
    all = LoadAllProgress()
    if all[title] <> invalid then return all[title]
    return invalid
end function

' ----- Estatísticas pessoais (por perfil): segundos assistidos e títulos vistos -----

function EstatLer() as Object
    reg = GetRegistry()
    raw = reg.Read(ChavePerfil("estatisticas"))
    if raw <> "" then
        parsed = ParseJson(raw)
        if parsed <> invalid and parsed.vistos <> invalid then return parsed
    end if
    return { segundos: 0, vistos: {} }
end function

sub EstatGravar(e as Object)
    reg = GetRegistry()
    reg.Write(ChavePerfil("estatisticas"), FormatJson(e))
    reg.Flush()
end sub

sub EstatSomar(segundos as Integer, vistoTitulo = "" as String)
    e = EstatLer()
    if segundos > 0 then e.segundos = e.segundos + segundos
    if vistoTitulo <> "" then e.vistos[vistoTitulo] = true
    EstatGravar(e)
end sub

function EstatResumo() as String
    e = EstatLer()
    minutos = Int(e.segundos / 60)
    filmes = 0
    episodios = 0
    for each k in e.vistos
        if Instr(1, k, " · T") > 0 or Instr(1, k, "|") > 0 then
            episodios = episodios + 1
        else
            filmes = filmes + 1
        end if
    end for
    return Int(minutos / 60).ToStr() + " h " + (minutos mod 60).ToStr() + " min · " + filmes.ToStr() + " filmes · " + episodios.ToStr() + " episódios"
end function

sub SaveVODProgress(title as String, posSec as Integer, durSec as Integer, season = 0 as Integer, episode = 0 as Integer, epTitle = "" as String, url = "" as String, extra = invalid as Dynamic)
    if title = "" or durSec <= 0 then return
    all = LoadAllProgress()
    percent = Int((posSec / durSec) * 100)
    ' Estatísticas: soma o que andou desde a última gravação (teto de 2 min: salto não conta).
    anteriorEst = all[title]
    if anteriorEst <> invalid and anteriorEst.position <> invalid then
        delta = posSec - anteriorEst.position
        if delta > 0 and delta <= 120 then EstatSomar(delta)
    end if
    if percent >= 92 and durSec > 300 then
        chaveVisto = title
        if season > 0 then chaveVisto = title + " · T" + season.ToStr() + " E" + episode.ToStr()
        EstatSomar(0, chaveVisto)
    end if

    ' Se assistiu mais de 92%, marca como concluído
    if percent >= 92 then
        if all[title] <> invalid then
            all.Delete(title)
            reg = GetRegistry()
            reg.Write(ChavePerfil("vod_progress"), FormatJson(all))
            reg.Flush()
        end if
        return
    end if

    ' Capa, tipo e letra do título: o Continuar assistindo mostra a capa e
    ' reabre o título sem procurar de novo. Sem eles, mantém os já guardados.
    anterior = all[title]
    if extra = invalid then extra = {}
    poster = extra.poster
    if (poster = invalid or poster = "") and anterior <> invalid then poster = anterior.poster
    serie = extra.isSeries
    if serie = invalid and anterior <> invalid then serie = anterior.isSeries
    if serie = invalid then serie = (season > 0)
    letra = extra.letter
    if (letra = invalid or letra = "") and anterior <> invalid then letra = anterior.letter

    all[title] = {
        poster: poster,
        isSeries: serie,
        letter: letra,
        title: title,
        position: posSec,
        duration: durSec,
        percent: percent,
        season: season,
        episode: episode,
        episodeTitle: epTitle,
        url: url,
        updatedAt: CreateObject("roDateTime").AsSeconds()
    }

    reg = GetRegistry()
    reg.Write(ChavePerfil("vod_progress"), FormatJson(all))
    reg.Flush()
end sub

' ----- Favoritos -----

function LoadFavoriteChannels() as Object
    reg = GetRegistry()
    raw = reg.Read(ChavePerfil("fav_channels"))
    if raw <> "" then
        parsed = ParseJson(raw)
        if parsed <> invalid then return parsed
    end if
    return []
end function

sub ToggleFavoriteChannel(channelName as String)
    favs = LoadFavoriteChannels()
    idx = -1
    for i = 0 to favs.Count() - 1
        if favs[i] = channelName then
            idx = i
            exit for
        end if
    end for
    if idx >= 0 then
        favs.Delete(idx)
    else
        favs.Push(channelName)
    end if
    reg = GetRegistry()
    reg.Write(ChavePerfil("fav_channels"), FormatJson(favs))
    reg.Flush()
end sub

function IsChannelFavorite(channelName as String) as Boolean
    favs = LoadFavoriteChannels()
    for each f in favs
        if f = channelName then return true
    end for
    return false
end function

' ----- VOD Favoritos (Filmes e Séries) -----

function LoadFavoriteVOD() as Object
    reg = GetRegistry()
    raw = reg.Read(ChavePerfil("fav_vod"))
    if raw <> "" then
        parsed = ParseJson(raw)
        if parsed <> invalid then return parsed
    end if
    return []
end function

sub ToggleFavoriteVOD(item as Object)
    if item = invalid or item.title = invalid or item.title = "" then return
    favs = LoadFavoriteVOD()
    idx = -1
    for i = 0 to favs.Count() - 1
        if favs[i].title = item.title then
            idx = i
            exit for
        end if
    end for
    if idx >= 0 then
        favs.Delete(idx)
    else
        clean = {
            title: item.title,
            isSeries: (item.isSeries = true),
            letter: item.letter,
            poster: item.poster,
            backdrop: item.backdrop,
            year: item.year,
            genres: item.genres,
            overview: item.overview,
            category: item.category
        }
        favs.Push(clean)
    end if
    reg = GetRegistry()
    reg.Write(ChavePerfil("fav_vod"), FormatJson(favs))
    reg.Flush()
end sub

function IsVODFavorite(title as String) as Boolean
    if title = "" then return false
    favs = LoadFavoriteVOD()
    for each f in favs
        if f.title = title then return true
    end for
    return false
end function

function GetInProgressList() as Object
    all = LoadAllProgress()
    list = []
    for each key in all
        it = all[key]
        if it <> invalid and it.percent <> invalid and it.percent > 2 and it.percent < 92 then
            list.Push(it)
        end if
    end for
    return list
end function

sub RemoveInProgress(title as String)
    if title = "" then return
    all = LoadAllProgress()
    changed = false
    for each key in all
        it = all[key]
        if key = title or (it <> invalid and it.title = title) then
            all.Delete(key)
            changed = true
        end if
    end for
    if changed then
        reg = GetRegistry()
        reg.Write(ChavePerfil("vod_progress"), FormatJson(all))
        reg.Flush()
    end if
end sub

' ----- Minhas listas (só os dados de cada lista; os canais ficam no cachefs) -----
function LoadMinhasListas() as Object
    bruto = GetRegistry().Read("minhas_listas")
    if bruto <> "" then
        dados = ParseJson(bruto)
        if dados <> invalid then return dados
    end if
    return []
end function

sub SaveMinhasListas(listas as Object)
    reg = GetRegistry()
    reg.Write("minhas_listas", FormatJson(listas))
    reg.Flush()
end sub

' ====================================================================
' Perfis: cada um com os seus favoritos e onde parou; listas e ajustes são
' do aparelho todo. Contrato em SaimoPlayer/docs/perfis.md. O perfil
' principal usa as chaves de sempre; os outros, a chave com "@<id>". No Roku
' os perfis ficam só no aparelho (o Connect daqui é só controle remoto).
' ====================================================================

function PerfisAvatares() as Object
    return ["gato", "cachorro", "raposa", "urso", "panda", "coelho", "coruja", "pinguim", "sapo", "leao", "coala", "robo", "alien", "monstro", "dino", "polvo", "pintinho", "tigre", "astronauta", "abelha", "fantasma"]
end function

function PerfisEstado() as Object
    raw = GetRegistry().Read("perfis")
    e = invalid
    if raw <> invalid and raw <> "" then e = ParseJson(raw)
    if e = invalid or type(e) <> "roAssociativeArray" then e = {}
    if e.lista = invalid then e.lista = []
    if e.ativo = invalid then e.ativo = "principal"
    if e.perguntar = invalid then e.perguntar = true
    temPrincipal = false
    for each p in e.lista
        if p.id = "principal" then
            temPrincipal = true
            p.kids = false
            p.codigo = ""
        end if
    end for
    if not temPrincipal then e.lista.Unshift({ id: "principal", nome: "Principal", avatar: "gato", em: 0, kids: false, codigo: "" })
    existe = false
    for each p in e.lista
        if p.id = e.ativo then existe = true
    end for
    if not existe then e.ativo = "principal"
    return e
end function

sub PerfisGravar(e as Object)
    reg = GetRegistry()
    reg.Write("perfis", FormatJson(e))
    reg.Flush()
end sub

function PerfilAtivo() as Object
    e = PerfisEstado()
    for each p in e.lista
        if p.id = e.ativo then return p
    end for
    return e.lista[0]
end function

function KidsAtivo() as Boolean
    p = PerfilAtivo()
    return p.kids = true
end function

function ChavePerfil(nome as String) as String
    id = PerfisEstado().ativo
    if id = "principal" then return nome
    return nome + "@" + id
end function

function PerfisSha256(texto as String) as String
    ba = CreateObject("roByteArray")
    ba.FromAsciiString(texto)
    d = CreateObject("roEVPDigest")
    d.Setup("sha256")
    return LCase(d.Process(ba))
end function

function PerfisHashCodigo(id as String, codigo as String) as String
    return PerfisSha256("saimo-kids:" + id + ":" + codigo)
end function

function PerfisPedeCodigo(p as Object) as Boolean
    return p.kids = true and p.codigo <> invalid and p.codigo <> ""
end function

function PerfisConferirCodigo(p as Object, codigo as String) as Boolean
    if not PerfisPedeCodigo(p) then return true
    return PerfisHashCodigo(p.id, codigo) = p.codigo
end function

function PerfisNovoId() as String
    letras = "abcdefghijklmnopqrstuvwxyz0123456789"
    s = "p"
    for i = 1 to 9
        s = s + Mid(letras, Rnd(36), 1)
    end for
    return s
end function

function PerfisAgoraMs() as Double
    dt = CreateObject("roDateTime")
    return dt.AsSeconds() * 1000#
end function

' kidsCodigo: "" = perfil comum; 4 dígitos = Kids com esse código.
function PerfisCriar(nome as String, avatar as String, kidsCodigo as String) as Boolean
    e = PerfisEstado()
    nome = Left(nome.Trim(), 20)
    if nome = "" or e.lista.Count() >= 10 then return false
    id = PerfisNovoId()
    p = { id: id, nome: nome, avatar: avatar, em: PerfisAgoraMs(), kids: false, codigo: "" }
    if Len(kidsCodigo) = 4 then
        p.kids = true
        p.codigo = PerfisHashCodigo(id, kidsCodigo)
    end if
    e.lista.Push(p)
    PerfisGravar(e)
    return true
end function

' kidsCodigo: invalid mantém; "" desliga o Kids; 4 dígitos liga ou troca o código.
sub PerfisEditar(id as String, nome as String, avatar as String, kidsCodigo as Dynamic)
    e = PerfisEstado()
    nome = Left(nome.Trim(), 20)
    if nome = "" then return
    for each p in e.lista
        if p.id = id then
            p.nome = nome
            p.avatar = avatar
            p.em = PerfisAgoraMs()
            if kidsCodigo <> invalid then
                if kidsCodigo = "" then
                    p.kids = false
                    p.codigo = ""
                else if id <> "principal" and Len(kidsCodigo) = 4 then
                    p.kids = true
                    p.codigo = PerfisHashCodigo(id, kidsCodigo)
                end if
            end if
        end if
    end for
    PerfisGravar(e)
end sub

sub PerfisApagar(id as String)
    if id = "principal" then return
    e = PerfisEstado()
    nova = []
    for each p in e.lista
        if p.id <> id then nova.Push(p)
    end for
    e.lista = nova
    if e.ativo = id then e.ativo = "principal"
    PerfisGravar(e)
    reg = GetRegistry()
    for each k in ["vod_progress", "fav_channels", "fav_vod"]
        reg.Delete(k + "@" + id)
    end for
    reg.Flush()
end sub

sub PerfisEntrar(id as String)
    e = PerfisEstado()
    e.ativo = id
    PerfisGravar(e)
end sub

' Controle parental: no Roku o conteúdo adulto fica sempre de fora; a senha
' (padrão 0000) só existe para manter o mesmo controle dos outros apps.
function ParentalConferir(senha as String) as Boolean
    if KidsAtivo() then return false
    h = GetRegistry().Read("parental_senha")
    if h = invalid or h = "" then return senha = "0000"
    return PerfisSha256("saimo-parental:" + senha) = h
end function

function ParentalTrocar(atual as String, nova as String) as Boolean
    if not ParentalConferir(atual) or Len(nova) <> 4 then return false
    reg = GetRegistry()
    reg.Write("parental_senha", PerfisSha256("saimo-parental:" + nova))
    reg.Flush()
    return true
end function
