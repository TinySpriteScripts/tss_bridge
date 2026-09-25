-- ox_inventory adapter owned by the Inventory module.
local Utils = TSS.Inventory.Utils

local function normaliseShopItems(resource, items)
    if type(items) ~= 'table' or #items == 0 then return nil, 'invalid_shop_items' end

    local result = {}
    for i = 1, #items do
        local source = items[i]
        if type(source) ~= 'table' or type(source.name) ~= 'string' or source.name == '' then
            return nil, ('invalid_shop_item:%s'):format(i)
        end
        if type(source.price) ~= 'number' then
            return nil, ('invalid_shop_price:%s'):format(source.name)
        end

        local exists, definition = Utils.CallExport(resource, 'Items', source.name)
        if not exists or type(definition) ~= 'table' then
            return nil, ('item_not_defined:%s'):format(source.name)
        end

        local item = {}
        for key, value in pairs(source) do item[key] = value end
        -- Bridge consumers commonly share QB-style shop definitions. OX calls
        -- these fields count and metadata; preserve native OX fields when given.
        if item.count == nil then item.count = item.amount end
        if item.metadata == nil then item.metadata = item.info end
        result[i] = item
    end

    return result
end

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
        if type(data) ~= 'table' or type(data.id) ~= 'string' or data.id == '' then
            return false, 'invalid_shop_id'
        end

        local items, err = normaliseShopItems(resource, data.items)
        if not items then return false, err end

        local locations
        if data.coords then
            if type(data.coords.x) ~= 'number' or type(data.coords.y) ~= 'number' or type(data.coords.z) ~= 'number' then
                return false, 'invalid_shop_coords'
            end
            locations = { vector3(data.coords.x, data.coords.y, data.coords.z) }
        end

        local ok, result = Utils.CallExport(resource, 'RegisterShop', data.id, {
            name = data.label or data.id, inventory = items, groups = data.groups,
            locations = locations,
        })
        if not ok or result == false then return false, tostring(result) end
        return true
    end,
    openShop = function(resource, source, id)
        TriggerClientEvent('tss_bridge:client:openRegisteredShop', source, id)
        return true
    end,
    setMetadata = function(resource, source, slot, metadata)
        local found, slotData = Utils.CallExport(resource, 'GetSlot', source, slot)
        if not found or type(slotData) ~= 'table' then return false, 'slot_not_found' end
        local ok = Utils.CallExport(resource, 'SetMetadata', source, slot, metadata)
        return ok == true
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
        if type(filename) == 'string' and (filename:match('^https?://') or filename:match('^nui://')) then
            return filename
        end

        local imagePath = GetConvar('inventory:imagepath', ('nui://%s/web/images'):format(resource))
        imagePath = tostring(imagePath):gsub('/+$', '')
        local nuiResource, nuiPath = imagePath:match('^nui://([^/]+)/?(.*)$')
        if nuiResource then
            imagePath = ('https://cfx-nui-%s%s'):format(nuiResource, nuiPath ~= '' and ('/' .. nuiPath) or '')
        end

        return ('%s/%s'):format(imagePath, tostring(filename):gsub('^/+', ''))
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

    getSlot = function(resource, source, slot)
        if TSS.IsClient() then return Utils.GetSlot(Utils.TryExports(resource, { 'GetPlayerItems' }), slot) end
        return Utils.TryExports(resource, { 'GetSlot' }, source, slot)
    end,

    find = function(resource, source, item, metadata)
        if TSS.IsClient() then return Utils.TryExports(resource, { 'Search' }, 'slots', item, metadata) or {} end
        return Utils.TryExports(resource, { 'GetSlotsWithItem' }, source, item, metadata, false) or {}
    end,

    weight = function(resource, source)
        if TSS.IsClient() then return Utils.TryExports(resource, { 'GetPlayerWeight' }) end
        local inventory = Utils.TryExports(resource, { 'GetInventory' }, source)
        return inventory and inventory.weight
    end,

    maxWeight = function(resource, source)
        if TSS.IsClient() then return Utils.TryExports(resource, { 'GetPlayerMaxWeight' }) end
        local inventory = Utils.TryExports(resource, { 'GetInventory' }, source)
        return inventory and inventory.maxWeight
    end,

    registerStash = function(resource, data)
        data = Utils.NormaliseStash(data)
        return Utils.TryExportOk(resource, { 'RegisterStash' }, data.id, data.label, data.slots, data.weight, data.owner, data.groups, data.coords, data.instance)
    end,

    openInventory = function(resource, source, invType, data)
        if TSS.IsServer() then
            -- forceOpenInventory does not support every client inventory type.
            -- Route those through the normal client export so OX keeps its
            -- standard access and proximity validation.
            if invType == 'shop' or invType == 'crafting' or invType == 'policeevidence' then
                TriggerClientEvent('tss_bridge:client:openInventory', source, invType, data)
                return true
            end

            local ok, result = Utils.CallExport(resource, 'forceOpenInventory', source, invType, data)
            return ok == true and result ~= nil and result ~= false
        end

        local ok, result = Utils.CallExport(resource, 'openInventory', invType, data)
        return ok == true and result == true
    end,

    close = function(resource, source)
        if TSS.IsServer() then
            TriggerClientEvent('ox_inventory:closeInventory', source)
            return true
        end

        return Utils.TryExportOk(resource, { 'closeInventory' })
    end,
}, 10)
