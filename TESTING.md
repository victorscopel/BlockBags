# Validação

## Automatizada

```sh
python -m pip install -r tests/requirements.txt
python tests/validate.py ptBR
python tests/validate.py enUS
python tools/package.py
```

Os testes usam Lua 5.1 através do lupa. Compilam todos os módulos e exercitam
classificação, posições, editor, importação, integração e os recursos da 0.6.2
com APIs simuladas. Incluem limites de cache, crescimento retido após GC,
reutilização de frames e cancelamento de operações. Não substituem o cliente.

## No WoW Retail, antes de publicar como estável

- [ ] Confirmar título Backpack/Mochila conforme o cliente e sons ao abrir/fechar.
- [ ] Barra nativa de bolsas oculta por padrão; alternar pelo menu, trocar perfil e dar reload.
- [ ] Conferir menus e mensagens em clientes ptBR e enUS; testar `/bb help`.
- [ ] Confirmar que o X aparece e fecha o inventário em ambos os modos de bolsas.

Ative `/console scriptErrors 1`, desative outros substitutos de bolsa e dê `/reload`.
Use itens comuns e baratos para validar ações de servidor.

- [ ] Abrir pelas teclas de bolsa, fechar pelo X e por Esc; arrastar o título.
- [ ] Abrir/fechar opções por Esc e X sem fechar o inventário; o próximo Esc
  fecha o inventário. Inventário fechado permanece fechado ao abrir opções.
- [ ] Usar, equipar, separar pilhas, linkar no chat e mover fisicamente itens.
- [ ] Arrastar um item entre categorias com bolsas cheias; atribuição persiste.
- [ ] Comprar/receber/remover itens sem mover ou redimensionar categorias.
- [ ] Alterar tamanho dos itens (24–56 px), conferir bordas de qualidade/missão e alternar bolsas físicas.
- [ ] Redimensionar/arrastar categorias; Salvar/Cancelar preservam cada visão.
- [ ] Novo item mantém sua categoria e recebe destaque.
- [ ] Mostrar bolsas físicas, trocar uma bolsa equipada e voltar às categorias.
- [ ] Moedas atualizam por evento; limite de sete e seleção persistem no reload.
- [ ] Ilvl corresponde à instância; conjuntos usam o gerenciador nativo do WoW.
- [ ] Setas ignoram equipamento inutilizável; Pawn funciona e ausência dele
  mantém comparação por ilvl. Transmog T desaparece após aprender a aparência.
- [ ] Buscar conjunto e tooltip com valores entre aspas; combinar/negativar filtros.
- [ ] Criar/renomear/excluir abas, atribuir categorias e editar layouts distintos.
- [ ] Exportar/importar perfis do inventário e do banco separadamente; preservar abas, moedas e layouts de cada um.
- [ ] Abrir banco do personagem e tropa sem sobreposição da interface Blizzard.
- [ ] Manter inventário e banco abertos juntos; alternar banco/tropa sem alterar o inventário.
- [ ] Renomear/recolorir/criar categorias no banco sem alterar o inventário; conferir favoritos e perfis independentes.
- [ ] Arrastar entre inventário e banco transfere fisicamente; arrastar dentro do banco altera apenas sua categoria.
- [ ] Abrir opções de cada janela e fechar por Esc sem fechar nenhuma das duas.
- [ ] Banco da tropa respeita restrições, abas compradas e estado de bloqueio.
- [ ] Menu de compra de aba mostra confirmação e atualiza a seleção após compra.
- [ ] Depositar/retirar uma categoria; favoritos e conjuntos não se movem.
- [ ] Vender uma categoria só após confirmar; verificar itens vendidos/recompra.
- [ ] Fechar banco/vendedor, entrar em combate ou pegar outro item interrompe lote.
- [ ] Banco/inventário cheio ou transferência rejeitada não cria tentativas infinitas.
- [ ] Fechar só o inventário mantém o banco aberto; fechar o banco encerra a sessão sem fechar o inventário.
- [ ] Layouts e posições de banco da versão anterior sobrevivem à migração e ao reload.
- [ ] Em combate, atualizações são pausadas e retomadas sem erros de taint.
- [ ] Repetir abas/bancos/arrastos e comparar `/bb memory`; usar `/bb memory gc`
  apenas no diagnóstico, distinguindo temporários de memória retida.

Registre build do WoW, versão e erro completo em um issue. Nunca envie arquivos
WTF completos como requisito de reprodução.

### Bank regression checks (0.7.0)

Offline tests cover tab routing, access guards, native button template selection, refund popup arguments, scoped profiles, selective reads and bounded retries. Native clicks, protected execution and visual layering still need the WoW client.

- [ ] Select a Warband tab; right-click a backpack item and confirm it goes only to that tab. Fill it and confirm other tabs are not used.
- [ ] Check incompatible item dimming, read-only access, no purchased tabs and blocked bank access.
- [ ] Shift-split, link, drag and right-click bank items without taint errors. Confirm or cancel refundable deposits.
- [ ] Create/edit profiles and categories separately in character bank and Warband bank; reload and verify each.
- [ ] Bank settings omit currencies, the equipped-bag bar and favorites. Backpack favorites still work.
- [ ] Overlap both windows, click/drag each title and click items; the active window and its controls stay together.
- [ ] Open bank with slow data arrival, switch storage and close while loading. Check recovery and that retries stop.

### Window focus and unified Warband (0.7.1)

- [ ] Open Settings and backpack/bank together. Settings stays above both while typing/clicking controls.
- [ ] Overlap, reopen and drag both inventory windows; bag button, title and close button remain visible.
- [ ] Warband storage shows items and total capacity from every purchased tab, in categorized and physical views.
- [ ] Storage selector offers only character bank and Warband bank. Fill one physical tab and verify deposits use another.
- [ ] Existing per-tab manual assignments survive migration into the unified bank.
