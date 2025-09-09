Ext.Require("DWE_CommonUtils.lua")
Ext.Require("DWE_StatusUtils.lua")

Ext.Require("DTrueStrike_Server.lua")
Ext.Require("DTrueStrike_UAWC.lua")
Ext.Require("DTrueStrike_SpellLists.lua")

local function DWE_OnGameStateChanged(event)
	-- print("server OnGameStateChanged: " .. event.FromState.Label .. " -> " .. event.ToState.Label)

	if event.FromState == "LoadSession" and event.ToState == "LoadLevel" then
		DWE_AddTrueStrikeToSpellLists()
	end
end

Ext.Events.GameStateChanged:Subscribe(DWE_OnGameStateChanged, { Priority = -100 })
Ext.Events.ResetCompleted:Subscribe(DWE_AddTrueStrikeToSpellLists, { Priority = -100 })
