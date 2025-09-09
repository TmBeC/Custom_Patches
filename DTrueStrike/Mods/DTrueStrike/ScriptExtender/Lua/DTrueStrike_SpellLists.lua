

-- add Target_DWE_TrueStrike to spell lists that contain Target_TrueStrike
function DWE_AddTrueStrikeToSpellList(spells)
	local trueStrikeFound = false
	for _, spellName in pairs(spells) do
		if spellName == "Target_TrueStrike" then
			trueStrikeFound = true
			break
		elseif spellName == "Target_DWE_TrueStrike" then
			-- our spell is already present - no need to do anything
			return
		end
	end

	if not trueStrikeFound then
		return
	end

	local newList = {}
	for _, spellName in pairs(spells) do
		if spellName == "Target_TrueStrike" then
			-- place our True Strike just before the standard one, to maintain alphabetical order
			table.insert(newList, "Target_DWE_TrueStrike")
		end
		table.insert(newList, spellName)
	end
	return newList
end

function DWE_AddTrueStrikeToSpellLists()
	-- print("DTrueStrike: Patching spell lists")

	local numPatchedLists = 0

	local allSpellLists = Ext.StaticData.GetAll("SpellList")
	for _, listGuid in pairs(allSpellLists) do
		local spellList = Ext.StaticData.Get(listGuid, "SpellList")
		local spells = spellList.Spells

		local newList = DWE_AddTrueStrikeToSpellList(spells)

		if newList then
			-- print(listGuid .. ": " .. spellList.Name)

			spellList.Spells = newList
			numPatchedLists = numPatchedLists + 1
		end
	end

	if numPatchedLists > 0 then
		print("DTrueStrike: Added to " .. numPatchedLists .. (Ext.IsServer() and " server" or " client") .. " spell lists")
	end
end
