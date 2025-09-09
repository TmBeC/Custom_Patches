local pairs = pairs
local next = next

local DWE_GetEntity = DWE_GetEntity
local DWE_GetLongUUID = DWE_GetLongUUID
local DWE_GetShortUUID = DWE_GetShortUUID
local DWE_GetUUID = DWE_GetUUID
local DWE_IsSameUUID = DWE_IsSameUUID

local Ext_Entity_HandleToUuid = Ext.Entity.HandleToUuid

function DWE_HasStatusFrom(target, statusId, source)
	local entity = DWE_GetEntity(target)
	if not entity then
		return
	end

	local serverComponent = entity.ServerCharacter or entity.ServerItem
	local statusManager = serverComponent.StatusManager

	local sourceUUID
	for _, status in pairs(statusManager.Statuses) do
		if status and status.StatusId == statusId then
			local statusSource = status.StatusSource
			if statusSource then
				local uuid = Ext_Entity_HandleToUuid(statusSource)
				sourceUUID = sourceUUID or DWE_GetShortUUID(source)
				if DWE_IsSameUUID(uuid, sourceUUID) then
					return true, status
				end
			end
		end
	end
	return false
end
local DWE_HasStatusFrom = DWE_HasStatusFrom

function DWE_RemoveStatusFrom(target, statusId, source)
	local _, status = DWE_HasStatusFrom(target, statusId, source)
	if status then
		status.Flags = status.Flags | "RequestDelete"

		-- requires Script Extender v25
		-- print("> ServerStatusRequest.Destroy: " .. DWE_GetLongUUID(target) .. ", " .. statusId)
		local destroyRequests = Ext.System.ServerStatusRequest.Destroy
		destroyRequests[#destroyRequests + 1] = {
			Type = 'StatusHandle',
			StatusId = statusId,
			Owner = DWE_GetEntity(target),
			StatusHandle = status.StatusHandle,
		}
		return true
	end
	return false
end
local DWE_RemoveStatusFrom = DWE_RemoveStatusFrom

function DWE_MultiRemoveStatus(target, statusesToRemove)
	local entity = DWE_GetEntity(target)
	if not entity then
		return
	end

	local serverComponent = entity.ServerCharacter or entity.ServerItem
	local statusManager = serverComponent.StatusManager

	local removeSet = {}
	for _, status in pairs(statusManager.Statuses) do
		local statusId = status and status.StatusId
		if statusId and statusesToRemove[statusId] then
			removeSet[statusId] = true
		end
	end

	if next(removeSet) == nil then
		return
	end

	local uuid = DWE_GetUUID(target)
	for statusId, _ in pairs(removeSet) do
		-- print('> Osi.RemoveStatus("' .. uuid .. '", "' .. statusId .. '")')
		Osi.RemoveStatus(uuid, statusId)
	end
end

function DWE_MultiRemoveStatusFrom(target, statusesToRemove, source)
	local entity = DWE_GetEntity(target)
	if not entity then
		return
	end

	local sourceUUID = DWE_GetShortUUID(source)

	local serverComponent = entity.ServerCharacter or entity.ServerItem
	local statusManager = serverComponent.StatusManager

	-- requires Script Extender v25
	local destroyRequests = Ext.System.ServerStatusRequest.Destroy

	for _, status in pairs(statusManager.Statuses) do
		local statusId = status and status.StatusId
		if statusId and statusesToRemove[statusId] then
			local statusSourceUUID = DWE_GetShortUUID(status.StatusSource)
			if DWE_IsSameUUID(sourceUUID, statusSourceUUID) then
				status.Flags = status.Flags | "RequestDelete"
				-- print("> ServerStatusRequest.Destroy: " .. DWE_GetLongUUID(target) .. ", " .. statusId)
				destroyRequests[#destroyRequests + 1] = {
					Type = 'StatusHandle',
					StatusId = statusId,
					Owner = entity,
					StatusHandle = status.StatusHandle,
				}
			end
		end
	end
end

function DWE_RemoveStatusesWithStackId(target, stackId)
	local entity = DWE_GetEntity(target)
	if not entity then
		return
	end

	local serverComponent = entity.ServerCharacter or entity.ServerItem
	local statusManager = serverComponent.StatusManager

	local removeSet = {}
	for _, status in pairs(statusManager.Statuses) do
		if status and status.StackId == stackId then
			removeSet[status.StatusId] = true
		end
	end

	if next(removeSet) == nil then
		return
	end

	local uuid = DWE_GetUUID(target)
	for statusId, _ in pairs(removeSet) do
		-- print('> Osi.RemoveStatus("' .. uuid .. '", "' .. statusId .. '")')
		Osi.RemoveStatus(uuid, statusId)
	end
end

function DWE_TrackAppliedStatus(target, statusId, source, trackingVariable)
	assert(trackingVariable)
	local sourceEntity = DWE_GetEntity(source)

	local tracking = sourceEntity.Vars[trackingVariable] or {}
	local statusTracking = tracking[statusId] or {}

	local targetUUID = DWE_GetShortUUID(target)

	statusTracking[targetUUID] = true

	tracking[statusId] = statusTracking
	sourceEntity.Vars[trackingVariable] = tracking
end
local DWE_TrackAppliedStatus = DWE_TrackAppliedStatus

function DWE_ApplyTrackedStatus(target, statusId, source, trackingVariable)
	assert(trackingVariable)
	if DWE_HasStatusFrom(target, statusId, source) then
		return -- don't add duplicates
	end

	local targetUUID = DWE_GetShortUUID(target)
	local sourceUUID = DWE_GetUUID(source)

	Osi.ApplyStatus(targetUUID, statusId, -1, 1, sourceUUID)
	DWE_TrackAppliedStatus(target, statusId, source, trackingVariable)
end

function DWE_RemoveTrackedStatus(target, statusId, source, trackingVariable)
	assert(trackingVariable)
	local sourceEntity = DWE_GetEntity(source)

	local targetUUID = DWE_GetShortUUID(target)
	DWE_RemoveStatusFrom(targetUUID, statusId, source)

	local tracking = sourceEntity.Vars[trackingVariable]
	local statusTracking = tracking and tracking[statusId]
	if not statusTracking then
		return
	end

	statusTracking[targetUUID] = nil

	if next(statusTracking) == nil then
		statusTracking = nil
	end
	tracking[statusId] = statusTracking

	if next(tracking) == nil then
		tracking = nil
	end
	sourceEntity.Vars[trackingVariable] = tracking
end

function DWE_RemoveTrackedStatusFromAllTargets(source, statusId, trackingVariable)
	assert(trackingVariable)
	local sourceEntity = DWE_GetEntity(source)

	local tracking = sourceEntity.Vars[trackingVariable]
	local statusTracking = tracking and tracking[statusId]
	if not statusTracking then
		return
	end

	for target, _ in pairs(statusTracking) do
		DWE_RemoveStatusFrom(target, statusId, source)
	end

	tracking[statusId] = nil

	if next(tracking) == nil then
		tracking = nil
	end
	sourceEntity.Vars[trackingVariable] = tracking
end

function DWE_BM_StatusApplied_Tracked(target, statusId, source, applyStoryActionID, trackingVariable)
	-- print("DWE_BM_StatusApplied_Tracked: " .. target .. ", " .. statusId .. ", " .. source .. ", " .. applyStoryActionID)

	DWE_TrackAppliedStatus(target, statusId, source, trackingVariable)
end
local DWE_BM_StatusApplied_Tracked = DWE_BM_StatusApplied_Tracked

function DWE_BM_GetTrackedStatusAppliedHandler(trackingVariable)
	return function(target, statusId, source, applyStoryActionID)
		return DWE_BM_StatusApplied_Tracked(target, statusId, source, applyStoryActionID, trackingVariable)
	end
end

function DWE_BM_GetTrackedStatusTargets(source, statusId, trackingVariable)
	-- print("DWE_BM_GetTrackedStatusTargets: " .. DWE_GetLongUUID(source) .. ", " .. statusId .. ", " .. trackingVariable)

	assert(trackingVariable)
	local sourceEntity = DWE_GetEntity(source)

	local targets = {}

	local tracking = sourceEntity.Vars[trackingVariable]
	local statusTracking = tracking and tracking[statusId]
	if not statusTracking then
		-- print("  no tracking")
		return targets
	end

	local changed = false

	for target, _ in pairs(statusTracking) do
		if DWE_HasStatusFrom(target, statusId, source) then
			targets[target] = true
		else
			statusTracking[target] = nil
			changed = true
			-- print("  removed " .. target)
		end
	end

	if changed then
		if next(statusTracking) == nil then
			statusTracking = nil
		end
		tracking[statusId] = statusTracking

		if next(tracking) == nil then
			tracking = nil
		end
		sourceEntity.Vars[trackingVariable] = tracking
	end

	-- print("  targets: " .. setToString(targets))

	return targets
end
