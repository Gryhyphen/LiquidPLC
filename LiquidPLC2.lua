local fun = require "fun"
local _ = require "lodash" -- LuaLodash


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
---@field id string                  # Unique peripheral ID (e.g. "right", "back")
---@field config DeviceConfig        # Configuration object discovered from inventory
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
    local config = discoverConfig(localInventory, transposer, sides.itemInputId)

    -- Final device model
    return {
        id = id,
        config = config,
        outputId = sides.itemOutputId,
        itemInputId = sides.itemInputId,
        fluidInputId = nil
    }
end

-- Exports
return {
    discoverSides = discoverSides,
    getItemMetaFromRemote = getItemMetaFromRemote,
    discoverConfig = discoverConfig,
    createDeviceModel = createDeviceModel
}

--[[ 
local directEnderchest = peripheral.wrap("left")
local transposers =
    fun.iter(_.uniq(peripheral.getNames(), function(x) return x end))
    :filter(function(x) return peripheral.getType(x) == "transposer" end)
    :map(function(x) return {id = x, transposer = peripheral.wrap(x)} end)

local plcs = fun.iter(transposers)
    :map(function(t)
        local sides = 6
        local results =
            fun.range(0, sides - 1)
            :map(function(x) return {sideId = x, name = t.transposer.getInventoryName(x)} end)
        return {transposer = t, results = results}
    end)

plcs:each(function(t)
    --print(peripheral.getName(t))
    --fun.iter(t.transposer):each(function(stuff) print(perostuff) end)
end)

transposers
   :each(function(x) print(x.id) end) ]]

--local plcs = _.map(transposer, function(t)
--    local sides = 6
--    _.range(6)
--    return {
--        config
--    }
--end)

--print(fun.range(5):map(function(x) return x^2 end):reduce(operator.add, 0))