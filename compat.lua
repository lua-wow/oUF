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
