local _, ns = ...
local oUF = ns.oUF
local Private = oUF.Private

-- public client flags for plugins, core uses Private.GameVersion
-- https://warcraft.wiki.gg/wiki/WOW_PROJECT_ID
oUF.isRetail = (WOW_PROJECT_ID == WOW_PROJECT_MAINLINE)
oUF.isClassic = (WOW_PROJECT_ID == WOW_PROJECT_CLASSIC)
oUF.isTBC = (WOW_PROJECT_ID == WOW_PROJECT_BURNING_CRUSADE_CLASSIC)
oUF.isWrath = (WOW_PROJECT_ID == WOW_PROJECT_WRATH_CLASSIC)
oUF.isCata = (WOW_PROJECT_ID == WOW_PROJECT_CATACLYSM_CLASSIC)
oUF.isMoP = (WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC)

-- silent, unlike Private.validateEvent which reports through the error handler
function Private.eventExists(event)
	return C_EventUtils.IsEventValid(event)
end

local hiddenParent = CreateFrame('Frame', nil, UIParent)
hiddenParent:SetAllPoints()
hiddenParent:Hide()

local hookedFrames = {}

local function resetParent(self, parent)
	if(parent ~= hiddenParent) then
		self:SetParent(hiddenParent)
	end
end

-- Classic has no SetRolesets, so blocked frames are hidden and kept in a hidden parent.
-- doNotReparent is for frames whose parent lays them out (pools, nameplates).
function Private.setRolesets(frame, set, doNotReparent)
	if(frame.SetRolesets) then
		frame:SetRolesets(set)
	elseif(set == 'alwaysBlocked') then
		frame:Hide()

		if(not doNotReparent) then
			frame:SetParent(hiddenParent)

			if(not hookedFrames[frame]) then
				hooksecurefunc(frame, 'SetParent', resetParent)

				hookedFrames[frame] = true
			end
		end
	end
end

-- Classic has no UnitSelectionType; use UnitSelectionColor
function Private.unitSelectionColor(unit, considerHostile)
	if(considerHostile and UnitThreatSituation('player', unit)) then
		return oUF.colors.selection[oUF.Enum.SelectionType.Hostile]
	end

	local r, g, b = UnitSelectionColor(unit, true)
	if(r) then
		return oUF:CreateColor(r, g, b)
	end
end

-- follows Blizzard_UnitFrame/Wrath/AlternatePowerBar.lua: the mana bar shows while druids (WotLK,
-- MoP) and monks (MoP) display another power; Era and TBC have no such bar
local altPowerBarPairDisplayInfo = _G.ALT_POWER_BAR_PAIR_DISPLAY_INFO
if(not altPowerBarPairDisplayInfo) then
	local GameVersion = Private.GameVersion
	local mana = { powerType = Enum.PowerType.Mana, powerName = 'MANA' }

	altPowerBarPairDisplayInfo = {}

	if(GameVersion.Wrath or GameVersion.Mists) then
		altPowerBarPairDisplayInfo.DRUID = {
			[Enum.PowerType.Rage] = mana,
			[Enum.PowerType.Energy] = mana,
		}
	end

	if(GameVersion.Mists) then
		altPowerBarPairDisplayInfo.MONK = {
			[Enum.PowerType.Energy] = mana,
		}
	end
end

Private.altPowerBarPairDisplayInfo = altPowerBarPairDisplayInfo

-- without SetRolesets, frames hide in pet battles through a secure parent instead
if(UIParent.SetRolesets) then
	Private.unitFrameParent = UIParent
else
	local parent = CreateFrame('Frame', nil, UIParent, 'SecureHandlerStateTemplate')
	parent:SetAllPoints()
	RegisterStateDriver(parent, 'visibility', '[petbattle] hide; show')

	Private.unitFrameParent = parent
end
