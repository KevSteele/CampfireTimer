# Campfire Timer

**Summary (for the short field):**
Countdown boxes for your campfire, your camp items, and your sleeping bag in WoW Forever, with a summary of the camp buffs.

---

**Description (for the project page):**

## What it does

Campfire Timer shows the remaining life of your campfire as a small countdown box.

- The countdown starts when you complete the cast of the campfire spell.
- Each camp item that you put near the fire gets its own small box: the Fish Bowl, the Camp Tent, the Camp Chair, and 36 more.
- A small box shows the buff of the item at your level. The text is green when you have the buff.
- The Cozy Sleeping Bag has its own box. It does not need a fire.
- The box of the fire shows the number of your camp items and the limit of the fire.
- `/cft camp` and the tooltip of the minimap button show a summary: the countdowns and the camp buffs that you have now.
- The boxes show only during a countdown. At zero, they go away.
- The box has the look of a plate of the Legacy Challenges view.
- You can move the box to any position on the screen.
- The "Hide" button on the box, or the minimap button, hides the boxes if you go away from your camp. The countdowns continue.

## Why

The camping system of WoW Forever makes the campfire important. The game shows no clock for the fire or for the camp items. This addon gives you one, so you know when to make a new fire.

## Commands

| Command | Function |
|---|---|
| `/cft` | Shows the help. |
| `/cft camp` | Prints the countdowns and the camp buffs that you have. |
| `/cft test` | Shows a countdown of 20 seconds. |
| `/cft test camp` | Shows a fire, two camp items, and a sleeping bag for a short time. |
| `/cft items`, `/cft bag` | Sets the countdowns of the camp items or of the sleeping bag to on or off. |
| `/cft unlock` | Shows the box, so that you can move it. |
| `/cft lock` | Locks the box. Then it shows only during a countdown. |
| `/cft hide` and `/cft show` | Hides or shows the boxes. The countdowns continue. |
| `/cft minimap` | Shows or hides the minimap button. |
| `/cft duration <seconds>` | Sets the life of a fire. |
| `/cft stop` | Stops all countdowns. |
| `/cft reset` | Puts the position and the settings back to the defaults. |

## Limits

- The addon shows your own fire and your own camp items only. WoW Forever does not let an addon see the objects of a different player. The summary does show the buffs that you get from their items.
- The durations and the values of the buffs come from the spell data of the game. They are not measured in the game.
- The addon counts from the moment of your cast. If the life of a fire in the game changes with a patch, set the new value with `/cft duration <seconds>`.

## Feedback

Tell me about errors in the comments. Include the text of the error and what you did.
