' ====================================================================
' Saimo TV - Storage & Preferences (Roku Registry Section)
' Persistência nativa de configurações, progresso e favoritos
' ====================================================================

function GetRegistry() as Object
    if m.registry = invalid then
        m.registry = CreateObject("roRegistrySection", "saimo_tv")
    end if
    return m.registry
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
        urlCanais: "https://canais-saimo.pages.dev/",
        urlFilmes: "https://filmes-saimo.pages.dev/"
    }
end function

function LoadPreferences() as Object
    reg = GetRegistry()
    raw = reg.Read("prefs")
    defaults = GetDefaultPreferences()
    if raw <> "" then
        parsed = ParseJson(raw)
        if parsed <> invalid then
            for each key in defaults
                if parsed[key] = invalid then
                    parsed[key] = defaults[key]
                end if
            end for
            return parsed
        end if
    end if
    return defaults
end function

sub SavePreferences(prefs as Object)
    if prefs = invalid then return
    reg = GetRegistry()
    json = FormatJson(prefs)
    reg.Write("prefs", json)
    reg.Flush()
end sub

' ----- Progresso VOD ("Continuar Assistindo") -----

function LoadAllProgress() as Object
    reg = GetRegistry()
    raw = reg.Read("vod_progress")
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

sub SaveVODProgress(title as String, posSec as Integer, durSec as Integer, season = 0 as Integer, episode = 0 as Integer, epTitle = "" as String, url = "" as String)
    if title = "" or durSec <= 0 then return
    all = LoadAllProgress()
    percent = Int((posSec / durSec) * 100)
    
    ' Se assistiu mais de 92%, marca como concluído
    if percent >= 92 then
        if all[title] <> invalid then
            all.Delete(title)
            reg = GetRegistry()
            reg.Write("vod_progress", FormatJson(all))
            reg.Flush()
        end if
        return
    end if

    all[title] = {
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
    reg.Write("vod_progress", FormatJson(all))
    reg.Flush()
end sub

' ----- Favoritos -----

function LoadFavoriteChannels() as Object
    reg = GetRegistry()
    raw = reg.Read("fav_channels")
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
    reg.Write("fav_channels", FormatJson(favs))
    reg.Flush()
end sub

function IsChannelFavorite(channelName as String) as Boolean
    favs = LoadFavoriteChannels()
    for each f in favs
        if f = channelName then return true
    end for
    return false
end function
