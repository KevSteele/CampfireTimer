# Changelog

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
