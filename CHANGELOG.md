# Changelog

Each version has a section `## <version> (<date>)` summarising, for players, what is new (`### New`), fixed (`### Fixed`) and changed (`### Changed`). That section, and only that section, is sent to CurseForge as the changelog of the version's file, so it shows on the website and in the CurseForge app. A beta (`1.1.0-beta1`) uses its own section if it has one, otherwise the section of its final version (`1.1.0`). The full feature list is in FEATURES.md.

## 1.0.0 (2026-11-22)

First public release of BGComs - Battle Ground Communications, for World of Warcraft: Forever.

### New

- Middle-click a place on the battlefield map (Shift-M), drag towards a call and release: the callout goes out in battleground chat, where everyone reads it, with or without the addon.
- Six calls: INC and SPOTTED with a count from 1 to 5+ (drag further for more), HELP, OMW, CLEAR, and EFC in flag battlegrounds. Release in the centre to cancel.
- Places for Arathi Basin, Warsong Gulch, Alterac Valley and Darkspear Islands, shown as codes on the map. Move them or add your own with `/bgc place`.
- Works in combat.
- The battlefield map opens by itself when you enter a battleground.
- Options (`/bgc`): the click, your own messages, the map, test buttons.
- Test mode anywhere (`/bgc test ab`): Arathi Basin on your map, callouts shown in your chat only, or really sent with `/s`.
