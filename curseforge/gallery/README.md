# Gallery

Images for the CurseForge gallery go in this folder.

`private/` is ignored by git. It keeps the originals that don't belong in the repository: captures too large to commit, and screenshots showing a character name. CurseForge shows each image with a title and a description, so each one below has both ready to paste.

To show one in the description or the README, commit it here and load it in the description from `https://raw.githubusercontent.com/Malven31/battle-ground-communications/main/curseforge/gallery/<file>` (the README uses the relative path). That needs the repository to be public.

## Captures in this folder

| File | What it shows | Title | Description |
|---|---|---|---|
| `bgcoms_1.gif` | In the game, Arathi Basin's battlefield map: a middle-click on BS opens the wheel, a drag three rings out towards SPOTTED (x3), the release sends "3 spotted BS" (367×253, 60 frames, 4.2 s, 3.2 MB) | One gesture | Middle-click a base, drag towards a call: further means more enemies. Release, and it is in battleground chat. |
| `options.png` | The options page (`/bgc`), in the game: the click, the battlefield map settings, the six messages, the test and check buttons (710×643). The game's "Capture d'écran sauvegardée" (screenshot saved) message shows over its middle | Options | Choose the click, write your own messages, and try it all outside battlegrounds. |

`description.md` and the repository's README show the GIF, loaded from this folder. Checked frame by frame (2026-11-22): only the map, the wheel, the game's base tooltip and the callout. No chat window, no player frame, no readable name. `options.png` (2026-11-22, committed 2026-11-23) shows only the options page: no name.

## Illustrations in this folder

Drawn by `scripts/make-gallery.ps1` (1280×720) on the real Arathi Basin map art, with the addon's own layout: the same directions, count rings, place codes and messages. The wheel's disc, glow and icons come from `scripts/wheel-art.ps1`, the drawing the addon's textures are made from (since 1.0.1), so they look as in the game. Only the font differs: the game uses its own. They are still illustrations, not game captures. No character names (the sender is "You"). Replace them with real screenshots when there are some.

`bgcoms_1.gif` was recorded with 1.0.0, whose wheel used Blizzard's ping icons (a sword, a green flag, a blue arrow). From 1.0.1 the wheel looks like the illustrations: record it again then.

| File | What it shows | Title | Description |
|---|---|---|---|
| `1-map.png` | The battlefield map with the place codes | Your bases, named | BGComs marks the places it knows on the battlefield map (Shift-M). |
| `2-wheel.png` | A middle-click on Gold Mine, dragged three rings up: "3 inc GM" | One gesture | Middle-click a base, drag towards a call: further means more enemies. Release to send. |
| `3-chat.png` | Six callouts in battleground chat | Everyone reads it | Callouts are plain text in battleground chat: your team needs no addon. |
| `4-calls.png` | The wheel and what each direction sends | Six calls | Incoming and spotted take a count; help, on my way, clear and the enemy flag carrier don't. |

## Screenshots to take

- Take them with the in-game screenshot key (Print Screen). They are saved in `_forever_\Screenshots`.
- Crop them: no character names, no player frame, and only BGComs' lines in the chat.
- `/bgc test ab` (chat only) or `/bgc test ab say` shows everything outside a battleground.

| File | What to show | Title | Description |
|---|---|---|---|
| `01-wheel.jpg` | The wheel open over the battlefield map, a call selected | One gesture | Middle-click a base, drag towards a call, release. |
| `02-chat.jpg` | A few callouts in the chat window (`/bgc test ab say`) | Everyone reads it | Plain text in battleground chat. |
| `03-map.jpg` | The battlefield map in a battleground with the place codes | Your bases, named | The codes the callouts use. |

Rename or drop shots freely.
