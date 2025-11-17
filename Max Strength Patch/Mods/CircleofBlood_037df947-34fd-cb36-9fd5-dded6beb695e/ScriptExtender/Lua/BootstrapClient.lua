-- Defining the key pieces of information for the mod here
--local modGuid = "7588b857-8bae-4967-a73c-20f7833ae26f"
--local subClassGuid = "2c3b6583-e8bd-4310-82b1-94cd0beb5542"
--local BootStrap = {}

-- If SCF is loaded, use it to load Subclass into Progressions. Otherwise, DIY.
--if Ext.Mod.IsModLoaded("67fbbd53-7c7d-4cfa-9409-6d737b4d92a9") then
-- local subClasses = {
--    HavsglimtCircleofBlood = {
--      modGuid = modGuid,
--      subClassGuid = subClassGuid,
--      class = "druid",
--      subClassName = "Circle of Blood"
--    }
--  }

--  local function OnStatsLoaded()
--    Mods.SubclassCompatibilityFramework = Mods.SubclassCompatibilityFramework or {}
--    Mods.SubclassCompatibilityFramework.API = Mods.SubclassCompatibilityFramework.Api or {}
--    Mods.SubclassCompatibilityFramework.API.InsertSubClasses(subClasses)
--  end

--  Ext.Events.StatsLoaded:Subscribe(OnStatsLoaded)
-- If SCF isn't installed, insert class into Progression if another mod overwrites the Progression
--else
--  local function InsertSubClass(arr)
--    table.insert(arr, subClassGuid)
--  end

--  local function DetectSubClass(arr)
--    for _, value in pairs(arr) do
--      if value == subClassGuid then
--        return true
--      end
--    end
--  end

-- function BootStrap.loadSubClass(arr)
--    if arr ~= nil then
--      local found = DetectSubClass(arr)
--      if not found then
--        InsertSubClass(arr)
--      end
--    end
--  end

--  BootStrap.loadSubClass(Ext.Definition.Get("95322dde-349a-4101-964f-9aa46abd890b", "Progression").SubClasses)
--end