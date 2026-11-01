' ====================================================================
' Saimo TV para Roku - Versão 2.6.0
' Ponto de entrada nativo BrightScript / SceneGraph
' ====================================================================

sub Main(args as Dynamic)
    ' Inicializa o display SceneGraph
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.SetMessagePort(m.port)

    ' Cria a cena principal
    scene = screen.CreateScene("MainScene")
    scene.observeField("sairDoApp", m.port)
    screen.Show()

    ' Passa argumentos de deep linking (se houver, ex.: do Saimo Connect)
    if args <> invalid and args.contentId <> invalid then
        scene.deepLink = args
    end if

    ' Loop de eventos do canal
    while true
        msg = wait(0, m.port)
        msgType = type(msg)

        if msgType = "roSGScreenEvent" then
            if msg.isScreenClosed() then
                exit while
            end if
        else if msgType = "roSGNodeEvent" then
            ' Timer de sono: fecha o app
            exit while
        else if msgType = "roSocketEvent" then
            ' Eventos de socket tratados no contexto global se necessário
        end if
    end while
end sub
