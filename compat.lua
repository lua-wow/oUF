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
