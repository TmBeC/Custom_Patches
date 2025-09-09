Ext.Require("DTrueStrike_UAWC.lua")
Ext.Require("DTrueStrike_Patch.lua")
Ext.Require("DTrueStrike_SpellLists.lua")

local function DWE_OnGameStateChanged(event)
	-- print("client OnGameStateChanged: " .. event.FromState.Label .. " -> " .. event.ToState.Label)

	if event.FromState == "LoadLevel" and event.ToState == "SwapLevel" then
		DWE_AddTrueStrikeToSpellLists()
	end
end

Ext.Events.StatsLoaded:Subscribe(DWE_AddTrueStrikeToSpellLists, { Priority = -100 })
Ext.Events.GameStateChanged:Subscribe(DWE_OnGameStateChanged, { Priority = -100 })
Ext.Events.ResetCompleted:Subscribe(DWE_AddTrueStrikeToSpellLists, { Priority = -100 })
