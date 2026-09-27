-- qb-inventory adapter owned by the Inventory module.
local Utils = TSS.Inventory.Utils
local server = TSS.IsServer()

-- QB only saves non-player inventories when its UI closes. Server-side stash
-- transactions must also persist the live inventory so a restart cannot resell it.
local function saveStash(resource, id)
    local inventory = Utils.TryExports(resource, { 'GetInventory' }, id)
    if not inventory then return end
    local items = json.encode(inventory.items or {})
    local ok, result = Utils.CallExport('oxmysql', 'update_async',
        'INSERT INTO inventories (identifier, items) VALUES (?, ?) ON DUPLICATE KEY UPDATE items = ?',
        { id, items, items })
    if not ok or result == nil or result == false then
        TSS.Warn('Failed to persist QB stash transaction: ' .. id)
    end
end

TSS.Inventory.RegisterAdapter('qb', TSS.Resources.QbInventory, {
    stashItems = function(resource, id)
        local inventory = Utils.TryExports(resource, { 'GetInventory' }, id)
        return inventory and inventory.items
    end,
    stashAdd = function(resource, id, item, amount, metadata, slot, reason)
        local success = Utils.TryExports(resource, { 'AddItem' }, id, item, amount, slot or false, metadata or false, reason) == true
        if success then saveStash(resource, id) end
        return success
    end,
    stashRemove = function(resource, id, item, amount, metadata, slot, reason)
        local success = Utils.TryExports(resource, { 'RemoveItem' }, id, item, amount, slot or false, reason) == true
        if success then saveStash(resource, id) end
        return success
    end,

    registerShop = function(resource, data)
        return Utils.TryExportOk(resource, { 'CreateShop' }, {
            name = data.id, label = data.label, slots = #data.items, items = data.items, coords = data.coords,
        })
    end,
    openShop = function(resource, source, id)
        return Utils.TryExportOk(resource, { 'OpenShop' }, source, id)
    end,
    setMetadata = function(resource, source, slot, metadata)
        local item = Utils.TryExports(resource, { 'GetItemBySlot' }, source, slot)
        if not item then return false end
        return Utils.TryExports(resource, { 'SetItemData' }, source, item.name, 'info', metadata, slot) == true
    end,

    add = function(resource, source, item, amount, metadata, slot, reason)
        return Utils.TryExports(resource, { 'AddItem' }, source, item, amount or 1, slot or false, metadata or false, reason or 'tss_inventory')
    end,

    remove = function(resource, source, item, amount, metadata, slot, reason)
        return Utils.TryExports(resource, { 'RemoveItem' }, source, item, amount or 1, slot or false, reason or 'tss_inventory')
    end,

    count = function(resource, source, item, metadata)
        if TSS.IsClient() then
            return Utils.CountItems(Utils.QBPlayerItems(), item, metadata)
        end

        if metadata == nil then
            local count = Utils.TryExports(resource, { 'GetItemCount' }, source, item)
            if count ~= nil then return count end
        end

        return Utils.CountItems(Utils.UnwrapInventory(Utils.TryExports(resource, { 'GetInventory' }, source)), item, metadata)
    end,

    canCarry = function(resource, source, item, amount)
        return Utils.TryExports(resource, { 'CanAddItem' }, source, item, amount or 1) == true
    end,

    image = function(resource, item, definition)
        local filename = definition.image or (item .. '.png')
        return ('https://cfx-nui-%s/html/images/%s'):format(resource, filename)
    end,

    items = function() return Utils.QBItems() end,

    inventory = function(resource, source)
        if TSS.IsClient() then
            return Utils.QBPlayerItems()
        end

        local inventory = Utils.TryExports(resource, { 'GetInventory' }, source)
        if inventory and inventory.items then return inventory.items end
        if inventory then return inventory end

        return Utils.QBPlayerItems(source)
    end,

    getSlot = server and function(resource, source, slot)
        return Utils.TryExports(resource, { 'GetItemBySlot' }, source, slot)
    end or nil,

    find = function(resource, source, item, metadata)
        if TSS.IsClient() then return Utils.FindItems(Utils.QBPlayerItems(), item, metadata) end
        return Utils.FindItems(Utils.UnwrapInventory(Utils.TryExports(resource, { 'GetInventory' }, source)), item, metadata)
    end,

    weight = function(resource, source)
        local items = TSS.IsClient() and Utils.QBPlayerItems()
            or Utils.UnwrapInventory(Utils.TryExports(resource, { 'GetInventory' }, source))
        if TSS.IsClient() then return Utils.CalculateUnitWeight(items) end
        return Utils.TryExports(resource, { 'GetTotalWeight' }, items)
    end,

    maxWeight = server and function(resource, source)
        local inventory = Utils.TryExports(resource, { 'GetInventory' }, source)
        local _, maximum = Utils.InventoryWeights(inventory)
        return maximum
    end or nil,

    registerStash = function(resource, data)
        data = Utils.NormaliseStash(data)
        return Utils.TryExportOk(resource, { 'CreateInventory' }, data.id, {
            label = data.label,
            maxweight = data.weight,
            slots = data.slots,
        })
    end,

    openInventory = server and function(resource, source, invType, data)
        if invType == 'player' then
            return Utils.TryExportOk(resource, { 'OpenInventoryById' }, source, data)
        end

        return Utils.TryExportOk(resource, { 'OpenInventory' }, source, data and (data.id or data.name) or invType, data)
    end or nil,

    close = server and function(resource, source)
        return Utils.TryExportOk(resource, { 'CloseInventory' }, source)
    end or nil,
}, 20)
