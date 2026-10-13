local _, ns = ...
local Private = ns.oUF.Private

-- deprecated: only defined while the loadDeprecationFallbacks CVar is set
local ShowBossFrameWhenUninteractable = ShowBossFrameWhenUninteractable or UnitIsVisible

-- follows Blizzard_UnitFrame/Wrath/AlternatePowerBar.lua (wrath, cata, mists): the mana bar shows
-- while another power is displayed; no such bar on Era and TBC
local ALT_POWER_BAR_PAIR_DISPLAY_INFO = {}
if(ns.oUF.isWrath or ns.oUF.isMoP) then
	ALT_POWER_BAR_PAIR_DISPLAY_INFO.DRUID = {
		[Enum.PowerType.Rage] = { powerType = Enum.PowerType.Mana, powerName = "MANA" },
		[Enum.PowerType.Energy] = { powerType = Enum.PowerType.Mana, powerName = "MANA" },
	}
end
if(ns.oUF.isMoP) then
	-- Mistweaver only, see AdditionalPower
	ALT_POWER_BAR_PAIR_DISPLAY_INFO.MONK = {
		[Enum.PowerType.Energy] = { powerType = Enum.PowerType.Mana, powerName = "MANA" },
	}
end

function Private.argcheck(value, num, ...)
	assert(type(num) == 'number', "Bad argument #2 to 'argcheck' (number expected, got " .. type(num) .. ')')

	for i = 1, select('#', ...) do
		if(type(value) == select(i, ...)) then return end
	end

	local types = string.join(', ', ...)
	local name = debugstack(2,2,0):match(": in function [`<](.-)['>]")
	error(string.format("Bad argument #%d to '%s' (%s expected, got %s)", num, name, types, type(value)), 3)
end

function Private.print(...)
	print('|cff33ff99oUF:|r', ...)
end

function Private.error(...)
	Private.print('|cffff0000Error:|r ' .. string.format(...))
end

function Private.nierror(...)
	return geterrorhandler()(...)
end

function Private.unitExists(unit)
	return unit and (UnitExists(unit) or ShowBossFrameWhenUninteractable(unit))
end

local validator = CreateFrame('Frame')

function Private.validateUnit(unit)
	local isOK, _ = pcall(validator.RegisterUnitEvent, validator, 'UNIT_HEALTH', unit)
	if(isOK) then
		_, unit = validator:IsEventRegistered('UNIT_HEALTH')
		validator:UnregisterEvent('UNIT_HEALTH')

		return not not unit
	end
end

function Private.UnitSelectionColor(unit, useExtendedColors)
	local r, g, b, a = UnitSelectionColor(unit, useExtendedColors)
	if not r or not g or not b then
		return nil
	end
	return ns.oUF:CreateColor(r, g, b, a or 1)
end

-- callbacks take a color object, as Retail's curve colors; one per element, reused
function Private.SmoothColor(element, r, g, b)
	local color = element.__smoothColor
	if(color) then
		color:SetRGBA(r, g, b)
	else
		color = ns.oUF:CreateColor(r, g, b)
		element.__smoothColor = color
	end

	return color
end

function Private.xpcall(func, ...)
	return xpcall(func, Private.nierror, ...)
end

function Private.validateEvent(event)
	local isOK = xpcall(validator.RegisterEvent, Private.nierror, validator, event)
	if(isOK) then
		validator:UnregisterEvent(event)
	end

	return isOK
end

function Private.isUnitEvent(event, unit)
	local isOK = pcall(validator.RegisterUnitEvent, validator, event, unit)
	if(isOK) then
		validator:UnregisterEvent(event)
	end

	return isOK
end

function Private.GetAltPowerBarDisplayInfo()
	return ALT_POWER_BAR_PAIR_DISPLAY_INFO
end
