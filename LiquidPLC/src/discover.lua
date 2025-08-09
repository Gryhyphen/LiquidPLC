require "bootstrap"
local fun = require "fun"
local _ = require "lodash" -- LuaLodash
local config = require "config"
local pretty = require "cc.pretty"

local CONFIG_SIDE_ID = 1 -- top is always the config

local function discoverSides(transposer)
    -- cubes have 6 sides we need to check
    return fun.range(0, 5)
        :map(function(x)
            local name, err = transposer.getInventoryName(x)
            if err ~= nil then
                return nil -- skip sides with no inventory
            end
            return { sideId = x, name = name }
        end)
        :filter(function(x) return x ~= nil end)
        :reduce(function(acc, x)
            if x.name == "enderstorage:ender_storage" then
                if acc.itemInputId ~= nil then
                    error("Duplicate itemInputId detected: side " .. acc.itemInputId .. " and side " .. x.sideId)
                end
                acc.itemInputId = x.sideId
            elseif x.name == "enderio:block_buffer" then
                if acc.itemOutputId ~= nil then
                    error("Duplicate itemOutputId detected: side " .. acc.itemOutputId .. " and side " .. x.sideId)
                end
                acc.itemOutputId = x.sideId
            end
            return acc
        end, {})
end

local function getItemMetaFromRemote(localInventory, transposer, configSideId, itemInputSideId, slot)
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
            if itemSpec and itemSpec.pattern and itemSpec.pattern.outputs and itemSpec.pattern.inputs then
                local fluid = string.match(itemSpec.pattern.outputs[1].displayName, "%a+")
                local ingredients = itemSpec.pattern.inputs
                return { fluid = fluid, ingredients = ingredients }
            end
            return nil
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
        fluidInputId = nil
    }
end

if (type(package.loaded['discover']) ~= 'table') then
    print("Running as a script")
    local transposers =
        fun.iter(_.uniq(peripheral.getNames(), function(x) return x end))
        :filter(function(x) return peripheral.getType(x) == "transposer" end)
        :map(function(x) return {id = x, transposer = peripheral.wrap(x)} end)
    
    --transposers = fun.iter(_.difference(transposers:totable(), config.deviceTransposerBlacklist))
    --    :map(function(x) return {id = x, transposer = peripheral.wrap(x)} end)
    
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