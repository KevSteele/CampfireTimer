-- Campfire Timer
-- Shows a countdown bar for the life of a campfire, of each camp item that
-- you put near the fire, and of your sleeping bag.
-- An addon cannot read the objects of a camp. Thus the addon starts a clock
-- when it sees the cast of the spell, and counts down from a known duration.

local _, ns = ...

-- The life of a campfire in seconds. The source is the spell data of
-- spell 1307227 (15 minutes). It is not measured in the game.
local DEFAULT_DURATION = 900

-- Spells that put a campfire on the ground: ns.FIRES in Data.lua.
local PLACE_SPELLS = ns.FIRES

-- Spells that make a campfire kit. They have "Campfire" in the name, but
-- they do not put a fire on the ground.
local CRAFT_SPELLS = {
	[1229737] = true, -- Basic Campfire Kit
	[1283400] = true, -- Journeyman Campfire Kit
	[1291341] = true, -- Expert Campfire Kit
}

-- A spell with this text in its name is a campfire spell, unless a list
-- gives a different answer. This is a safety net for a fire spell that
-- the lists do not have.
local NAME_PATTERN = "campfire"

local LOG_SIZE = 20
local LOG_PRINT = 10
local TEST_SECONDS = 20
local BAR_WIDTH, BAR_HEIGHT = 180, 18
local PREFIX = "|cffff9933CampfireTimer|r: "

local db
-- The countdowns. The keys: "own" is your fire, "bag" is your sleeping
-- bag, and "f:<slot>" is a camp item.
-- A value: { finish, duration, label, family, slots }.
local timers = {}
local bars = {} -- bars.own: the box of the fire
local rows = {} -- the small boxes of the camp items and the sleeping bag

local function Print(text)
	print(PREFIX .. text)
end

-- True if the client hides the value from addons.
local function IsSecret(value)
	return issecretvalue ~= nil and issecretvalue(value) == true
end

local function FormatTime(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(seconds / 60), seconds % 60)
end

local function SpellName(spellId)
	local name
	if C_Spell and C_Spell.GetSpellName then
		local ok, result = pcall(C_Spell.GetSpellName, spellId)
		if ok then name = result end
	elseif GetSpellInfo then
		local ok, result = pcall(GetSpellInfo, spellId)
		if ok then name = result end
	end
	if type(name) == "string" and not IsSecret(name) then
		return name
	end
end

-- Gives the aura of the spell on you, or nil.
local function PlayerAura(spellId)
	if not spellId or not C_UnitAuras or not C_UnitAuras.GetPlayerAuraBySpellID then return end
	local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellId)
	if ok and type(aura) == "table" then return aura end
end

-- Gives the remaining seconds of an aura, or nil if the client hides them.
local function AuraRemaining(aura)
	local finish = aura and aura.expirationTime
	if IsSecret(finish) or type(finish) ~= "number" or finish <= 0 then return end
	return math.max(0, finish - GetTime())
end

local function BenefitText(family)
	local benefit = family and ns.BENEFITS[family]
	if not benefit then return end
	local level = UnitLevel and UnitLevel("player") or 60
	if type(level) ~= "number" or level < 1 then level = 60 end
	return benefit.text(level), benefit.aura
end

-- The number of camp items with a countdown.
local function FeatureCount()
	local count = 0
	for key in pairs(timers) do
		if key:sub(1, 2) == "f:" then count = count + 1 end
	end
	return count
end

-- Tells if the spell puts a campfire on the ground.
-- The order of the tests: your setting, the lists, then the name.
local function IsCampfireSpell(spellId, name)
	if type(spellId) == "number" and spellId > 0 then
		local setting = db.spells[spellId]
		if setting ~= nil then return setting end
		if PLACE_SPELLS[spellId] then return true end
		if CRAFT_SPELLS[spellId] then return false end
		name = name or SpellName(spellId)
	end
	if type(name) == "string" then
		local lower = name:lower()
		return lower:find(NAME_PATTERN, 1, true) ~= nil and lower:find("kit", 1, true) == nil
	end
	return false
end

local function AddLog(event, spellId, name, source)
	local log = db.log
	log[#log + 1] = {
		t = time(),
		event = event,
		id = spellId,
		name = name,
		source = source,
	}
	while #log > LOG_SIZE do
		table.remove(log, 1)
	end
end

------------------------------------------------------------------------
-- Bars
------------------------------------------------------------------------

-- A box in the style of the Classic interface: a gold border, an opaque
-- background, the name and the time at the top, and a countdown bar below.
local BOX_WIDTH, BOX_HEIGHT = 220, 48
local ROW_HEIGHT = 36

local function CreateBar(name, r, g, b)
	-- BackdropTemplate can be absent on a client, thus pcall.
	local ok, box = pcall(CreateFrame, "Frame", name, UIParent, "BackdropTemplate")
	if not ok or not box then
		box = CreateFrame("Frame", name, UIParent)
	end
	box:SetSize(BOX_WIDTH, BOX_HEIGHT)
	if box.SetBackdrop then
		box:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 })
		box:SetBackdropBorderColor(0.85, 0.55, 0.30) -- the copper of a Legacy Challenges plate
	end
	local background = box:CreateTexture(nil, "BACKGROUND", nil, -1)
	background:SetPoint("TOPLEFT", 4, -4)
	background:SetPoint("BOTTOMRIGHT", -4, 4)
	background:SetColorTexture(0.16, 0.10, 0.05, 1) -- shows if the parchment file is absent
	-- The parchment of the Legacy Challenges view (the achievement art of the game).
	local paper = box:CreateTexture(nil, "BACKGROUND", nil, 0)
	paper:SetAllPoints(background)
	paper:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
	paper:SetTexCoord(0, 1, 0, 0.5)

	box.label = box:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	box.label:SetPoint("TOPLEFT", 12, -7)
	box.label:SetPoint("RIGHT", box, "RIGHT", -52, 0)
	box.label:SetJustifyH("LEFT")
	box.label:SetWordWrap(false)

	box.time = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	box.time:SetPoint("TOPRIGHT", -12, -7)

	local status = CreateFrame("StatusBar", nil, box)
	status:SetPoint("BOTTOMLEFT", 12, 7)
	status:SetPoint("BOTTOMRIGHT", -12, 7)
	status:SetHeight(12)
	status:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	status:SetStatusBarColor(r, g, b)
	status:SetMinMaxValues(0, 1)
	status:SetValue(1)
	local track = status:CreateTexture(nil, "BACKGROUND")
	track:SetAllPoints(status)
	track:SetColorTexture(0, 0, 0, 0.55)
	box.status = status

	-- The other code sets the values on the box.
	function box:SetMinMaxValues(low, high) self.status:SetMinMaxValues(low, high) end
	function box:SetValue(value) self.status:SetValue(value) end

	box:Hide()
	return box
end

-- A small box for one camp item or for the sleeping bag: the name and the
-- time at the top, the buff below, and a thin countdown bar at the bottom.
local function CreateRow(index)
	local ok, row = pcall(CreateFrame, "Frame", "CampfireTimerRow" .. index, UIParent, "BackdropTemplate")
	if not ok or not row then
		row = CreateFrame("Frame", "CampfireTimerRow" .. index, UIParent)
	end
	row:SetSize(BOX_WIDTH, ROW_HEIGHT)
	if row.SetBackdrop then
		row:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12 })
		row:SetBackdropBorderColor(0.60, 0.42, 0.25)
	end
	local background = row:CreateTexture(nil, "BACKGROUND")
	background:SetPoint("TOPLEFT", 3, -3)
	background:SetPoint("BOTTOMRIGHT", -3, 3)
	background:SetColorTexture(0.10, 0.07, 0.04, 0.92)

	row.time = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	row.time:SetPoint("TOPRIGHT", -10, -6)

	row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	row.label:SetPoint("TOPLEFT", 10, -6)
	row.label:SetPoint("RIGHT", row.time, "LEFT", -6, 0)
	row.label:SetJustifyH("LEFT")
	row.label:SetWordWrap(false)

	row.benefit = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	row.benefit:SetPoint("TOPLEFT", 10, -18)
	row.benefit:SetPoint("RIGHT", row, "RIGHT", -10, 0)
	row.benefit:SetJustifyH("LEFT")
	row.benefit:SetWordWrap(false)

	local status = CreateFrame("StatusBar", nil, row)
	status:SetPoint("BOTTOMLEFT", 5, 4)
	status:SetPoint("BOTTOMRIGHT", -5, 4)
	status:SetHeight(3)
	status:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	status:SetMinMaxValues(0, 1)
	row.status = status

	row:Hide()
	rows[index] = row
	return row
end

-- The sleeping bag goes last. The camp items are in the order of their names.
local function RowOrder(a, b)
	if (a.key == "bag") ~= (b.key == "bag") then return b.key == "bag" end
	if a.label ~= b.label then return a.label < b.label end
	return a.key < b.key
end

-- Gives the countdowns that are not the fire, in the order of the boxes.
local function OtherTimers()
	local list = {}
	for key, timer in pairs(timers) do
		if key ~= "own" then
			timer.key = key
			list[#list + 1] = timer
		end
	end
	table.sort(list, RowOrder)
	return list
end

-- Shows one small box for each countdown that is not the fire. The boxes
-- are in a column below the box of the fire. If the box of the fire does
-- not show, the first small box goes to its position.
local function LayoutRows(now)
	local list = db.dismissed and {} or OtherTimers()
	local anchor = bars.own
	for i, timer in ipairs(list) do
		local row = rows[i] or CreateRow(i)
		row:ClearAllPoints()
		if i == 1 and not bars.own:IsShown() then
			row:SetPoint("TOP", bars.own, "TOP", 0, 0)
		else
			row:SetPoint("TOP", anchor, "BOTTOM", 0, -2)
		end
		anchor = row
		local remaining = timer.finish - now
		row.label:SetText(timer.label)
		row.time:SetText(FormatTime(remaining))
		local text, aura = BenefitText(timer.family)
		row.benefit:SetText(text or "")
		-- Green: you have the buff. Grey: you do not have it.
		if aura and PlayerAura(aura) then
			row.benefit:SetTextColor(0.3, 1.0, 0.3)
		else
			row.benefit:SetTextColor(0.6, 0.6, 0.6)
		end
		row.status:SetMinMaxValues(0, timer.duration)
		row.status:SetValue(remaining)
		if timer.key == "bag" then
			row.status:SetStatusBarColor(0.4, 0.7, 1.0)
		else
			row.status:SetStatusBarColor(1.0, 0.5, 0.1)
		end
		row:Show()
	end
	for i = #list + 1, #rows do
		rows[i]:Hide()
	end
end

local function ApplyPosition()
	local bar = bars.own
	local p = db.point
	bar:ClearAllPoints()
	if p then
		bar:SetPoint(p[1], UIParent, p[2], p[3], p[4])
	else
		bar:SetPoint("CENTER", UIParent, "CENTER", 0, -160)
	end
end

local function ApplyLock()
	bars.own:EnableMouse(not db.locked)
end

local function CreateBars()
	-- Your fire: an orange bar. You move this bar.
	local own = CreateBar("CampfireTimerBar", 1.0, 0.5, 0.1)
	own:SetMovable(true)
	own:SetClampedToScreen(true)
	own:RegisterForDrag("LeftButton")
	own:SetScript("OnDragStart", function(self)
		if not db.locked then self:StartMoving() end
	end)
	own:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local point, _, relativePoint, x, y = self:GetPoint(1)
		db.point = { point, relativePoint, x, y }
	end)
	bars.own = own

	ApplyPosition()
	ApplyLock()
end

local UpdateMinimapButton -- set in the minimap button section

-- Keeps the end time of a countdown, so that /reload does not stop it.
local function Save(key)
	local timer = timers[key]
	if not timer then
		db.ends[key] = nil
		return
	end
	db.ends[key] = {
		t = time() + math.floor(timer.finish - GetTime() + 0.5),
		d = timer.duration,
		l = timer.label,
		f = timer.family,
		s = timer.slots,
	}
end

local function Refresh()
	local now = GetTime()
	for key, timer in pairs(timers) do
		if timer.finish <= now then
			-- The countdown is at zero.
			timers[key] = nil
			db.ends[key] = nil
		end
	end
	if not next(timers) then db.dismissed = nil end

	local bar = bars.own
	local timer = timers.own
	if timer and db.dismissed then
		-- You hid the boxes. The countdowns continue.
		bar:Hide()
	elseif timer then
		local remaining = timer.finish - now
		local label = timer.label
		if timer.slots then
			label = label .. " (" .. FeatureCount() .. "/" .. timer.slots .. ")"
		end
		bar:SetMinMaxValues(0, timer.duration)
		bar:SetValue(remaining)
		bar.label:SetText(label)
		bar.time:SetText(FormatTime(remaining))
		bar:Show()
	elseif not db.locked then
		-- Show an empty bar, so that you can move it.
		bar:SetMinMaxValues(0, 1)
		bar:SetValue(1)
		bar.label:SetText("Campfire")
		bar.time:SetText("")
		bar:Show()
	else
		bar:Hide()
	end
	LayoutRows(now)
	-- The "Hide" button shows only during a countdown of the fire.
	if bar.hide then bar.hide:SetShown(timers.own ~= nil) end
	if UpdateMinimapButton then UpdateMinimapButton() end
end

-- Starts a countdown. "info" can have: family, slots, keep.
-- keep = false: /reload stops the countdown (for a test).
local function StartTimer(key, seconds, label, info)
	timers[key] = {
		finish = GetTime() + seconds,
		duration = seconds,
		label = label,
		family = info and info.family,
		slots = info and info.slots,
	}
	if info and info.keep == false then
		db.ends[key] = nil
	else
		Save(key)
	end
	-- A new countdown shows the boxes again.
	db.dismissed = nil
	Refresh()
end

-- The lines of the summary: the countdowns, then the buffs that you have.
-- Each line is { text, r, g, b }.
local function Summary()
	local now = GetTime()
	local lines = {}
	local function Add(text, r, g, b)
		lines[#lines + 1] = { text, r or 0.8, g or 0.8, b or 0.8 }
	end

	local fire = timers.own
	if fire then
		local text = fire.label .. ": " .. FormatTime(fire.finish - now)
		if fire.slots then
			text = text .. ", camp items " .. FeatureCount() .. " of " .. fire.slots
		end
		Add(text, 1, 0.82, 0)
	end
	for _, timer in ipairs(OtherTimers()) do
		local text = timer.label .. ": " .. FormatTime(timer.finish - now)
		local benefit = BenefitText(timer.family)
		if benefit then text = text .. " - " .. benefit end
		Add(text, 1, 0.82, 0)
	end
	if #lines == 0 then Add("No countdown runs.") end

	-- The buffs. These also come from the camp items of other players.
	local buffs = 0
	for _, family in ipairs(ns.BENEFIT_ORDER) do
		local text, aura = BenefitText(family)
		local found = PlayerAura(aura)
		if found then
			if buffs == 0 then Add("Camp buffs on you:", 1, 1, 1) end
			buffs = buffs + 1
			local remaining = AuraRemaining(found)
			Add("  " .. text .. (remaining and (" (" .. FormatTime(remaining) .. ")") or ""), 0.3, 1.0, 0.3)
		end
	end
	if buffs == 0 then
		local welcome = PlayerAura(ns.AURA_WELCOME)
		local remaining = AuraRemaining(welcome)
		if welcome and remaining then
			Add("The camp buffs come in " .. FormatTime(remaining) .. ". Stay near the fire.")
		elseif PlayerAura(ns.AURA_BENEFITS) then
			Add("You have the camp buff, but the camp has no item with a buff.")
		elseif fire then
			Add("No camp buff yet. Sit near the fire for 1 minute.")
		end
	end
	local rested = PlayerAura(ns.AURA_RESTED)
	if rested then
		local count = rested.applications
		local text = "Well-Rested (sleeping bag)"
		if not IsSecret(count) and type(count) == "number" and count > 1 then
			text = text .. " x" .. count
		end
		local remaining = AuraRemaining(rested)
		Add(text .. (remaining and (" (" .. FormatTime(remaining) .. ")") or ""), 0.3, 1.0, 0.3)
	end
	local cooldown = AuraRemaining(PlayerAura(ns.AURA_COOLDOWN))
	if cooldown then
		Add("Your next camp item: in " .. FormatTime(cooldown) .. ".")
	end
	return lines
end

-- Hides or shows all boxes. The countdowns continue.
local function ToggleBox()
	if not next(timers) then
		Print("no countdown runs.")
		return
	end
	db.dismissed = not db.dismissed or nil
	Refresh()
	if db.dismissed then
		Print("the boxes are hidden. The countdowns continue.")
	end
end

-- The red "Hide" button on the box. It does the same as a left click on the
-- minimap button. The box itself ignores the mouse when it is locked, but
-- the button always gets the click.
local function BuildHideButton()
	local box = bars.own
	local ok, b = pcall(CreateFrame, "Button", "CampfireTimerHideButton", box, "UIPanelButtonTemplate")
	if not ok or not b then return end
	-- The right edge is in line with the countdown bar. 5 pixels of space are
	-- above the button and between the button and the bar.
	b:SetSize(42, 17)
	b:SetPoint("TOPRIGHT", box, "TOPRIGHT", -12, -9)
	b:SetText("Hide")
	if b.SetNormalFontObject then
		b:SetNormalFontObject("GameFontNormalSmall")
		b:SetHighlightFontObject("GameFontHighlightSmall")
	end
	b:SetScript("OnClick", ToggleBox)
	b:Hide()
	box.hide = b
	-- The time goes to the left of the button.
	box.time:ClearAllPoints()
	box.time:SetPoint("RIGHT", b, "LEFT", -6, 0)
	box.label:ClearAllPoints()
	box.label:SetPoint("LEFT", box, "TOPLEFT", 12, -17.5)
	box.label:SetWidth(BOX_WIDTH - 112)
end

local function SetLocked(locked)
	db.locked = locked
	-- To move the box, you must see it.
	if not locked then db.dismissed = nil end
	bars.own:EnableMouse(not locked)
	Refresh()
	Print(locked and "the bar is locked. It shows only during a countdown."
		or "the bar is not locked. Move it with the left mouse button.")
end

------------------------------------------------------------------------
-- The minimap button
------------------------------------------------------------------------

local ICON = "Interface\\Icons\\Spell_Fire_Fire"
local minimapButton

local function PlaceMinimapButton()
	local angle = math.rad(db.minimapAngle or 225)
	local radius = (Minimap:GetWidth() / 2) + 8
	minimapButton:ClearAllPoints()
	minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function ShowButtonTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("Campfire Timer", 1, 1, 1)
	for _, line in ipairs(Summary()) do
		GameTooltip:AddLine(line[1], line[2], line[3], line[4])
	end
	GameTooltip:AddLine(" ")
	if next(timers) then
		GameTooltip:AddLine(db.dismissed and "Left-click: show the boxes." or "Left-click: hide the boxes.", 0.8, 0.8, 0.8)
	end
	GameTooltip:AddLine(db.locked and "Right-click: show the box to move it." or "Right-click: lock the box.", 0.8, 0.8, 0.8)
	GameTooltip:AddLine("Drag: move this button.", 0.8, 0.8, 0.8)
	GameTooltip:Show()
end

UpdateMinimapButton = function()
	if not minimapButton then return end
	-- The icon has full colour while the box of a countdown shows.
	local any = next(timers) ~= nil
	local lit = any and not db.dismissed
	minimapButton.icon:SetDesaturated(not lit)
	minimapButton:SetAlpha(any and 1 or 0.7)
	if GameTooltip:IsOwned(minimapButton) then ShowButtonTooltip(minimapButton) end
end

local function BuildMinimapButton()
	if minimapButton or not Minimap then return end
	local b = CreateFrame("Button", "CampfireTimerMinimapButton", Minimap)
	b:SetSize(32, 32)
	b:SetFrameStrata("MEDIUM")
	b:SetFrameLevel(8)
	local bg = b:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetSize(25, 25)
	bg:SetPoint("TOPLEFT", 2, -4)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetTexture(ICON)
	b.icon:SetSize(22, 22)
	b.icon:SetPoint("TOPLEFT", 6, -5)
	if b.icon.AddMaskTexture and b.CreateMaskTexture then
		local mask = b:CreateMaskTexture()
		mask:SetAllPoints(b.icon)
		mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		b.icon:AddMaskTexture(mask)
	end
	local border = b:CreateTexture(nil, "OVERLAY", nil, 1)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetSize(54, 54)
	border:SetPoint("TOPLEFT")
	b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
	b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	b:RegisterForDrag("LeftButton")
	b:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local scale = Minimap:GetEffectiveScale()
			db.minimapAngle = math.deg(math.atan2(cy / scale - my, cx / scale - mx))
			PlaceMinimapButton()
		end)
	end)
	b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	b:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			SetLocked(not db.locked)
		else
			ToggleBox()
		end
	end)
	b:SetScript("OnEnter", ShowButtonTooltip)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	minimapButton = b
	PlaceMinimapButton()
	b:SetShown(db.minimap ~= false)
	UpdateMinimapButton()
end

local function StartOwnFire(spellId)
	local fire = PLACE_SPELLS[spellId]
	StartTimer("own", db.duration, "Campfire", { slots = fire and fire.slots })
end

-- A camp item. An item with the same slot replaces the item that is there.
local function StartFeature(feature)
	local slot = feature.slot or feature.family
	StartTimer("f:" .. slot, ns.FEATURE_DURATION, feature.name, { family = feature.family })
end

-- The sleeping bag. It does not need a fire.
local function StartBag()
	StartTimer("bag", ns.BAG_DURATION, "Sleeping Bag", { family = "bag" })
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

local function OnPlayerCast(unit, _, spellId)
	if unit ~= "player" then return end
	if IsSecret(spellId) or type(spellId) ~= "number" then return end

	local feature = ns.FEATURES[spellId]
	local isBag = spellId == ns.BAG_SPELL
	local isFire = not feature and not isBag and IsCampfireSpell(spellId)
	if isFire or feature or isBag or db.debug then
		AddLog("CAST", spellId, SpellName(spellId), "you")
	end
	if feature then
		if db.items ~= false then StartFeature(feature) end
	elseif isBag then
		if db.bag ~= false then StartBag() end
	elseif isFire then
		StartOwnFire(spellId)
	end
end

-- The fire of a different player: not possible. WoW Forever forbids the
-- combat log events (COMBAT_LOG_EVENT_UNFILTERED) to addons. To register
-- one of them causes the "blocked from an action" message.

local function OnLoad()
	CampfireTimerDB = CampfireTimerDB or {}
	db = CampfireTimerDB
	if type(db.duration) ~= "number" or db.duration <= 0 then
		db.duration = DEFAULT_DURATION
	end
	-- The bar shows only during a countdown. Thus the default is locked.
	-- Version 2 of the settings sets this one time for an old saved file.
	if db.locked == nil or not db.v2 then db.locked = true end
	db.v2 = true
	db.spells = db.spells or {}
	db.log = db.log or {}

	CreateBars()

	-- Continue the countdowns after /reload or a new login.
	if type(db.ends) ~= "table" then db.ends = {} end
	if db.ownEnd then
		-- The saved value of version 0.2.
		db.ends.own = db.ends.own or { t = db.ownEnd, d = db.duration, l = "Campfire" }
		db.ownEnd = nil
	end
	for key, saved in pairs(db.ends) do
		local remaining = type(saved) == "table" and type(saved.t) == "number" and saved.t - time() or 0
		if remaining > 0 then
			timers[key] = {
				finish = GetTime() + remaining,
				duration = math.max(tonumber(saved.d) or remaining, remaining),
				label = saved.l or "Campfire",
				family = saved.f,
				slots = saved.s,
			}
		else
			db.ends[key] = nil
		end
	end
	if not next(timers) then db.dismissed = nil end
	-- pcall: an error in a button must not stop the countdown.
	pcall(BuildHideButton)
	pcall(BuildMinimapButton)
	Refresh()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if ... ~= "CampfireTimer" then return end
		self:UnregisterEvent("ADDON_LOADED")
		OnLoad()
		-- pcall: if the client refuses an event, the other parts continue.
		pcall(self.RegisterUnitEvent, self, "UNIT_SPELLCAST_SUCCEEDED", "player")
	elseif not db then
		return
	elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
		pcall(OnPlayerCast, ...)
	end
end)

local elapsedTotal = 0
frame:SetScript("OnUpdate", function(_, elapsed)
	elapsedTotal = elapsedTotal + elapsed
	if elapsedTotal < 0.1 then return end
	elapsedTotal = 0
	if db and next(timers) then
		Refresh()
	end
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------

local function PrintHelp()
	Print("commands:")
	print("  /cft camp - print the countdowns and the camp buffs that you have")
	print("  /cft test - show a countdown of " .. TEST_SECONDS .. " seconds")
	print("  /cft test camp - show a fire, two camp items, and a sleeping bag")
	print("  /cft items, /cft bag - count the camp items or the sleeping bag (on or off)")
	print("  /cft duration <seconds> - set the life of a fire (now " .. db.duration .. " s)")
	print("  /cft unlock - show the bar, so that you can move it")
	print("  /cft lock - lock the bar. Then it shows only during a countdown")
	print("  /cft hide, /cft show - hide or show the boxes. The countdowns continue")
	print("  /cft minimap - show or hide the minimap button")
	print("  /cft reset - put the bar and the settings back to the defaults")
	print("  /cft stop - stop all countdowns")
	print("  /cft mark - use two times to measure a time")
	print("  /cft log - print the last campfire events")
	print("  /cft debug - put all your spell casts in the log (on or off)")
	print("  /cft add <spell ID>, /cft ignore <spell ID> - correct the spell list")
end

local function PrintLog()
	local log = db.log
	if #log == 0 then
		Print("the log is empty.")
		return
	end
	Print("the last events (newest last):")
	for i = math.max(1, #log - LOG_PRINT + 1), #log do
		local e = log[i]
		print(string.format("  %s  %s  spell %s (%s)  source: %s",
			date("%H:%M:%S", e.t), tostring(e.event), tostring(e.id or "?"),
			tostring(e.name or "?"), tostring(e.source or "?")))
	end
end

local function Mark()
	if not db.mark then
		db.mark = time()
		Print("the mark is set. Use /cft mark again when the fire goes out.")
		return
	end
	local seconds = time() - db.mark
	db.mark = nil
	Print(string.format("%d seconds (%s) from the mark.", seconds, FormatTime(seconds)))
	Print("to use this value, type /cft duration " .. seconds)
end

local commands = {}

commands.test = function(arg)
	if arg == "camp" then
		StartTimer("own", TEST_SECONDS, "Test", { slots = 3, keep = false })
		StartTimer("f:stats", TEST_SECONDS - 4, "Fish Bowl", { family = "stats", keep = false })
		StartTimer("f:rest", TEST_SECONDS - 8, "Camp Tent", { family = "rest", keep = false })
		StartTimer("bag", TEST_SECONDS + 5, "Sleeping Bag", { family = "bag", keep = false })
	else
		StartTimer("own", TEST_SECONDS, "Test", { keep = false })
	end
	Print("the test countdown runs for " .. TEST_SECONDS .. " seconds.")
end

commands.camp = function()
	Print("the camp:")
	for _, line in ipairs(Summary()) do
		print("  " .. line[1])
	end
end

commands.items = function()
	db.items = db.items == false
	Print(db.items and "a camp item starts a countdown." or "a camp item does not start a countdown.")
end

commands.bag = function()
	db.bag = db.bag == false
	Print(db.bag and "the sleeping bag starts a countdown." or "the sleeping bag does not start a countdown.")
end

commands.duration = function(arg)
	local seconds = tonumber(arg)
	if not seconds or seconds < 1 then
		Print("the duration is " .. db.duration .. " seconds. To change it: /cft duration <seconds>")
		return
	end
	db.duration = math.floor(seconds)
	Print("the duration is now " .. db.duration .. " seconds (" .. FormatTime(db.duration) .. ").")
end

commands.lock = function() SetLocked(true) end
commands.unlock = function() SetLocked(false) end

commands.hide = function()
	if next(timers) and db.dismissed then
		Print("the boxes are hidden already.")
	else
		ToggleBox()
	end
end

commands.show = function()
	if next(timers) and not db.dismissed then
		Print("the boxes show already.")
	else
		ToggleBox()
	end
end

commands.minimap = function()
	db.minimap = db.minimap == false
	if minimapButton then minimapButton:SetShown(db.minimap) end
	Print(db.minimap and "the minimap button shows." or "the minimap button is hidden. Type /cft minimap to show it.")
end

commands.reset = function()
	db.point = nil
	db.dismissed = nil
	db.locked = true
	db.duration = DEFAULT_DURATION
	db.spells = {}
	db.debug = nil
	db.items = nil
	db.bag = nil
	ApplyPosition()
	ApplyLock()
	Refresh()
	Print("the position and the settings are back to the defaults.")
end

commands.stop = function()
	for key in pairs(timers) do
		timers[key] = nil
	end
	db.ends = {}
	db.dismissed = nil
	Refresh()
	Print("all countdowns stopped.")
end

commands.mark = Mark
commands.log = PrintLog

commands.debug = function()
	db.debug = not db.debug or nil
	Print("debug is " .. (db.debug and "on. The log gets all your spell casts." or "off."))
end

commands.add = function(arg)
	local spellId = tonumber(arg)
	if not spellId then
		Print("give a spell ID: /cft add <spell ID>")
		return
	end
	db.spells[spellId] = true
	Print("spell " .. spellId .. " now starts the countdown.")
end

commands.ignore = function(arg)
	local spellId = tonumber(arg)
	if not spellId then
		Print("give a spell ID: /cft ignore <spell ID>")
		return
	end
	db.spells[spellId] = false
	Print("spell " .. spellId .. " does not start the countdown.")
end

SLASH_CAMPFIRETIMER1 = "/cft"
SLASH_CAMPFIRETIMER2 = "/campfiretimer"
SlashCmdList["CAMPFIRETIMER"] = function(message)
	if not db then return end
	local command, arg = (message or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
	local handler = commands[command]
	if handler then
		handler(arg)
	else
		PrintHelp()
	end
end
