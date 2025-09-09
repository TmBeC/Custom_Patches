local Ext = Ext
local Osi = Osi
local Ext_Entity_Get = Ext.Entity.Get
local stringSub = string.sub
local pairs = pairs
local DWE_GetShortUUID = DWE_GetShortUUID
local DWE_GetEntity = DWE_GetEntity

local locSpellCategoryCache = {}
local locHasStatusesForCategoryCache = {}
local locHasFXCache = {}
local locStatusCacheVersion = {}
local locHasRegisteredListeners = false

local locCategories = {
	Target_DWE_TrueStrike				= 1,
	Target_DWE_TrueStrike_Melee			= 1,
	Projectile_DWE_TrueStrike_Ranged	= 2,
	Shout_DWE_TrueStrike_Toggle_Melee	= 3,
	Shout_DWE_TrueStrike_Toggle_Ranged	= 4,
	Shout_DWE_TrueStrike_Radiant_Melee	= 5,
	Shout_DWE_TrueStrike_Radiant_Ranged	= 6,

	Internal							= 10,

	CompatibleMelee						= 11,
	CompatibleRanged					= 12,
}

local locStatusesToRemoveOnEndCast = {
	DWE_TRUE_STRIKE = true,
	DWE_TRUE_STRIKE_DAMAGE = true,
	DWE_TRUE_STRIKE_RADIANT = true,

	DWE_TRUE_STRIKE_OWNER = true,
	DWE_TRUE_STRIKE_OWNER_INT = true,
	DWE_TRUE_STRIKE_OWNER_WIS = true,
	DWE_TRUE_STRIKE_OWNER_CHA = true,

	DWE_TRUE_STRIKE_WEAPON = true,
	DWE_TRUE_STRIKE_WEAPON_INT = true,
	DWE_TRUE_STRIKE_WEAPON_WIS = true,
	DWE_TRUE_STRIKE_WEAPON_CHA = true,

	DWE_TRUE_STRIKE_FX = true,
	DWE_TRUE_STRIKE_FX_RADIANT = true,

	DWE_TRUE_STRIKE_CHARISMACASTER_CANTRIPBOOSTER = true,
	DWE_TRUE_STRIKE_ARCANESYNERGY_RING = true,
}

local locDefaultVFX = {
	physical = 'DWE_TRUE_STRIKE_FX',
	radiant = 'DWE_TRUE_STRIKE_FX_RADIANT',
}
local locFXPerClass = {}
function RegisterClassWeaponFX(classUUID, physicalFXStatusName, radiantFXStatusName)
	assert(DWE_IsGUID(classUUID) and DWE_ShortUUID(classUUID) == classUUID)
	assert(type(physicalFXStatusName) == 'string' and physicalFXStatusName ~= '' and Ext.Stats.Get(physicalFXStatusName))
	assert(type(radiantFXStatusName) == 'string' and radiantFXStatusName ~= '' and Ext.Stats.Get(radiantFXStatusName))

	locFXPerClass[classUUID] = {
		physical = physicalFXStatusName,
		radiant = radiantFXStatusName,
	}
	locStatusesToRemoveOnEndCast[physicalFXStatusName] = true
	locStatusesToRemoveOnEndCast[radiantFXStatusName] = true
end

local function locCategoryIsMelee(category)
	return category == locCategories.Target_DWE_TrueStrike_Melee
		or category == locCategories.CompatibleMelee
end

local function locCategoryIsRanged(category)
	return category == locCategories.Projectile_DWE_TrueStrike_Ranged
		or category == locCategories.CompatibleRanged
end

local function locCategoryIsAuto(category)
	return category > locCategories.Internal
end

local function locShortUUID(uuid)
	return stringSub(uuid, -36)
end

local function locAccumulateSetUnion(dest, src)
	for k, v in pairs(src) do
		dest[k] = v
	end
end

local function locGetSpellCategoryUncached(spellName)
	local category = locCategories[spellName]
	if category then
		return category
	end

	local spell = Ext.Stats.Get(spellName)
	if not spell then
		return false
	end

	local isTarget = spell.SpellType == "Target"
	local isProjectile = spell.SpellType == "Projectile"
	if not (isTarget or isProjectile) then
		return false
	end

	local spellRoll = spell.SpellRoll
	if not spellRoll then
		return false
	end
	local defaultRoll = spellRoll.Default
	if not defaultRoll or spellRoll.Cast2 then
		return false
	end
	if not defaultRoll:find("WeaponAttack", 1, true) then
		return false
	end

	local tooltipDamage = spell.TooltipDamageList
	if not tooltipDamage:find("Main%w+Weapon") then
		return false
	end

	for _, flag in pairs(spell.SpellFlags) do
		if flag == "IsSpell" then
			return false
		end
	end

	local useCosts = {}
	for key, value in spell.UseCosts:gmatch("([^%s;:]+):([^%s;]*)") do
		useCosts[key] = value
	end
	if useCosts.ActionPoint ~= "1"
	or useCosts.SpellSlotsGroup
	then
		return false
	end

	local hitCosts = {}
	for key, value in spell.HitCosts:gmatch("([^%s;:]+):([^%s;]*)") do
		hitCosts[key] = value
	end
	if hitCosts.BardicInspiration -- Blade Flourish only works on the Attack action
	then
		return false
	end

	return isProjectile and locCategories.CompatibleRanged or locCategories.CompatibleMelee
end

local function locGetSpellCategory(spellName)
	local cached = locSpellCategoryCache[spellName]
	if cached ~= nil then
		-- print(spellName .. ": " .. tostring(cached))
		return cached
	end

	cached = locGetSpellCategoryUncached(spellName)

	locSpellCategoryCache[spellName] = cached
	-- print(spellName .. ": " .. tostring(cached) .. " (uncached)")
	return cached
end

local function locIsTrueStrikeCompatible(character, entity, spell)
	entity = entity or Ext_Entity_Get(character)

	if not (entity and entity.Player) then
		return
	end

	local category = locGetSpellCategory(spell)
	if not category then
		return
	elseif category <= locCategories.Internal then
		return category
	end

	if Osi.HasSpell(character, "Target_DWE_TrueStrike") ~= 1 then
		-- double-check in case the spell has been removed but that hasn't been recognized yet
		return
	end

	local turnBased = entity.TurnBased
	if not (turnBased.IsActiveCombatTurn or DWE_IsNullUUID(turnBased.CombatTeam)) then
		-- can't cast spells off-turn (except via War Caster, which uses Target_DWE_TrueStrike directly)
		return
	end

	local isRanged = (category == locCategories.CompatibleRanged)

	local toggleStatus = isRanged and "DWE_TRUE_STRIKE_TOGGLE_RANGED" or "DWE_TRUE_STRIKE_TOGGLE_MELEE"
	if Osi.HasActiveStatus(character, toggleStatus) ~= 1 then
		return
	end

	local equipSlot = isRanged and "Ranged Main Weapon" or "Melee Main Weapon"
	local weapon = Osi.GetEquippedItem(character, equipSlot)
	if not (weapon and Osi.IsProficientWith(character, weapon) == 1) then
		return
	end

	local weaponEntity = Ext.Entity.Get(weapon)
	if not weaponEntity or weaponEntity.SummonLifetime then
		-- summoned weapons don't fulfill the "worth 1+ CP" requirement
		-- (not enforced for manual use, but don't auto apply on them)
		return
	end

	return category
end

local function locGetCast(isCasting)
	-- IsCasting.Cast SHOULD always be present, and I've never seen otherwise,
	-- but a user reported logs that had it missing somehow, so make sure we can survive without it (with degraded functionality)

	if not isCasting then return end
	local ok, cast = pcall(function()
		return isCasting.Cast
	end)
	if not ok then
		Ext.Utils.PrintWarning("DTrueStrike: Failed to get IsCasting.Cast: " .. tostring(cast))
		return
	end
	return cast
end

local function locGetSpellCastingAbilityForCurrentCast(entity)
	local isCasting = entity.SpellCastIsCasting
	local cast = locGetCast(isCasting)
	local currentSpellId = cast and cast.SpellCastState.SpellId
	if not currentSpellId then
		return
	end

	local prototype = currentSpellId.Prototype
	local progressionSource = currentSpellId.ProgressionSource
	local source = currentSpellId.Source
	local sourceType = currentSpellId.SourceType

	local spellBook = entity.SpellBook
	for _, spell in pairs(spellBook.Spells) do
		local id = spell.Id
		if  prototype == id.Prototype
		and progressionSource == id.ProgressionSource
		and source == id.Source
		and sourceType == id.SourceType
		then
			return spell.SpellCastingAbility, progressionSource
		end
	end
end

local function locGetSpellCastingAbilityForSpell(entity, spellName)
	local spellBook = entity.SpellBook
	for _, spell in pairs(spellBook.Spells) do
		local id = spell.Id
		if id.Prototype == spellName then
			return spell.SpellCastingAbility, id.ProgressionSource
		end
	end
end

local function locGetBestSpellCastingAbility(entity)
	local abilities = entity.Stats.Abilities
	local int = abilities[5]
	local wis = abilities[6]
	local cha = abilities[7]
	if int >= wis then
		if int >= cha then
			return 'Intelligence'
		else
			return 'Charisma'
		end
	else
		if cha >= wis then
			return 'Charisma'
		else
			return 'Wisdom'
		end
	end
end

local function locGetWeapon(character, category)
	local weapon
	if locCategoryIsMelee(category) then
		weapon = Osi.GetEquippedItem(character, "Melee Main Weapon")
	elseif locCategoryIsRanged(category) then
		weapon = Osi.GetEquippedItem(character, "Ranged Main Weapon")
	end
	if not weapon or Osi.IsProficientWith(character, weapon) ~= 1 then
		return
	end
	return weapon
end

local function locWantsFX(character, entity, category)
	entity = entity or Ext_Entity_Get(character)

	local isCasting = entity and entity.SpellCastIsCasting
	if not isCasting then
		return
	end

	local isAuto = locCategoryIsAuto(category)
	if not isAuto then
		return true
	end

	local cast = isCasting and locGetCast(isCasting)
	local hoverPreview = cast and cast.SpellCastState.CastOptions.IsHoverPreview
	if not hoverPreview then
		return true
	end

--	if Osi.IsInCombat(character) == 0 then
	if not DWE_IsTurnBased(entity) then
		return false
	end

	local weapon = locGetWeapon(character, category)
	if Osi.HasActiveStatus(weapon, "DWE_BM_DISAPPEAR_WEAPONS_FX") == 1 then
		-- caster is an Occultist transformed into a form that hides weapons
		return false
	end
	return true
end

local function locApplyFXStatus(shortUUID, entity, category)
	if locHasFXCache[shortUUID]
	or not locWantsFX(shortUUID, entity, category)
	then
		return
	end

	local weapon = locGetWeapon(shortUUID, category)
	if not weapon then
		return
	end

	entity = entity or Ext_Entity_Get(shortUUID)

	local _, classUUID = locGetSpellCastingAbilityForCurrentCast(entity)
	if DWE_IsNullUUID(classUUID) then
		_, classUUID = locGetSpellCastingAbilityForSpell(entity, "Target_DWE_TrueStrike_Melee")
	end

	local fx = locDefaultVFX
	if classUUID then
		fx = locFXPerClass[classUUID] or fx
	end

	local isMelee = locCategoryIsMelee(category)
	local radiantToggle = isMelee
					 and "DWE_TRUE_STRIKE_RADIANT_TOGGLE_MELEE"
					  or "DWE_TRUE_STRIKE_RADIANT_TOGGLE_RANGED"
	local isRadiant = Osi.HasActiveStatus(shortUUID, radiantToggle) == 1
	local statusName = isRadiant and fx.radiant or fx.physical

	Osi.ApplyStatus(weapon, statusName, -1, 0, shortUUID)
	locHasFXCache[shortUUID] = true
end

local locStatToSuffix = {
	Intelligence = "_INT",
	Wisdom = "_WIS",
	Charisma = "_CHA",
}
local function locApplyStatuses(character, entity, spell, category)
	local shortUUID = locShortUUID(character)
	local cached = locHasStatusesForCategoryCache[shortUUID]
	if cached == category then
		-- if we already have statuses for the same category then don't reapply them,
		-- but update the cache version so any in-flight delayed removals will be cancelled
		locStatusCacheVersion[shortUUID] = (locStatusCacheVersion[shortUUID] or 0) + 1

		locApplyFXStatus(shortUUID, entity, category)
		return
	elseif cached then
		-- character already has statuses for a different category - remove them first
		locRemoveStatuses(character)
	end

	local isMelee = locCategoryIsMelee(category)
	local isRanged = locCategoryIsRanged(category)
	local isAuto = locCategoryIsAuto(category)

	if not (isMelee or isRanged) then
		return
	end

	entity = entity or Ext_Entity_Get(character)

	local AP = Osi.GetActionResourceValuePersonal(shortUUID, 'ActionPoint', 0)
	if isAuto and AP < 1 then -- when casting manually, allow missing AP to support Quickened Spell metamagic
		return
	end

	for _, status in pairs(entity.ServerCharacter.StatusManager.Statuses) do
		if status then
			if status.StackId == "EXTRA_ATTACK" then
				-- can't cast cantrips in extra attack (ignoring the exceptions)
				return
			end

			-- Echo Knight attack via echo handling
			local statusId = status.StatusId
			if statusId == "DWE_EK_ATTACKSWAP_KNIGHT" -- controlling echo
			or (isMelee and statusId == "DWE_EK_ATTACKTOGGLE_ACTIVE") -- attack near echo
			then
				-- can't cast cantrips via Echo
				return 
			end
		end
	end

	local weapon = locGetWeapon(character, category)
	if not weapon then
		return
	end

	local castingAbility = locGetSpellCastingAbilityForCurrentCast(entity)
	local statSuffix = locStatToSuffix[castingAbility]
	if not statSuffix then
		castingAbility = locGetSpellCastingAbilityForSpell(entity, "Target_DWE_TrueStrike_Melee")
		statSuffix = locStatToSuffix[castingAbility]
	end
	if not statSuffix then
		castingAbility = locGetBestSpellCastingAbility(entity)
		statSuffix = locStatToSuffix[castingAbility]
	end
	statSuffix = statSuffix or ''
	-- print("castingAbility: " .. tostring(castingAbility) .. ", statSuffix: " .. tostring(statSuffix))

	locApplyFXStatus(shortUUID, entity, category)

	Osi.ApplyStatus(character, "DWE_TRUE_STRIKE", -1)
	Osi.ApplyStatus(character, "DWE_TRUE_STRIKE_OWNER" .. statSuffix, -1)

	if Osi.GetLevel(character) >= 5 then
		Osi.ApplyStatus(character, "DWE_TRUE_STRIKE_DAMAGE", -1)
	end

	Osi.ApplyStatus(weapon, "DWE_TRUE_STRIKE_WEAPON" .. statSuffix, -1, 0, character)

	local radiantToggle = isMelee and "DWE_TRUE_STRIKE_RADIANT_TOGGLE_MELEE" or "DWE_TRUE_STRIKE_RADIANT_TOGGLE_RANGED"
	if Osi.HasActiveStatus(character, radiantToggle) == 1 then
		Osi.ApplyStatus(weapon, "DWE_TRUE_STRIKE_RADIANT", -1, 0, character)
	end

	if isAuto then
		-- make Auto True Strike work with effects checking for cantrip casts

		-- Potent Robe
		if Osi.HasPassive(character, "MAG_CharismaCaster_CantripBooster_Passive") == 1 then
			Osi.ApplyStatus(character, "DWE_TRUE_STRIKE_CHARISMACASTER_CANTRIPBOOSTER", -1)
		end

		-- Ring of Arcane Synergy
		if Osi.HasPassive(character, "MAG_Gish_ArcaneSynergy_Ring_Passive") == 1 then
			Osi.ApplyStatus(character, "DWE_TRUE_STRIKE_ARCANESYNERGY_RING", -1)
		end
	end

	locHasStatusesForCategoryCache[shortUUID] = category
	locStatusCacheVersion[shortUUID] = (locStatusCacheVersion[shortUUID] or 0) + 1
end

function locRemoveStatuses(character, cacheVersionToRemove)
	local shortUUID = locShortUUID(character)
	local cached = locHasStatusesForCategoryCache[shortUUID]
	if cached == false then
		return
	end
	if cacheVersionToRemove then
		local version = locStatusCacheVersion[shortUUID]
		if cacheVersionToRemove ~= version then
			return
		end
	end

	DWE_MultiRemoveStatus(character, locStatusesToRemoveOnEndCast)

	local melee = Osi.GetEquippedItem(character, "Melee Main Weapon")
	if melee then
		DWE_MultiRemoveStatus(melee, locStatusesToRemoveOnEndCast)
	end

	local ranged = Osi.GetEquippedItem(character, "Ranged Main Weapon")
	if ranged then
		DWE_MultiRemoveStatus(ranged, locStatusesToRemoveOnEndCast)
	end

	locHasStatusesForCategoryCache[shortUUID] = false
	locHasFXCache[shortUUID] = false
	locStatusCacheVersion[shortUUID] = (locStatusCacheVersion[shortUUID] or 0) + 1
end

local function locOnSpellStart(object, spell)
	local category = locIsTrueStrikeCompatible(object, nil, spell)
	if category then
		if not locHasRegisteredListeners then
			DWE_TrueStrike_RegisterListeners()
		end
		locApplyStatuses(object, nil, spell, category)
	else
		local shortUUID = locShortUUID(object)
		local hasStatus = locHasStatusesForCategoryCache[shortUUID]
		if hasStatus then
			locRemoveStatuses(object, spell)
		end
	end
end

local function locDelayRemoveStatuses(object, delay)
	local shortUUID = locShortUUID(object)
	local cacheVersionToRemove = locStatusCacheVersion[shortUUID]
	if cacheVersionToRemove then
		Ext.Timer.WaitFor(delay, function()
			locRemoveStatuses(object, cacheVersionToRemove)
		end)
	end
end

local function locOnCastSpellFailed(object, spell)
	local category = locIsTrueStrikeCompatible(object, nil, spell)
	if category then
		if locCategoryIsAuto(category) then
			-- don't remove statuses right away when cancelling Auto True Strike, as simply moving
			-- the cursor over an enemy or breakable object starts and then cancels a spell preparation,
			-- which causes VFX flashing if we respond immediately
			locDelayRemoveStatuses(object, 5000)
		else
			locRemoveStatuses(object)
		end
	end
end

local function locOnCasted(object, spell)
	local category = locIsTrueStrikeCompatible(object, nil, spell)
	if category then
		if not locHasRegisteredListeners then
			DWE_TrueStrike_RegisterListeners()
		end

		if locCategoryIsRanged(category) then
			-- ranged attacks at long distance may hit after the spell is done casting,
			-- so wait a little before removing statuses or they won't affect the hit
			locDelayRemoveStatuses(object, 3000)
		else
			locRemoveStatuses(object)
		end

		local toggleStatus, toggleName
		if category == locCategories.Shout_DWE_TrueStrike_Toggle_Melee then
			toggleStatus = "DWE_TRUE_STRIKE_TOGGLE_MELEE"
			toggleName = "Auto melee"
		elseif category == locCategories.Shout_DWE_TrueStrike_Toggle_Ranged then
			toggleStatus = "DWE_TRUE_STRIKE_TOGGLE_RANGED"
			toggleName = "Auto melee"
		elseif category == locCategories.Shout_DWE_TrueStrike_Radiant_Melee then
			toggleStatus = "DWE_TRUE_STRIKE_RADIANT_TOGGLE_MELEE"
			toggleName = "Radiant melee"
		elseif category == locCategories.Shout_DWE_TrueStrike_Radiant_Ranged then
			toggleStatus = "DWE_TRUE_STRIKE_RADIANT_TOGGLE_RANGED"
			toggleName = "Radiant ranged"
		end
		if toggleStatus then
			if Osi.HasActiveStatus(object, toggleStatus) == 1 then
				Osi.RemoveStatus(object, toggleStatus)
				print("DTrueStrike: " .. toggleName .. " True Strike toggled OFF")
			else
				Osi.ApplyStatus(object, toggleStatus, -1)
				print("DTrueStrike: " .. toggleName .. " True Strike toggled ON")
			end
		end
	end
end

local function locOnCreateIsCasting(casterEntity, componentType, component)
	local castEntity = locGetCast(component)
	if not castEntity then return end

	local spellCastState = castEntity.SpellCastState
	local spell = spellCastState.SpellId.Prototype

	local shortCaster = DWE_GetShortUUID(casterEntity)

	local category = locIsTrueStrikeCompatible(shortCaster, casterEntity, spell)
	if category then
		locApplyStatuses(shortCaster, casterEntity, spell, category)
	elseif locHasStatusesForCategoryCache[shortCaster] then
		locRemoveStatuses(shortCaster)
	end
end

local function locOnSpellSyncTargeting(castEntity)
	local spellCastState = castEntity.SpellCastState
	local spell = spellCastState.SpellId.Prototype

	local casterEntity = spellCastState.Caster
	local shortCaster = DWE_GetShortUUID(casterEntity)

	local category = locIsTrueStrikeCompatible(shortCaster, casterEntity, spell)
	if category then
		locApplyStatuses(shortCaster, casterEntity, spell, category)
	elseif locHasStatusesForCategoryCache[shortCaster] then
		locRemoveStatuses(shortCaster)
	end
end

function DWE_TrueStrike_RegisterListeners()
	if locHasRegisteredListeners then
		return
	end
	locHasRegisteredListeners = true
	print("DTrueStrike: Spell found; registering listeners")

	-- SpellCastIsCasting is required for the statuses to apply quickly enough to take effect
	-- when the spellcast is triggered without a prepare stage, such as via War Caster reaction
	Ext.Entity.OnCreate("SpellCastIsCasting", locOnCreateIsCasting)

	-- SpellSyncTargeting is used to detect just-before cast of a prepared spell
	Ext.Entity.OnChange("SpellSyncTargeting", locOnSpellSyncTargeting)

	-- the Osiris events are simply easier to deal with, with fewer edge cases, so use them too
	-- to cover every situation
	Ext.Osiris.RegisterListener("CastSpell", 5, "before", locOnSpellStart)
	Ext.Osiris.RegisterListener("CastSpellFailed", 5, "after", locOnCastSpellFailed)
end

local locStatusesToRemoveOnNoSpell = {
	DWE_TRUE_STRIKE_TOGGLE_MELEE = true,
	DWE_TRUE_STRIKE_TOGGLE_RANGED = true,

	DWE_TRUE_STRIKE_RADIANT_TOGGLE_MELEE = true,
	DWE_TRUE_STRIKE_RADIANT_TOGGLE_RANGED = true,
}
locAccumulateSetUnion(locStatusesToRemoveOnNoSpell, locStatusesToRemoveOnEndCast)

local function locCheckForSpell(character)
	if Osi.IsCharacter(character) == 0 then
		return
	end
	if Osi.HasSpell(character, "Target_DWE_TrueStrike") == 1 then
		if not locHasRegisteredListeners then
			DWE_TrueStrike_RegisterListeners()
		end
	else
		DWE_MultiRemoveStatus(character, locStatusesToRemoveOnNoSpell)
	end
end

local function locUpdateParty()
	local partyMembers = Osi.DB_PartyMembers:Get(nil)

	for k, v in pairs(partyMembers) do
		local character = v[1]
		local entity = DWE_GetEntity(character)

		if entity then
			locCheckForSpell(character)

			if not entity.SpellCastIsCasting then
				locRemoveStatuses(character)
			end
		end
	end
end

local function locOnGameStateChanged(event)
	local fromRunning = event.FromState.Label == "Running"
	local toRunning = event.ToState.Label == "Running"

	if fromRunning or toRunning then
		locUpdateParty()
	end
end

Ext.Osiris.RegisterListener("StartedPreviewingSpell", 4, "before", locOnSpellStart)
Ext.Osiris.RegisterListener("CastedSpell", 5, "after", locOnCasted)

Ext.Osiris.RegisterListener("CharacterJoinedParty", 1, "after", locCheckForSpell)
Ext.Osiris.RegisterListener("EnteredCombat", 2, "after", locCheckForSpell)
Ext.Osiris.RegisterListener("EnteredForceTurnBased", 1, "after", locCheckForSpell)
Ext.Osiris.RegisterListener("ShortRested", 1, "after", locCheckForSpell)
Ext.Osiris.RegisterListener("UserCharacterLongRested", 2, "after", locCheckForSpell)
Ext.Osiris.RegisterListener("RespecCompleted", 1, "after", locCheckForSpell)
Ext.Osiris.RegisterListener("LeveledUp", 1, "after", locCheckForSpell)

Ext.Events.GameStateChanged:Subscribe(locOnGameStateChanged)
Ext.Events.ResetCompleted:Subscribe(locUpdateParty)
