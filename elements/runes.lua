--[[
# Element: Runes

Handles the visibility and updating of Death Knight's runes.

## Widget

Runes - An `table` holding `StatusBar`s.

## Sub-Widgets

.bg - A `Texture` used as a background. It will inherit the color of the main StatusBar.

## Notes

A default texture will be applied if the sub-widgets are StatusBars and don't have a texture set.

## Options

.colorSpec - Use `self.colors.runes[specID]` to color the bar based on player's spec. `specID` is defined by the return
             value of [API_GetInspectSpecialization](https://warcraft.wiki.gg/wiki/API_GetInspectSpecialization) (boolean)
.sortOrder - Sorting order. Sorts by the remaining cooldown time, 'asc' - from the least cooldown time remaining (fully
             charged) to the most (fully depleted), 'desc' - the opposite (string?)['asc', 'desc']

With rune types (`GetRuneType`, WotLK and MoP) the runes keep Blizzard's order, each rune is colored by its type
(`self.colors.runes`: 1 blood, 2 frost, 3 unholy, 4 death) and `.colorSpec` and `.sortOrder` are ignored.

## Sub-Widgets Options

.multiplier - Used to tint the background based on the main widgets R, G and B values. Defaults to 1 (number)[0-1]

## Examples

    local Runes = {}
    for index = 1, 6 do
        -- Position and size of the rune bar indicators
        local Rune = CreateFrame('StatusBar', nil, self)
        Rune:SetSize(120 / 6, 20)
        Rune:SetPoint('TOPLEFT', self, 'BOTTOMLEFT', index * 120 / 6, 0)

        Runes[index] = Rune
    end

    -- Register with oUF
    self.Runes = Runes
--]]

if(select(2, UnitClass('player')) ~= 'DEATHKNIGHT') then return end

local _, ns = ...
local oUF = ns.oUF

-- Blizzard
local GetSpecialization = C_SpecializationInfo.GetSpecialization
-- undocumented, WotLK and MoP; Blizzard's rune frame and combat text use it
local GetRuneType = GetRuneType

-- Blizzard's display order (RuneFrame_FixRunes); maps both ways
local runemap = GetRuneType and {1, 2, 5, 6, 3, 4} or {1, 2, 3, 4, 5, 6}
-- rune type (1 blood, 2 unholy, 3 frost, 4 death per combat text) to colors.runes index (unverified)
local runeTypeColor = {1, 3, 2, 4}
local hasSortOrder = false

local function onUpdate(self, elapsed)
	local duration = self.duration + elapsed
	self.duration = duration
	self:SetValue(duration)
end

local function ascSort(runeAID, runeBID)
	local runeAStart, _, runeARuneReady = GetRuneCooldown(runeAID)
	local runeBStart, _, runeBRuneReady = GetRuneCooldown(runeBID)
	if(runeARuneReady ~= runeBRuneReady) then
		return runeARuneReady
	elseif(runeAStart ~= runeBStart) then
		return runeAStart < runeBStart
	else
		return runeAID < runeBID
	end
end

local function descSort(runeAID, runeBID)
	local runeAStart, _, runeARuneReady = GetRuneCooldown(runeAID)
	local runeBStart, _, runeBRuneReady = GetRuneCooldown(runeBID)
	if(runeARuneReady ~= runeBRuneReady) then
		return runeBRuneReady
	elseif(runeAStart ~= runeBStart) then
		return runeAStart > runeBStart
	else
		return runeAID > runeBID
	end
end

local function colorRune(rune, r, g, b)
	rune:SetStatusBarColor(r, g, b)

	local bg = rune.bg
	if(bg) then
		local mu = bg.multiplier or 1
		bg:SetVertexColor(r * mu, g * mu, b * mu)
	end
end

local function UpdateRuneType(self, element, runeID)
	local rune = element[runemap[runeID]]
	if(not rune) then return end

	local runeType = GetRuneType(runeID)
	local color = runeType and self.colors.runes[runeTypeColor[runeType]] or self.colors.power.RUNES
	colorRune(rune, color[1], color[2], color[3])

	--[[ Callback: Runes:PostUpdateColor(color, rune)
	Called after a rune's color has been updated (rune types only).

	* self  - the Runes element
	* color - the used color (table)
	* rune  - the updated rune (StatusBar)
	--]]
	if(element.PostUpdateColor) then
		element:PostUpdateColor(color, rune)
	end
end

local function UpdateColor(self, event, runeID)
	local element = self.Runes

	if(GetRuneType) then
		if(event == 'RUNE_TYPE_UPDATE') then
			UpdateRuneType(self, element, runeID)
		else
			for id = 1, #runemap do
				UpdateRuneType(self, element, id)
			end
		end

		return
	end

	local spec = GetSpecialization() or 0

	local color
	if(spec > 0 and spec < 4 and element.colorSpec) then
		color = self.colors.runes[spec]
	else
		color = self.colors.power.RUNES
	end

	local r, g, b = color[1], color[2], color[3]

	for index = 1, #element do
		colorRune(element[index], r, g, b)
	end

	--[[ Callback: Runes:PostUpdateColor(color)
	Called after the element color has been updated.

	* self  - the Runes element
	* color - the used ColorMixin-based object (table)
	--]]
	if(element.PostUpdateColor) then
		element:PostUpdateColor(color)
	end
end

local function ColorPath(self, ...)
	--[[ Override: Runes.UpdateColor(self, event, ...)
	Used to completely override the internal function for updating the widgets' colors.

	* self  - the parent object
	* event - the event triggering the update (string)
	* ...   - the arguments accompanying the event
	--]]
	(self.Runes.UpdateColor or UpdateColor) (self, ...)
end

local function Update(self, event)
	local element = self.Runes

	-- rune types keep Blizzard's order
	if(not GetRuneType) then
		if(element.sortOrder == 'asc') then
			table.sort(runemap, ascSort)
			hasSortOrder = true
		elseif(element.sortOrder == 'desc') then
			table.sort(runemap, descSort)
			hasSortOrder = true
		elseif(hasSortOrder) then
			table.sort(runemap)
			hasSortOrder = false
		end
	end

	local currentTime = GetTime()
	local rune, start, duration, runeReady
	for index, runeID in next, runemap do
		rune = element[index]
		if(not rune) then break end

		if(UnitHasVehicleUI('player')) then
			rune:Hide()
		else
			start, duration, runeReady = GetRuneCooldown(runeID)
			if(runeReady) then
				rune:SetMinMaxValues(0, 1)
				rune:SetValue(1)
				rune:SetScript('OnUpdate', nil)
			elseif(start) then
				rune.duration = currentTime - start
				rune:SetMinMaxValues(0, duration)
				rune:SetValue(0)
				rune:SetScript('OnUpdate', onUpdate)
			end

			rune:Show()
		end
	end

	--[[ Callback: Runes:PostUpdate(runemap)
	Called after the element has been updated.

	* self    - the Runes element
	* runemap - the ordered list of runes' indices (table)
	--]]
	if(element.PostUpdate) then
		return element:PostUpdate(runemap)
	end
end

local function Path(self, ...)
	--[[ Override: Runes.Override(self, event, ...)
	Used to completely override the internal update function.

	* self  - the parent object
	* event - the event triggering the update (string)
	* ...   - the arguments accompanying the event
	--]]
	(self.Runes.Override or Update) (self, ...)
end

local function AllPath(...)
	Path(...)
	ColorPath(...)
end

local function ForceUpdate(element)
	Path(element.__owner, 'ForceUpdate')
	ColorPath(element.__owner, 'ForceUpdate')
end

local function Enable(self, unit)
	local element = self.Runes
	if(element and UnitIsUnit(unit, 'player')) then
		element.__owner = self
		element.ForceUpdate = ForceUpdate

		for i = 1, #element do
			local rune = element[i]
			if(rune:IsObjectType('StatusBar') and not rune:GetStatusBarTexture()) then
				rune:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
			end
		end

		self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED', ColorPath)
		self:RegisterEvent('RUNE_POWER_UPDATE', Path, true)
		if(GetRuneType) then
			self:RegisterEvent('RUNE_TYPE_UPDATE', ColorPath, true)
		end

		return true
	end
end

local function Disable(self)
	local element = self.Runes
	if(element) then
		for i = 1, #element do
			element[i]:Hide()
		end

		self:UnregisterEvent('PLAYER_SPECIALIZATION_CHANGED', ColorPath)
		self:UnregisterEvent('RUNE_POWER_UPDATE', Path)
		if(GetRuneType) then
			self:UnregisterEvent('RUNE_TYPE_UPDATE', ColorPath)
		end
	end
end

oUF:AddElement('Runes', AllPath, Enable, Disable)
