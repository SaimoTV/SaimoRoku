' ====================================================================
' Saimo TV para Roku
' Ponto de entrada nativo BrightScript / SceneGraph
' ====================================================================

sub Main(args as Dynamic)
    screen = CreateObject("roSGScreen")
    m.port = CreateObject("roMessagePort")
    screen.SetMessagePort(m.port)

    ' Necessário para receber ECP/deep links enquanto o app já está aberto.
    m.input = CreateObject("roInput")
    if m.input <> invalid then m.input.SetMessagePort(m.port)
    scene = screen.CreateScene("MainScene")
    scene.observeField("sairDoApp", m.port)
    screen.Show()

    ' Deep link: o nome da chave pode vir em qualquer caixa (contentId/contentid).
    ' A cena faz a leitura case-insensitive e ignora links inválidos.
    if args <> invalid then scene.deepLink = args

    while true
        msg = wait(0, m.port)
        msgType = type(msg)

        if msgType = "roSGScreenEvent" then
            if msg.isScreenClosed() then exit while
        else if msgType = "roInputEvent" then
            if msg.IsInput() then
                info = msg.GetInfo()
                if info <> invalid then scene.deepLink = info
            end if
        else if msgType = "roSGNodeEvent" then
            if msg.getField() = "sairDoApp" and msg.getData() = true then exit while
        end if
    end while
end sub
