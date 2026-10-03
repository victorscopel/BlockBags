# BlockBags architecture

The invariant is a user-owned category rectangle: inventory events never pack,
resize or move panels. Layout changes occur only through user interaction.

## Modules

- Locale: client-language text and default category/tab labels; custom names remain unchanged.

- Core: SavedVariables migration, event routing, coalesced refresh and combat state.
- Inventory: reusable physical-slot models and bounded current-inventory metadata.
- ItemFeatures: instance ilvl, usability-aware upgrades, optional Pawn, equipment
  sets, transmog, binding data, on-demand tooltip indexing and selected currencies.
- Query: bounded data-only filters shared by search and category rules; quoted
  values support equipment-set names and tooltip phrases.
- Views: category tabs and independent layouts keyed by storage + tab. Main
  inventory/default-tab layout keeps its original schema for existing profiles.
- Storage/BankAccess/BankWindow: purchased containers, native bank context, exact
  unified bank routing, access guards and independent bank controllers.
- BankTools: pooled purchased-tab controls, native settings and transaction dialogs,
  automatic deposits, reagent inclusion and event-driven Warband money display.
- Placement: surviving GUID positions, favorite reservations, optional compaction,
  physical empty destinations and collision-aware persistent geometry.
- Theme/BagTools/UI: pooled Blizzard decoration and native slot buttons. Physical
  bag mode is transient; switching back restores the category window dimensions.
- Interaction/Editor: tracked item sources, category-only reassignment, direct
  header movement, transactional resizing, guides and snapping.
- BulkActions: concrete native confirmation, guarded source snapshots and one
  outstanding operation at a time. Rejections stop instead of retrying forever.
- Profiles/Settings/FeatureSettings: validated data-only BB1 codes, native Settings
  pages, category editing, currencies, indicators and tab management.

## Persistence

`BlockBagsDB.profiles` stores categories, rules, favorites, settings and layouts.
The base `layout` stays the bags/default view; `extraLayouts[storage:tab]` stores
other views. `categoryTabs` assigns categories to tabs; omitted membership means
Principal. Each view keeps all category definitions but renders only its members.

`inventoryPositions[character][profile]` keeps the base physical item positions;
its `views[storage:tab]` table keeps other position maps isolated. BB1 exports omit
physical GUID positions. Imports validate category/tab IDs, geometries, rules,
settings and overlap within a category group, with bounded parsing and no Lua eval.

Bank profiles live under `BlockBagsDB.bank.scopes.character` and
`BlockBagsDB.bank.scopes.account`, each with its own profiles, categories and
position maps. Physical Warband tabs share the account storage view; legacy
per-tab layouts and positions migrate to it. Existing shared bank profiles seed
both scopes once. Bank
favorites are removed during migration/selection; favorites remain a backpack
feature. Bank settings omit character currencies and equipped-bag controls.

## Event and allocation boundaries

No idle OnUpdate: only active dragging/resizing uses it, skipping unchanged cursor
positions. Refresh requests coalesce, hidden windows defer scans, item requests
have no permanent timer retry loop, and currency updates do not rescan inventory. Bank slots
are scanned only while their bank is viewable. Metadata/tooltip data are refreshed
by item or equipment/collection events; tooltips are queried only when searched.
Dirty bag events reuse unchanged slot models. Bank opening retries delayed data
at most six times; generation checks cancel retries on storage switches or close.

Slot models, ItemLocations, group buffers, native buttons and auxiliary visuals are
reused. Bank/group switches allocate a bounded initial set of parents/maps, then
reuse them. Forced garbage collection is a manual diagnostic only.

Bulk queues snapshot GUID/link/count and verify the source before acting. Protected
favorites and equipment sets are skipped. Closing interaction/window, switching
view, combat and cursor items cancel work; callbacks use identity guards so stale
callbacks cannot restart a cancelled queue. A rejected operation attempts once.

## Integration constraints

The backpack and bank have separate windows and button pools. The focused window
uses a higher frame level, while bag and close controls share its strata. Native
BankPanel context follows the selected bank type. Purchases are user-triggered through
native confirmation. Exact protected-frame behavior remains subject to in-game
validation in TESTING.md; offline Lua mocks cannot certify freedom from taint.

No libraries or complete external addon are embedded. The MIT adaptation notices
are kept in THIRD_PARTY_NOTICES.md. World of Warcraft provides all UI artwork.
