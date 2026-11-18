' ====================================================================
' Saimo TV - AddonsScreen (BrightScript)
' Gerenciamento nativo de Addons Stremio + Debrid + QR Code LAN :8999
' ====================================================================

sub init()
    m.qrGroup = m.top.findNode("qrGroup")
    m.qrUrlLabel = m.top.findNode("qrUrlLabel")
    m.debridSummaryLabel = m.top.findNode("debridSummaryLabel")
    m.lblSecao = m.top.findNode("lblSecao")
    m.aviso = m.top.findNode("aviso")
    m.painelLista = m.top.findNode("painelLista")
    m.lista = m.top.findNode("lista")
    m.painelTeclado = m.top.findNode("painelTeclado")
    m.tituloCampo = m.top.findNode("tituloCampo")
    m.subtituloCampo = m.top.findNode("subtituloCampo")
    m.teclado = m.top.findNode("teclado")
    ' O campo do teclado: caixa branca e texto escuro. O padrão do Roku deixava,
    ' em alguns aparelhos, letra branca sobre a caixa clara (não se via o que se digitava).
    if m.teclado.textEditBox <> invalid then
        m.teclado.textEditBox.backgroundUri = "pkg:/images/p_branca.9.png"
        m.teclado.textEditBox.textColor = "0x11161EFF"
        m.teclado.textEditBox.hintTextColor = "0x6B7280FF"
    end if
    m.botoes = m.top.findNode("botoes")

    m.modo = "main" ' main | addonActions | debrid | debridProvider | addUrl | debridKey
    m.addons = []
    m.selectedAddonIdx = -1
    m.selectedProviderKey = ""
    m.ocupado = false
    m.manageTask = invalid
    m.lastQrUrl = ""

    opcoesBotoes = CreateObject("roSGNode", "ContentNode")
    for each txt in ["Salvar", "Limpar", "Cancelar"]
        bNode = opcoesBotoes.CreateChild("ContentNode")
        bNode.title = txt
    end for
    m.botoes.content = opcoesBotoes
    m.botoes.observeField("itemSelected", "onBotaoTeclado")
    m.lista.observeField("itemSelected", "onItemSelected")
    m.top.observeField("focusedChild", "onFocusChange")

    refresh()
end sub

sub onFocusChange()
    if m.top.isInFocusChain() then
        updateQrAndSummary()
        if m.painelTeclado.visible then
            if not m.teclado.isInFocusChain() and not m.botoes.isInFocusChain() then
                m.teclado.setFocus(true)
            end if
        else if not m.lista.isInFocusChain() then
            m.lista.setFocus(true)
        end if
    end if
end sub

sub refresh()
    updateQrAndSummary()
    if m.modo = "debrid" then
        showDebridMenu()
    else if m.modo = "debridProvider" then
        showDebridProviderMenu()
    else if m.modo = "addonActions" then
        showAddonActionsMenu()
    else if not m.painelTeclado.visible then
        showMainList()
    end if
end sub

sub updateQrAndSummary()
    ip = GetLocalDeviceIp()
    url = "http://IP-DA-TV:8999/addons"
    if ip <> "" then
        url = "http://" + ip + ":8999/addons"
        m.qrUrlLabel.text = "Celular/PC na mesma rede: " + url
        if url <> m.lastQrUrl then
            m.lastQrUrl = url
            while m.qrGroup.getChildCount() > 0
                m.qrGroup.removeChildIndex(0)
            end while
            QrRenderToGroup(m.qrGroup, url, 280)
        end if
    else
        m.qrUrlLabel.text = "Conecte a TV ao Wi-Fi/cabo para ver o endereço LAN (:8999/addons)"
    end if

    ativos = GetEnabledDebridProviders()
    if ativos.Count() > 0 then
        nomes = []
        for each p in ativos
            nomes.Push(DebridProviderDisplayName(p))
        end for
        m.debridSummaryLabel.text = "Debrid ativo: " + nomes.Join(", ")
    else
        m.debridSummaryLabel.text = "Debrid: nenhum provedor configurado"
    end if
end sub

sub preencherLista(rows as Object, keepIdx = -1 as Integer)
    raiz = CreateObject("roSGNode", "ContentNode")
    for each r in rows
        no = raiz.CreateChild("ContentNode")
        no.title = r.titulo
        no.description = r.detalhe
    end for
    m.lista.content = raiz
    if keepIdx >= 0 and keepIdx < rows.Count() then
        m.lista.jumpToItem = keepIdx
    else
        m.lista.jumpToItem = 0
    end if
end sub

sub showMainList()
    m.modo = "main"
    m.lblSecao.text = "GERENCIAR ADDONS"
    m.addons = LoadAddons()
    rows = []

    rows.Push({
        titulo: "+ Adicionar Addon Stremio",
        detalhe: "Digite https://.../manifest.json ou stremio://... (ou envie pelo QR Code)"
    })

    ativos = GetEnabledDebridProviders()
    debridDesc = "Configure TorBox, Real-Debrid, AllDebrid ou Premiumize"
    if ativos.Count() > 0 then
        debridDesc = "Ativos: " + ativos.Join(", ") + " · OK para gerenciar"
    end if
    rows.Push({
        titulo: "Configurar Debrid",
        detalhe: debridDesc
    })

    for each a in m.addons
        estado = "Ativo"
        if a.enabled <> true then estado = "Desativado"
        tiposStr = ""
        if a.types <> invalid and a.types.Count() > 0 then tiposStr = a.types.Join(", ")
        resStr = ""
        if a.resources <> invalid and a.resources.Count() > 0 then
            resNames = []
            for each r in a.resources
                if Type(r) = "roAssociativeArray" and r.name <> invalid then
                    resNames.Push(r.name)
                else if r <> invalid then
                    resNames.Push(r.ToStr())
                end if
            end for
            resStr = resNames.Join(", ")
        end if
        det = estado
        if tiposStr <> "" then det = det + " · " + tiposStr
        if resStr <> "" then det = det + " · [" + resStr + "]"
        rows.Push({
            titulo: a.name,
            detalhe: det
        })
    end for

    preencherLista(rows)
    m.painelTeclado.visible = false
    m.painelLista.visible = true
    if m.top.isInFocusChain() then m.lista.setFocus(true)
end sub

sub showAddonActionsMenu()
    m.addons = LoadAddons()
    if m.selectedAddonIdx < 0 or m.selectedAddonIdx >= m.addons.Count() then
        showMainList()
        return
    end if
    m.modo = "addonActions"
    a = m.addons[m.selectedAddonIdx]
    m.lblSecao.text = "ADDON: " + UCase(a.name)

    toggleLabel = "Desativar addon"
    if a.enabled <> true then toggleLabel = "Ativar addon"

    rows = [
        { titulo: toggleLabel, detalhe: a.url },
        { titulo: "Mover para cima", detalhe: "Aumentar prioridade deste addon nas buscas e fontes" },
        { titulo: "Mover para baixo", detalhe: "Diminuir prioridade deste addon" },
        { titulo: "Revalidar manifesto", detalhe: "Baixar novamente manifest.json e atualizar catálogo/recursos" },
        { titulo: "Remover addon", detalhe: "Excluir da TV e limpar cache deste manifesto" },
        { titulo: "Voltar", detalhe: "Retornar para a lista de addons" }
    ]
    preencherLista(rows)
    if m.top.isInFocusChain() then m.lista.setFocus(true)
end sub

sub showDebridMenu()
    m.modo = "debrid"
    m.lblSecao.text = "PROVEDORES DEBRID"
    cfg = LoadDebridConfig()

    rows = []
    keys = ["torbox", "realDebrid", "allDebrid", "premiumize"]
    for each k in keys
        p = cfg[k]
        nome = DebridProviderDisplayName(k)
        status = "Não configurado"
        if p <> invalid and p.apiKey <> invalid and p.apiKey.Trim() <> "" then
            mascara = DebridMaskKey(p.apiKey)
            if p.enabled = true then
                status = "Ativo · Chave " + mascara
            else
                status = "Desativado · Chave " + mascara
            end if
        end if
        rows.Push({ titulo: nome, detalhe: status })
    end for

    syncDesc = "Desativado · Chaves ficam somente nesta TV (Recomendado)"
    if cfg.sincronizarConnect = true then syncDesc = "Ativado · Cuidado ao expor na rede local"
    rows.Push({ titulo: "Sincronizar chaves com Saimo Connect", detalhe: syncDesc })
    rows.Push({ titulo: "Voltar", detalhe: "Retornar para Addons" })

    preencherLista(rows)
    if m.top.isInFocusChain() then m.lista.setFocus(true)
end sub

sub showDebridProviderMenu()
    if m.selectedProviderKey = "" then
        showDebridMenu()
        return
    end if
    m.modo = "debridProvider"
    cfg = LoadDebridConfig()
    p = cfg[m.selectedProviderKey]
    nome = DebridProviderDisplayName(m.selectedProviderKey)
    m.lblSecao.text = "DEBRID: " + UCase(nome)

    hasKey = (p <> invalid and p.apiKey <> invalid and p.apiKey.Trim() <> "")
    stateTxt = "Sem API Key salva"
    if hasKey then
        if p.enabled = true then
            stateTxt = "Ativo · Chave " + DebridMaskKey(p.apiKey)
        else
            stateTxt = "Desativado · Chave " + DebridMaskKey(p.apiKey)
        end if
    end if

    toggleTxt = "Ativar provedor"
    if p <> invalid and p.enabled = true then toggleTxt = "Desativar provedor"

    rows = [
        { titulo: "Definir / Alterar API Key", detalhe: stateTxt },
        { titulo: toggleTxt, detalhe: "Habilita ou pausa resolução via " + nome },
        { titulo: "Remover chave", detalhe: "Apaga a API Key de " + nome + " desta TV" },
        { titulo: "Voltar", detalhe: "Retornar aos provedores Debrid" }
    ]
    preencherLista(rows)
    if m.top.isInFocusChain() then m.lista.setFocus(true)
end sub

sub onItemSelected()
    if m.ocupado then return
    idx = m.lista.itemSelected

    if m.modo = "main" then
        if idx = 0 then
            abrirEditor("addUrl", "Adicionar Addon Stremio", "Cole ou digite a URL https://.../manifest.json ou stremio://...", "")
        else if idx = 1 then
            m.aviso.text = ""
            showDebridMenu()
        else
            addonIdx = idx - 2
            if addonIdx >= 0 and addonIdx < m.addons.Count() then
                m.aviso.text = ""
                m.selectedAddonIdx = addonIdx
                showAddonActionsMenu()
            end if
        end if
    else if m.modo = "addonActions" then
        if idx = 0 then
            runManageTask("toggle", "", m.selectedAddonIdx)
        else if idx = 1 then
            runManageTask("moveUp", "", m.selectedAddonIdx)
        else if idx = 2 then
            runManageTask("moveDown", "", m.selectedAddonIdx)
        else if idx = 3 then
            runManageTask("revalidate", "", m.selectedAddonIdx)
        else if idx = 4 then
            runManageTask("remove", "", m.selectedAddonIdx)
        else
            showMainList()
        end if
    else if m.modo = "debrid" then
        keys = ["torbox", "realDebrid", "allDebrid", "premiumize"]
        if idx >= 0 and idx <= 3 then
            m.selectedProviderKey = keys[idx]
            showDebridProviderMenu()
        else if idx = 4 then
            cfg = LoadDebridConfig()
            cfg.sincronizarConnect = not (cfg.sincronizarConnect = true)
            SaveDebridConfig(cfg)
            m.top.addonsChanged = true
            updateQrAndSummary()
            showDebridMenu()
        else
            showMainList()
        end if
    else if m.modo = "debridProvider" then
        cfg = LoadDebridConfig()
        p = cfg[m.selectedProviderKey]
        curKey = ""
        if p <> invalid and p.apiKey <> invalid then curKey = p.apiKey
        if idx = 0 then
            nome = DebridProviderDisplayName(m.selectedProviderKey)
            abrirEditor("debridKey", "API Key — " + nome, "Dica: pelo navegador em http://<ip>:8999/addons é muito mais rápido!", curKey)
        else if idx = 1 then
            if curKey = "" then
                m.aviso.text = "Defina uma API Key primeiro."
            else
                p.enabled = not (p.enabled = true)
                cfg[m.selectedProviderKey] = p
                SaveDebridConfig(cfg)
                m.aviso.text = "Configuração Debrid atualizada."
                m.top.addonsChanged = true
                updateQrAndSummary()
                showDebridProviderMenu()
            end if
        else if idx = 2 then
            cfg[m.selectedProviderKey] = { apiKey: "", enabled: false }
            SaveDebridConfig(cfg)
            m.aviso.text = "Chave removida."
            m.top.addonsChanged = true
            updateQrAndSummary()
            showDebridProviderMenu()
        else
            showDebridMenu()
        end if
    end if
end sub

sub runManageTask(acao as String, urlVal as String, idxVal as Integer)
    if m.manageTask <> invalid then
        m.manageTask.unobserveField("result")
        m.manageTask.control = "stop"
        m.manageTask = invalid
    end if
    m.ocupado = true
    if acao = "add" or acao = "revalidate" then
        m.aviso.text = "Validando manifesto (/manifest.json)..."
    else
        m.aviso.text = "Atualizando addons..."
    end if

    m.manageTask = CreateObject("roSGNode", "AddonManageTask")
    m.manageTask.action = acao
    m.manageTask.url = urlVal
    m.manageTask.index = idxVal
    m.manageTask.observeField("result", "onManageResult")
    m.manageTask.control = "run"
end sub

sub onManageResult(evt as Object)
    res = evt.getData()
    if m.manageTask <> invalid then
        m.manageTask.unobserveField("result")
        m.manageTask = invalid
    end if
    m.ocupado = false

    if res <> invalid and res.ok = true then
        m.aviso.color = "#4FE3D0"
        m.aviso.text = "Addons atualizados com sucesso!"
        m.top.addonsChanged = true
        showMainList()
    else
        errMsg = "Não foi possível atualizar o addon."
        if res <> invalid and res.error <> invalid and res.error <> "" then errMsg = res.error
        m.aviso.color = "#FFB454"
        m.aviso.text = errMsg
        if m.modo = "addonActions" then
            showAddonActionsMenu()
        else
            showMainList()
        end if
    end if
end sub

sub abrirEditor(modoEditor as String, titulo as String, subtitulo as String, valorInicial as String)
    m.modo = modoEditor
    m.tituloCampo.text = titulo
    m.subtituloCampo.text = subtitulo
    m.teclado.text = valorInicial
    if m.teclado.textEditBox <> invalid then m.teclado.textEditBox.text = valorInicial
    m.botoes.jumpToItem = 0
    m.painelLista.visible = false
    m.lblSecao.visible = false
    m.painelTeclado.visible = true
    m.teclado.setFocus(true)
end sub

sub fecharEditor()
    m.painelTeclado.visible = false
    m.painelLista.visible = true
    m.lblSecao.visible = true
    if m.modo = "debridKey" then
        showDebridProviderMenu()
    else
        showMainList()
    end if
end sub

function lerTextoTeclado() as String
    t = ""
    if m.teclado <> invalid and m.teclado.text <> invalid then t = m.teclado.text
    if t = "" and m.teclado <> invalid and m.teclado.textEditBox <> invalid and m.teclado.textEditBox.text <> invalid then
        t = m.teclado.textEditBox.text
    end if
    return t.Trim()
end function

sub salvarCampoEditor()
    valor = lerTextoTeclado()
    if m.modo = "addUrl" then
        m.painelTeclado.visible = false
        m.painelLista.visible = true
        m.lblSecao.visible = true
        m.modo = "main"
        if valor = "" then
            m.aviso.color = "#FFB454"
            m.aviso.text = "Digite uma URL válida do addon Stremio."
            showMainList()
            return
        end if
        runManageTask("add", valor, -1)
    else if m.modo = "debridKey" then
        cfg = LoadDebridConfig()
        if m.selectedProviderKey <> "" then
            cfg[m.selectedProviderKey] = {
                apiKey: valor,
                enabled: (valor <> "")
            }
            SaveDebridConfig(cfg)
            m.aviso.color = "#4FE3D0"
            if valor <> "" then
                m.aviso.text = "API Key de " + DebridProviderDisplayName(m.selectedProviderKey) + " salva!"
            else
                m.aviso.text = "Chave removida."
            end if
            m.top.addonsChanged = true
            updateQrAndSummary()
        end if
        fecharEditor()
    end if
end sub

sub onBotaoTeclado()
    idx = m.botoes.itemSelected
    if idx = 0 then
        salvarCampoEditor()
    else if idx = 1 then
        m.teclado.text = ""
        if m.teclado.textEditBox <> invalid then m.teclado.textEditBox.text = ""
        m.teclado.setFocus(true)
    else
        fecharEditor()
    end if
end sub

sub onTextoRecebido()
    txt = m.top.textoRecebido
    if txt = invalid or txt.Trim() = "" then return
    if not m.painelTeclado.visible then
        if m.modo = "debridProvider" and m.selectedProviderKey <> "" then
            nome = DebridProviderDisplayName(m.selectedProviderKey)
            abrirEditor("debridKey", "API Key — " + nome, "Texto recebido via Saimo Connect", txt.Trim())
        else
            abrirEditor("addUrl", "Adicionar Addon Stremio", "URL recebida via Saimo Connect", txt.Trim())
        end if
    end if
    if m.painelTeclado.visible then
        m.teclado.text = txt.Trim()
        if m.teclado.textEditBox <> invalid then m.teclado.textEditBox.text = txt.Trim()
        m.botoes.jumpToItem = 0
        m.botoes.setFocus(true)
    end if
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.painelTeclado.visible then
        if key = "back" then
            fecharEditor()
            return true
        else if key = "play" then
            salvarCampoEditor()
            return true
        else if key = "down" and m.teclado.isInFocusChain() then
            m.botoes.jumpToItem = 0
            m.botoes.setFocus(true)
            return true
        else if key = "up" and m.botoes.isInFocusChain() then
            m.teclado.setFocus(true)
            return true
        end if
        return true
    end if

    if key = "back" then
        if m.modo = "addonActions" then
            showMainList()
            return true
        else if m.modo = "debridProvider" then
            showDebridMenu()
            return true
        else if m.modo = "debrid" then
            showMainList()
            return true
        end if
        return false
    end if

    if key = "up" and m.lista.itemFocused <= 0 then
        m.top.focusUpRequested = true
        return true
    end if

    return false
end function

sub cleanUp()
    if m.manageTask <> invalid then
        m.manageTask.unobserveField("result")
        m.manageTask.control = "stop"
        m.manageTask = invalid
    end if
    if m.painelTeclado <> invalid and m.painelTeclado.visible then
        m.painelTeclado.visible = false
        m.painelLista.visible = true
        if m.lblSecao <> invalid then m.lblSecao.visible = true
    end if
end sub
