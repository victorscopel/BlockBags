# BlockBags

**Automatic item organization. A layout that stays where you put it.**

BlockBags is a bag replacement for World of Warcraft Retail built around spatial
memory. Categories keep their position and size as items enter or leave your
inventory, so you can always find things where you expect them.

Arrange categories like blocks, choose their dimensions, and decide whether each
category keeps item positions or automatically fills gaps.

> **Early preview — 0.8.0.** Bank integration and bulk actions are still being
> tested in-game. The interface follows your WoW client language: Portuguese or English.

## Features

- Unified inventory, including the reagent bag.
- Automatic categories, custom rules, and manual assignments per item stack.
- Persistent category layouts with free resizing, alignment guides, and snapping.
- Per-category colors, item sizes, spacing, and optional compaction.
- Favorites and a visual highlight for newly acquired items.
- Category tabs with independent layouts.
- Unified Warband inventory covering every purchased physical tab.
- Visible bank tab count, numbered tab icons and purchase control.
- Warband gold balance and native gold deposit/withdraw dialogs.
- Native automatic deposits, optional Warband reagent inclusion and physical-tab deposit filters.
- Separate bank window; character and Warband banks have independent categories, settings and profiles. Favorites are backpack-only.
- Character bank and Warband tabs with independent layouts.
- Temporary physical-bag view and equipped-bag controls.
- Item levels, potential upgrade indicators, equipment-set markers, and
  uncollected appearance markers. Optional Pawn integration.
- Search by name, quality, item level, expansion, binding, equipment slot,
  equipment set, and tooltip text.
- Selected currencies in the footer.
- Category-wide deposit, withdrawal, and sale actions with confirmation;
  favorites and saved equipment-set items are excluded.
- Shareable profiles with import and export codes.

## Installation

1. Download the addon ZIP from [Releases](https://github.com/victorscopel/BlockBags/releases), when available.
2. Extract the `BlockBags` folder into `World of Warcraft/_retail_/Interface/AddOns/`.
3. Make sure the resulting path is `Interface/AddOns/BlockBags/BlockBags.toc`.
4. Disable other bag replacement addons, including ElvUI's bags module if enabled.
5. Start the game or run `/reload`, then open your bags normally.

Retail only. Classic, guild banks, and offline character inventories are not
currently supported.

## Getting started

- Open your bags with the usual keybind or `/bb`.
- Click the circular bag button for settings and layout options.
- Drag a category header to move it. Hold **Shift** to bypass snapping.
- Enter layout editing to resize categories and the inventory window.
- Drag an item onto another category to assign it manually.
- Right-click the bag button to switch temporarily to physical bags.
- The Blizzard bag bar is hidden by default; use **Show WoW bag bar** in the
  bag button menu to display it.
- Right-click a category header for tab assignments and available bulk actions.
- Use `/bb config` for settings or `/bb edit` for layout editing.

Opening a bank shows a second window while your inventory stays available.
Use the bank window selector to switch between the character bank and Warband
tabs. Its bag button opens its own settings, including categories and profiles.
Closing the inventory keeps the bank open; closing the bank ends the banking
interaction. Existing bank layouts are migrated on first opening.

Inventory and bank profiles are exported and imported separately from their
respective settings pages.

Closing settings keeps your inventory open. New items stay in their assigned
categories instead of moving into a separate recent-items section.

The upgrade arrow suggests a possible improvement based on item level, or your
Pawn evaluation when enabled. It is not a complete evaluation of item stats.
The `C` marker identifies saved equipment-set items; `T` marks an uncollected
appearance.

## Search

Plain text searches item names. Combine filters with spaces, use `!` to exclude a
match, and quote values containing spaces. Item names and tooltip text follow
your WoW client language.

```text
name:potion
quality:epic ilvl:>=120
expansion:tww binding:boe
slot:ring !favorite:true
set:"Raid DPS"
tooltip:"movement speed"
upgrade:true uncollected:true
```

Custom category rules use the same filters, except `category`, `favorite`, and
`new`. Manual assignments take priority over automatic rules.

## Feedback

Found a problem? [Open an issue](https://github.com/victorscopel/BlockBags/issues)
with your WoW and addon versions, steps to reproduce it, and any Lua error.
Screenshots are useful for layout issues. Please remove personal information
before sharing logs or profile codes.

## License and credits

[MIT license](LICENSE). BlockBags is independent and does not require BetterBags
or MyBags. Adaptations from those projects retain their original licenses and
credits in [Third-party notices](THIRD_PARTY_NOTICES.md).

World of Warcraft and its assets belong to Blizzard Entertainment.
