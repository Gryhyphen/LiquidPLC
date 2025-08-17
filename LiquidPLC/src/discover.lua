require "bootstrap"
local fun = require "fun"
local _ = require "lodash" -- LuaLodash
local config = require "config"
local pretty = require "cc.pretty"
local util = require "util"

local CONFIG_SIDE_ID = 1 -- top is always the config

local function discoverSides(transposer)
    -- cubes have 6 sides we need to check
    return fun.range(0, 5)
        :map(function(x)
            local name, err = transposer.getInventoryName(x)
            if err ~= nil then
                -- ONLY if this side is not an inventory
                -- Try to detect Ender Tank via tank level
                local ok, tankLevel = pcall(transposer.getTankLevel, x, 1)
                if ok then
                    return { sideId = x, name = "enderstorage:ender_tank" }
                else
                    return nil -- skip sides with no inventory and no tank
                end
            end
            return { sideId = x, name = name }
        end)
        :filter(function(x) return x ~= nil end)
        :reduce(function(acc, x)
            if x.name == "enderstorage:ender_storage" then
                if acc.itemInputId ~= nil then
                    error("Duplicate itemInputId detected: side " .. tostring(acc.itemInputId) .. " and side " .. tostring(x.sideId))
                end
                acc.itemInputId = x.sideId
            elseif x.name == "enderio:block_buffer" then
                if acc.itemOutputId ~= nil then
                    error("Duplicate itemOutputId detected: side " .. tostring(acc.itemOutputId) .. " and side " .. tostring(x.sideId))
                end
                acc.itemOutputId = x.sideId
            elseif x.name == "thermalexpansion:machine" then
                -- just assuming that this must be a sequential fabricator
                if acc.itemOutputId ~= nil then
                    error("Duplicate itemOutputId detected: side " .. tostring(acc.itemOutputId) .. " and side " .. tostring(x.sideId))
                end
                acc.itemOutputId = x.sideId
            elseif x.name == "thermalexpansion:device" then
                -- just assuming that this must be a fluid allocator
                if acc.itemOutputId ~= nil then
                    error("Duplicate itemOutputId detected: side " .. tostring(acc.itemOutputId) .. " and side " .. tostring(x.sideId))
                end
                acc.itemOutputId = x.sideId
            elseif x.name == "enderstorage:ender_tank" then
                if acc.fluidInputId ~= nil then
                    error("Duplicate fluidInputId detected: side " .. tostring(acc.itemInputId) .. " and side " .. tostring(x.sideId))
                end
                acc.fluidInputId = x.sideId
            end
            return acc
        end, {})
end

local function getItemMetaFromRemote(localInventory, transposer, configSideId, itemInputSideId, slot)
    assert(itemInputSideId ~= nil, "Missing enderchest on a transposer, needed to read config")
    transposer.transferItem(configSideId, itemInputSideId, 1, slot, 1)
    local itemSpec = localInventory.getItemMeta(1)
    transposer.transferItem(itemInputSideId, configSideId, 1, 1, slot)
    return itemSpec
end

local function discoverConfig(localInventory, transposer, itemInputSideId)
    local size = transposer.getInventorySize(CONFIG_SIDE_ID)

    local slots = fun.range(1, size)

    local knownRecipes = slots
        :map(function(slot)
            local itemSpec = getItemMetaFromRemote(localInventory, transposer, CONFIG_SIDE_ID, itemInputSideId, slot)

            if not (itemSpec and itemSpec.pattern and itemSpec.pattern.outputs and itemSpec.pattern.inputs) then
                return nil
            end

            local displayName = itemSpec.pattern.outputs[1].displayName

            -- Test for fluid
            -- (Really, fluid should be renamed 'output', but I don't want to break working code that assumes fluid)
            -- (Right now, fluid will be 'muterially exclusive' with itemCraftingResult)
            -- (will refactor later)
            local fluid = util.getFluidFromDisplayName(displayName)
            if fluid ~= nil then
                local ingredients = itemSpec.pattern.inputs
                return { fluid = fluid, ingredients = ingredients }
            end

            -- Test for itemCraftingResult
            -- (Really, should have some sort of 'handler' maybe? Or 'patternType'?)
            -- (Because itemCraftingResult will use the 'detect current items being crafted' integrated dynamics compat)
            -- (when all fluids only use AE system "when fluid is below level" detection)
            local itemCraftingResult = itemSpec.pattern.outputs[1].displayName
            local ingredients = itemSpec.pattern.inputs
            return { itemCraftingResult = itemCraftingResult, ingredients = ingredients}

            -- The result of this is essentially a discriminated union
            -- except lua type system is shit and doesn't automatically flag issues where I haven't handled it correctly
            -- AND I've also not built the system to expect the type to be a discriminated union
            -- so it's pretty jank (luckily the orginal fluid system explicitly looks for fluids so will filter out the 'itemCraftingResult' elements)
        end)
        :filter(function(recipe) return recipe ~= nil end)
        :totable()

    return {
        knownRecipes = knownRecipes
    }
end

---@class KnownRecipe
---@field fluid string         # Fluid name extracted from item displayName
---@field ingredients table    # List of input items (structure depends on your item format)

---@class DeviceConfig
---@field knownRecipes KnownRecipe[]  # Array of known recipes

---@class DeviceModel
---@field id string                  # Unique peripheral ID (a guid)
---@field deviceConfig DeviceConfig  # Configuration object discovered from inventory
---@field outputId integer           # Side ID for item output
---@field itemInputId integer        # Side ID for item input
---@field fluidInputId integer?      # Optional side ID for fluid input (currently nil)

---@param localInventory any         # Peripheral used to read item metadata
---@param transposerWithId { id: string, transposer: any }  # Transposer and its ID
---@return DeviceModel
local function createDeviceModel(localInventory, transposerWithId)
    local transposer = transposerWithId.transposer
    local id = transposerWithId.id

    -- Discover sides 
    local sides = discoverSides(transposer)
    
    -- Discover config
    local deviceConfig = discoverConfig(localInventory, transposer, sides.itemInputId)

    -- Final device model
    return {
        id = id,
        deviceConfig = deviceConfig,
        outputId = sides.itemOutputId,
        itemInputId = sides.itemInputId,
        fluidInputId = sides.fluidInputId
    }
end

if (type(package.loaded['discover']) ~= 'table') then
    print("Running as a script")
    local transposers =
        fun.iter(_.uniq(peripheral.getNames(), function(x) return x end))
        :filter(function(x) return peripheral.getType(x) == "transposer" end)

    -- Ensuring none of the blacklisted transposers appear
    -- (Like those used by integratedDynamicsCraftSensor)
    transposers =
        fun.iter(_.difference(transposers:totable(), config.deviceTransposerBlacklist))
        :map(function(x) return {id = x, transposer = peripheral.wrap(x)} end)
    
    local localInventory = peripheral.wrap(config.localInventorySide)
    transposers =
        transposers
        :map(function(x) return createDeviceModel(localInventory, x) end)
        :totable()

    local file = fs.open("liquidplc_discover_data.txt", "w")
    if file then
        file.write(textutils.serialize(transposers))
        file.close()
        print("Data written to liquidplc_discover_data.txt")
    else
        print("Failed to open file for writing")
    end
end

-- Exports
return {
    discoverSides = discoverSides,
    getItemMetaFromRemote = getItemMetaFromRemote,
    discoverConfig = discoverConfig,
    createDeviceModel = createDeviceModel
}