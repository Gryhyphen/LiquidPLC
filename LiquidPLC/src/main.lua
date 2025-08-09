require "bootstrap"
local DeviceService = require "services.deviceService"
local MeService = require "services.meService"
local Config = require "config"

local meService = MeService.new(peripheral.wrap(Config.meSystemId))
local deviceService = DeviceService.new(Config.discoverDataFilePath)

local state = { workQueue = {}, currentFluids = {}}
local function InputScan()
    state["currentFluids"] = meService:getAllLiquids()
end

local function ProgramScan()
    deviceService:refreshCache()
    state["workQueue"] = deviceService:getRefillTasks(state["currentFluids"])
end

local function ExecuteProgramLogic()
    if #state.WorkQueue == 0 then
        print("WorkQueue is empty.")
        return
    end

end

InputScan()
ProgramScan()