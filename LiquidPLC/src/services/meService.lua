local fun = require "fun"

---@class MeService
---@field meInterface any
local MeService = {}
MeService.__index = MeService

---Create a new MeService
---@param meInterface any -- peripheral reference to ME system
---@return MeService
function MeService.new(meInterface)
    return setmetatable({
        meInterface = meInterface
    }, MeService)
end

---Get all fluids and gases currently in the ME network using luafun
---@return table[] -- list of {amount:number, label:string, name:string}
function MeService:getAllLiquids()
    local fluids = self.meInterface.getFluidsInNetwork() or {}
    local gases = self.meInterface.getGasesInNetwork() or {}

    return fun.chain(fun.iter(fluids), fun.iter(gases)):totable()
end



return MeService