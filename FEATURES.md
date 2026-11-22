# BGComs features

## The callout

On the battlefield map (Shift-M), press the middle mouse button near a place and keep it held. BGComs picks the place nearest to the click, and a wheel opens under the cursor with the place's code in its centre. Drag towards a call and release.

- **INC** (up) and **SPOTTED** (up-right) take a count: each ring further out adds one enemy, from 1 to 5, and past the rim it is "5+". The current count shows under the place's code.
- **HELP** (up-left), **OMW** (down-left), **CLEAR** (down) and **EFC** (down-right) take none.
- **EFC** only exists in battlegrounds with a flag (Warsong Gulch, Darkspear Islands).
- **Releasing in the centre cancels**, and so does a release far from the wheel.
- The wheel shows the message the release will send, under it.

The message goes out in battleground chat as plain text, sent as you, so everyone reads it, with or without the addon. During a match the game doesn't let addons send chat on their own, so the click runs a secure macro, chosen by a secure snippet from the click and the drag. That works in combat.

## Places

| Battleground | Places | Where they come from |
|---|---|---|
| Arathi Basin | `ST`, `GM`, `BS`, `LM`, `Farm` | The map's own points, or built-in positions |
| Warsong Gulch | `our base`, `our ramp`, `our tun`, `our GY`, `mid`, and the same with `their` | Built-in positions. "our" and "their" follow your faction |
| Alterac Valley | `DBN`, `DBS`, `IWB`, `SHB`, `IBT`, `TP`, `EFW`, `WFW`, the graveyards, the mines... | The map's own points. Points without a code keep their own name |
| Darkspear Islands | `tower`, `cove`, `ruins`, `camp`, `mid` | The map's own points, or built-in positions |
| Any other battleground | Its map points | Under their own names |

The codes are drawn on the battlefield map, above each place (`/bgc nodes` hides them). `/bgc place CODE` moves a place, or adds one of your own, with your next click on the map (out of combat). `/bgc forget CODE` undoes it. Places are kept per map.

## The battlefield map

- **Opened in battlegrounds:** when you enter a battleground, BGComs switches the battlefield map's own setting on, and Blizzard's map opens itself (option, on by default).
- **After leaving:** if the map was closed before, its setting goes back to closed, so it won't open by itself outside battlegrounds. It stays on screen until you press Shift-M: BGComs never shows or hides Blizzard's map itself, because doing that from an addon can cause errors in it.
- **Zoom:** the map can be zoomed with the mouse wheel and dragged when zoomed. BGComs follows it out of combat. In combat it keeps the view the fight started with. If the map is zoomed, panned, moved or opened during combat, a warning shows above it and on the wheel, until the fight ends.
- Left and right clicks, and the map's tooltips, still reach the map: only the middle button is taken.

## Options

Options > AddOns > BGComs, `/bgc`, or the addon compartment:

- **The click:** middle-click, or Alt, Ctrl or Shift + middle-click.
- **Open the battlefield map in battlegrounds.**
- **Show the place codes on the map.**
- **Map tooltips under the click area:** untick it if middle-clicks on the map do nothing at all.
- **The six messages:** `<n>` is the count, `<loc>` the place. An empty message switches its call off. "Default messages" puts them back.
- **Test buttons and checks:** see below.

## Test mode

`/bgc test ab` makes the battlefield map work anywhere, with Arathi Basin's map drawn over it and its places. Callouts are shown in your chat only, each with a line saying what was picked. `/bgc test ab say` really sends them, with `/s`, through the same secure path as in battlegrounds. `wsg`, `av` and `dsi` draw the other battlegrounds, `grid` puts a compass grid (N, NE, E...) on whatever map is shown, and `/bgc test off` stops it.

## Cost

BGComs runs nothing per frame outside battlegrounds and test mode. In a battleground it checks the map 5 times a second, and the wheel only works while it is open and the mouse moves. `/bgc perf` measures it in 18 seconds: normal, with the wheel open and a simulated cursor (the worst case), and paused. It prints BGComs' time per frame, its slowest run and the memory it allocates.

## For bug reports

- `/bgc debug` saves what BGComs sees into its saved variables (written on `/reload` or logout): the battleground, the map, the places and where they came from, the game's addon restrictions, and the secure button's state.
- BGComs also keeps a short log of each callout (the place, the drag, the result) in its saved variables.

## Commands

| Command | What it does |
|---|---|
| `/bgc` | Options |
| `/bgc help` | The command list |
| `/bgc test [grid\|ab\|wsg\|av\|dsi] [print\|say\|off]` | Test mode |
| `/bgc place CODE`, `/bgc forget CODE` | Move or add a place, or undo it |
| `/bgc nodes` | Place codes on the map, on or off |
| `/bgc mod none\|alt\|ctrl\|shift` | The key held with the middle button |
| `/bgc motion on\|off` | Whether the click area takes mouse motion (off keeps the map's tooltips) |
| `/bgc perf` | Measure the cost per frame |
| `/bgc debug` | Save the state for a bug report |
