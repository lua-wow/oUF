--[[
# Element: Health Bar

Handles the updating of a status bar that displays the unit's health.

## Widget

Health - A `StatusBar` used to represent the unit's health.

## Sub-Widgets

.TempLoss                  - A `StatusBar` used to represent temporary max health reduction.
.bg                        - A `Texture` used as a background. It will inherit the color of the main StatusBar.
.HealingAll                - A `StatusBar` used to represent incoming heals from all sources.
.HealingPlayer             - A `StatusBar` used to represent incoming heals from the player.
.HealingOther              - A `StatusBar` used to represent incoming heals from others.
.OverHealIndicator         - A `Texture` used to indicate that the incoming healing is greater than the configured limits.
.DamageAbsorb              - A `StatusBar` used to represent damage absorbs.
.OverDamageAbsorbIndicator - A `Texture` used to signify that the amount of damage absorb is greater than the configured limits.
.HealAbsorb                - A `StatusBar` used to represent heal absorbs.
.OverHealAbsorbIndicator   - A `Texture` used to signify that the amount of heal absorb is greater than the configured limits.

## Notes

A default texture will be applied if the widget is a StatusBar and doesn't have a texture set.
A default texture will be applied to the Texture widgets if they don't have a texture or a color set.

## Options

.smoothGradient                   - 9 color values to be used with the .colorSmooth option (table)
.considerSelectionInCombatHostile - Indicates whether selection should be considered hostile while the unit is in
                                    combat with the player (boolean)
.maximumHealthClampMode           - Defines how maximum health should clamp. See [Enum.UnitMaximumHealthMode](https://warcraft.wiki.gg/wiki/Enum.UnitMaximumHealthMode).
.damageAbsorbClampMode            - Defines how damage absorbs should clamp. See [Enum.UnitDamageAbsorbClampMode](https://warcraft.wiki.gg/wiki/Enum.UnitDamageAbsorbClampMode).
.healAbsorbClampMode              - Defines how healing absorbs should clamp. See [Enum.UnitHealAbsorbClampMode](https://warcraft.wiki.gg/wiki/Enum.UnitHealAbsorbClampMode).
.healAbsorbMode                   - Defines how healing absorbs should be treated. See [Enum.UnitHealAbsorbMode](https://warcraft.wiki.gg/wiki/Enum.UnitHealAbsorbMode).
.incomingHealClampMode            - Defines how incoming healing should clamp. See [Enum.UnitIncomingHealClampMode](https://warcraft.wiki.gg/wiki/Enum.UnitIncomingHealClampMode).
.incomingHealOverflow             - The maximum amount of overflow past the end of the health bar. Set this to 1 to disable the overflow.
                                    Defaults to 1.05 (number)

The following options are listed by priority. The first check that returns true decides the color of the bar.

.colorDisconnected - Use `self.colors.disconnected` to color the bar if the unit is offline (boolean)
.colorTapping      - Use `self.colors.tapping` to color the bar if the unit isn't tapped by the player (boolean)
.colorThreat       - Use `self.colors.threat[threat]` to color the bar based on the unit's threat status. `threat` is
                     defined by the first return of [UnitThreatSituation](https://warcraft.wiki.gg/wiki/API_UnitThreatSituation) (boolean)
.colorClass        - Use `self.colors.class[class]` to color the bar based on unit class. `class` is defined by the
                     second return of [UnitClass](https://warcraft.wiki.gg/wiki/API_UnitClass) (boolean)
.colorClassNPC     - Use `self.colors.class[class]` to color the bar if the unit is a NPC (boolean)
.colorClassPet     - Use `self.colors.class[class]` to color the bar if the unit is player controlled, but not a player
                     (boolean)
.colorSelection    - Use `self.colors.selection[selection]` to color the bar based on the unit's selection color.
                     `selection` is defined by the return value of Private.unitSelectionType, a wrapper function
                     for [UnitSelectionType](https://warcraft.wiki.gg/wiki/API_UnitSelectionType) (boolean)
.colorReaction     - Use `self.colors.reaction[reaction]` to color the bar based on the player's reaction towards the
                     unit. `reaction` is defined by the return value of
                     [UnitReaction](https://warcraft.wiki.gg/wiki/API_UnitReaction) (boolean)
.colorSmooth       - Use `smoothGradient` if present or `self.colors.smooth` to color the bar with a smooth gradient
                     based on the player's current health percentage (boolean)
.colorHealth       - Use `self.colors.health` to color the bar. This flag is used to reset the bar color back to default
                     if none of the above conditions are met (boolean)

## Sub-Widgets Options

.multiplier - Used to tint the background based on the main widgets R, G and B values. Defaults to 1 (number)[0-1]

## Attributes

.values - A [unit health prediction calculator](https://warcraft.wiki.gg/wiki/API_CreateUnitHealPredictionCalculator) used to calculate the values of the prediction sub-widgets.

## Examples

    -- Position and size
    local Health = CreateFrame('StatusBar', nil, self)
    Health:SetHeight(20)
    Health:SetPoint('TOP')
    Health:SetPoint('LEFT')
    Health:SetPoint('RIGHT')

    -- Add a background
    local Background = Health:CreateTexture(nil, 'BACKGROUND')
    Background:SetAllPoints()
    Background:SetTexture(1, 1, 1, .5)

    -- Options
    Health.colorTapping = true
    Health.colorDisconnected = true
    Health.colorClass = true
    Health.colorReaction = true
    Health.colorHealth = true

    -- Make the background darker.
    Background.multiplier = .5

    -- Register it with oUF
    Health.bg = Background
    self.Health = Health

    -- Alternatively, if .TempLoss is being used
    local TempLoss = CreateFrame('StatusBar', nil, self)
    TempLoss:SetReverseFill(true)
    TempLoss:SetHeight(20)
    TempLoss:SetPoint('TOP')
    TempLoss:SetPoint('LEFT')
    TempLoss:SetPoint('RIGHT')

    local Health = CreateFrame('StatusBar', nil, self)
    Health:SetPoint('LEFT')
    Health:SetPoint('TOPRIGHT', TempLoss:GetStatusBarTexture(), 'TOPLEFT')
    Health:SetPoint('BOTTOMRIGHT', TempLoss:GetStatusBarTexture(), 'BOTTOMLEFT')

    -- Add a background
    local Background = TempLoss:CreateTexture(nil, 'BACKGROUND')
    Background:SetAllPoints()
    Background:SetTexture(1, 1, 1, .5)

    -- Options
    Health.colorTapping = true
    Health.colorDisconnected = true
    Health.colorClass = true
    Health.colorReaction = true
    Health.colorHealth = true

    -- Make the background darker.
    Background.multiplier = .5

    -- Register it with oUF
    Health.TempLoss = TempLoss
    Health.bg = Background
    self.Health = Health
--]]

local _, ns = ...
local oUF = ns.oUF
local Private = oUF.Private

local STATE = {}

local UnitSelectionColor = Private.UnitSelectionColor
local SmoothColor = Private.SmoothColor

local function UpdateColor(self, event, unit)
	if(not unit or self.__unit ~= unit) then return end
	local element = self.Health

	local selectionColor = UnitSelectionColor(unit, element.considerSelectionInCombatHostile)

	local r, g, b, color
	if(element.colorDisconnected and not UnitIsConnected(unit)) then
		color = self.colors.disconnected
	elseif(element.colorTapping and not UnitPlayerControlled(unit) and UnitIsTapDenied(unit)) then
		color = self.colors.tapped
	elseif(element.colorThreat and not UnitPlayerControlled(unit) and UnitThreatSituation('player', unit)) then
		color =  self.colors.threat[UnitThreatSituation('player', unit)]
	elseif(element.colorClass and (UnitIsPlayer(unit) or UnitInPartyIsAI(unit)))
		or (element.colorClassNPC and not (UnitIsPlayer(unit) or UnitInPartyIsAI(unit)))
		or (element.colorClassPet and UnitPlayerControlled(unit) and not UnitIsPlayer(unit)) then
		local _, class = UnitClass(unit)
		color = self.colors.class[class]
	elseif(element.colorSelection and selectionColor) then
		color = selectionColor
	elseif(element.colorReaction and UnitReaction(unit, 'player')) then
		color = self.colors.reaction[UnitReaction(unit, 'player')]
	elseif(element.colorSmooth) then
		r, g, b = self:ColorGradient(element.cur or 1, element.max or 1, unpack(element.smoothGradient or self.colors.smooth))
		color = SmoothColor(element, r, g, b)
	elseif(element.colorHealth) then
		color = self.colors.health
	end

	if(color) then
		r, g, b = color[1], color[2], color[3]
	end

	if(b) then
		element:SetStatusBarColor(r, g, b)

		local bg = element.bg
		if(bg) then
			local mu = bg.multiplier or 1
			bg:SetVertexColor(r * mu, g * mu, b * mu)
		end
	end

	--[[ Callback: Health:PostUpdateColor(unit, color)
	Called after the element color has been updated.

	* self  - the Health element
	* unit  - the unit for which the update has been triggered (string)
	* color - the used ColorMixin-based object (table?)
	--]]
	if(element.PostUpdateColor) then
		element:PostUpdateColor(unit, color)
	end
end

local function ColorPath(self, ...)
	--[[ Override: Health.UpdateColor(self, event, unit)
	Used to completely override the internal function for updating the widgets' colors.

	* self  - the parent object
	* event - the event triggering the update (string)
	* unit  - the unit accompanying the event (string)
	--]]
	(self.Health.UpdateColor or UpdateColor) (self, ...)
end

local function Update(self, event, unit)
	if(not unit or self.__unit ~= unit) then return end
	local element = self.Health

	--[[ Callback: Health:PreUpdate(unit)
	Called before the element has been updated.

	* self - the Health element
	* unit - the unit for which the update has been triggered (string)
	--]]
	if(element.PreUpdate) then
		element:PreUpdate(unit)
	end

	local cur, max = UnitHealth(unit), UnitHealthMax(unit)
	element:SetMinMaxValues(0, max)

	if(UnitIsConnected(unit)) then
		element:SetValue(cur)
	else
		element:SetValue(max)
	end

	element.cur = cur
	element.max = max

	local lossPerc = 0
	if(element.TempLoss and GetUnitTotalModifiedMaxHealthPercent) then
		lossPerc = Clamp(GetUnitTotalModifiedMaxHealthPercent(unit), 0, 1)

		element.TempLoss:SetValue(lossPerc)
	end

	-- the main bar keeps UnitHealth/UnitHealthMax, the calculator only feeds the prediction sub-widgets
	if(STATE[element].prediction) then
		UnitGetDetailedHealPrediction(unit, 'player', element.values)
	end

	if(element.HealingAll or element.HealingPlayer or element.HealingOther or element.OverHealIndicator) then
		local allHeal, playerHeal, otherHeal, healClamped = element.values:GetIncomingHeals()
		if(element.HealingAll) then
			element.HealingAll:SetMinMaxValues(0, max)
			element.HealingAll:SetValue(allHeal)
		end
		if(element.HealingPlayer) then
			element.HealingPlayer:SetMinMaxValues(0, max)
			element.HealingPlayer:SetValue(playerHeal)
		end
		if(element.HealingOther) then
			element.HealingOther:SetMinMaxValues(0, max)
			element.HealingOther:SetValue(otherHeal)
		end
		if(element.OverHealIndicator) then
			element.OverHealIndicator:SetAlphaFromBoolean(healClamped, 1, 0)
		end
	end

	if(element.DamageAbsorb or element.OverDamageAbsorbIndicator) then
		local damageAbsorbAmount, damageAbsorbClamped = element.values:GetDamageAbsorbs()
		if(element.DamageAbsorb) then
			element.DamageAbsorb:SetMinMaxValues(0, max)
			element.DamageAbsorb:SetValue(damageAbsorbAmount)
		end
		if(element.OverDamageAbsorbIndicator) then
			element.OverDamageAbsorbIndicator:SetAlphaFromBoolean(damageAbsorbClamped, 1, 0)
		end
	end

	if(element.HealAbsorb or element.OverHealAbsorbIndicator) then
		local healAbsorbAmount, healAbsorbClamped = element.values:GetHealAbsorbs()
		if(element.HealAbsorb) then
			element.HealAbsorb:SetMinMaxValues(0, max)
			element.HealAbsorb:SetValue(healAbsorbAmount)
		end
		if(element.OverHealAbsorbIndicator) then
			element.OverHealAbsorbIndicator:SetAlphaFromBoolean(healAbsorbClamped, 1, 0)
		end
	end

	--[[ Callback: Health:PostUpdate(unit, cur, max, lossPerc)
	Called after the element has been updated.

	* self     - the Health element
	* unit     - the unit for which the update has been triggered (string)
	* cur      - the unit's current health value (number)
	* max      - the unit's maximum possible health value (number)
	* lossPerc - the percent by which the unit's max health has been temporarily reduced (number)
	--]]
	if(element.PostUpdate) then
		element:PostUpdate(unit, cur, max, lossPerc)
	end
end

local function UpdatePredictionSize(self, event, unit)
	local element = self.Health

	local method = STATE[element].horizontal and 'SetWidth' or 'SetHeight'
	if(element.HealingAll) then
		element.HealingAll[method](element.HealingAll, STATE[element].size)
	end

	if(element.HealingPlayer) then
		element.HealingPlayer[method](element.HealingPlayer, STATE[element].size)
	end

	if(element.HealingOther) then
		element.HealingOther[method](element.HealingOther, STATE[element].size)
	end

	if(element.DamageAbsorb) then
		element.DamageAbsorb[method](element.DamageAbsorb, STATE[element].size)
	end

	if(element.HealAbsorb) then
		element.HealAbsorb[method](element.HealAbsorb, STATE[element].size)
	end
end

local function shouldUpdatePredictionSize(self)
	local element = self.Health

	local horizontal = element:GetOrientation() == 'HORIZONTAL'
	local size = horizontal and element:GetWidth() or element:GetHeight()
	size = math.floor((size + 0.005) * 100) / 100 -- normalize floating point errors
	if(horizontal ~= STATE[element].horizontal or size ~= STATE[element].size) then
		STATE[element].horizontal = horizontal
		STATE[element].size = size

		return true
	end
end

local function Path(self, ...)
	--[[ Override: Health.UpdatePredictionSize(self, event, unit, ...)
	Used to completely override the internal function for updating the healing prediction sub-widgets' size.

	* self  - the parent object
	* event - the event triggering the update (string)
	* unit  - the unit accompanying the event (string)
	* ...   - the arguments accompanying the event
	--]]
	if(STATE[self.Health].prediction and shouldUpdatePredictionSize(self)) then
		(self.Health.UpdatePredictionSize or UpdatePredictionSize) (self, ...)
	end

	--[[ Override: Health.Override(self, event, unit)
	Used to completely override the internal update function.

	* self  - the parent object
	* event - the event triggering the update (string)
	* unit  - the unit accompanying the event (string)
	--]]
	(self.Health.Override or Update) (self, ...);

	ColorPath(self, ...)
end

local function ForceUpdate(element)
	STATE[element].horizontal = nil
	STATE[element].size = nil

	Path(element.__owner, 'ForceUpdate', element.__owner.__unit)
end

--[[ Health:SetColorDisconnected(state, isForced)
Used to toggle coloring if the unit is offline.

* self     - the Health element
* state    - the desired state (boolean)
* isForced - forces the event update even if the state wasn't changed (boolean)
--]]
local function SetColorDisconnected(element, state, isForced)
	if(element.colorDisconnected ~= state or isForced) then
		element.colorDisconnected = state
		if(state) then
			element.__owner:RegisterEvent('UNIT_CONNECTION', ColorPath)
		else
			element.__owner:UnregisterEvent('UNIT_CONNECTION', ColorPath)
		end
	end
end

--[[ Health:SetColorSelection(state, isForced)
Used to toggle coloring by the unit's selection.

* self     - the Health element
* state    - the desired state (boolean)
* isForced - forces the event update even if the state wasn't changed (boolean)
--]]
local function SetColorSelection(element, state, isForced)
	if(element.colorSelection ~= state or isForced) then
		element.colorSelection = state
		if(state) then
			element.__owner:RegisterEvent('UNIT_FLAGS', ColorPath)
		else
			element.__owner:UnregisterEvent('UNIT_FLAGS', ColorPath)
		end
	end
end

--[[ Health:SetColorTapping(state, isForced)
Used to toggle coloring if the unit isn't tapped by the player.

* self     - the Health element
* state    - the desired state (boolean)
* isForced - forces the event update even if the state wasn't changed (boolean)
--]]
local function SetColorTapping(element, state, isForced)
	if(element.colorTapping ~= state or isForced) then
		element.colorTapping = state
		if(state) then
			element.__owner:RegisterEvent('UNIT_FACTION', ColorPath)
		else
			element.__owner:UnregisterEvent('UNIT_FACTION', ColorPath)
		end
	end
end

--[[ Health:SetColorThreat(state, isForced)
Used to toggle coloring by the unit's threat status.

* self     - the Health element
* state    - the desired state (boolean)
* isForced - forces the event update even if the state wasn't changed (boolean)
--]]
local function SetColorThreat(element, state, isForced)
	if(element.colorThreat ~= state or isForced) then
		element.colorThreat = state
		if(state) then
			element.__owner:RegisterEvent('UNIT_THREAT_LIST_UPDATE', ColorPath)
		else
			element.__owner:UnregisterEvent('UNIT_THREAT_LIST_UPDATE', ColorPath)
		end
	end
end

local function Enable(self)
	local element = self.Health
	if(element) then
		element.__owner = self
		element.ForceUpdate = ForceUpdate
		element.SetColorDisconnected = SetColorDisconnected
		element.SetColorSelection = SetColorSelection
		element.SetColorTapping = SetColorTapping
		element.SetColorThreat = SetColorThreat

		STATE[element] = {
			prediction = element.HealingAll or element.HealingPlayer or element.HealingOther or element.OverHealIndicator
				or element.DamageAbsorb or element.OverDamageAbsorbIndicator or element.HealAbsorb or element.OverHealAbsorbIndicator,
		}

		if(STATE[element].prediction) then
			if(element.values) then
				element.values:ResetPredictedValues()
			else
				element.values = CreateUnitHealPredictionCalculator()
			end

			if(element.maximumHealthClampMode) then
				element.values:SetMaximumHealthMode(element.maximumHealthClampMode)
			end

			if(element.damageAbsorbClampMode) then
				element.values:SetDamageAbsorbClampMode(element.damageAbsorbClampMode)
			end

			if(element.healAbsorbClampMode) then
				element.values:SetHealAbsorbClampMode(element.healAbsorbClampMode)
			end

			if(element.healAbsorbMode) then
				element.values:SetHealAbsorbMode(element.healAbsorbMode)
			end

			if(element.incomingHealClampMode) then
				element.values:SetIncomingHealClampMode(element.incomingHealClampMode)
			end

			if(element.incomingHealOverflow) then
				element.values:SetIncomingHealOverflowPercent(element.incomingHealOverflow)
			end
		end

		if(element.colorDisconnected) then
			self:RegisterEvent('UNIT_CONNECTION', ColorPath)
		end

		if(element.colorSelection) then
			self:RegisterEvent('UNIT_FLAGS', ColorPath)
		end

		if(element.colorTapping) then
			self:RegisterEvent('UNIT_FACTION', ColorPath)
		end

		if(element.colorThreat) then
			self:RegisterEvent('UNIT_THREAT_LIST_UPDATE', ColorPath)
		end

		self:RegisterEvent('UNIT_HEALTH', Path)
		self:RegisterEvent('UNIT_MAXHEALTH', Path)
		self:RegisterEvent('UNIT_MAX_HEALTH_MODIFIERS_CHANGED', Path)

		if(element.HealingAll or element.HealingPlayer or element.HealingOther or element.OverHealIndicator) then
			self:RegisterEvent('UNIT_HEAL_PREDICTION', Path)
		end

		if(element.DamageAbsorb or element.OverDamageAbsorbIndicator) then
			self:RegisterEvent('UNIT_ABSORB_AMOUNT_CHANGED', Path)
		end

		if(element.HealAbsorb or element.OverHealAbsorbIndicator) then
			self:RegisterEvent('UNIT_HEAL_ABSORB_AMOUNT_CHANGED', Path)
		end

		if(element:IsObjectType('StatusBar') and not element:GetStatusBarTexture()) then
			element:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
		end

		if(element.HealingAll) then
			element.HealingAll:Show()

			if(element.HealingAll:IsObjectType('StatusBar') and not element.HealingAll:GetStatusBarTexture()) then
				element.HealingAll:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
			end
		end

		if(element.HealingPlayer) then
			element.HealingPlayer:Show()

			if(element.HealingPlayer:IsObjectType('StatusBar') and not element.HealingPlayer:GetStatusBarTexture()) then
				element.HealingPlayer:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
			end
		end

		if(element.HealingOther) then
			element.HealingOther:Show()

			if(element.HealingOther:IsObjectType('StatusBar') and not element.HealingOther:GetStatusBarTexture()) then
				element.HealingOther:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
			end
		end

		if(element.OverHealIndicator) then
			element.OverHealIndicator:Show()

			if(element.OverHealIndicator:IsObjectType('Texture') and not element.OverHealIndicator:GetTexture()) then
				element.OverHealIndicator:SetTexture([[Interface\RaidFrame\Shield-Overshield]])
				element.OverHealIndicator:SetBlendMode('ADD')
			end
		end

		if(element.DamageAbsorb) then
			element.DamageAbsorb:Show()

			if(element.DamageAbsorb:IsObjectType('StatusBar') and not element.DamageAbsorb:GetStatusBarTexture()) then
				element.DamageAbsorb:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
			end
		end

		if(element.HealAbsorb) then
			element.HealAbsorb:Show()

			if(element.HealAbsorb:IsObjectType('StatusBar') and not element.HealAbsorb:GetStatusBarTexture()) then
				element.HealAbsorb:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
			end
		end

		if(element.OverDamageAbsorbIndicator) then
			element.OverDamageAbsorbIndicator:Show()

			if(element.OverDamageAbsorbIndicator:IsObjectType('Texture') and not element.OverDamageAbsorbIndicator:GetTexture()) then
				element.OverDamageAbsorbIndicator:SetTexture([[Interface\RaidFrame\Shield-Overshield]])
				element.OverDamageAbsorbIndicator:SetBlendMode('ADD')
			end
		end

		if(element.OverHealAbsorbIndicator) then
			element.OverHealAbsorbIndicator:Show()

			if(element.OverHealAbsorbIndicator:IsObjectType('Texture') and not element.OverHealAbsorbIndicator:GetTexture()) then
				element.OverHealAbsorbIndicator:SetTexture([[Interface\RaidFrame\Absorb-Overabsorb]])
				element.OverHealAbsorbIndicator:SetBlendMode('ADD')
			end
		end

		element:Show()

		if(element.TempLoss) then
			if(element.TempLoss:IsObjectType('StatusBar')) then
				element.TempLoss:SetMinMaxValues(0, 1)
				element.TempLoss:SetValue(0)

				if(not element.TempLoss:GetStatusBarTexture()) then
					element.TempLoss:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
				end
			end

			element.TempLoss:Show()
		end

		return true
	end
end

local function Disable(self)
	local element = self.Health
	if(element) then
		element:Hide()

		if(element.HealingAll) then
			element.HealingAll:Hide()
		end

		if(element.HealingPlayer) then
			element.HealingPlayer:Hide()
		end

		if(element.HealingOther) then
			element.HealingOther:Hide()
		end

		if(element.OverHealIndicator) then
			element.OverHealIndicator:Hide()
		end

		if(element.DamageAbsorb) then
			element.DamageAbsorb:Hide()
		end

		if(element.HealAbsorb) then
			element.HealAbsorb:Hide()
		end

		if(element.OverDamageAbsorbIndicator) then
			element.OverDamageAbsorbIndicator:Hide()
		end

		if(element.OverHealAbsorbIndicator) then
			element.OverHealAbsorbIndicator:Hide()
		end

		self:UnregisterEvent('UNIT_HEALTH', Path)
		self:UnregisterEvent('UNIT_MAXHEALTH', Path)
		self:UnregisterEvent('UNIT_HEAL_PREDICTION', Path)
		self:UnregisterEvent('UNIT_ABSORB_AMOUNT_CHANGED', Path)
		self:UnregisterEvent('UNIT_HEAL_ABSORB_AMOUNT_CHANGED', Path)
		self:UnregisterEvent('UNIT_CONNECTION', ColorPath)
		self:UnregisterEvent('UNIT_FACTION', ColorPath)
		self:UnregisterEvent('UNIT_FLAGS', ColorPath)
		self:UnregisterEvent('UNIT_THREAT_LIST_UPDATE', ColorPath)
		self:UnregisterEvent('UNIT_MAX_HEALTH_MODIFIERS_CHANGED', Path)

		if(element.TempLoss) then
			element.TempLoss:Hide()
		end
	end
end

oUF:AddElement('Health', Path, Enable, Disable)
