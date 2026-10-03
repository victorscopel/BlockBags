# Changelog

## 0.6.1 — preview

- Use the WoW client's localized Backpack title.
- Hide the Blizzard bag bar by default and add a toggle in the bag button menu.
- Keep physical bag view as a separate menu option.
- Play native backpack sounds when opening and closing the window.
- Avoid duplicate decoration frame names across backpack and bank windows.

## 0.6.0 — preview

- Open the character bank and Warband tabs in a separate window alongside the inventory.
- Give the bank its own categories, favorites, manual assignments, settings and profiles.
- Preserve existing bank layouts and positions when migrating to separate bank data.
- Keep the inventory open when the bank closes, and keep the banking interaction open when only the inventory closes.
- Reuse bank frames and isolate refresh queues across repeated openings.

## 0.5.2 — preview

- Fix the profile code field calling an unsupported EditBox height method.

- Show individual item slots during category resizing and snap dimensions to whole slots; hold Shift for free pixel sizing.

- Keep whole stacks in their original slot when dropped within the same category; matching stacks still use native merging.

- Switching to automatic positions releases manual slot placements and sorts consistently across the header, settings and saved edits; favorites remain reserved.

- Restore favorites to a free slot in their automatic category without displacing existing items.

- Move only the selected stack between categories, leaving identical stacks in place.
- Keep split stacks in the chosen slot, including categories with automatic compaction.
- Allow native stack merging without intercepting the drop as a category move.
- Use secure item actions for ordinary inventory right-clicks.
- Load key bindings once and declare the binding header only once.
- Add currency search by name or ID, selected currencies first, and eight entries per page.
- Separate gold thousands with dots, preserving silver and copper values.
- Prune assignments and explicit positions for consumed stacks.

## 0.5.1 — preview

- Use `/bb` as the primary command; `/blockbags` and `/blocks` remain available.
- Follow the WoW client language: Portuguese for ptBR/ptPT, English otherwise.
- Translate settings, menus, messages and default labels in existing profiles.
- Keep custom names, item assignments and saved layout positions unchanged.
- Show the inventory close button above the window border.

## 0.5.0 — prévia

- Fechar opções abertas pelo BlockBags preserva o inventário sem abrir o menu Esc.
- Moedas selecionáveis no rodapé, até sete por perfil.
- Indicadores de melhoria, conjunto de equipamento e transmog não coletado.
- Avaliação opcional pelo Pawn com comparação por ilvl como alternativa.
- Filtros por expansão, vínculo, slot, conjunto, tooltip, melhoria e transmog.
- Valores entre aspas na busca e indexação de tooltip sob demanda.
- Abas de categorias com edição de layout independente.
- Banco do personagem e abas compradas da tropa, com posições isoladas.
- Depósito, retirada e venda de categorias após confirmação; favoritos e
  conjuntos protegidos, verificação de origem e cancelamento por contexto.
- Compra de abas pelo menu da bolsa, mediante confirmação nativa.
- Correção da posição do indicador de reagente na leitura de GetItemInfo.
- Estrutura de repositório, licença MIT, testes, CI e empacotamento de releases.

## 0.4.3

- Título Inventário e preservação do inventário ao fechar as configurações.

## 0.4.2

- Visualização temporária por bolsa física, restauração das categorias e
  correção da camada do botão circular.

## 0.4.1

- Botão circular de bolsa, menu, controles de bolsas equipadas e ilvl por item.

## 0.4.0

- Interface moderna e interação direta com categorias.
- Reclassificação de itens sem exigir espaço físico livre.
- Regras de categoria e busca por atributos.
- Adaptações MIT do BetterBags e MyBags com créditos preservados.
