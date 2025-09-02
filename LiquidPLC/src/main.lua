require "bootstrap"
local fun = require "fun"
local util = require "util"
local _ = require "lodash" -- LuaLodash
local DeviceService = require "services.deviceService"
local MeService = require "services.meService"
local IntegratedDynamicsCraftSensorService = require "services.integratedDynamicsCraftSensorService"
local Config = require "config"

local meService = MeService.new(peripheral.wrap(Config.meSystemId))
local deviceService = DeviceService.new(Config.discoverDataFilePath)
local integratedDynamicsCraftSensorService = IntegratedDynamicsCraftSensorService.new(Config.integratedDynamicsMeSensorId, Config.integratedDynamicsMeSensorSide)
local localMe = peripheral.wrap(Config.ccMeControllerId)

local gasSource = peripheral.wrap(Config.gasExportBusId)

-- local liquidSource = peripheral.wrap(Config.ccMeFluidInterfaceId)
local liquidSources = { peripheral.find('appliedenergistics2:fluid_interface') }


local state = { workQueue = {}, currentFluids = {}, currentMeCrafts = {}}
local function InputScan()
    state["currentFluids"] = meService:getAllLiquids()
    state["currentMeCrafts"] = integratedDynamicsCraftSensorService:getActiveCrafts()
    --print(textutils.serialize(integratedDynamicsCraftSensorService:getActiveCrafts()))
end

local function ProgramScan()
    deviceService:refreshCache()

    local allTasks =
        fun.iter(deviceService:getRefillTasks(state["currentFluids"]))
        :chain(deviceService:getActiveCraftLiquidSupportTasks(state["currentMeCrafts"]))
        :totable()

    -- Group tasks by device ID
    local grouped = _.groupBy(allTasks, function(task)
        return task.device.id
    end)

    -- Take the first task from each device group
    -- Tasks should be scanned in the order in which they are defined
    -- in the configuration chest (i.e. higher priority tasks)
    state["workQueue"] = fun.iter(grouped)
        :map(function(_, group) return group[1] end)
        :totable()
end

local function ExecuteProgramLogic()
    if #state["workQueue"] == 0 then
        print("WorkQueue is empty.")
        return
    end

    fun.iter(state["workQueue"])
    :each(function(x)
        local deviceModel = x.device
        local ingredientsRequested = fun.iter(x.ingredients)

        local fluidIngredients, dryIngredients =
            ingredientsRequested
            --:map(function(x,c) print(textutils.serialize(x),textutils.serialize(c)); return x; end)
            :partition(function(x) return util.getFluidFromDisplayName(x.displayName) end)

        local gasIngredients, liquidIngredients =
            fluidIngredients
            :partition(function(x) return util.getGasFromDisplayName(x.displayName) end)

        if (#dryIngredients:totable() > 0) then
            dryIngredients
            :each(function(ingredient)
                local success1, item = pcall(function()
                    return localMe.findItem(ingredient.name)
                end)
                
                if not success1 then
                    print("Unable to fufill request for '" .. ingredient.name .. "'")
                    return
                end

                local success2, _ = pcall(function()
                    return item.export(Config.localInventorySide)
                end)

                if not success2 then
                    print("Unable to fufill request for '" .. ingredient.name .. "'")
                    print("Attempting to craft" )
                    return item.craft(32)
                end

            end)

            local transposer = peripheral.wrap(deviceModel.id)
            transposer.transferItem(deviceModel.itemInputId, deviceModel.outputId, 64, 1)

            -- Clearing away any other items in localInventory/ the enderchest
            -- for the next work queue task
            localMe.pullItems(Config.localInventorySide, 1, 64)
            localMe.pullItems(Config.localInventorySide, 2, 64)
            localMe.pullItems(Config.localInventorySide, 3, 64)
        end

        if(#liquidIngredients:totable() > 0) then
            liquidIngredients
            :each(function(ingredient)
                local liquidCodeName = util.getFluidCodeNameFromDisplayName(ingredient.displayName)
                
                local potentialLiquidSources = fun.iter(liquidSources)
                    :filter(function(x)
                        local hasFluid = fun.iter(x.getTanks())
                            :any(function(y) return y.name == liquidCodeName end)
                        return hasFluid
                    end)
                    :totable()

                -- Ensure exactly one match
                if (#potentialLiquidSources ~= 1) then
                    error("Expected exactly one liquid source for '" .. liquidCodeName .. "', found " .. #potentialLiquidSources)
                end

                local liquidSource = potentialLiquidSources[1]
                
                liquidSource.pushFluid(Config.localFluidInventoryId, 1000, liquidCodeName)
                -- TODO: don't transfer fluid if it would put it over 6000 in the transposer output
                -- as soon as any fluid hits the 8000 cap, stuff breaks
                local transposer = peripheral.wrap(deviceModel.id)
                transposer.transferFluid(deviceModel.fluidInputId, deviceModel.outputId, 1000)
                -- clean up any remaining fluid
                liquidSource.pullFluid(Config.localFluidInventoryId, 1000, liquidCodeName)
            end)
        end

        if(#gasIngredients:totable() > 0) then
            gasIngredients
            :each(function(ingredient)
                local gasName = util.getGasFromDisplayName(ingredient.displayName)
                -- hardcoding gasses from the database because I'm lazy
                -- (the database is essentially a lookup table)
                local gasDatabaseIndex = Config.gasDatabaseLookupTable["Chlorine"]
                gasSource.setGasExportConfiguration(Config.gasExportBusPartSlot, Config.gasDatabaseId, gasDatabaseIndex)
                -- This is a HACK
                -- It slows down the entire control loop
                -- But since I'm not actively controlling the gas export with the computer
                -- I just have to wait to let to transfer a little bit of gas
                os.sleep(1)
                -- This clears the gas, for some reason, idk.
                -- But it works and I do want the gas to be cleared
                gasSource.setGasExportConfiguration(Config.gasExportBusPartSlot,4)
            end)
        end

        --gasExport.setGasExportConfiguration(5,'Config.databaseId',1)
        -- clear with gasExport.setGasExportConfiguration(5,4)


    end)

    

end

while true do
    InputScan()
    ProgramScan()
    ExecuteProgramLogic()

    os.sleep(1)  -- Sleeps for 1 second before repeating
end