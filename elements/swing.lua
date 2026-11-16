--[[
# Element: Swing

Handles creation, visibility and updating of swing timer status bars.

## Widget

Swing - A `StatusBar` to represent swing timer.

## Sub-Widgets

.Time - A `FontString` to represent swing duration.

## Notes

This is not a traditional element; like Auras it only exposes meta functions.

The element only functions in Forever and Classic Era. Era has no native swing timer, so swings are read
from the combat log and `.checkRange` is ignored.

## Options

.showCombat - Keep element shown during combat even when swing duration is depleted (bool?)
.showAlways - Always keep element shown (bool?)
.checkRange - Only show element when in the correct range (bool?)
.smoothing  - Which status bar smoothing method to use, defaults to `Enum.StatusBarInterpolation.Immediate` (number)
.direction  - Which direction the bar move, defaults to `Enum.StatusBarTimerDirection.ElapsedTime` (number)

## Sub-Widget options

.Time.binding   - A [`DurationTextBinding`](https://warcraft.wiki.gg/wiki/ScriptObject_DurationTextBinding) object to override the default
.Time.formatter - A [`NumericFormatter`](https://warcraft.wiki.gg/wiki/ScriptObject_NumericFormatter) to override the default

## Examples

  -- Initialize
  local Swing = self:CreateSwingElement(Enum.PlayerSwingType.Ranged)

  -- Position
  Swing:SetPoint('TOP', self, 'BOTTOM')
  Swing:SetSize(200, 30)

  -- Enable options
  Swing.showCombat = true
  Swing.checkRange = true

--]]
local _, ns = ...
local oUF = ns.oUF

local Private = oUF.Private

local argcheck = Private.argcheck
local nierror = Private.nierror
local GameVersion = Private.GameVersion

local STATE = {}

-- Era has no native swing timer, Enum.PlayerSwingType included
local SwingType = Enum.PlayerSwingType or {MainHand = 0, OffHand = 1, Ranged = 2}

local defaultFormatter = C_StringUtil.CreateSecondsFormatter()
defaultFormatter:SetDefaultAbbreviation(Enum.SecondsFormatterAbbreviation.OneLetter)
defaultFormatter:SetMinInterval(Enum.SecondsFormatterInterval.Seconds)
defaultFormatter:SetMillisecondsThreshold(60)

local function reset(state)
	local element = state.element

	state.isSwinging = false
	state.timer = nil

	element:SetMinMaxValues(0, 1)
	element:SetValue(element.direction == Enum.StatusBarTimerDirection.RemainingTime and 1 or 0)

	if(element.Time) then
		element.Time:SetText('')
	end

	local shouldHide
	if(element.showAlways) then
		shouldHide = false
	else
		shouldHide = not (element.showCombat and state.inCombat)
	end

	if(shouldHide) then
		element:Hide()
	end
end

local function Update(self, event, swingType, ...)
	local state = STATE[self][swingType]
	local element = state.element

	--[[ Callback: Swing:PreUpdate()
	Called before the element has been updated.

	* self - the Swing element
	--]]
	if(element.PreUpdate) then
		element:PreUpdate()
	end

	if(event == 'PLAYER_SWING_RANGE_UPDATE') then
		local isInRange, checksRange = ...
		state.inRange = not checksRange or isInRange
	elseif(event == 'PLAYER_SWING') then
		local swingDuration, startTime = ...
		if(swingDuration and swingDuration > 0) then
			startTime = startTime or GetTime()

			local duration = state.duration
			duration:SetTimeFromStart(startTime, swingDuration)

			element:SetTimerDuration(duration, element.smoothing, element.direction)

			if(element.Time) then
				element.Time.binding:SetDuration(duration)
			end

			if(state.timer) then
				state.timer:Cancel()
			end

			state.isSwinging = true
			state.timer = C_Timer.NewTimer(startTime + swingDuration - GetTime(), GenerateClosure(reset, state))
		end
	elseif(event == 'PLAYER_IN_COMBAT_CHANGED') then
		state.inCombat = not not (...)
	else -- ForceUpdate
		state.inCombat = UnitAffectingCombat('player')
	end

	local shouldShow
	if(not state.inRange) then
		shouldShow = false
	elseif(state.isSwinging or element.showAlways) then
		shouldShow = true
	else
		shouldShow = element.showCombat and state.inCombat
	end

	if(not state.isSwinging) then
		element:SetMinMaxValues(0, 1)
		element:SetValue(element.direction == Enum.StatusBarTimerDirection.RemainingTime and 1 or 0)

		if(element.Time) then
			element.Time:SetText('')
		end
	end

	element:SetShown(not not shouldShow)

	--[[ Callback: Swing:PostUpdate()
	Called after the element has been updated.

	* self      - the Swing element
	* event     - the callback event
	* swingType - the swing type for the element
	* ...       - the remaining payload for the callback
	--]]
	if(element.PostUpdate) then
		return element:PostUpdate(event, swingType, ...)
	end
end

local function Path(self, event, ...)
	if(event == 'PLAYER_SWING_RANGE_UPDATE') then
		local swingType, isInRange, checksRange = ...

		local state = STATE[self][swingType]
		if(state) then
			--[[ Override: Swing.Override(self, event, swingType, ...)
			Used to completely override the internal update function.

			* self      - the parent object
			* event     - the event triggering the update (string)
			* swingType - the swing type for the element (number)
			* ...       - the remaining payload for the event
			--]]
			(state.element.Override or Update)(self, event, swingType, isInRange, checksRange)
		end
	elseif(event == 'PLAYER_SWING') then
		local swingDuration, swingType, startTime = ...

		local state = STATE[self][swingType]
		if(state) then
			(state.element.Override or Update)(self, event, swingType, swingDuration, startTime)
		end
	else
		for swingType, state in next, STATE[self] do
			(state.element.Override or Update)(self, event, swingType, ...)
		end
	end
end

-- Era: swings from the combat log, fed to Path as PLAYER_SWING with an optional start time
local NEXT_MELEE_SPELLS = {78, 845, 2973, 6807} -- Heroic Strike, Cleave, Raptor Strike, Maul
local RANGED_SPELLS = {[75] = true, [5019] = true} -- Auto Shot, Shoot (wand)
local SLOT_SWING_TYPES = {[16] = SwingType.MainHand, [17] = SwingType.OffHand, [18] = SwingType.Ranged}

local playerGUID
local nextMelee -- by name so every rank matches; these replace the next main-hand swing

local function startSwing(self, swingType, speed, startTime)
	local state = STATE[self][swingType]
	if(state and speed) then
		state.start = startTime or GetTime()
		state.speed = speed

		Path(self, 'PLAYER_SWING', speed, swingType, state.start)
	end
end

-- keep the elapsed fraction when the attack speed changes mid-swing
local function rescale(self, swingType, speed)
	local state = STATE[self][swingType]
	if(state and state.isSwinging and speed and speed ~= state.speed) then
		local now = GetTime()
		startSwing(self, swingType, speed, now - (now - state.start) / state.speed * speed)
	end
end

-- parrying cuts 40% of the main-hand swing, leaving at least 20% of it
local function parryHaste(self)
	local state = STATE[self][SwingType.MainHand]
	if(state and state.isSwinging) then
		local now = GetTime()
		local remaining = state.start + state.speed - now
		local minimum = state.speed * 0.2
		if(remaining > minimum) then
			remaining = math.max(remaining - state.speed * 0.4, minimum)
			startSwing(self, SwingType.MainHand, state.speed, now + remaining - state.speed)
		end
	end
end

local function CombatLog(self)
	local _, subEvent, _, sourceGUID, _, _, _, destGUID, _, _, _, arg12, arg13, _, arg15, _, _, _, _, _, arg21 = C_CombatLog.GetCurrentEventInfo()
	if(sourceGUID == playerGUID) then
		if(subEvent == 'SWING_DAMAGE' or subEvent == 'SWING_MISSED') then
			local isOffHand
			if(subEvent == 'SWING_DAMAGE') then
				isOffHand = arg21
			else
				isOffHand = arg13
			end

			local mainSpeed, offSpeed = UnitAttackSpeed('player')
			if(isOffHand) then
				startSwing(self, SwingType.OffHand, offSpeed)
			else
				startSwing(self, SwingType.MainHand, mainSpeed)
			end
		elseif((subEvent == 'SPELL_DAMAGE' or subEvent == 'SPELL_MISSED') and nextMelee[arg13]) then
			startSwing(self, SwingType.MainHand, (UnitAttackSpeed('player')))
		end
	elseif(destGUID == playerGUID) then
		if((subEvent == 'SWING_MISSED' and arg12 == 'PARRY') or (subEvent == 'SPELL_MISSED' and arg15 == 'PARRY')) then
			parryHaste(self)
		end
	end
end

local function RangedShot(self, event, unit, _, spellID)
	if(RANGED_SPELLS[spellID]) then
		startSwing(self, SwingType.Ranged, (UnitRangedDamage('player')))
	end
end

local function AttackSpeedChanged(self)
	local mainSpeed, offSpeed = UnitAttackSpeed('player')
	rescale(self, SwingType.MainHand, mainSpeed)
	rescale(self, SwingType.OffHand, offSpeed)
end

-- a weapon swap restarts its swing
local function EquipmentChanged(self, event, slot)
	local swingType = SLOT_SWING_TYPES[slot]
	local state = swingType and STATE[self][swingType]
	if(state and state.isSwinging) then
		state.timer:Cancel()
		reset(state)
	end
end

local function Disable(self)
	if(STATE[self]) then
		for _, state in next, STATE[self] do
			if(state.timer) then
				state.timer:Cancel()
				state.timer = nil
			end

			local Time = state.element.Time
			if(Time and Time.binding) then
				Time.binding:SetEnabled(false)
			end

			state.isSwinging = nil
			state.element:Hide()
		end

		self:UnregisterEvent('PLAYER_SWING', Path)
		self:UnregisterEvent('PLAYER_SWING_RANGE_UPDATE', Path)
		self:UnregisterEvent('PLAYER_IN_COMBAT_CHANGED', Path)
		self:UnregisterEvent('COMBAT_LOG_EVENT_UNFILTERED', CombatLog)
		self:UnregisterEvent('UNIT_SPELLCAST_SUCCEEDED', RangedShot)
		self:UnregisterEvent('UNIT_ATTACK_SPEED', AttackSpeedChanged)
		self:UnregisterEvent('PLAYER_EQUIPMENT_CHANGED', EquipmentChanged)
	end
end

--[[ Swing: frame:CreateSwingElement(swingType[, templates])
Create and return a swing element.

* self      - The unit frame on which to create the element
* swingType - Swing type (see [Enum.PlayerSwingType](https://warcraft.wiki.gg/wiki/Enum.PlayerSwingType))
* templates - Extra templates to use for the swing element (string?)

## Returns

* Swing - the element used to represent the swing bars
--]]
local function Create(self, swingType, templates)
	argcheck(swingType, 1, 'number')
	argcheck(templates, 2, 'string', 'nil')

	if(GameVersion.Forever and not table.contains(Enum.PlayerSwingType, swingType)) then
		nierror(string.format('Invalid swing type %d passed to CreateSwingElement', swingType))
	end

	if(STATE[self] and STATE[self][swingType]) then
		return STATE[self][swingType].element
	end

	local element = CreateFrame('StatusBar', '$parentSwing' .. swingType, self, templates)
	element.__owner = self

	-- keep a local state of elements created for each frame
	if(not STATE[self]) then
		STATE[self] = {}
	end

	STATE[self][swingType] = {
		element = element,
	}

	if(self.__unit ~= 'player' or not (GameVersion.Forever or GameVersion.Vanilla)) then
		Disable(self)
	end

	return element
end

local function Enable(self, unit)
	if(STATE[self] and unit == 'player' and (GameVersion.Forever or GameVersion.Vanilla)) then
		local shouldCheckRange
		for swingType, state in next, STATE[self] do
			local element = state.element

			state.duration = state.duration or C_DurationUtil.CreateDuration()
			state.inRange = true -- in case we're not checking range

			if(C_SwingTimer) then
				C_SwingTimer.EnableRangeCheck(swingType, not not element.checkRange)
			end

			local Time = element.Time
			if(Time) then
				if(not Time.binding) then
					Time.binding = C_DurationUtil.CreateDurationTextBinding()
					Time.binding:SetFormatter(Time.formatter or defaultFormatter)
				end

				Time.binding:SetFontString(Time)
				Time.binding:SetEnabled(true)
			end

			if(element.checkRange) then
				shouldCheckRange = true
			end

			element:Hide()
		end

		self:RegisterEvent('PLAYER_IN_COMBAT_CHANGED', Path, true)

		if(C_SwingTimer) then
			self:RegisterEvent('PLAYER_SWING', Path, true)

			if(shouldCheckRange) then
				self:RegisterEvent('PLAYER_SWING_RANGE_UPDATE', Path, true)
			end

			C_CVar.SetCVar('showSwingTimer', 0)
		else
			playerGUID = UnitGUID('player')

			if(not nextMelee) then
				nextMelee = {}
				for _, spellID in next, NEXT_MELEE_SPELLS do
					local name = C_Spell.GetSpellName(spellID)
					if(name) then
						nextMelee[name] = true
					end
				end
			end

			self:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED', CombatLog, true)
			self:RegisterEvent('UNIT_SPELLCAST_SUCCEEDED', RangedShot)
			self:RegisterEvent('UNIT_ATTACK_SPEED', AttackSpeedChanged)
			self:RegisterEvent('PLAYER_EQUIPMENT_CHANGED', EquipmentChanged, true)
		end

		return true
	end
end

oUF:AddMetaElement('Swing', Create, Path, Enable, Disable)
