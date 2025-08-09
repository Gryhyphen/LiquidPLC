
local function getFluidFromDisplayName(displayName)
    return string.match(displayName, "^ME Fluid Pattern:%s*(.+)$")
            or string.match(displayName, "^Gas:%s*(.+)$")
end

local function getGasFromDisplayName(displayName)
       return string.match(displayName, "^Gas:%s*(.+)$")
end

return {
    getFluidFromDisplayName = getFluidFromDisplayName,
    getGasFromDisplayName = getGasFromDisplayName
}