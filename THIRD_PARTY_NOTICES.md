# Third-party notices

BlockBags is an independent addon. It does not load BetterBags or MyBags as
dependencies, and does not claim feature parity with either project.

## BetterBags

Source: https://github.com/Cidan/BetterBags

Theme.lua adapts the reusable DefaultPanelTemplate decoration approach from
themes/default.lua. The categorization, window-decoration and reusable frame
design were also studied as references. Reference installed version: v0.5.13.

BagTools.lua adapts the bag portrait artwork coordinates from themes/themes.lua
and the equipped-bag controls from frames/bagbutton.lua and frames/bagslots.lua.
The images themselves are Blizzard's built-in assets, not bundled copies.

Storage.lua adapts Retail bank-frame suppression and BankPanel lifetime from
core/init.lua and bags/bank.lua. ItemFeatures.lua follows the equipment-set
location API handling in data/equipmentsets.lua. Upgrade/binding checks were
studied in data/items.lua, data/binding.lua and integrations/pawn.lua.

Copyright (c) 2023 Antonio Lobato

## MyBags

Source: https://github.com/MyGamesDevelopmentAcc/MyBags

Interaction.lua adapts source tracking, focused-frame ancestry and category-only
item reassignment from dragndrop.lua. The algorithm is integrated with BlockBags'
own native item buttons, fixed layout, favorites and profiles. Column packing and
whole-addon hooks were not imported. Reference: main branch reviewed 2026-10-02.

Copyright (c) 2026 MyGamesDevelopmentAcc

## MIT License (applies to both adaptations above)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

No third-party textures, logos or bundled libraries are copied by this rebuild.
The frame templates and texture paths used by the addon are provided by WoW.
