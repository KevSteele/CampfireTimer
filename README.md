# Campfire Timer

Campfire Timer shows the remaining life of your campfire as a small countdown bar.
It also shows a countdown for each camp item that you put near the fire, and for your sleeping bag.
It is an addon for WoW Forever (interface 16001).

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
| 1307227 | Basic Campfire (3 camp items) | starts the countdown |
| 1307252 | Journeyman Campfire (5 camp items) | starts the countdown |
| 1307237 | Expert Campfire (10 camp items) | starts the countdown |
| 818 | Basic Campfire (old Classic) | starts the countdown |
| 1229737, 1283400, 1291341 | recipes for the campfire kits | no effect |

For a spell that is not in the lists, the addon looks for "Campfire" in the name of the spell.
This name test works only with the English client.
If a fire does not start the countdown, do this:

1. Type `/cft debug`.
2. Make the fire.
3. Type `/cft log` and find the spell ID of the fire.
4. Type `/cft add <spell ID>`.
5. Type `/cft debug` again to set it to off.

If a spell starts the countdown in error, type `/cft ignore <spell ID>`.

## The camp items

A camp item is an object that you put near the fire, for example the Fish Bowl, the Camp Tent, or the Camp Chair.
The addon knows the place spells of 39 camp items. The list is in `CampfireTimer/Data.lua`.
When you put an item, a small box shows below the box of the fire.
The small box shows the name, the remaining time, and the buff of the item at your level.
The text of the buff is green when you have the buff. If not, it is grey.

- The life of a camp item is 15 minutes, from the spell data.
- An item of the same family replaces the earlier item. Example: the Fishing Hut replaces the Fish Bowl.
- The box of the fire shows the number of your items and the limit of the fire, for example "Campfire (1/3)".
- `/cft items` sets the countdowns of the camp items to on or off.

## The sleeping bag

The Cozy Sleeping Bag has its own small box, with a blue bar.
It does not need a fire. If no fire burns, the box of the bag goes to the position of the box of the fire.
The life of the bag is 20 minutes, from the spell data.
`/cft bag` sets this countdown to on or off.

## The summary of the camp buffs

`/cft camp` prints a summary. The tooltip of the minimap button shows the same summary.
The summary has these parts:

1. The countdowns of the fire, the camp items, and the sleeping bag.
2. The camp buffs that you have now, with their remaining time. These also come from the items of other players.
3. The time until the camp buffs start, if you are near a fire and do not have them yet.
4. The Well-Rested buff of the sleeping bag.
5. The time until you can put the next camp item, if the game shows this cooldown as an aura.

The game gives the camp buffs after you sit near the fire for 1 minute.

## The fire of a different player

This is not possible. WoW Forever forbids the combat log events to addons.
An addon that registers one of them gets the "blocked from an action" message.
Thus the addon shows only your own fire and your own camp items.
The summary shows the buffs from the items of other players, because the addon can read your buffs.

## The minimap button

- A left click hides all boxes. The countdowns continue. A second left click shows the boxes again.
- A new fire, a new camp item, or a new sleeping bag shows the boxes again.
- The red "Hide" button on the box does the same as a left click on the minimap button.
- A right click shows the box so that you can move it. A second right click locks it.
- Point at the button to see the summary of the camp.
- Drag the button to move it.

## Commands

| Command | Function |
|---|---|
| `/cft` | Shows the help. |
| `/cft camp` | Prints the countdowns and the camp buffs that you have. |
| `/cft test` | Shows a countdown of 20 seconds. |
| `/cft test camp` | Shows a fire, two camp items, and a sleeping bag for a short time. |
| `/cft items` | Sets the countdowns of the camp items to on or off. |
| `/cft bag` | Sets the countdown of the sleeping bag to on or off. |
| `/cft duration <seconds>` | Sets the life of a fire. |
| `/cft unlock` | Releases the bar. Move it with the left mouse button. |
| `/cft lock` | Locks the bar. The empty bar goes out of view. |
| `/cft hide` and `/cft show` | Hides or shows the boxes. The countdowns continue. |
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
- The addon does not know if a camp item goes away when its fire goes out. Each item has its own countdown.
- The durations and the values of the buffs come from the spell data of build 1.60.1.71037. They are not measured in the game.
- The names of the camp items are in English.
- The addon does not share fire times between players.
- The saved variable is `CampfireTimerDB`.
