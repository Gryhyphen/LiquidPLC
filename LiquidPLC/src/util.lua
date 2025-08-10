
local function getFluidFromDisplayName(displayName)
    return string.match(displayName, "^ME Fluid Pattern:%s*(.+)$")
            or string.match(displayName, "^Gas:%s*(.+)$")
end

local function getGasFromDisplayName(displayName)
       return string.match(displayName, "^Gas:%s*(.+)$")
end

-- Use this function to resolve the name used by 'code
-- to indentify the fluid from the displayname
local function getFluidCodeNameFromDisplayName(displayName)
    local liquidCodeName = string.gsub(string.lower(getFluidFromDisplayName(displayName)), "%s+", "")
    
    -- Special handling for redstone
    if liquidCodeName == "destabilizedredstone" then
        return "redstone"
    end
    return liquidCodeName
end

return {
    getFluidFromDisplayName = getFluidFromDisplayName,
    getGasFromDisplayName = getGasFromDisplayName,
    getFluidCodeNameFromDisplayName = getFluidCodeNameFromDisplayName
}