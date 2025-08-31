
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
    
    -- Special handling for annoying liquids
    if liquidCodeName == "destabilizedredstone" then
        return "redstone"
    elseif liquidCodeName == "moltensulfur" then
        return "sulfur"
    elseif liquidCodeName == "sulfurdioxide" then
        return "sulfur_dioxide"
    elseif liquidCodeName == "sulfurtrioxide" then
        return "sulfur_trioxide"
    end
    return liquidCodeName
end

return {
    getFluidFromDisplayName = getFluidFromDisplayName,
    getGasFromDisplayName = getGasFromDisplayName,
    getFluidCodeNameFromDisplayName = getFluidCodeNameFromDisplayName
}