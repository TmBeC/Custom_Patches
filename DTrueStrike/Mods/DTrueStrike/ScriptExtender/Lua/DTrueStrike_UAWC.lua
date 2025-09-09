
local modName = "DTrueStrike"
local tableVersion = 1
local spellTable = {
	Target_DWE_TrueStrike = {
		container = true,
		bladeCantrip = true,
		subSpells = {
			Target_DWE_TrueStrike_Melee = { bladeCantrip = true },
		},
	},
}

if Ext.Mod.IsModLoaded("61a154cf-07a9-42bf-b209-1d562770a520") then
	local UAWC = Mods.UAWarCaster
	if UAWC and UAWC.RegisterSpells then
		UAWC.RegisterSpells(modName, tableVersion, spellTable)
	else
		Ext.Utils.PrintWarning(modName .. ": Could not find UAWarCaster API. Use UAWarCaster version 1.4+ and load it before " .. modName)
	end
end

if false then
	local sourceFilenames = {
		"Public/Shared/Stats/Generated/Data/Spell_Target.txt",

		"Public/DTrueStrike/Stats/Generated/Data/DTrueStrike_Spells.txt",
	}

	-- Will write interrupt stats to "%LocalAppData%\Larian Studios\Baldur's Gate 3\Script Extender\UAWC_Reactions.txt"
	Mods.UAWarCaster.ConvertStats(modName, sourceFilenames, spellTable)
end
