local DeviceService = {}
DeviceService.__index = DeviceService

---@param discoverDataFilePath string -- filePath to
---@return DeviceService
function DeviceService.new(discoverDataFilePath)
    return setmetatable({
        discoverDataFilePath = discoverDataFilePath,
        deviceDataCache = nil
    }, DeviceService)
end

---Refresh the device data cache from file
function DeviceService:refreshCache()
    local file = assert(io.open(self.discoverDataFilePath, "r"), "Failed to open device data file: " .. self.discoverDataFilePath)
    local content = file:read("*a")
    file:close()

    local data = textutils.unserialize(content)
    if not data then
        error("Failed to deserialize device data from file: " .. self.discoverDataFilePath)
    end

    self.deviceDataCache = data
end

---Get refill tasks based on current fluid levels
---@param currentFluids table[] -- list of {amount:number, label:string, name:string}
---@return WorkTask[]
function DeviceService:getRefillTasks(currentFluids)
    local tasks = {}

    for _, device in ipairs(self.deviceDataCache) do
        for _, recipe in ipairs(device.deviceConfig.knownRecipes) do
            for _, fluid in ipairs(currentFluids) do
                if fluid.label == recipe.fluid and fluid.amount < 5000 then
                    print("Refill needed for fluid:", fluid.label)
                    table.insert(tasks, {
                        ingredients = recipe.ingredients,
                        device = device
                    })
                end
            end
        end
    end

    return tasks
end

return DeviceService