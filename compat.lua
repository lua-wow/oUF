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

-- Classic has no C_PetInfo.GetPetHappiness; the global's first return is the same 1-3 level
Private.getPetHappiness = C_PetInfo.GetPetHappiness or GetPetHappiness

-- Classic has no UnitFrameUtil; same fields and defaults as Retail's GetArenaSpecValues
-- (Blizzard_UnitFrame/Shared/UnitFrameUtil.lua), data as Classic Blizzard_ArenaUI reads it
if(UnitFrameUtil) then
	Private.getArenaOpponentSpecInfo = UnitFrameUtil.GetArenaOpponentSpecDisplayInfo
else
	function Private.getArenaOpponentSpecInfo(index)
		local info = {
			hasSpec = false,
			specName = '',
			className = '',
			barColorR = 1,
			barColorG = 0,
			barColorB = 0,
		}

		local specID, gender = GetArenaOpponentSpec(index)
		if(specID and specID > 0) then
			local _, specName, _, _, _, class, className = GetSpecializationInfoByID(specID, gender)

			info.hasSpec = true
			info.specName = specName or ''
			info.className = className or ''

			local color = class and RAID_CLASS_COLORS[class]
			if(color) then
				info.barColorR, info.barColorG, info.barColorB = color.r, color.g, color.b
			end
		end

		return info
	end
end

-- follows Blizzard_UnitFrame/Wrath/AlternatePowerBar.lua: the mana bar shows while druids and monks
-- (MoP) display another power; Blizzard has no such bar on Era and TBC, oUF adds it there too
local altPowerBarPairDisplayInfo = _G.ALT_POWER_BAR_PAIR_DISPLAY_INFO
if(not altPowerBarPairDisplayInfo) then
	local GameVersion = Private.GameVersion
	local mana = { powerType = Enum.PowerType.Mana, powerName = 'MANA' }

	altPowerBarPairDisplayInfo = {
		DRUID = {
			[Enum.PowerType.Rage] = mana,
			[Enum.PowerType.Energy] = mana,
		},
	}

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
