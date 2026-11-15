# Campfire Timer

**Summary (for the short field):**
A small countdown box for your campfire in WoW Forever. It shows how long your fire still burns.

---

**Description (for the project page):**

## What it does

Campfire Timer shows the remaining life of your campfire as a small countdown box.

- The countdown starts when you complete the cast of the campfire spell.
- The box shows only during a countdown. At zero, it goes away.
- The box has the look of a plate of the Legacy Challenges view.
- You can move the box to any position on the screen.
- A minimap button hides the box if you go away from your camp. The countdown continues, and the tooltip of the button shows the remaining time.

## Why

The camping system of WoW Forever makes the campfire important. The game shows no clock for the fire. This addon gives you one, so you know when to make a new fire.

## Commands

| Command | Function |
|---|---|
| `/cft` | Shows the help. |
| `/cft test` | Shows a countdown of 20 seconds. |
| `/cft unlock` | Shows the box, so that you can move it. |
| `/cft lock` | Locks the box. Then it shows only during a countdown. |
| `/cft hide` and `/cft show` | Hides or shows the box. The countdown continues. |
| `/cft minimap` | Shows or hides the minimap button. |
| `/cft duration <seconds>` | Sets the life of a fire. |
| `/cft stop` | Stops the countdown. |
| `/cft reset` | Puts the position and the settings back to the defaults. |

## Limits

- The addon shows your own fire only. WoW Forever does not let an addon see the fire of a different player.
- The addon counts from the moment of your cast. If the life of a fire in the game changes with a patch, set the new value with `/cft duration <seconds>`.

## Feedback

Tell me about errors in the comments. Include the text of the error and what you did.
