-- Campfire Timer
-- Shows a countdown bar for the life of a campfire.
-- An addon cannot read the campfire object. Thus the addon starts a clock
-- when it sees the cast of the campfire spell, and counts down from a
-- duration that you can set.

-- The life of a campfire in seconds. The source is the spell data of
-- spell 1307227 (15 minutes). It is not measured in the game.
local DEFAULT_DURATION = 900

-- Spells that put a campfire on the ground.
local PLACE_SPELLS = {
	[1307227] = true, -- Basic Campfire (WoW Forever, from the spell data)
	[818] = true, -- Basic Campfire (old Classic spell)
}

-- Spells that make a campfire kit. They have "Campfire" in the name, but
-- they do not put a fire on the ground.
local CRAFT_SPELLS = {
	[1229737] = true, -- Basic Campfire Kit
	[1283400] = true, -- Journeyman Campfire Kit
	[1291341] = true, -- Expert Campfire Kit
}

-- A spell with this text in its name is a campfire spell, unless a list
-- gives a different answer. This finds the Journeyman and Expert spells,
-- because their spell IDs are not known.
local NAME_PATTERN = "campfire"

local LOG_SIZE = 20
local LOG_PRINT = 10
local TEST_SECONDS = 20
local BAR_WIDTH, BAR_HEIGHT = 180, 18
local PREFIX = "|cffff9933CampfireTimer|r: "

local db
local timers = {} -- own = { finish, duration, label }, other = { ... }
local bars = {}

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
local BOX_WIDTH, BOX_HEIGHT = 190, 42

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

	-- The fire of a different player: a blue bar below your bar.
	local other = CreateBar("CampfireTimerOtherBar", 0.3, 0.6, 1.0)
	other:SetPoint("TOP", own, "BOTTOM", 0, -3)
	bars.other = other

	ApplyPosition()
	ApplyLock()
end

local function Refresh()
	local now = GetTime()
	for key, bar in pairs(bars) do
		local timer = timers[key]
		if timer and timer.finish <= now then
			-- The countdown is at zero.
			timers[key] = nil
			timer = nil
			if key == "own" then db.ownEnd = nil end
		end
		if timer then
			local remaining = timer.finish - now
			bar:SetMinMaxValues(0, timer.duration)
			bar:SetValue(remaining)
			bar.label:SetText(timer.label)
			bar.time:SetText(FormatTime(remaining))
			bar:Show()
		elseif key == "own" and not db.locked then
			-- Show an empty bar, so that you can move it.
			bar:SetMinMaxValues(0, 1)
			bar:SetValue(1)
			bar.label:SetText("Campfire")
			bar.time:SetText("")
			bar:Show()
		else
			bar:Hide()
		end
	end
end

local function StartTimer(key, seconds, label)
	timers[key] = {
		finish = GetTime() + seconds,
		duration = seconds,
		label = label,
	}
	Refresh()
end

local function StartOwnFire()
	StartTimer("own", db.duration, "Campfire")
	-- Keep the end time, so that /reload does not stop the countdown.
	db.ownEnd = time() + db.duration
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------

local function OnPlayerCast(unit, _, spellId)
	if unit ~= "player" then return end
	if IsSecret(spellId) or type(spellId) ~= "number" then return end

	local isFire = IsCampfireSpell(spellId)
	if isFire or db.debug then
		AddLog("CAST", spellId, SpellName(spellId), "you")
	end
	if isFire then
		StartOwnFire()
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

	-- Continue the countdown after /reload or a new login.
	if db.ownEnd then
		local remaining = db.ownEnd - time()
		if remaining > 0 then
			timers.own = {
				finish = GetTime() + remaining,
				duration = math.max(db.duration, remaining),
				label = "Campfire",
			}
		else
			db.ownEnd = nil
		end
	end
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
	if db and (timers.own or timers.other) then
		Refresh()
	end
end)

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------

local function PrintHelp()
	Print("commands:")
	print("  /cft test - show a countdown of " .. TEST_SECONDS .. " seconds")
	print("  /cft duration <seconds> - set the life of a fire (now " .. db.duration .. " s)")
	print("  /cft unlock - show the bar, so that you can move it")
	print("  /cft lock - lock the bar. Then it shows only during a countdown")
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

commands.test = function()
	StartTimer("own", TEST_SECONDS, "Test")
	db.ownEnd = nil
	Print("the test countdown runs for " .. TEST_SECONDS .. " seconds.")
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

commands.lock = function()
	db.locked = true
	ApplyLock()
	Refresh()
	Print("the bar is locked. It shows only during a countdown.")
end

commands.unlock = function()
	db.locked = false
	ApplyLock()
	Refresh()
	Print("the bar is not locked. Move it with the left mouse button.")
end

commands.reset = function()
	db.point = nil
	db.locked = true
	db.duration = DEFAULT_DURATION
	db.spells = {}
	db.debug = nil
	ApplyPosition()
	ApplyLock()
	Refresh()
	Print("the position and the settings are back to the defaults.")
end

commands.stop = function()
	timers.own = nil
	timers.other = nil
	db.ownEnd = nil
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
