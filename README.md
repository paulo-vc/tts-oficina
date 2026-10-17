# Oficina de Peças (TTS)

Deixa **qualquer jogador** criar componentes custom no Tabletop Simulator — mesmo na mesa de outro mestre. Normalmente a janela de importação do TTS aparece só para o host; aqui o jogador responde caixas de diálogo que aparecem **só para ele**, e o script cria a peça a partir de um link de imagem. Português e inglês.

## Instalação
1. **Objects > Components > Custom > Model**
   - Model/Mesh: `assets/oficina.obj`
   - Diffuse/Image: `assets/oficina.png`
   - Aceite subir para a Steam Cloud e clique em Import.
2. Clique direito no objeto > **Scripting > Scripting Editor**, cole `Oficina.lua` e clique em **Save & Play**.

Funciona também num bloco comum (Objects > Blocks > Square).

## Como os jogadores usam
1. Clique no tipo de peça: **Token**, **Tile**, **Figura**, **Carta** ou **Modelo 3D**.
2. Cole o link da imagem (`.png` / `.jpg` — Imgur, Discord, Steam Cloud...).
   - Figura e Carta: link do verso (opcional). Tile: formato (quadrado, hexágono, redondo, cantos arredondados). Modelo 3D: link do `.obj` e, opcionalmente, da textura.
3. Dê um nome e escolha o tamanho. A peça aparece na frente do seu lugar.

**Minha biblioteca:** cada jogador guarda as peças que já criou (até 40, ligadas à conta Steam) para recriar depois ou apagar.

## Para o mestre
- **Aprovação:** ligada, as peças de jogadores vão para uma fila no painel, com miniatura, nome, quem pediu e o tipo. **Aprovar** cria a peça; **Recusar** descarta. O mestre recebe um aviso no chat a cada pedido. Peças do próprio mestre não passam pela fila.
- **Idioma:** botões Português / English.

## Limitações
- O jogador precisa de um **link** de imagem: o script roda no computador do host e não consegue ler arquivos do PC dos jogadores.
- Só jogadores sentados numa cor podem criar peças (espectadores não).

---

# Piece Workshop (TTS)

Lets **any player** create custom components in Tabletop Simulator — even at another GM's table. Normally TTS's import window only shows up for the host; here the player answers dialogs that appear **only to them**, and the script builds the piece from an image link. English and Portuguese.

## Install
1. **Objects > Components > Custom > Model** — Model/Mesh: `assets/oficina.obj`, Diffuse/Image: `assets/oficina.png`. Accept the Steam Cloud upload, then Import.
2. Right-click the object > **Scripting > Scripting Editor**, paste `Oficina.lua`, click **Save & Play**.

## How players use it
1. Click a piece type: **Token**, **Tile**, **Standee**, **Card** or **3D model**.
2. Paste the image link (`.png` / `.jpg`). Standee and Card: optional back image. Tile: shape. 3D model: `.obj` link and optional texture.
3. Name it and pick a size. The piece appears in front of your seat.

**My library:** each player keeps the pieces they made (up to 40, tied to their Steam account) to recreate or delete later.

## For the GM
- **Approval:** when on, players' pieces wait in a queue on the board (thumbnail, name, who asked, type). **Approve** creates it, **Reject** discards it. GMs get a chat notice for each request. The GM's own pieces skip the queue.

## Limitations
- Players need an image **link**: the script runs on the host's computer and can't read files from players' PCs.
- Only seated players can create pieces (not spectators).
