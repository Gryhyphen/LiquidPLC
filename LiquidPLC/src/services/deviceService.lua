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

    -- Ensure cache is loaded
    if not self.deviceDataCache then
        error("Device data cache is not loaded. Call refreshCache() first.")
    end

    for _, device in ipairs(self.deviceDataCache) do
        for _, recipe in ipairs(device.deviceConfig.knownRecipes) do
            if recipe.fluid == nil then  -- no 'continue' in lua :(
                -- skip this recipe
            else
                -- process recipe
                local foundFluid = nil

                for _, fluid in ipairs(currentFluids) do
                    if fluid.label == recipe.fluid then
                        foundFluid = fluid
                        break
                    end
                end

                -- If fluid is missing or amount is too low, trigger refill
                if not foundFluid or foundFluid.amount < 5000 then
                    print("Refill needed for fluid:", recipe.fluid)
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


---Get tasks to support active crafts that require fluid handling
---@param activeCrafts string[] -- list of active craft labels
---@return WorkTask[]
function DeviceService:getActiveCraftLiquidSupportTasks(activeCrafts)
    local tasks = {}
    --print(textutils.serialize(activeCrafts))

    -- Ensure cache is loaded
    if not self.deviceDataCache then
        error("Device data cache is not loaded. Call refreshCache() first.")
    end

    for _, device in ipairs(self.deviceDataCache) do
        for _, recipe in ipairs(device.deviceConfig.knownRecipes) do
            
            if recipe.itemCraftingResult == nil then -- no 'continue' in lua :(
                -- skip this recipe
            else
                -- process recipe
                local foundCraft = nil

                for _, craft in ipairs(activeCrafts) do
                    if craft == recipe.itemCraftingResult then
                        foundCraft = craft
                        break
                    end
                end

                if foundCraft then
                    print("Craft '" .. foundCraft .. "' requires fluid")
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