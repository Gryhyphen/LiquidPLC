local fun = require "fun"
local _ = require "lodash" -- LuaLodash


local function generateConfig(transposer, itemInputSideId)
    local configSideId = 1 -- 'top' is always config chest
    local size = transposer.getInventorySize(configSideId)

    local slots = fun.range(1, size)

    local knownRecipes = slots
        :map(function(slot)
            local itemSpec = getItemSpec(transposer, itemInputSideId, slot)
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

local function createDevice(transposerWithId)
    local transposer = transposerWithId.transposer
    local id = transposerWithId.id

    -- Discover sides (cubes have 6)
    local sides =
        fun.range(0, 5)
        :map(function(x) return {sideId = x, name = t.transposer.getInventoryName(x)} end)
    
    -- Discover config
    local topSideId = 1 -- Assume 'top' is an inventory which contains config
    local config = generateConfig(transposer, itemInputSideId)

    -- Final device object
    return {
        id = id,
        config = config,
        Output = sides.front.proxy,
        ItemInput = sides.back.proxy,
        FluidInput = sides.right.proxy
    }
end


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
   :each(function(x) print(x.id) end)

--local plcs = _.map(transposer, function(t)
--    local sides = 6
--    _.range(6)
--    return {
--        config
--    }
--end)

--print(fun.range(5):map(function(x) return x^2 end):reduce(operator.add, 0))