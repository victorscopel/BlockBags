# Native backpack interaction implementation plan

**Goal:** Make the backpack movable, openable and closable during combat, including combat reloads, while preserving category interactions.

**Architecture:** An ordinary window contains native container buttons. Their native right-click script remains untouched. Ordinary child controls handle category placement and Alt-right-click menus; right clicks pass through to the native buttons otherwise. Bank transactions retain their existing guards. Layout editing and category movement remain outside combat.

**Tech stack:** Retail Lua, ContainerFrameItemButtonTemplate, native click passthrough, existing offline regression harness.

## Tasks

- [x] Add failing tests for ordinary frame templates, untouched native right clicks and window movement during combat.
- [x] Remove custom secure item actions and combat binding overrides; retain native handlers and use a separate category interaction layer.
- [x] Make ordinary window toggling and dragging available in combat; handle initial rendering and native bag integration without protected writes.
- [x] Update interaction, bank and combat regressions; validate supported languages and repeated rendering.
- [x] Consolidate release notes under 1.0.0, update public descriptions and package/deploy locally.
- [x] Review, commit and document the in-game checks required before publication.

No third-party implementation code is copied. Native item scripts and bank safeguards are retained.

Offline validation passed in enUS, ptBR, esES and frFR. The release candidate still needs the native combat checks in TESTING.md before publication.
