
local function locStatsLoaded()

	local numPatched = 0
	local unleashIncarnation = Ext.Stats.Get("DWE_EK_UnleashIncarnation_OnAttackAction")
	if unleashIncarnation then
		local conditions = unleashIncarnation.Conditions
		if not conditions:find("DWE_TRUE_STRIKE") then
			local newConditions = "(" .. conditions .. ") and not HasStatus('DWE_TRUE_STRIKE', context.Source)"
			unleashIncarnation.Conditions = newConditions
			--print(unleashIncarnation.Conditions)
			numPatched = numPatched + 1
		end
	end

	local passivesToPatch = {
		'MAG_ChargedLightning_Charge_OnSpellDamage_Passive', -- "IsSpell()"
		'MAG_ChargedLightning_LightningDischargeSpell_Passive', -- "IsSpell() and not HasStatus('MAG_CHARGED_LIGHTNING_AURA_TECHNICAL', context.Source)"
		'MAG_CQCaster_GainArcaneChargeOnDamage_Quarterstaff_Passive', -- "IsSpell() and HasSpellRangeEqualOrLessThan(5, context.Source)"
		'MAG_CQCaster_TempHPAfterCast_Cloak_Passive', -- "HasStatus('FLANKED', context.Source) and IsSpell()"
		'MAG_Gish_ArcaneAcuity_Gloves_Passive', -- "ArcaneAcuityGlovesCondition();"
		'MAG_GreaterNecromancyStaff_LifeEssenceHarvest_Passive', -- "not Item() and Enemy() and IsKillingBlow() and IsSpell()"
		'MAG_Radiant_RadiatingOrb_Ring_Passive', -- "IsSpell() and not Item()"
		'MagicAllergy_InRange', -- "HasSpellFlag(SpellFlags.Spell)"
		'UNI_MartyrAmulet_Passive', -- "HasSpellFlag(SpellFlags.Spell)"
		'WildMagic_Swap', -- "(HasSpellFlag(SpellFlags.Spell) or SpellActivations()) and not WildMagicSpell() and Character() and not Grounded()"
	}
	for _, name in pairs(passivesToPatch) do
--	for _, name in pairs(Ext.Stats.GetStats("PassiveData")) do
		local passive = Ext.Stats.Get(name)
		if passive then
			local conditions = passive.Conditions

			local newConditions = conditions
			newConditions = newConditions:gsub("%f[%w_]HasSpellFlag%(SpellFlags.Spell%)", "(HasSpellFlag(SpellFlags.Spell) or HasStatus('DWE_TRUE_STRIKE',context.Source))")
			newConditions = newConditions:gsub("%f[%w_]IsSpell%(%)", "(IsSpell() or HasStatus('DWE_TRUE_STRIKE',context.Source))")
			newConditions = newConditions:gsub("%f[%w_]ArcaneAcuityGlovesCondition%(%)", "(ArcaneAcuityGlovesCondition() or HasStatus('DWE_TRUE_STRIKE',context.Source))")

			if newConditions ~= conditions then
				-- print(name .. ":")
				-- print("  <: " .. conditions)
				-- print("  >: " .. newConditions)
				passive.Conditions = newConditions
				numPatched = numPatched + 1
			else
				Ext.Utils.PrintWarning("DTrueStrike: Could not patch passive conditions for '" .. name .. "'")
			end
		else
			Ext.Utils.PrintWarning("DTrueStrike: Could not find passive '" .. name .. "'")
		end
	end

	local removeSEErrorsFrom = {
		'Target_DWE_TrueStrike',
		'Target_DWE_TrueStrike_Melee',
		'Projectile_DWE_TrueStrike_Ranged',
		'Shout_DWE_TrueStrike_Toggle_Melee',
		'Shout_DWE_TrueStrike_Toggle_Ranged',
		'Shout_DWE_TrueStrike_Radiant_Melee',
		'Shout_DWE_TrueStrike_Radiant_Ranged',
	}
	for _, name in pairs(removeSEErrorsFrom) do
		local spell = Ext.Stats.Get(name)
		spell.RequirementConditions = spell.RequirementConditions:gsub("DWE_TrueStrike_ScriptExtenderError%(%) and ", "")
	end

	print("DTrueStrike: Patched " .. numPatched .. " passives to handle Auto True Strike")
end

Ext.Events.StatsLoaded:Subscribe(locStatsLoaded)
