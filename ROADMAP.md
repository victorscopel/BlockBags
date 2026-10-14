# BlockBags roadmap

## Implemented for 1.0.0

- [x] Native backpack item clicks, combat toggling and window movement, with category layout changes deferred.
- [x] Exact-slot drop previews and removal of missing favorites from their faded icons.
- [x] Three layout presets, appearance copying and individual category reset.
- [x] Visual AND/OR rules, matching-stack previews, priorities and text editing.
- [x] Profession material-family and reagent-quality filters.
- [x] Sorting by name, quality, item level, quantity and expansion.
- [x] Optional visual stack grouping with access to individual physical slots.
- [x] Blizzard/dark themes and optional ElvUI fonts and colors.
- [x] English, Portuguese, Spanish/esMX and French interface catalogs.
- [x] Separate character/Warband categories and profiles in a dedicated bank window.
- [x] Opt-in offline history with age, character and item limits.
- [x] Bounded pools and aggregate CPU/memory/refresh diagnostics.
- [x] Automated regression coverage and release packaging.

Implemented features still require native checks. Mocked Lua tests do not mark
protected actions or visual behavior as verified in WoW.

## Retail validation

- [ ] Complete TESTING.md in Retail, especially combat taint, item use, stack
  splitting/merging, bank refunds and gold transactions.
- [ ] Stress actual loot, moves, settings and bank switches; measure CPU time and
  retained memory rather than temporary allocation alone.
- [ ] Check clipping, legibility, drop highlights and resize guides at different scales.
- [ ] Review Spanish and French wording with players using those clients.
- [ ] Test saved-data migrations and profile exchanges between locales.
- [ ] Collect reproducible issues from players and verify fixes in Retail.

## Possible follow-up work

These are separate extensions, not requirements of 1.0.0.

- Additional client languages.
- Recipe-level profession filters beyond material-family matching.
- Keyboard-accessible category movement and rule editing.
- Quick layout switching without overwriting customized layouts.
- Guild-bank support after its permissions and transfer model is designed.

Publication is a separate step. A local commit or generated ZIP does not publish
an addon or certify it as stable.
