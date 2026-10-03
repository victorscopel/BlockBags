# BlockBags

**Automatic item organization. A layout that stays where you put it.**

BlockBags replaces the bags in World of Warcraft Retail with categories that keep
their position and size when items enter or leave your inventory. Arrange panels
like blocks, resize each one, and choose fixed or automatic item positions.

> **Early preview — 0.9.0.** Combat controls, bank transactions and visual behavior
> still need testing in the Retail client. Automated Lua tests do not certify
> freedom from taint. Interface languages: English, Portuguese, Spanish (esES/esMX)
> and French. Other clients use English.

## Features

- Unified backpack, including the reagent bag.
- Automatic categories, visual AND/OR rules and assignments for individual stacks.
- Persistent panels with free resizing, alignment guides and magnetic snapping.
- Per-category colors, icon sizes, spacing, sorting and optional compaction.
- Compact, balanced and spacious presets; copy appearance or reset one category.
- Favorites with reserved slots and faded icons when absent; new-item highlights.
- Backpack category tabs with independent layouts.
- Optional visual stack grouping, with access to every physical stack.
- Blizzard, dark and ElvUI appearance options.
- Separate bank window; character and Warband banks have independent categories,
  settings and profiles. Every purchased physical tab is shown together.
- Bank tab count, settings, purchases, Warband gold transactions and native deposits.
- Temporary physical-bag view and equipped-bag controls.
- Item levels, possible upgrades, equipment sets and uncollected appearances.
  Optional Pawn support.
- Search filters, selected backpack currencies and confirmed category actions.
- Shareable profiles with validated import/export codes.
- Optional, bounded offline history and performance diagnostics.

## Installation

1. Download the ZIP from [Releases](https://github.com/victorscopel/BlockBags/releases), when available.
2. Extract `BlockBags` into `World of Warcraft/_retail_/Interface/AddOns/`.
3. Confirm that `Interface/AddOns/BlockBags/BlockBags.toc` exists.
4. Disable other bag replacements, including ElvUI's bags module if enabled.
5. Start the game or run `/reload`, then open your bags normally.

Retail only. Classic and guild banks are not supported.

## Using BlockBags

Open with your usual bag key or `/bb`. The circular bag button opens settings and
layout tools; right-click it for physical bags. Toggle **Show WoW bag bar** there.

Drag a category header to move it. Enter layout editing to resize panels and the
window. Hold **Shift** to bypass snapping. Drag a stack onto another category to
assign only that stack. Within its current category, drop onto a specific slot to
reposition it; a background drop leaves it in place.

Right-click a header for sorting, customization and bulk actions. Fixed positions
preserve holes; automatic positions sort and fill gaps. Favorites keep their slots.
Native AddOns settings contain **Rules**, **Layouts and tools** and **Offline history**.
Closing settings leaves your bags open.

Opening a bank shows a second window. Its selector switches between character
and Warband banks. All purchased tabs remain unified; numbered icons edit native
tab names, icons and deposit filters. **+** purchases an eligible tab. Closing the
backpack keeps the bank open; closing the bank ends the interaction. Favorites,
currencies, equipped bags and virtual category tabs are backpack-only. Inventory
and bank profiles are exported separately.

### Combat

The prepared backpack uses secure controls for bag keybinds, the native backpack
button, X, Escape and ordinary right-click item use. Layout and scroll positions
freeze in combat; editing, dragging, sorting and transfers wait until it ends.
Collapsed groups reveal individual physical stacks. Banks remain paused. `/bb`
cannot perform a protected toggle in combat; use a bag key. Actual taint testing
in Retail is still required before considering this build stable.

### Virtual stacks and offline history

Grouping is optional per category. Identical links/bindings share an icon and total
count; **+** reveals the original slots. Use/drag acts on that physical stack only.
Equipment, favorites and explicitly positioned stacks stay separate. Grouping
never merges items or changes saved placements.

Offline collection is disabled by default. Enable it to record inventories you
visit. `/bb offline` opens a searchable, read-only viewer showing last-visit data.
Default limits: **5 characters, 6,000 occupied slots total and 30 days**. Configurable
bounds: 1–20 characters, 500–12,000 slots and 1–90 days; each snapshot holds at most
1,600 slots. Warband has one shared record. Oldest snapshots are discarded first;
oversized records are rejected. Disabling collection retains records until they
expire or are cleared. History is excluded from profile exports.

## Search and rules

Plain text searches names. Spaces/`AND` combine conditions; `OR`/`|` accepts either
branch. Use parentheses, `!` for exclusion and quotes for values containing spaces.
Keywords support English and Portuguese; names/tooltip text follow the client.

```text
quality:epic ilvl:>=120
(type:consumable OR type:tradegoods) expansion:tww
slot:ring !favorite:true
set:"Raid DPS"
profession:alchemy craftquality:>=2
tooltip:"movement speed"
upgrade:true uncollected:true
```

Rules support the same filters except `category`, `favorite` and `new`. Manual
assignments and favorites take priority; the first matching rule wins. The visual
editor supports eight conditions in four groups (AND within, OR between), with
live matches. Advanced expressions remain text-editable. Rules are limited to
256 characters and never execute Lua. Profession families identify material types,
not every reagent used by a profession. Tooltip-text search requires live inventory.

Upgrade markers compare item levels or use Pawn; they are not a complete stat
evaluation. `C` identifies equipment sets; `T` identifies uncollected appearances.

## Commands

| Command | Action |
| --- | --- |
| `/bb` | Toggle backpack outside combat |
| `/bb config` | Native addon settings |
| `/bb edit` | Layout editing |
| `/bb offline` | Saved inventory history |
| `/bb diagnostics` | Refresh timing, CPU availability, memory and history size |
| `/bb memory` | Attributed memory and pooled frame counts |
| `/bb memory gc` | One manual garbage collection and memory comparison |
| `/bb reset` | Restore layout while preserving item positions |
| `/bb scale 0.85` | Window scale (0.5–1.25) |

CPU totals require WoW's `scriptProfile` setting. Diagnostics do not enable it.
There is no idle inventory scanning or automatic forced garbage collection.

## Feedback and credits

[Report issues](https://github.com/victorscopel/BlockBags/issues) with versions,
reproduction steps and the full error. Remove personal information before sharing.
See [testing](TESTING.md) and [roadmap](ROADMAP.md) for pending client validation.

[MIT license](LICENSE). BlockBags is independent and does not require BetterBags or
MyBags. Adaptations retain credits in [Third-party notices](THIRD_PARTY_NOTICES.md).
World of Warcraft and its assets belong to Blizzard Entertainment.
