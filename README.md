# Campfire Timer

Campfire Timer shows the remaining life of your campfire as a small countdown bar.
It is a personal addon for WoW Forever (interface 16001).

## How it works

An addon cannot read the campfire object in the world.
Thus the addon starts a clock when you complete the cast of the campfire spell.
The clock counts down from a duration that you set.
At zero, the bar goes out of view.
A new cast starts the countdown again.
The countdown continues after `/reload`.

## The duration (not confirmed)

The default duration is 900 seconds (15 minutes).
The source is the spell data of spell 1307227 (Basic Campfire) on Wowhead.
Some guides give 10 minutes, from an early interview with the developers.
No source measured the time in the game.
Measure the time with `/cft mark`, then set it with `/cft duration <seconds>`.

## The spells

| Spell ID | Name | Effect in the addon |
|---|---|---|
| 1307227 | Basic Campfire (Forever) | starts the countdown |
| 818 | Basic Campfire (old Classic) | starts the countdown |
| 1229737, 1283400, 1291341 | recipes for the campfire kits | no effect |

The spell IDs of the Journeyman Campfire and the Expert Campfire are not known.
For these, the addon looks for "Campfire" in the name of the spell.
This name test works only with the English client.
If a fire does not start the countdown, do this:

1. Type `/cft debug`.
2. Make the fire.
3. Type `/cft log` and find the spell ID of the fire.
4. Type `/cft add <spell ID>`.
5. Type `/cft debug` again to set it to off.

If a spell starts the countdown in error, type `/cft ignore <spell ID>`.

## The fire of a different player

This is not possible. WoW Forever forbids the combat log events to addons.
An addon that registers one of them gets the "blocked from an action" message.
Thus the addon shows only your own fire.

## The minimap button

- A left click hides the box. The countdown continues. A second left click shows the box again.
- A new fire shows the box again.
- A right click shows the box so that you can move it. A second right click locks it.
- Point at the button to see the remaining time.
- Drag the button to move it.

## Commands

| Command | Function |
|---|---|
| `/cft` | Shows the help. |
| `/cft test` | Shows a countdown of 20 seconds. |
| `/cft duration <seconds>` | Sets the life of a fire. |
| `/cft unlock` | Releases the bar. Move it with the left mouse button. |
| `/cft lock` | Locks the bar. The empty bar goes out of view. |
| `/cft hide` and `/cft show` | Hides or shows the box. The countdown continues. |
| `/cft minimap` | Shows or hides the minimap button. |
| `/cft reset` | Puts the position and the settings back to the defaults. |
| `/cft stop` | Stops all countdowns. |
| `/cft mark` | The first use stores the time. The second use prints the elapsed seconds. |
| `/cft log` | Prints the last 10 campfire events (time, event, spell, source). |
| `/cft debug` | Puts all your spell casts in the log. Use it to find a spell ID. |
| `/cft add <spell ID>` | Makes the spell start the countdown. |
| `/cft ignore <spell ID>` | Makes the spell not start the countdown. |

## How to measure the life of a fire

1. Make a campfire.
2. When the cast is complete, type `/cft mark`.
3. When the fire goes out, type `/cft mark` again.
4. Type `/cft duration <seconds>` with the value that the addon prints.

## Limits

- The addon does not know if a fire goes out early.
- The addon does not share fire times between players.
- The saved variable is `CampfireTimerDB`.
