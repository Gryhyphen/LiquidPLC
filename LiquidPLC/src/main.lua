require "bootstrap"
local fun = require "fun"
local DeviceService = require "services.deviceService"
local MeService = require "services.meService"
local Config = require "config"

local meService = MeService.new(peripheral.wrap(Config.meSystemId))
local deviceService = DeviceService.new(Config.discoverDataFilePath)
local localMe = peripheral.wrap(Config.ccMeControllerId)

local state = { workQueue = {}, currentFluids = {}}
local function InputScan()
    state["currentFluids"] = meService:getAllLiquids()
end

local function ProgramScan()
    deviceService:refreshCache()
    state["workQueue"] = deviceService:getRefillTasks(state["currentFluids"])
end

local function ExecuteProgramLogic()
    if #state["workQueue"] == 0 then
        print("WorkQueue is empty.")
        return
    end

    fun.iter(state["workQueue"])
    :each(function(x)
        local deviceModel = x.device
        local ingredientsRequested = x.ingredients


        fun.iter(ingredientsRequested)
        :each(function(key,ingredient)
            local success1, item = pcall(function()
                return localMe.findItem(ingredient.name)
            end)
            
            if not success1 then
                print("Unable to fufill request for '" .. ingredient.name)
                return
            end

            local success2, _ = pcall(function()
                return item.export(Config.localInventorySide)
            end)

            if not success2 then
                return item.craft(32)
            end

        end)

        local transposer = peripheral.wrap(deviceModel.id)
        transposer.transferItem(deviceModel.itemInputId, deviceModel.outputId, 64, 1)
    end)

    

end

while true do
    InputScan()
    ProgramScan()
    ExecuteProgramLogic()

    os.sleep(1)  -- Sleeps for 1 second before repeating
end