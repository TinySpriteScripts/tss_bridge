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
    server = function(context)
        ---@type TSSInventoryServerModule
        local Inventory = context.CopyFunctions(TSS.Inventory, {
            'System', 'Supports', 'Count', 'Has', 'Player', 'Items', 'Open', 'OpenStash', 'Close',
        })

        --- Adds an item to a player's inventory.
        ---@param source integer Server player ID.
        ---@param item string Item name.
        ---@param amount? integer Amount to add.
        ---@param metadata? table Item metadata.
        ---@param slot? integer Preferred slot.
        ---@param reason? string Audit reason.
        ---@return boolean success
        function Inventory.Add(source, item, amount, metadata, slot, reason)
            local _, resource, adapter = TSS.Inventory._GetAdapter()
            if not adapter then return false end
            return adapter.add(resource, source, item, amount, metadata, slot, reason) == true
        end

        --- Removes an item from a player's inventory.
        ---@param source integer Server player ID.
        ---@param item string Item name.
        ---@param amount? integer Amount to remove.
        ---@param metadata? table|string Metadata filter.
        ---@param slot? integer Exact slot.
        ---@param reason? string Audit reason.
        ---@return boolean success
        function Inventory.Remove(source, item, amount, metadata, slot, reason)
            local _, resource, adapter = TSS.Inventory._GetAdapter()
            if not adapter then return false end
            return adapter.remove(resource, source, item, amount, metadata, slot, reason) == true
        end

        --- Checks whether a player can carry an item amount.
        ---@param source integer Server player ID.
        ---@param item string Item name.
        ---@param amount? integer Amount to test.
        ---@param metadata? table Item metadata.
        ---@return boolean canCarry
        function Inventory.CanCarry(source, item, amount, metadata)
            local _, resource, adapter = TSS.Inventory._GetAdapter()
            if not adapter then return false end
            return adapter.canCarry(resource, source, item, amount, metadata) == true
        end

        --- Registers a stash with the active inventory.
        ---@param data TSSStashData Stash definition.
        ---@return boolean registered
        function Inventory.RegisterStash(data)
            local _, resource, adapter = TSS.Inventory._GetAdapter()
            if not adapter then return false end
            data.weight = data.weight or data.maxWeight or data.maxweight
            return adapter.registerStash(resource, data) == true
        end

        return Inventory
    end,
})
