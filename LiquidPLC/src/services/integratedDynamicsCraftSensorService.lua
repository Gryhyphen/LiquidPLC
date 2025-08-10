local fun = require "fun"

local IntegratedDynamicsCraftSensorService = {}
IntegratedDynamicsCraftSensorService.__index = IntegratedDynamicsCraftSensorService


---Create a new MeService
---@param integratedDynamicsMeSensorId string
---@param integratedDynamicsMeSensorSide number

function IntegratedDynamicsCraftSensorService.new(
    integratedDynamicsMeSensorId,
    integratedDynamicsMeSensorSide
)
    return setmetatable({
        integratedDynamicsMeSensorId = integratedDynamicsMeSensorId,
        integratedDynamicsMeSensorSide = integratedDynamicsMeSensorSide 
    }, IntegratedDynamicsCraftSensorService)
end


function IntegratedDynamicsCraftSensorService:getActiveCrafts()
    local transposer = peripheral.wrap(self.integratedDynamicsMeSensorId)

    -- GetAllStacks is broken, so manually iterating
    local side = self.integratedDynamicsMeSensorSide
    local size = transposer.getInventorySize(side)
    local currentCrafts =
        fun.range(1, size)
        :map(function(slot) return transposer.getStackInSlot(side, slot) end)
        :filter(function(stack) return stack ~= nil end)
        :map(function(stack) return stack.label end)
        :map(function(label)
            -- This part is a hack because I messed up the ID sensor
            -- I should probably write the ID sensor to use labels instead
            -- of the minecraft id
            if label == "libvulpes:productingot" then
                return "Titanium Ingot"
            end
            error("unable to match label '" .. label .. "'")
        end)

    return currentCrafts:totable()

end

return IntegratedDynamicsCraftSensorService
