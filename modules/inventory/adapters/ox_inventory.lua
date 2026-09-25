-- ox_inventory adapter owned by the Inventory module.
local Utils = TSS.Inventory.Utils

TSS.Inventory.RegisterAdapter('ox', TSS.Resources.OxInventory, {
    registerUsable = function(resource, item, callback)
        local ok, definition = Utils.CallExport(resource, 'Items', item)
        if not ok or type(definition) ~= 'table' then return false, 'item_not_defined' end

        -- OX only reaches framework usable-item callbacks when consume is nil/false.
        -- That excludes QB-Core and also makes `consume = 0` (OX's documented
        -- reusable-item setting) impossible to register through the old route.
        -- Use OX's supported hook pipeline instead and make a plain item enter it
        -- without consuming the item.
        if definition.cb or (definition.consume ~= nil and definition.consume ~= false and definition.consume ~= 0) then
            return false, 'ox_item_uses_native_handler: remove consuming/client use actions/server export or set consume to 0'
        end

        local originalConsume = definition.consume
        local changedConsume = originalConsume ~= 0
        if changedConsume then
            definition.consume = 0

            -- The official Items export currently returns the live definition.
            -- Verify that behaviour so forks returning a copy fail safely instead
            -- of reporting a registration that can never dispatch.
            local verified, current = Utils.CallExport(resource, 'Items', item)
            if not verified or type(current) ~= 'table' or current.consume ~= 0 then
                definition.consume = originalConsume
                return false, 'ox_item_requires_consume_zero'
            end
        end

        local hooked, hookId = Utils.CallExport(resource, 'registerHook', 'usingItem', function(payload)
            if type(payload) ~= 'table' or type(payload.item) ~= 'table' then return end
            return callback(payload.source, payload.item)
        end, {
            itemFilter = { [item] = true },
        })
        if not hooked or not hookId then
            if changedConsume then definition.consume = originalConsume end
            return false, hooked and 'ox_hook_registration_failed' or tostring(hookId)
        end

        local removed = false
        local function cleanup()
            if removed then return end
            removed = true
            Utils.CallExport(resource, 'removeHooks', hookId)
        end

        return true, nil, cleanup
    end,

    stashItems = function(resource, id)
        return Utils.TryExports(resource, { 'GetInventoryItems' }, id)
    end,
    stashAdd = function(resource, id, item, amount, metadata, slot)
        return Utils.TryExports(resource, { 'AddItem' }, id, item, amount, metadata, slot) == true
    end,
    stashRemove = function(resource, id, item, amount, metadata, slot)
        return Utils.TryExports(resource, { 'RemoveItem' }, id, item, amount, metadata, slot) == true
    end,

    registerShop = function(resource, data)
        return Utils.TryExportOk(resource, { 'RegisterShop' }, data.id, {
            name = data.label, inventory = data.items, groups = data.groups,
            locations = data.coords and { vector3(data.coords.x, data.coords.y, data.coords.z) } or nil,
        })
    end,
    openShop = function(resource, source, id)
        TriggerClientEvent('tss_bridge:client:openRegisteredShop', source, id)
        return true
    end,
    setMetadata = function(resource, source, slot, metadata)
        return Utils.TryExportOk(resource, { 'SetMetadata' }, source, slot, metadata)
    end,

    add = function(resource, source, item, amount, metadata, slot)
        return Utils.TryExports(resource, { 'AddItem' }, source, item, amount or 1, metadata, slot)
    end,

    remove = function(resource, source, item, amount, metadata, slot)
        return Utils.TryExports(resource, { 'RemoveItem' }, source, item, amount or 1, metadata, slot)
    end,

    count = function(resource, source, item, metadata)
        if TSS.IsClient() then
            return Utils.TryExports(resource, { 'GetItemCount' }, item, metadata, true) or 0
        end

        return Utils.TryExports(resource, { 'GetItemCount' }, source, item, metadata, true) or 0
    end,

    canCarry = function(resource, source, item, amount, metadata)
        return Utils.TryExports(resource, { 'CanCarryItem' }, source, item, amount or 1, metadata) == true
    end,

    image = function(resource, item, definition)
        local filename = definition.image or (definition.client and definition.client.image) or (item .. '.png')
        return ('https://cfx-nui-%s/web/images/%s'):format(resource, filename)
    end,

    items = function(resource)
        return Utils.TryExports(resource, { 'Items' })
    end,

    inventory = function(resource, source)
        if TSS.IsClient() then
            return Utils.TryExports(resource, { 'GetPlayerItems' }) or {}
        end

        return Utils.TryExports(resource, { 'GetInventoryItems' }, source) or {}
    end,

    registerStash = function(resource, data)
        data = Utils.NormaliseStash(data)
        return Utils.TryExportOk(resource, { 'RegisterStash' }, data.id, data.label, data.slots, data.weight, data.owner, data.groups, data.coords)
    end,

    openInventory = function(resource, source, invType, data)
        if TSS.IsServer() then
            return Utils.TryExportOk(resource, { 'forceOpenInventory' }, source, invType, data)
        end

        return Utils.TryExportOk(resource, { 'openInventory' }, invType, data)
    end,

    close = function(resource, source)
        if TSS.IsServer() then
            TriggerClientEvent('ox_inventory:closeInventory', source)
            return true
        end

        return Utils.TryExportOk(resource, { 'closeInventory' })
    end,
}, 10)
