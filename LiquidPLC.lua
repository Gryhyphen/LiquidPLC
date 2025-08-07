-- NOTES: Because the me interface is having issues with us pulling items
--        from it via the transposer, I want to go back to using the
--        offical opencomputers AE component.
--        A smart way of doing this is to reuse the enderchest
--        to dump items into it, then transposering them out.


local sides = {
    ["bottom"] = 0,
    ["top"] = 1,
    ["left"] = 5,
    ["front"] = 3,
    ["back"] = 2,
    ["right"] = 4
}

local myTransposer = peripheral.wrap("20f9691a-ba2e-4d4d-b1a9-0ba8e6549574")
local rawConfigCache = peripheral.wrap("left")
local meSystem = peripheral.wrap("9e160c33-50ca-43c2-8905-fe9695e0021a")
--local databaseAddress = "ee122a86-a66a-4ad1-81c6-48af5fc19d9a"
--local database = peripheral.wrap(databaseAddress)

--myTransposer.store(sides.top, 1, databaseAddress, 1)
--for k,v in pairs(database.get(1)) do print(k,v) end



function getItemSpec(slot)
    myTransposer.transferItem(sides.top, sides.back, 1, slot, slot)
    local itemSpec = rawConfigCache.getItemMeta(1)
    myTransposer.transferItem(sides.back, sides.top, 1, slot, slot)
    return itemSpec
end

function getConfig()
    local itemSpec = getItemSpec(1)
    local fluid = string.match(itemSpec.pattern.outputs[1].displayName, "%a+")
    local ingredients = itemSpec.pattern.inputs


    print(fluid)
    return {
        knownRecipes = {
            {["fluid"] = fluid, ["ingredients"]= ingredients}
        }
    }
end

local config = getConfig()
local state = { WorkQueue = {}}
function InputScan()
    -- Shape of
    -- {
    --    {amount: num, hasTag: bool, label: string, name: string}
    --}
    state["CurrentFluids"] = meSystem.getFluidsInNetwork()
end

function ProgramScan()
    for _, recipe in pairs(config.knownRecipes) do
        for _, fluid in pairs(state.CurrentFluids or {}) do
            if fluid.label == recipe.fluid and fluid.amount < 5000 then
                print("Found fluid needing refill!")
                --ingredients has shape of
                -- {
                --    [3] = {
                --          count: num, damage: num, displayName:string, maxCount:num, maxDamage:num, name:string, ores:any, rawName:string
                --      }
                --}
                table.insert(state.WorkQueue, recipe.ingredients)
            end
        end
    end
end

function ExecuteProgramLogic()
    -- me interface 4
    -- block buffer 3

    local interfaceSize = myTransposer.getInventorySize(4)

    if #state.WorkQueue == 0 then
        print("WorkQueue is empty.")
        return
    end

    local currentTask = state.WorkQueue[1]  -- Get first recipe ingredients

    for i = 1, interfaceSize do
        -- potentialInput shape of
        -- {
        -- damage: num, hasTag:bool, label:string, maxDamage: num, maxSize: num, name: string, size:num
        --}
        local potentialInput = myTransposer.getStackInSlot(4, i)

        if potentialInput then
            for _, ingredient in pairs(currentTask) do
                if potentialInput.name == ingredient.name then
                    print("Matching input found in interface slot " .. i)
                    myTransposer.transferItem(sides.right, sides.front, 1, i)
                    -- You could add more tracking logic here if needed
                end
            end
        end
    end

    -- Pop the first item from the queue
    table.remove(state.WorkQueue, 1)
end


--for k,v in pairs(itemSpec.pattern.outputs[1]) do print(k,v) end
--for k,v in pairs(getConfig().pattern.outputs[1]) do print(k,v) end

while true do
    InputScan()
    ProgramScan()
    ExecuteProgramLogic()

    os.sleep(1)  -- Sleeps for 1 second before repeating
end
