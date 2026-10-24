local _, ns = ...
local oUF = ns.oUF
local Private = oUF.Private

local GameVersion = Private.GameVersion

-- sourced from Blizzard_UnitFrame/Mainline/TargetFrame.lua
local MAX_BOSS_FRAMES = _G.MAX_BOSS_FRAMES or 5

-- sourced from Blizzard_FrameXMLBase/Shared/Constants.lua
local MEMBERS_PER_RAID_GROUP = _G.MEMBERS_PER_RAID_GROUP or 5

-- sourced from Blizzard_ArenaUI/Blizzard_ArenaUI.lua (Classic)
local MAX_ARENA_ENEMIES = _G.MAX_ARENA_ENEMIES or 5

local isPlayerHooked = false
local isArenaHooked = false
local isBossHooked = false
local isPartyHooked = false
local hookedNameplates = {}

local function handleFrame(baseName, doNotReparent)
	local frame
	if(type(baseName) == 'string') then
		frame = _G[baseName]
	else
		frame = baseName
	end

	if(frame) then
		frame:UnregisterAllEvents()
		Private.setRolesets(frame, 'alwaysBlocked', doNotReparent)

		local health = frame.healthBar or frame.healthbar or frame.HealthBar or (frame.HealthBarsContainer and frame.HealthBarsContainer.healthBar)
		if(health) then
			health:UnregisterAllEvents()
		end

		local power = frame.manabar or frame.ManaBar
		if(power) then
			power:UnregisterAllEvents()
		end

		local castbar = frame.castBar or frame.spellbar or frame.CastingBarFrame or (frame.CastBarsContainer and frame.CastBarsContainer.castBar)
		if(castbar) then
			castbar:UnregisterAllEvents()
		end

		local altpowerbar = frame.powerBarAlt or frame.PowerBarAlt
		if(altpowerbar) then
			altpowerbar:UnregisterAllEvents()
		end

		local buffFrame = frame.BuffFrame or frame.AurasFrame
		if(buffFrame) then
			buffFrame:UnregisterAllEvents()
		end

		local petFrame = frame.petFrame or frame.PetFrame
		if(petFrame) then
			petFrame:UnregisterAllEvents()
		end

		local totFrame = frame.totFrame
		if(totFrame) then
			totFrame:UnregisterAllEvents()
		end

		local ccRemoverFrame = frame.CcRemoverFrame
		if(ccRemoverFrame) then
			ccRemoverFrame:UnregisterAllEvents()
		end

		local debuffFrame = frame.DebuffFrame
		if(debuffFrame) then
			debuffFrame:UnregisterAllEvents()
		end
	end
end

local function insecureHide(self)
	self:Hide()
end

local function hideArenaFrames()
	for i = 1, MAX_ARENA_ENEMIES do
		handleFrame('ArenaEnemyFrame' .. i)
	end
end

function oUF:DisableBlizzard(unit)
	if(not unit) then return end

	if(unit == 'player') then
		handleFrame(PlayerFrame)

		if(GameVersion.Forever and not isPlayerHooked) then
			isPlayerHooked = true

			-- by killing PlayerFrame we also inadvertedly kill the sound played when
			-- the player toggles pvp status, so we'll have to re-implement that.
			-- no fix for this for retail (yet - the event might be added in 12.1.7).
			-- this should really be handled by GameEvent...
			local f = CreateFrame('Frame')
			f:RegisterEvent('PLAYER_PVP_FLAG_CHANGED')
			f:SetScript('OnEvent', function(_, _, isFlagged)
				if(isFlagged) then
					PlaySound(SOUNDKIT.IG_PVP_UPDATE)
				end
			end)
		end
	elseif(unit == 'pet') then
		handleFrame(PetFrame)
	elseif(unit == 'target') then
		handleFrame(TargetFrame)
		handleFrame(ComboFrame) -- Classic
	elseif(unit == 'focus') then
		handleFrame(FocusFrame)
	elseif(unit:match('boss%d?$')) then
		if(not isBossHooked) then
			isBossHooked = true

			-- it's needed because the layout manager can bring frames that are
			-- controlled by containers back from the dead when a user chooses
			-- to revert all changes
			-- for now I'll just reparent it, but more might be needed in the
			-- future, watch it
			handleFrame(BossTargetFrameContainer)

			for i = 1, MAX_BOSS_FRAMES do
				handleFrame('Boss' .. i .. 'TargetFrame')
			end
		end
	elseif(unit:match('party%d?$')) then
		if(not isPartyHooked) then
			isPartyHooked = true

			handleFrame(PartyFrame)

			for frame in PartyFrame.PartyMemberFramePool:EnumerateActive() do
				handleFrame(frame, true)
			end

			for i = 1, MEMBERS_PER_RAID_GROUP do
				handleFrame('CompactPartyFrameMember' .. i)
			end
		end
	elseif(unit:match('arena%d?$')) then
		if(not isArenaHooked) then
			isArenaHooked = true

			if(CompactArenaFrame) then -- does not exist in Forever
				handleFrame(CompactArenaFrame)

				for _, frame in next, CompactArenaFrame.memberUnitFrames do
					handleFrame(frame)
				end
			end

			if(ArenaEnemyMatchFramesContainer) then
				-- old arena frames, they're still used for flag carriers etc in battlegrounds
				handleFrame(ArenaEnemyMatchFramesContainer)

				for _, frame in next, ArenaEnemyMatchFramesContainer.UnitFrames do
					handleFrame(frame)
				end
			else
				-- Classic arena frames, Blizzard_ArenaUI is load-on-demand
				C_CVar.SetCVar('showArenaEnemyFrames', '0')

				if(C_AddOns.IsAddOnLoaded('Blizzard_ArenaUI')) then
					hideArenaFrames()
				else
					local f = CreateFrame('Frame')
					f:RegisterEvent('ADDON_LOADED')
					f:SetScript('OnEvent', function(_, _, name)
						if(name == 'Blizzard_ArenaUI') then
							f:UnregisterAllEvents()
							hideArenaFrames()
						end
					end)
				end
			end
		end
	elseif(unit:match('nameplate%d?%d?%d?$')) then
		local frame = C_NamePlate.GetNamePlateForUnit(unit)
		local unitFrame = frame and frame.UnitFrame
		if(not unitFrame or unitFrame:IsForbidden()) then return end

		if(unitFrame.SetRolesets) then
			handleFrame(unitFrame)
		else
			-- Classic: Blizzard pools nameplate unit frames and re-shows them on reuse
			if(not hookedNameplates[unitFrame]) then
				unitFrame:HookScript('OnShow', insecureHide)

				hookedNameplates[unitFrame] = true
			end

			handleFrame(unitFrame, true)
		end
	end
end
