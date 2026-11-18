# Kindouse Tweaks

A collection of UI changes, sound tweaks and convenience settings for World of Warcraft: Forever (Interface 16001). Every tweak has its own toggle.

Open the settings with `/ktw`, `/kindouse` or `/kindousetweaks`, or with the minimap button.

## Features

**Unit frames** (off by default)
- Thick, class-coloured health bars on the player and target frames
- Custom text on health and power bars: None, Remaining, Numeric Value, Percentage or Both
- Expressway font on bar numbers

**Action bars**
- Colours action buttons that are out of range, out of mana or unusable, with a colour picker

**World**
- Keeps the game's sparkle on quest loot
- Sparkles on herbs, ore veins, quest objects, lootable corpses and other interactable objects within about 15 yards

**Vendors** (off by default)
- Auto repair
- Auto sell junk (hold Shift while opening the merchant to skip both once)

**Items** (off by default)
- Item level in item tooltips, right below the name
- Quality-coloured borders on items in your bags, bank, character panel and inspect window, optionally on equipment only

**Sound**
- Mutes the spell fizzle sound
- Disables error speech

## Install

Copy the folder into `Interface\AddOns` and name it `KindouseTweaks`.

## Credits

- Sparkles: `Sparkles.lua` and `media/flare.tga` come from [Forever Loot Sparkles - Herbs & Ores](https://www.curseforge.com/wow/addons/forever-loot-sparkles-herbs-ores) 2.1.0 by Sven, which builds on [Forever Loot Sparkles](https://github.com/svengabr/ForeverLootSparkles) by conoar. GPL-3.0-or-later. The changes made are listed at the top of `Sparkles.lua`.
- Action button colouring uses the method of [tullaRange](https://github.com/tullamods/tullaRange), Copyright (c) 2010 Jason Greer, MIT licence (notice below).
- `media/Expressway.ttf` is the Expressway font, (c) 2005 Typodermic (Ray Larabie). It is not covered by the GPL licence of the code.
- The frame art in `media` is an edit of Blizzard's player frame texture. World of Warcraft and its art are the property of Blizzard Entertainment.

## Licence

GPL-3.0-or-later, see [LICENSE](LICENSE).

### tullaRange notice (MIT)

Copyright (c) 2010 Jason Greer

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
