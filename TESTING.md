# BlockBags validation

## Automated checks

```sh
python -m pip install -r tests/requirements.txt
python tests/validate.py ptBR
python tests/validate.py enUS
python tests/validate.py esES
python tests/validate.py frFR
python tools/package.py
```

The suite uses Lua 5.1 through lupa and mocked WoW APIs. It compiles all modules
and exercises persistent slots, rules, profiles, native button setup, banks,
combat snippets, themes, grouping, locale catalogs and bounded offline history.
Stress checks measure frame reuse, coalescing and retained Lua growth after test GC.
They do not measure native frame memory or certify freedom from taint.

## Retail checklist — 0.9.0

No native result is implied by automated tests. Complete these before a stable
release. Enable `/console scriptErrors 1`, disable other bag replacements and
`/reload`. Use ordinary, inexpensive items for server actions.

### Backpack and item interactions

- [ ] Open through bag keys/native backpack button; close by X and Escape. Check
  localized Backpack title, sounds and native bag-bar show/hide after reload.
- [ ] Keep settings, backpack and bank open; controls remain clickable and settings
  above both. Closing settings keeps bags open without opening Game Menu.
- [ ] Use/equip, split/merge, link in chat and physically move items.
- [ ] Move one of two identical stacks to another category; the other stays put.
  Remove its favorite and confirm subsequent movement remains independent.
- [ ] Split into a chosen slot; the new stack keeps that visual position.
- [ ] Reposition within a category by dropping onto a slot; a background drop in
  the same category leaves the item in its original slot.
- [ ] Exact-slot previews distinguish swaps, native merges and favorite reservations.
- [ ] Consume a favorite: its faded icon supports tooltip/removal. Reacquiring it
  restores its slot. Restore its automatic category without displacing other items.
- [ ] Loot/remove items without changing panel geometry; new highlights stay in-category.
- [ ] Switch physical bags, change an equipped bag and return to categories.
- [ ] Check instance levels, equipment sets, transmog and upgrade indicators with
  and without Pawn; unusable equipment should not gain upgrade arrows.
- [ ] Selected currencies update by event and obey the seven-currency limit.
  Gold uses the requested thousands separators.

### Combat

- [ ] Enter with backpack closed/open; every assigned bag key, native button, X
  and Escape toggles it without ADDON_ACTION_FORBIDDEN.
- [ ] Right-click a consumable and verify use, counts, icons, locks and cooldowns.
- [ ] Receive/remove items: physical slots remain usable; categories refresh afterward.
- [ ] Enter while editing/dragging. Draft cancellation writes no protected geometry
  or attributes; saved layout returns after combat.
- [ ] Collapsed groups reveal individual physical stacks.
- [ ] Scrolling, editing, movement, sorting and transfers stay disabled. Bank stays paused.
- [ ] Change bindings outside combat; next combat uses them. Exit clears addon
  overrides, including Escape; other panels close normally afterward.
- [ ] Repeat after bank/settings interactions with native bag bar shown and hidden;
  check accumulated taint errors.

### Layouts, rules and themes

- [ ] Resize icons 24–56px; quality/mission borders scale with them.
- [ ] Resize panels with visible slot previews and slot snapping; Shift gives free
  pixel sizes. Magnetic movement aligns without trapping the cursor.
- [ ] Save/cancel drafts with category spacing 0 and 16. Scrollbars stay outside
  item grids; window minimum respects panel bounds.
- [ ] Each preset affects only the current backpack tab/bank scope; rules,
  favorites and placements survive. Other layouts stay untouched.
- [ ] Appearance copy changes icons/spacing/color, preserving rules and geometry.
  Single-category reset and draft cancellation preserve other panels.
- [ ] Visual AND conditions/OR groups, comparisons and negation match their previews.
  Priority changes classification without moving panels; manual assignments win.
- [ ] Advanced parentheses/quoted names/tooltip text work; invalid expressions
  are rejected and advanced rules are not silently overwritten by visual editing.
- [ ] Profession material families and native reagent qualities match expected items.
- [ ] Each sort field/direction works: fixed slots stay put until Organize;
  automatic positions sort/fill gaps while favorite reservations stay fixed.
- [ ] Grouping sums identical stacks; + exposes original slots; use/drag affects
  one physical stack. Favorites, equipment and manually pinned stacks stay separate.
- [ ] Switch Blizzard/dark/ElvUI and back; fonts/colors restore. Test ElvUI absent
  and installed with its bags module disabled.
- [ ] Custom categories create/rename/hide/delete; built-ins cannot be deleted.
  Category tabs exist only for backpack; bank stays unified.
- [ ] Check ptBR/enUS/esES/esMX/frFR wording. Default labels follow locale changes;
  custom names remain unchanged.
- [ ] Export/import each scope: rules, themes, sorting and grouping survive;
  physical GUIDs and offline history are excluded.

### Character bank and Warband bank

- [ ] Separate windows focus correctly when overlapped; header controls follow
  their window. Each bank scope has independent categories/settings/profiles.
- [ ] All purchased tabs contribute capacity/items in categorized and physical
  views. Compatible deposits find another tab when one is full.
- [ ] Tab count/icons remain visible; + shows cost/confirmation, updates after
  purchase and disappears at the maximum.
- [ ] Native tab name/icon/deposit/expansion settings persist and never filter the
  unified view. Include-reagents and automatic deposits obey native settings.
- [ ] Warband gold reflects account money. Native deposit/withdraw input, cancel
  and event-driven updates work.
- [ ] Native bank clicks/splits/dragging/chat links are taint-free. Refundable items
  use Blizzard confirmation; unavailable/read-only/incompatible actions are guarded.
- [ ] Confirm category deposits/withdrawals/sales. Equipment-set items and relevant
  backpack favorite protections are respected.
- [ ] Closing bank/vendor, cursor items, scope changes and combat cancel batches.
  Full/locked/rejected destinations stop without infinite retries.
- [ ] Bank settings omit favorites, backpack currencies/equipped bags/category tabs.
- [ ] Closing only backpack keeps bank open; closing bank ends its interaction
  without closing backpack. Dialogs close on scope changes/combat/bank close.
- [ ] Delayed bank data recovers within six retries; switching/closing cancels
  stale callbacks. Existing data survives migration/reload.

### Offline history and performance

- [ ] Collection starts only after enabling. Visit backpack and both bank scopes;
  /bb offline shows dates, searchable saved records and backpack gold.
- [ ] Offline icons provide saved item tooltips without use/drag/transfer actions.
  Warband has one shared record across characters.
- [ ] Limits remove oldest whole snapshots; oversized snapshots are rejected.
  Disabling retains records until expiration/clear, and clear requires confirmation.
- [ ] Level/set/appearance changes refresh metadata even without slot/count changes.
- [ ] Repeated scrolling/reopening keeps viewer frames bounded to its viewport.
- [ ] Stress loot, moves/splits/merges, settings and banks; compare /bb diagnostics
  and /bb memory. Use /bb memory gc only for manual diagnosis.
- [ ] Enable scriptProfile and reload only when profiling CPU, then disable after
  testing. Record WoW build/addon version, reproduction and full errors.

Do not require full WTF folders to reproduce issues.
