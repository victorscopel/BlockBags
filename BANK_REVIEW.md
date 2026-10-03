# Bank review — 0.7.1

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

## Still missing from the native bank

- Warband gold balance and native gold deposit/withdraw controls. The current
  footer still displays character gold.
- Native automatic reagent deposits and deposit-all controls.
- Physical tab deposit filters/settings (such as expansion filters).
- More detailed lock/access reasons and native purchase/access prompts.

These are additional bank features, not completed features of the current version.
