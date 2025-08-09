local config = {
    deviceTransposerBlacklist = {},
    localInventorySide = "left",
    meSystemId = "9e160c33-50ca-43c2-8905-fe9695e0021a",
    discoverDataFilePath = "liquidplc_discover_data.txt",
    ccMeControllerId = 'top',
    localFluidInventoryId = "bottom",
    ccMeFluidInterfaceId = "right",
    gasExportBusId = "406a8282-0e95-4031-bc42-b3715f72fea3",
    gasExportBusPartSlot = 5,
    gasDatabaseId = "1e0521a2-b8ac-4a04-a0a0-56f732b285e8",
    gasDatabaseLookupTable = {
        ["Chlorine"] = 1
    }
}

return config