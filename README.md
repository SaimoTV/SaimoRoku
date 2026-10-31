# Saimo TV para Roku (v2.6.0)

Aplicativo oficial 100% nativo para TVs e dispositivos Roku, desenvolvido em **BrightScript** e **SceneGraph** para máxima performance, baixíssimo consumo de memória e resposta instantânea ao controle remoto.

## Recursos
- **Paridade 1:1 com Android TV Box:**
  - **Ao Vivo:** Zapping rápido (Cima/Baixo), teclado numérico direto (0-9), mini ZapHUD com programação EPG, Drawer lateral de canais (tecla OK) e Bloqueio Parental.
  - **Início (Home):** Hero banner com reprodução em 1 clique e trilhos dinâmicos ("Continuar Assistindo", "Destaques", "Ao Vivo Agora").
  - **Acervo (VOD):** Filtros rápidos por Filmes, Séries, Animes e Doramas com navegação fluida em grade de pôsteres acelerada por GPU.
  - **Ficha Técnica:** Sinopse, ano, nota TMDB, áudio/legendas, e seletor de temporadas/episódios para séries.
  - **Player Nativo:** Decodificação direta por hardware (HLS / MP4), scrubber OSD, avanço/retrocesso rápido, botão de pular abertura (+85s) e salvamento automático de progresso.
  - **Guia de TV (EPG):** Grade completa de 2 colunas com sintonia em 1 clique.
  - **Agenda Esportiva:** Jogos ao vivo de hoje com placar em tempo real e atalho direto para o canal da transmissão.
  - **Rádios:** Estações AM/FM e Web Rádios brasileiras com áudio contínuo.
  - **Busca:** Teclado nativo com pesquisa em tempo real por canais, filmes e séries.
  - **Ajustes:** Configuração de buffer (Zero Delay), áudio inteligente, idioma preferido e controle parental.
- **Saimo Connect Integrado:**
  - Servidor socket na porta `8999` com resposta instantânea a `GET /info` e controle remoto pelo aplicativo de celular na rede local Wi-Fi.

## Layout
Todas as telas seguem a TV Box: mesma fonte (Roboto, em `fonts/`), fundo aurora (`images/fundo.jpg`), abas em pílula com ícones Material, cartões `PosterItem` e medidas em dp × 2. Cantos arredondados vêm dos `images/p_*.9.png`.

## Minhas listas
Em Ajustes, a pessoa adiciona uma lista `.m3u` pelo link (teclado da TV ou Saimo Connect). Roku não tem seletor de arquivos. O link fica no registro; os canais, no `cachefs:` e são baixados de novo se o sistema limpar. Até 5.000 canais por lista; canais adultos ficam de fora. Código: `source/utils/LeitorM3u.brs`, `components/tasks/MinhasListasTask.brs`, `components/screens/MinhasListasScreen.brs`.

## Como Gerar o Pacote
```bash
./build.sh
```
O pacote final será gerado em `dist/SaimoTV-Roku.zip`.

## Instalação no Roku (Modo Desenvolvedor)
1. Ative o modo desenvolvedor no Roku (sequência no controle: `Home 3x`, `Up 2x`, `Right`, `Left`, `Right`, `Left`, `Right`).
2. Acesse o endereço IP da sua TV pelo navegador (`http://<ip-do-roku>`).
3. Envie o arquivo `dist/SaimoTV-Roku.zip` e clique em **Install**.
