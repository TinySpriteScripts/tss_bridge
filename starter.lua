TSS = TSS or {}
TSSBridge = TSSBridge or TSS

local bridgeResource = 'tss_bridge'
local files = {
    'config.lua',
    'helpers.lua',
    'modules/debug.lua',
    'modules/notify.lua',
    'modules/progressbars.lua',
    'modules/blips.lua',
    'modules/peds.lua',
    'modules/props.lua',
    'modules/vehicles.lua',
    'modules/world.lua',
    'modules/groups.lua',
    'modules/targets.lua',
    'modules/inventory.lua',
    'inventory/ox_inventory.lua',
    'inventory/qb-inventory.lua',
    'inventory/ps-inventory.lua',
    'inventory/lj-inventory.lua',
    'inventory/qs-inventory.lua',
    'inventory/core_inventory.lua',
    'inventory/codem-inventory.lua',
    'inventory/origen_inventory.lua',
    'inventory/tgiann-inventory.lua',
    'inventory/ak47_inventory.lua',
    'inventory/mf-inventory.lua',
    'inventory/tss-inventory.lua',
    'inventory/inventory.lua',
}

for i = 1, #files do
    local file = files[i]
    local contents = LoadResourceFile(bridgeResource, ('shared/%s'):format(file))

    if not contents then
        error(('[tss_bridge] Unable to load shared/%s'):format(file))
    end

    local chunk = assert(load(contents, ('@@%s/shared/%s'):format(bridgeResource, file)))
    chunk()
end
