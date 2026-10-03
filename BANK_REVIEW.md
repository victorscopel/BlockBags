# Bank review — 0.8.0

The eight fixes addressed these areas. Offline tests verify the Lua behavior;
protected execution and visual rendering still require the WoW client.

| Area | Current implementation | Validation limits |
| --- | --- | --- |
| Native bank context | BankPanel receives the active character or account bank type. | Native item context needs client validation. |
| Deposit routing | The unified Warband view uses compatible space across all purchased tabs. Individual tab selection was removed in 0.7.1 at the user's request. | Transfers, restrictions and server rejections need client validation. |
| Incompatible items | Backpack buttons show a restriction overlay and transfer guards reject incompatible items. | Overlay appearance needs client validation. |
| Bank item buttons | Native BankItemButtonTemplate, modified-click delegation and Blizzard refund confirmation. No addon UseContainerItem call for bank transfers. | Split stacks, refundable confirmation and taint need client validation. |
| Access states | Unavailable, read-only and no-tabs states; click/drag/bulk actions guard writes. | Actual account-lock scenarios need client validation. |
| Selective refresh | Dirty container reads, event coalescing, unchanged slot reuse. | CPU cost under real event sequences is not measured offline. |
| Delayed loading | Six bounded retries, cancellation on close/storage change, assignments retained during loading. | Slow server arrivals need client validation. |
| Independent data | Separate character/account category registries, layouts and profiles. Bank favorites removed at the user's request. | Reload/migration with existing saved data needs client validation. |

## Bank controls added in 0.8.0

- Warband gold balance, updated through ACCOUNT_MONEY; gold deposit and withdraw
  use Blizzard's native money-input dialogs.
- Native automatic item deposits, including Blizzard's refundable-item confirmation.
  Character bank uses its reagent deposit action; Warband bank offers the native
  include-reagents CVar toggle.
- Native physical-tab settings (name, icon, deposit flags and expansion filters)
  open independently of the unified item view.
- Persistent tab count, numbered tab icons and a + purchase button. The button
  uses native purchase confirmation, shows the cost on hover and disappears at
  the native maximum tab count.
- Specific lock reasons, plus transaction/settings cleanup on storage switches,
  combat and bank close.

Offline regressions cover control delegation, permissions, tab purchase updates,
CVar persistence, bank-specific balance and bounded frame reuse. Native popup
acceptance, filter saving, protected execution and visual layout still need client
validation in TESTING.md. No in-game validation is claimed by the offline suite.
