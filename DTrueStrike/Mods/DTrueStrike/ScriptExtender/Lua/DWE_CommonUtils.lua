
local Ext_Entity_Get = Ext.Entity.Get
local stringSub = string.sub
local stringFind = string.find
local stringMatch = string.match
local tostring = tostring
local pairs = pairs
local type = type
local next = next
local table = table

local Ext_Entity_HandleToUuid = Ext.Entity.HandleToUuid

DWE_NullUUID_Short = "00000000-0000-0000-0000-000000000000"
DWE_NullUUID_Long = "NULL_00000000-0000-0000-0000-000000000000"

local DWE_NullUUID_Short = DWE_NullUUID_Short
local DWE_NullUUID_Long = DWE_NullUUID_Long

DWE_CharacterComponent = Ext.IsServer() and "ServerCharacter" or "ClientCharacter"
DWE_ItemComponent = Ext.IsServer() and "ServerItem" or "ClientItem"

local DWE_CharacterComponent = DWE_CharacterComponent
local DWE_ItemComponent = DWE_ItemComponent

function pairsByKeys(t, f)
	local a = {}
	for n in pairs(t) do table.insert(a, n) end
	table.sort(a, f)
	local i = 0
	local iter = function()
		i = i + 1
		if a[i] == nil then return nil
		else return a[i], t[a[i]]
		end
	end
	return iter
end

function tableToString(tbl)
	if type(tbl) ~= "table" then return tostring(tbl) end
	if next(tbl) == nil then return "{}" end
	local str = "{ "
	for k, v in pairsByKeys(tbl) do
		str = str .. "[" .. tostring(k) .. "] = " .. tableToString(v) .. ", "
	end
	str = stringSub(str, 1, -3) .. " }"
	return str
end

function setToString(tbl)
	if type(tbl) ~= "table" then return tostring(tbl) end
	if next(tbl) == nil then return "{}" end
	local str = "{ "
	for k, v in pairsByKeys(tbl) do
		str = str .. tostring(k) .. ", "
	end
	str = str:sub(1, -3) .. " }"
	return str
end

function DWE_ShortUUID(uuid)
	return (uuid and stringSub(uuid, -36)) or DWE_NullUUID_Short
end
local DWE_ShortUUID = DWE_ShortUUID

function DWE_IsNullUUID(uuid)
	return (uuid == nil) or stringFind(uuid, '00000000[-]0000[-]0000[-]0000[-]000000000000$')
end

function DWE_IsSameUUID(uuid1, uuid2)
	return DWE_ShortUUID(uuid1) == DWE_ShortUUID(uuid2)
end

function DWE_IsGUID(str)
	if str == nil then return end
	return nil ~= stringMatch(str, "%x%x%x%x%x%x%x%x[-]%x%x%x%x[-]%x%x%x%x[-]%x%x%x%x[-]%x%x%x%x%x%x%x%x%x%x%x%x$")
end

function DWE_GetEntity(uuidOrEntity)
	if uuidOrEntity == nil then return end
	if type(uuidOrEntity) == 'string' then return Ext_Entity_Get(uuidOrEntity) end
	return uuidOrEntity
end

function DWE_GetUUID(uuidOrEntity)
	if uuidOrEntity == nil then return 'nil' end
	if type(uuidOrEntity) == 'string' then return uuidOrEntity end
	return Ext_Entity_HandleToUuid(uuidOrEntity)
end

function DWE_GetShortUUID(uuidOrEntity)
	if uuidOrEntity == nil then return 'nil' end
	if type(uuidOrEntity) == 'string' then return DWE_ShortUUID(uuidOrEntity) end
	return Ext_Entity_HandleToUuid(uuidOrEntity)
end

function DWE_IsTurnBased(uuidOrEntity)
	local entity = DWE_GetEntity(uuidOrEntity)
	local turnBased = entity.TurnBased
	return turnBased and not DWE_IsNullUUID(turnBased.CombatTeam)
end

function DWE_GetLongUUID(uuidOrEntity)
	if uuidOrEntity == nil then return 'nil' end
	if type(uuidOrEntity) == 'string' then
		if uuidOrEntity:len() > 36 then
			return uuidOrEntity
		else
			local entity = DWE_GetEntity(uuidOrEntity)
			if entity then
				uuidOrEntity = entity
			else
				return uuidOrEntity
			end
		end
	end
	local uuid = Ext_Entity_HandleToUuid(uuidOrEntity)
	local component = uuidOrEntity[DWE_CharacterComponent] or uuidOrEntity[DWE_ItemComponent]
	if component then
		return component.Template.Name .. '_' .. uuid
	else
		return uuid
	end
end

function DWE_ListToSet(list)
	local set = {}
	for i, item in pairs(list) do
		set[item] = i
	end
	return set
end

function DWE_GetModifier(value)
	return math.floor((value - 10) / 2)
end
