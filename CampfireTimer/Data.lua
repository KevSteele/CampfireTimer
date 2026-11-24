-- Campfire Timer: the data of the camp items.
-- The source is the spell data of game build 1.60.1.71037 (wago.tools).
-- The values are not measured in the game.

local _, ns = ...

-- The life of a camp item and of the sleeping bag, in seconds.
ns.FEATURE_DURATION = 900
ns.BAG_DURATION = 1200

-- The spell of the item "Cozy Sleeping Bag" (Unroll Bag).
ns.BAG_SPELL = 429961

-- Auras that the game puts on you at a camp.
ns.AURA_BENEFITS = 1229741 -- Camp Benefits: you have the buffs of the camp
ns.AURA_WELCOME = 1229739 -- Welcoming Campfire: the minute before the buffs
ns.AURA_COOLDOWN = 1308027 -- Camping: the cooldown that all camp items share
ns.AURA_RESTED = 429959 -- Well-Rested: the buff of the sleeping bag

-- Spells that put a campfire on the ground. "slots" is the number of camp
-- items that the fire permits.
ns.FIRES = {
	[1307227] = { slots = 3 }, -- Basic Campfire
	[1307252] = { slots = 5 }, -- Journeyman Campfire
	[1307237] = { slots = 10 }, -- Expert Campfire
	[818] = {}, -- Basic Campfire (old Classic spell)
}

-- Gives the value for a level. "tiers" is a list of pairs: below this
-- level, this value. "top" is the value for all higher levels.
local function Tier(level, tiers, top)
	for i = 1, #tiers, 2 do
		if level < tiers[i] then return tiers[i + 1] end
	end
	return top
end

-- The buffs of a camp. The key is the family of the camp item.
-- aura: the buff that you get. text: the effect at your level.
ns.BENEFITS = {
	mana = { aura = 1230587, text = function(level)
		return Tier(level, { 24, 10, 34, 15, 44, 20, 54, 24 }, 29) .. " mana each 5 sec"
	end },
	strength = { aura = 1230172, text = function(level)
		return "+" .. Tier(level, { 24, 6, 38, 11, 52, 20 }, 34) .. " Strength"
	end },
	lute = { aura = 1230653, text = function(level)
		local text = "+" .. Tier(level, { 10, 28, 20, 71, 30, 114, 40, 163, 50, 211, 60, 260 }, 308) .. " Armor"
		local stats = Tier(level, { 10, 0, 20, 2, 30, 4, 40, 7, 50, 9, 60, 12 }, 13)
		local resist = Tier(level, { 30, 0, 40, 6, 50, 12, 60, 16 }, 22)
		if stats > 0 then text = text .. ", +" .. stats .. " stats" end
		if resist > 0 then text = text .. ", +" .. resist .. " resist" end
		return text
	end },
	stamina = { aura = 1230124, text = function(level)
		return "+" .. Tier(level, { 12, 3, 24, 8, 36, 21, 48, 34, 60, 45 }, 56) .. " Stamina"
	end },
	stats = { aura = 1230098, text = function() return "+8% all stats" end },
	intellect = { aura = 1229513, text = function(level)
		return "+" .. Tier(level, { 14, 2, 28, 6, 42, 12, 56, 18 }, 25) .. " Intellect"
	end },
	power = { aura = 1230164, text = function(level)
		return "+" .. Tier(level, { 12, 12, 22, 20, 32, 32, 42, 49, 52, 67 }, 90) .. " melee Attack Power"
	end },
	crit = { aura = 1229519, text = function() return "+2% critical strike" end },
	spirit = { aura = 1229718, text = function(level)
		return "+" .. Tier(level, { 40, 14, 50, 19, 60, 27 }, 32) .. " Spirit"
	end },
	-- The tents give rested experience at once. They give no buff.
	rest = { text = function() return "Rested XP to 5% of a level" end },
	rest20 = { text = function() return "Rested XP to 20% of a level (party)" end },
	bag = { aura = 429959, text = function() return "Rest 1 minute: bonus XP" end },
}

-- The order of the buffs in the summary.
ns.BENEFIT_ORDER = { "stats", "lute", "stamina", "strength", "power", "crit", "intellect", "spirit", "mana" }

-- Spells that put a camp item near the fire.
-- name: the name of the item. family: the buff that the item gives.
-- slot: an item with the same slot replaces the item that is there. If
-- there is no slot, the family is the slot.
ns.FEATURES = {
	[1307259] = { name = "Mana Well", family = "mana" },
	[1307172] = { name = "Alchemy Laboratory", family = "mana" },
	[1307242] = { name = "Fermenter", family = "mana" },
	[1307392] = { name = "Sharpening Wheel", family = "strength" },
	[1307175] = { name = "Anvil", family = "strength" },
	[1307261] = { name = "Master Forge", family = "strength" },
	[1307234] = { name = "Enchanted Lute", family = "lute" },
	[1307176] = { name = "Arcane Forge", family = "lute" },
	[1307223] = { name = "Arcane Salvager", family = "lute" },
	[1307244] = { name = "First Aid Kit", family = "stamina" },
	[1307265] = { name = "Plague Doctor's Laboratory", family = "stamina" },
	[1307396] = { name = "Toxin Study", family = "stamina" },
	[1307245] = { name = "Fish Bowl", family = "stats" },
	[1307246] = { name = "Fishing Hut", family = "stats" },
	[1307247] = { name = "Fishing Rack", family = "stats" },
	[1307251] = { name = "Incense Candle", family = "intellect" },
	[1307248] = { name = "Greenhouse", family = "intellect" },
	[1307387] = { name = "Seed Hybridizer", family = "intellect" },
	[1307254] = { name = "Lodestone", family = "power" },
	[1307264] = { name = "Molten Foundry", family = "power" },
	[1307386] = { name = "Rock Garden", family = "power" },
	[1307229] = { name = "Camp Chair", family = "crit" },
	[1307243] = { name = "Field Guide", family = "crit" },
	[1307397] = { name = "Trapper's Workbench", family = "crit" },
	[1307239] = { name = "Faction Banner", family = "spirit" }, -- Alliance
	[1307240] = { name = "Faction Banner", family = "spirit" }, -- Horde
	[1307255] = { name = "Loom", family = "spirit" },
	[1307393] = { name = "Spinning Wheel", family = "spirit" },
	[1307230] = { name = "Camp Tent", family = "rest" },
	[1307391] = { name = "Sewing Machine", family = "rest" },
	[1307395] = { name = "Tanning Rack", family = "rest" },
	[1325145] = { name = "Adventurer's Tent", family = "rest20" },
	-- Items that give no buff.
	[1307266] = { name = "Reagent Bot", slot = "bot" },
	[1307385] = { name = "Repair Bot", slot = "bot" },
	[1307174] = { name = "Anarchist's Workbench", slot = "workbench" },
	[1307226] = { name = "Iron Oven", slot = "oven" },
	[1307257] = { name = "Cookie's Feast", slot = "feast" },
	[1302502] = { name = "Library Shelf", slot = "shelf" },
	[1303543] = { name = "Scarlet Banner", slot = "scarlet" },
}
