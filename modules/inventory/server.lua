local files = {
    'modules/inventory/shared.lua',
    'modules/inventory/adapters/ox_inventory.lua',
    'modules/inventory/adapters/qb-inventory.lua',
    'modules/inventory/adapters/ps-inventory.lua',
    'modules/inventory/adapters/lj-inventory.lua',
    'modules/inventory/adapters/core_inventory.lua',
    'modules/inventory/adapters/codem-inventory.lua',
    'modules/inventory/adapters/origen_inventory.lua',
    'modules/inventory/adapters/tgiann-inventory.lua',
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
            'System', 'Supports', 'Count', 'Has', 'Player', 'GetSlot', 'Find', 'Weight', 'MaxWeight',
            'Items', 'Image', 'Open', 'OpenStash', 'Close',
        })

        local stopped = false
        local function audit(action, system, resource, data)
            data.action = action
            data.system = system
            data.resource = resource
            data.caller = context.Caller
            data.timestamp = os.time()
            TriggerEvent('tss_bridge:server:inventoryAudit', data)
        end

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
            local system, resource, adapter = TSS.Inventory._GetAdapter()
            amount = tonumber(amount) or 1
            if not adapter or type(adapter.add) ~= 'function' or not tonumber(source)
                or type(item) ~= 'string' or item == '' or amount <= 0
            then return false end
            local success = adapter.add(resource, source, item, amount, metadata, slot, reason) == true
            if success then audit('add', system, resource, {
                source = tonumber(source), item = item, amount = amount, metadata = metadata,
                slot = tonumber(slot), reason = reason,
            }) end
            return success
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
            local system, resource, adapter = TSS.Inventory._GetAdapter()
            amount = tonumber(amount) or 1
            if not adapter or type(adapter.remove) ~= 'function' or not tonumber(source)
                or type(item) ~= 'string' or item == '' or amount <= 0
            then return false end
            local success = adapter.remove(resource, source, item, amount, metadata, slot, reason) == true
            if success then audit('remove', system, resource, {
                source = tonumber(source), item = item, amount = amount, metadata = metadata,
                slot = tonumber(slot), reason = reason,
            }) end
            return success
        end

        --- Checks whether a player can carry an item amount.
        ---@param source integer Server player ID.
        ---@param item string Item name.
        ---@param amount? integer Amount to test.
        ---@param metadata? table Item metadata.
        ---@return boolean canCarry
        function Inventory.CanCarry(source, item, amount, metadata)
            local _, resource, adapter = TSS.Inventory._GetAdapter()
            amount = tonumber(amount) or 1
            if not adapter or type(adapter.canCarry) ~= 'function' or not tonumber(source)
                or type(item) ~= 'string' or item == '' or amount <= 0
            then return false end
            return adapter.canCarry(resource, source, item, amount, metadata) == true
        end

        --- Registers a stash with the active inventory.
        ---@param data TSSStashData Stash definition.
        ---@return boolean registered
        function Inventory.RegisterStash(data)
            local _, resource, adapter = TSS.Inventory._GetAdapter()
            if not adapter or type(adapter.registerStash) ~= 'function' or type(data) ~= 'table'
                or type(data.id or data.name) ~= 'string'
            then return false end
            data.weight = data.weight or data.maxWeight or data.maxweight
            return adapter.registerStash(resource, data) == true
        end

        --- Read a non-player stash. Unsupported adapters fail explicitly.
        function Inventory.Stash(id)
            local _, resource, adapter = TSS.Inventory._GetAdapter()
            if type(id) ~= 'string' or id == '' then return nil, 'invalid_stash' end
            if not adapter or not adapter.stashItems then return nil, 'unsupported_stash_items' end
            return adapter.stashItems(resource, id)
        end

        function Inventory.AddToStash(id, item, amount, metadata, slot, reason)
            local system, resource, adapter = TSS.Inventory._GetAdapter()
            amount = tonumber(amount) or 1
            if type(id) ~= 'string' or id == '' or type(item) ~= 'string' or item == '' or amount <= 0 then return false end
            if not adapter or not adapter.stashAdd then return false, 'unsupported_stash_add' end
            local success = adapter.stashAdd(resource, id, item, amount, metadata, slot, reason) == true
            if success then audit('stash_add', system, resource, {
                inventory = id, item = item, amount = amount, metadata = metadata,
                slot = tonumber(slot), reason = reason,
            }) end
            return success
        end

        function Inventory.RemoveFromStash(id, item, amount, metadata, slot, reason)
            local system, resource, adapter = TSS.Inventory._GetAdapter()
            amount = tonumber(amount) or 1
            if type(id) ~= 'string' or id == '' or type(item) ~= 'string' or item == '' or amount <= 0 then return false end
            if not adapter or not adapter.stashRemove then return false, 'unsupported_stash_remove' end
            local success = adapter.stashRemove(resource, id, item, amount, metadata, slot, reason) == true
            if success then audit('stash_remove', system, resource, {
                inventory = id, item = item, amount = amount, metadata = metadata,
                slot = tonumber(slot), reason = reason,
            }) end
            return success
        end

        --- Register a server-owned shop. Returns false when unsupported.
        function Inventory.RegisterShop(data)
            local _, resource, adapter = TSS.Inventory._GetAdapter()
            if type(data) ~= 'table' or type(data.id) ~= 'string' or data.id == '' or type(data.items) ~= 'table' then
                return false, 'invalid_shop'
            end
            if not adapter or not adapter.registerShop then return false, 'unsupported_shop' end
            return adapter.registerShop(resource, data)
        end

        function Inventory.OpenShop(source, id)
            local _, resource, adapter = TSS.Inventory._GetAdapter()
            if not tonumber(source) or type(id) ~= 'string' or id == '' then return false, 'invalid_shop' end
            if not adapter or not adapter.openShop then return false, 'unsupported_shop' end
            return adapter.openShop(resource, source, id)
        end

        --- Update metadata on an exact, server-verified inventory slot.
        function Inventory.SetMetadata(source, slot, metadata)
            local system, resource, adapter = TSS.Inventory._GetAdapter()
            if not adapter or not adapter.setMetadata then return false, 'unsupported_metadata' end
            source, slot = tonumber(source), tonumber(slot)
            if type(metadata) ~= 'table' or not source or not slot or slot < 1 then return false end
            local success, err = adapter.setMetadata(resource, source, slot, metadata)
            if success == true then audit('set_metadata', system, resource, {
                source = source, slot = slot, metadata = metadata,
            }) end
            return success == true, err
        end

        return Inventory
    end,
})
