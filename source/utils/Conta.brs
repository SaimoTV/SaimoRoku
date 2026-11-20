' ====================================================================
' Conta Saimo (opcional) no Roku: entra pelo celular (QR) ou com e-mail e
' senha e sincroniza perfis, onde parou e favoritos pela internet. Sem
' conta, nada muda. O que viaja é o pacote do Saimo Connect ({"t":"dados"},
' SaimoPlayer/docs/perfis.md). Listas e addons não vão nem voltam daqui (o
' servidor guarda os dos outros aparelhos sem mexer). A rede roda no
' ContaTask; estas funções só leem e gravam o registro.
' ====================================================================

function ContaApi() as String
    ' Servidor de teste: grave "conta_api" no registro (ex.: http://192.168.0.10:8787).
    api = GetRegistry().Read("conta_api")
    if api = invalid or api = "" then api = "https://conta.saimo-tv.com.br"
    return api
end function

function ContaSessao() as Object
    raw = GetRegistry().Read("conta")
    s = invalid
    if raw <> invalid and raw <> "" then s = ParseJson(raw)
    if s = invalid or type(s) <> "roAssociativeArray" then s = {}
    if s.token = invalid then s.token = ""
    if s.email = invalid then s.email = ""
    if s.sincronizadaEm = invalid then s.sincronizadaEm = 0
    return s
end function

sub ContaGravarSessao(s as Object)
    reg = GetRegistry()
    if s = invalid or s.token = invalid or s.token = "" then
        reg.Delete("conta")
    else
        reg.Write("conta", FormatJson(s))
    end if
    reg.Flush()
end sub

function ContaLogado() as Boolean
    return ContaSessao().token <> ""
end function

function ContaResumo() as String
    s = ContaSessao()
    if s.token = "" then return "Entrar pelo celular (QR) ou com e-mail e senha"
    quando = "ainda não sincronizou"
    if s.sincronizadaEm > 0 then
        minutos = Int((CreateObject("roDateTime").AsSeconds() - s.sincronizadaEm) / 60)
        if minutos < 1 then
            quando = "sincronizado agora"
        else if minutos < 60 then
            quando = "sincronizado há " + minutos.ToStr() + " min"
        else if minutos < 1440 then
            quando = "sincronizado há " + Int(minutos / 60).ToStr() + " h"
        else
            quando = "sincronizado há " + Int(minutos / 1440).ToStr() + " d"
        end if
    end if
    return s.email + " · " + quando
end function

' A chave de um dado de perfil para um perfil qualquer (não só o ativo).
function ContaChave(nome as String, id as String) as String
    if id = "principal" then return nome
    return nome + "@" + id
end function

function ContaLerJson(chave as String, padrao as Dynamic) as Dynamic
    raw = GetRegistry().Read(chave)
    if raw = invalid or raw = "" then return padrao
    v = ParseJson(raw)
    if v = invalid then return padrao
    return v
end function

function ContaTexto(v as Dynamic) as String
    if v = invalid then return ""
    if GetInterface(v, "ifString") <> invalid then return v
    return ""
end function

function ContaNumero(v as Dynamic) as Double
    if v = invalid then return 0#
    t = type(v)
    ' Converte qualquer número (Integer, LongInteger, Float) em Double.
    if t = "roInt" or t = "Integer" or t = "roFloat" or t = "Float" or t = "roDouble" or t = "Double" or t = "LongInteger" or t = "roLongInteger" then return v + 0#
    return 0#
end function

' Onde parou e favoritos de um perfil, no formato do pacote.
function ContaDadosDoPerfil(id as String) as Object
    remo = RemLer(id)
    progresso = []
    tudo = ContaLerJson(ContaChave("vod_progress", id), {})
    for each titulo in tudo
        it = tudo[titulo]
        if it <> invalid and ContaNumero(it.position) > 0 and ContaNumero(it.duration) > 0 then
            temporada = Int(ContaNumero(it.season))
            episodio = Int(ContaNumero(it.episode))
            serie = (it.isSeries = true) or temporada > 0
            if not serie or (temporada > 0 and episodio > 0) then
                tipo = "f"
                if serie then tipo = "s"
                if not RemTituloRemovido(remo.prog, tipo, titulo, ContaTexto(it.ano), ContaNumero(it.updatedAt) * 1000#) then
                    progresso.Push({
                        tipo: tipo, titulo: titulo, ano: ContaTexto(it.ano), letra: ContaTexto(it.letter),
                        temporada: temporada, episodio: episodio,
                        pos: ContaNumero(it.position) * 1000#, dur: ContaNumero(it.duration) * 1000#,
                        em: ContaNumero(it.updatedAt) * 1000#
                    })
                end if
            end if
        end if
    end for
    favTitulos = []
    for each f in ContaLerJson(ContaChave("fav_vod", id), [])
        if f <> invalid and ContaTexto(f.title) <> "" then
            tipo = "f"
            if f.isSeries = true then tipo = "s"
            ft = { tipo: tipo, titulo: f.title, ano: ContaTexto(f.year), letra: ContaTexto(f.letter) }
            emFav = remo.favEm[tipo + "|" + f.title + "|" + ContaTexto(f.year)]
            if emFav <> invalid then ft.em = emFav
            favTitulos.Push(ft)
        end if
    end for
    favCanais = []
    for each n in ContaLerJson(ContaChave("fav_channels", id), [])
        if ContaTexto(n) <> "" then favCanais.Push(n)
    end for
    return { progresso: progresso, favTitulos: favTitulos, favCanais: favCanais, remo: remo }
end function

function ContaPacote() as Object
    e = PerfisEstado()
    perfis = []
    for each p in e.lista
        d = ContaDadosDoPerfil(p.id)
        o = { id: p.id, nome: p.nome, avatar: p.avatar, em: ContaNumero(p.em), progresso: d.progresso, favTitulos: d.favTitulos, favCanais: d.favCanais }
        ' Remoções: o que foi tirado aqui não volta pela união.
        if d.remo.prog.Count() > 0 then o.progressoRemovido = d.remo.prog
        if d.remo.fav.Count() > 0 then o.favTitulosRemovidos = d.remo.fav
        if d.remo.canal.Count() > 0 then o.favCanaisRemovidos = d.remo.canal
        if d.remo.canalEm.Count() > 0 then o.favCanaisEm = d.remo.canalEm
        if p.kids = true then
            o.kids = true
            o.codigo = ContaTexto(p.codigo)
        end if
        perfis.Push(o)
    end for
    ' Os campos de sempre (apps sem perfis) levam o principal. Lidos de novo:
    ' o FormatJson recusa a mesma lista em dois lugares do pacote.
    principal = ContaDadosDoPerfil("principal")
    return {
        t: "dados", progresso: principal.progresso, favTitulos: principal.favTitulos, favCanais: principal.favCanais,
        perfis: perfis, perfisRemovidos: []
    }
end function

' Junta progresso e favoritos que vieram da conta aos de um perfil daqui.
sub ContaJuntarNoPerfil(id as String, chegou as Object)
    reg = GetRegistry()
    ' Remoções que vieram de fora: juntam às daqui e tiram o que entrou antes delas.
    remo = RemLer(id)
    remo.prog = RemJuntarLista("prog", remo.prog, chegou.progressoRemovido)
    remo.fav = RemJuntarLista("fav", remo.fav, chegou.favTitulosRemovidos)
    remo.canal = RemJuntarLista("canal", remo.canal, chegou.favCanaisRemovidos)
    if chegou.favCanaisEm <> invalid and type(chegou.favCanaisEm) = "roAssociativeArray" then
        for each n in chegou.favCanaisEm
            if ContaNumero(chegou.favCanaisEm[n]) > ContaNumero(remo.canalEm[n]) then remo.canalEm[n] = ContaNumero(chegou.favCanaisEm[n])
        end for
    end if
    if chegou.favTitulos <> invalid then
        for each f in chegou.favTitulos
            if ContaNumero(f.em) > 0 then
                tf = "f"
                if f.tipo = "s" then tf = "s"
                kf = tf + "|" + ContaTexto(f.titulo) + "|" + ContaTexto(f.ano)
                if ContaNumero(f.em) > ContaNumero(remo.favEm[kf]) then remo.favEm[kf] = ContaNumero(f.em)
            end if
        end for
    end if
    RemGravar(id, remo)
    chaveP = ContaChave("vod_progress", id)
    tudoP = ContaLerJson(chaveP, {})
    tirou = false
    for each k in tudoP
        it = tudoP[k]
        if it <> invalid then
            tp = "f"
            if it.isSeries = true then tp = "s"
            if RemTituloRemovido(remo.prog, tp, ContaTexto(it.title), ContaTexto(it.ano), ContaNumero(it.updatedAt) * 1000#) then
                tudoP.Delete(k)
                tirou = true
            end if
        end if
    end for
    if tirou then reg.Write(chaveP, FormatJson(tudoP))
    chaveF = ContaChave("fav_vod", id)
    favsF = ContaLerJson(chaveF, [])
    ficaF = []
    for each x in favsF
        tx = "f"
        if x.isSeries = true then tx = "s"
        kx = tx + "|" + ContaTexto(x.title) + "|" + ContaTexto(x.year)
        if not RemTituloRemovido(remo.fav, tx, ContaTexto(x.title), ContaTexto(x.year), ContaNumero(remo.favEm[kx])) then ficaF.Push(x)
    end for
    if ficaF.Count() <> favsF.Count() then reg.Write(chaveF, FormatJson(ficaF))
    chaveC = ContaChave("fav_channels", id)
    favsC = ContaLerJson(chaveC, [])
    ficaC = []
    for each n in favsC
        if not RemCanalRemovido(remo, ContaTexto(n)) then ficaC.Push(n)
    end for
    if ficaC.Count() <> favsC.Count() then reg.Write(chaveC, FormatJson(ficaC))
    if chegou.progresso <> invalid then
        chave = ContaChave("vod_progress", id)
        tudo = ContaLerJson(chave, {})
        mudou = false
        for each p in chegou.progresso
            titulo = ContaTexto(p.titulo)
            posSeg = ContaNumero(p.pos) / 1000
            durSeg = ContaNumero(p.dur) / 1000
            if titulo <> "" and posSeg > 0 and durSeg > 0 and posSeg / durSeg < 0.92 then
                serie = (p.tipo = "s")
                temporada = Int(ContaNumero(p.temporada))
                episodio = Int(ContaNumero(p.episodio))
                tpp = "f"
                if serie then tpp = "s"
                if RemTituloRemovido(remo.prog, tpp, titulo, ContaTexto(p.ano), ContaNumero(p.em)) then temporada = -1
                if temporada >= 0 and (not serie or (temporada > 0 and episodio > 0)) then
                    em = ContaNumero(p.em) / 1000
                    atual = tudo[titulo]
                    if atual = invalid or ContaNumero(atual.updatedAt) < em then
                        novo = {
                            title: titulo, isSeries: serie, letter: ContaTexto(p.letra), ano: ContaTexto(p.ano),
                            position: Int(posSeg), duration: Int(durSeg), percent: Int(posSeg / durSeg * 100),
                            season: temporada, episode: episodio, episodeTitle: "", url: "", updatedAt: Int(em)
                        }
                        if atual <> invalid then novo.poster = atual.poster
                        tudo[titulo] = novo
                        mudou = true
                    end if
                end if
            end if
        end for
        if mudou then reg.Write(chave, FormatJson(tudo))
    end if
    if chegou.favTitulos <> invalid then
        chave = ContaChave("fav_vod", id)
        favs = ContaLerJson(chave, [])
        mudou = false
        for each f in chegou.favTitulos
            titulo = ContaTexto(f.titulo)
            tff = "f"
            if f.tipo = "s" then tff = "s"
            if titulo <> "" and RemTituloRemovido(remo.fav, tff, titulo, ContaTexto(f.ano), ContaNumero(f.em)) then titulo = ""
            if titulo <> "" then
                tem = false
                for each x in favs
                    if x.title = titulo then tem = true
                end for
                if not tem then
                    favs.Push({ title: titulo, isSeries: (f.tipo = "s"), letter: ContaTexto(f.letra), year: ContaTexto(f.ano) })
                    mudou = true
                end if
            end if
        end for
        if mudou then reg.Write(chave, FormatJson(favs))
    end if
    if chegou.favCanais <> invalid then
        chave = ContaChave("fav_channels", id)
        favs = ContaLerJson(chave, [])
        mudou = false
        for each n in chegou.favCanais
            nome = ContaTexto(n)
            if nome <> "" and RemCanalRemovido(remo, nome) then nome = ""
            if nome <> "" then
                tem = false
                for each x in favs
                    if x = nome then tem = true
                end for
                if not tem then
                    favs.Push(nome)
                    mudou = true
                end if
            end if
        end for
        if mudou then reg.Write(chave, FormatJson(favs))
    end if
    reg.Flush()
end sub

' Junta o pacote da conta ao que o Roku tem (regras de SaimoPlayer/docs/perfis.md).
sub ContaAplicar(pacote as Object)
    if pacote = invalid or type(pacote) <> "roAssociativeArray" then return
    if pacote.perfis = invalid then
        ContaJuntarNoPerfil("principal", pacote)
        return
    end if
    e = PerfisEstado()
    reg = GetRegistry()
    ' Remoções mais novas que o perfil daqui apagam o perfil e os dados dele.
    if pacote.perfisRemovidos <> invalid then
        for each r in pacote.perfisRemovidos
            rid = ContaTexto(r.id)
            if rid <> "" and rid <> "principal" then
                nova = []
                for each p in e.lista
                    if p.id = rid and ContaNumero(p.em) < ContaNumero(r.em) then
                        for each k in ["vod_progress", "fav_channels", "fav_vod"]
                            reg.Delete(k + "@" + rid)
                        end for
                        if e.ativo = rid then e.ativo = "principal"
                    else
                        nova.Push(p)
                    end if
                end for
                e.lista = nova
            end if
        end for
    end if
    existem = {}
    for each o in pacote.perfis
        oid = ContaTexto(o.id)
        if oid <> "" then
            removido = false
            if pacote.perfisRemovidos <> invalid then
                for each r in pacote.perfisRemovidos
                    if r.id = oid and ContaNumero(r.em) >= ContaNumero(o.em) then removido = true
                end for
            end if
            if not removido then
                achado = invalid
                for each p in e.lista
                    if p.id = oid then achado = p
                end for
                nome = Left(ContaTexto(o.nome).Trim(), 20)
                if nome = "" then nome = "Perfil"
                avatar = ContaTexto(o.avatar)
                if avatar = "" then avatar = "gato"
                kids = (o.kids = true and oid <> "principal")
                codigo = ""
                if kids then codigo = ContaTexto(o.codigo)
                if achado = invalid then
                    if e.lista.Count() < 10 then
                        e.lista.Push({ id: oid, nome: nome, avatar: avatar, em: ContaNumero(o.em), kids: kids, codigo: codigo })
                        existem[oid] = true
                    end if
                else
                    existem[oid] = true
                    if ContaNumero(o.em) > ContaNumero(achado.em) then
                        achado.nome = nome
                        achado.avatar = avatar
                        achado.em = ContaNumero(o.em)
                        achado.kids = kids
                        achado.codigo = codigo
                    end if
                end if
            end if
        end if
    end for
    PerfisGravar(e)
    for each o in pacote.perfis
        if existem[ContaTexto(o.id)] = true then ContaJuntarNoPerfil(o.id, o)
    end for
end sub
