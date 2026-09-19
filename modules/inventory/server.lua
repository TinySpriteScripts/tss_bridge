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
    dependencies = { 'Framework' },
    files = files,
    serverFiles = { 'modules/inventory/usable.lua', 'modules/inventory/framework_usable.lua' },
    server = function(context)
        ---@type TSSInventoryServerModule
        local Inventory = context.CopyFunctions(TSS.Inventory, {
            'System', 'Supports', 'Count', 'Has', 'Player', 'Items', 'Image', 'Open', 'OpenStash', 'Close',
        })

        local stopped = false
        context.OnStop(function()
            stopped = true
            TSS.Inventory._ClearUseableItems(context.Caller)
        end)

        --- Registers an existing item for server-side use; does not consume it.
        ---@param item string Existing inventory item name.
        ---@param callback fun(source: integer, item: TSSUsedItem) Runs when the inventory uses the item.
        ---@return boolean registered
        ---@return string? error Registration failure reason.
        function Inventory.CreateUseableItem(item, callback)
            if stopped then return false, 'consumer_stopped' end
            return TSS.Inventory._CreateUseableItem(context.Caller, item, callback)
        end

        --- Alternate spelling of CreateUseableItem.
        Inventory.CreateUsableItem = Inventory.CreateUseableItem

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

        --- Register a server-owned shop. Returns false when unsupported.
        function Inventory.RegisterShop(data)
            local _, resource, adapter = TSS.Inventory._GetAdapter()
            if not adapter or not adapter.registerShop then return false, 'unsupported_shop' end
            return adapter.registerShop(resource, data)
        end

        function Inventory.OpenShop(source, id)
            local _, resource, adapter = TSS.Inventory._GetAdapter()
            if not adapter or not adapter.openShop then return false, 'unsupported_shop' end
            return adapter.openShop(resource, source, id)
        end

        --- Update metadata on an exact, server-verified inventory slot.
        function Inventory.SetMetadata(source, slot, metadata)
            local _, resource, adapter = TSS.Inventory._GetAdapter()
            if not adapter or not adapter.setMetadata then return false, 'unsupported_metadata' end
            if type(metadata) ~= 'table' or not tonumber(slot) then return false end
            return adapter.setMetadata(resource, source, tonumber(slot), metadata)
        end

        return Inventory
    end,
})
