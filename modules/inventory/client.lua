local files = {
    'modules/inventory/shared.lua',
    'modules/inventory/adapters/ox_inventory.lua',
    'modules/inventory/adapters/qb-inventory.lua',
    'modules/inventory/adapters/ps-inventory.lua',
    'modules/inventory/adapters/lj-inventory.lua',
    'modules/inventory/adapters/qs-inventory.lua',
    'modules/inventory/adapters/core_inventory.lua',
    'modules/inventory/adapters/codem-inventory.lua',
    'modules/inventory/adapters/origen_inventory.lua',
    'modules/inventory/adapters/tgiann-inventory.lua',
    'modules/inventory/adapters/ak47_inventory.lua',
    'modules/inventory/adapters/mf-inventory.lua',
    'modules/inventory/adapters/tss-inventory.lua',
    'modules/inventory/adapters/inventory.lua',
}

TSSModuleLoader.Define({
    name = 'Inventory',
    files = files,
    client = function(context)
        return context.CopyFunctions(TSS.Inventory, {
            'System', 'Supports', 'Count', 'Has', 'Player', 'Items', 'Image', 'Open', 'OpenStash', 'Close',
        })
    end,
})

RegisterNetEvent('tss_bridge:client:openRegisteredShop', function(id)
    if TSSModuleLoader.Ensure('Inventory') then
        TSS.Inventory.Open('shop', { type = id, id = 1 })
    end
end)

RegisterNetEvent('tss_bridge:client:openInventory', function(invType, data)
    if type(invType) == 'string' and TSSModuleLoader.Ensure('Inventory') then
        TSS.Inventory.Open(invType, data)
    end
end)
