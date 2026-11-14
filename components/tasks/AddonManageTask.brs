' ====================================================================
' Saimo TV - AddonManageTask (BrightScript)
' Executa validação de manifest.json, adição, toggle, reordenação,
' remoção e sincronização de cache de manifestos fora da thread de UI.
' ====================================================================

sub init()
    m.top.functionName = "executar"
end sub

sub executar()
    acao = LCase(m.top.action.Trim())
    res = { ok: false, error: "Ação inválida.", addons: LoadAddons() }

    if acao = "add" then
        res = AddOrUpdateAddon(m.top.url)
    else if acao = "toggle" then
        res = ToggleAddonAtIndex(m.top.index)
    else if acao = "moveup" then
        res = MoveAddonAtIndex(m.top.index, -1)
    else if acao = "movedown" then
        res = MoveAddonAtIndex(m.top.index, 1)
    else if acao = "remove" then
        res = RemoveAddonAtIndex(m.top.index)
    else if acao = "revalidate" then
        addons = LoadAddons()
        idx = m.top.index
        if idx >= 0 and idx < addons.Count() then
            res = AddOrUpdateAddon(addons[idx].url)
        end if
    else if acao = "syncmissing" then
        addons = LoadAddons()
        for idx = 0 to addons.Count() - 1
            a = addons[idx]
            precisaManifesto = (a.resources = invalid or a.resources.Count() = 0 or a.name = a.baseUrl)
            if precisaManifesto then
                AddOrUpdateAddon(a.url)
            else if a.enabled = true then
                GetAddonManifestCached(a, true)
            end if
        end for
        res = { ok: true, addons: LoadAddons(), error: "" }
    end if

    m.top.result = res
end sub
