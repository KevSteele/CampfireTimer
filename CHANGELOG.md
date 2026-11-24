# Changelog

## 0.3.0 (2026-11-24)

- New: a countdown for each camp item that you put near the fire, for example the Fish Bowl or the Camp Tent. Each item has a small box below the box of the fire.
- New: a countdown for the Cozy Sleeping Bag. It does not need a fire.
- Each small box shows the buff of the item at your level. The text is green when you have the buff.
- The box of the fire shows the number of your camp items and the limit of the fire, for example "Campfire (1/3)".
- New: `/cft camp` prints a summary of the countdowns and of the camp buffs that you have. The tooltip of the minimap button shows the same summary.
- The spells of the Journeyman Campfire and the Expert Campfire are now in the list.
- `/cft items` and `/cft bag` set these countdowns to on or off.
- `/cft test camp` shows an example of all boxes.
- The box is wider.

## 0.2.1 (2026-11-15)

- A red "Hide" button on the box. It does the same as a left click on the minimap button.

## 0.2.0 (2026-11-15)

- A minimap button. A left click hides or shows the box. The countdown continues while the box is hidden.
- A new fire shows the box again.
- A right click on the button shows the box so that you can move it, or locks it.
- The tooltip of the button shows the remaining time.
- `/cft hide`, `/cft show`, and `/cft minimap`.

## 0.1.0 (2026-11-14)

- First version.
- A countdown box for your own campfire. It starts when you complete the cast of the campfire spell.
- The box has the look of a plate of the Legacy Challenges view. It shows only during a countdown.
- `/cft unlock` shows the box so that you can move it. `/cft lock` hides it again.
- `/cft duration <seconds>` sets the life of a fire. The default is 900 seconds, from the spell data. It is not measured in the game.
- `/cft mark` measures a time. `/cft log` prints the last campfire events.
- A countdown for the fire of a different player is not possible. WoW Forever forbids the combat log events to addons.
