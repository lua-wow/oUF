--[[
# Element: Eclipse Bar

Handles the visibility and updating of the Cata and Mists Balance Druid's eclipse bar.

## Widget

EclipseBar - A `Frame` used to hold the sub-widgets.

## Sub-Widgets

LunarBar - A `StatusBar` filled from the lunar side up to the current balance power.
SolarBar - A `StatusBar` filled from the solar side, the complement of LunarBar.

## Notes

A default texture will be applied to the sub-widgets if they don't have a texture set.
Directions and eclipses are Blizzard's 'moon', 'sun' and 'none' strings (see ECLIPSE_MARKER_COORDS).

## Examples

    local EclipseBar = CreateFrame('Frame', nil, self)
    EclipseBar:SetSize(160, 20)
    EclipseBar:SetPoint('BOTTOM', self, 'TOP')

    local LunarBar = CreateFrame('StatusBar', nil, EclipseBar)
    LunarBar:SetPoint('LEFT')
    LunarBar:SetSize(160, 20)

    local SolarBar = CreateFrame('StatusBar', nil, EclipseBar)
    SolarBar:SetPoint('LEFT', LunarBar:GetStatusBarTexture(), 'RIGHT')
    SolarBar:SetSize(160, 20)

    -- Register with oUF
    EclipseBar.LunarBar = LunarBar
    EclipseBar.SolarBar = SolarBar
    self.EclipseBar = EclipseBar
--]]

local _, ns = ...
local oUF = ns.oUF
local Private = oUF.Private

local GameCompatibility = Private.GameCompatibility

local STATE = {}

local unitIsUnit = Private.unitIsUnit

-- sourced from Blizzard_FrameXMLBase/Classic/Constants.lua
local SPEC_DRUID_BALANCE = _G.SPEC_DRUID_BALANCE or 1
local MOONKIN_FORM = _G.MOONKIN_FORM or 31

-- sourced from Blizzard_UnitFrame/Cata/EclipseBarFrame.lua
local SPELL_LUNAR_ECLIPSE = 48518
local SPELL_SOLAR_ECLIPSE = 48517

local POWER_TYPE_BALANCE = 'BALANCE'

local function Update(self, event, unit, powerType)
	if(unit ~= self.__unit or (event == 'UNIT_POWER_FREQUENT' and powerType ~= POWER_TYPE_BALANCE)) then return end

	local element = self.EclipseBar

	local cur = UnitPower('player', Enum.PowerType.Balance)
	local max = UnitPowerMax('player', Enum.PowerType.Balance)

	if(element.LunarBar) then
		element.LunarBar:SetMinMaxValues(-max, max)
		-- negative power is lunar, so lunar fills as power goes down
		element.LunarBar:SetValue(-cur)
	end

	if(element.SolarBar) then
		element.SolarBar:SetMinMaxValues(-max, max)
		element.SolarBar:SetValue(cur)
	end

	--[[ Callback: EclipseBar:PostUpdate(cur, max)
	Called after the element has been updated.

	* self - the EclipseBar element
	* cur  - the player's balance power, negative towards lunar (number)
	* max  - the player's maximum balance power (number)
	--]]
	if(element.PostUpdate) then
		element:PostUpdate(cur, max)
	end
end

local function Path(self, ...)
	--[[ Override: EclipseBar.Override(self, event, unit, powerType)
	Used to completely override the internal update function.

	* self      - the parent object
	* event     - the event triggering the update (string)
	* unit      - the unit accompanying the event (string)
	* powerType - the power type accompanying the event (string)
	--]]
	return (self.EclipseBar.Override or Update) (self, ...)
end

local function UpdateEclipse(self, event, unit)
	if(unit ~= self.__unit) then return end

	local element = self.EclipseBar

	local eclipse = 'none'
	if(C_UnitAuras.GetPlayerAuraBySpellID(SPELL_LUNAR_ECLIPSE)) then
		eclipse = 'moon'
	elseif(C_UnitAuras.GetPlayerAuraBySpellID(SPELL_SOLAR_ECLIPSE)) then
		eclipse = 'sun'
	end

	if(eclipse == STATE[element].eclipse) then return end
	STATE[element].eclipse = eclipse

	--[[ Callback: EclipseBar:PostUpdateEclipse(eclipse)
	Called after the active eclipse has changed.

	* self    - the EclipseBar element
	* eclipse - the active eclipse, 'moon', 'sun' or 'none' (string)
	--]]
	if(element.PostUpdateEclipse) then
		element:PostUpdateEclipse(eclipse)
	end
end

local function UpdateDirection(self, event, direction)
	local element = self.EclipseBar

	--[[ Callback: EclipseBar:PostUpdateDirection(direction)
	Called after the eclipse direction has changed.

	* self      - the EclipseBar element
	* direction - the direction the bar is moving to, 'moon', 'sun' or 'none' (string)
	--]]
	if(element.PostUpdateDirection) then
		element:PostUpdateDirection(direction)
	end
end

local function Visibility(self, event, unit)
	local element = self.EclipseBar

	-- as Blizzard's EclipseBarFrameMixin:ShouldDisplay
	local form = GetShapeshiftFormID()
	local shouldShow = (not form or form == MOONKIN_FORM)
		and C_SpecializationInfo.GetSpecialization() == SPEC_DRUID_BALANCE
		and not UnitHasVehicleUI('player')

	if(not shouldShow) then
		if(element:IsShown()) then
			element:Hide()
			self:UnregisterEvent('UNIT_POWER_FREQUENT', Path)
			self:UnregisterEvent('UNIT_MAXPOWER', Path)
			self:UnregisterEvent('UNIT_AURA', UpdateEclipse)
			self:UnregisterEvent('ECLIPSE_DIRECTION_CHANGE', UpdateDirection)

			--[[ Callback: EclipseBar:PostVisibility(isVisible)
			Called after the element's visibility has been changed.

			* self      - the EclipseBar element
			* isVisible - the current visibility state of the element (boolean)
			--]]
			if(element.PostVisibility) then
				element:PostVisibility(false)
			end
		end
	elseif(not element:IsShown()) then
		element:Show()
		self:RegisterEvent('UNIT_POWER_FREQUENT', Path)
		self:RegisterEvent('UNIT_MAXPOWER', Path)
		self:RegisterEvent('UNIT_AURA', UpdateEclipse)
		self:RegisterEvent('ECLIPSE_DIRECTION_CHANGE', UpdateDirection, true)

		STATE[element].eclipse = nil
		UpdateEclipse(self, event, self.__unit)
		UpdateDirection(self, event, GetEclipseDirection())
		Path(self, event, self.__unit, POWER_TYPE_BALANCE)

		if(element.PostVisibility) then
			element:PostVisibility(true)
		end
	end
end

local function VisibilityPath(self, ...)
	--[[ Override: EclipseBar.OverrideVisibility(self, event, unit)
	Used to completely override the internal visibility toggling function.

	* self  - the parent object
	* event - the event triggering the update (string)
	* unit  - the unit accompanying the event (string)
	--]]
	return (self.EclipseBar.OverrideVisibility or Visibility) (self, ...)
end

local function ForceUpdate(element)
	local self = element.__owner
	VisibilityPath(self, 'ForceUpdate', self.__unit)

	if(element:IsShown()) then
		Path(self, 'ForceUpdate', self.__unit, POWER_TYPE_BALANCE)
	end
end

local function Disable(self)
	local element = self.EclipseBar
	if(element) then
		element:Hide()

		if(GameCompatibility.Mists) then
			self:UnregisterEvent('PLAYER_SPECIALIZATION_CHANGED', VisibilityPath)
		else
			self:UnregisterEvent('PLAYER_TALENT_UPDATE', VisibilityPath)
		end
		self:UnregisterEvent('UNIT_DISPLAYPOWER', VisibilityPath)
		self:UnregisterEvent('UPDATE_SHAPESHIFT_FORM', VisibilityPath)
		self:UnregisterEvent('UNIT_POWER_FREQUENT', Path)
		self:UnregisterEvent('UNIT_MAXPOWER', Path)
		self:UnregisterEvent('UNIT_AURA', UpdateEclipse)
		self:UnregisterEvent('ECLIPSE_DIRECTION_CHANGE', UpdateDirection)
	end
end

local function Enable(self, unit)
	if(UnitClassBase('player') ~= 'DRUID' or not GameCompatibility.Cataclysm or GameCompatibility.Warlords) then
		Disable(self)

		return false
	end

	local element = self.EclipseBar
	if(element and unitIsUnit(unit, 'player')) then
		element.__owner = self
		element.ForceUpdate = ForceUpdate

		STATE[element] = {}

		if(GameCompatibility.Mists) then
			self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED', VisibilityPath)
		else
			self:RegisterEvent('PLAYER_TALENT_UPDATE', VisibilityPath, true)
		end
		self:RegisterEvent('UNIT_DISPLAYPOWER', VisibilityPath)
		self:RegisterEvent('UPDATE_SHAPESHIFT_FORM', VisibilityPath, true)

		for _, bar in next, {element.LunarBar, element.SolarBar} do
			if(bar:IsObjectType('StatusBar') and not bar:GetStatusBarTexture()) then
				bar:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
			end
		end

		-- do not change this without taking Visibility into account
		element:Hide()

		return true
	end
end

oUF:AddElement('EclipseBar', VisibilityPath, Enable, Disable)
