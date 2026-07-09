local Utils = TSS.Inventory.Utils

TSS.Inventory.RegisterAdapter('qs', TSS.Resources.QsInventory, {
    add = function(resource, source, item, amount, metadata, slot, reason)
        return Utils.TryExports(resource, { 'AddItem', 'addItem', 'AddInventoryItem', 'addInventoryItem' }, source, item, amount or 1, slot, metadata, reason)
    end,

    remove = function(resource, source, item, amount, metadata, slot, reason)
        return Utils.TryExports(resource, { 'RemoveItem', 'removeItem', 'RemoveInventoryItem', 'removeInventoryItem' }, source, item, amount or 1, slot, metadata, reason)
    end,

    count = function(resource, source, item, metadata)
        local count = Utils.TryExports(resource, { 'GetItemCount', 'getItemCount', 'GetItemTotalAmount', 'GetItemAmount' }, source, item, metadata)
        if count ~= nil then return count end

        return Utils.CountFromItem(Utils.TryExports(resource, { 'GetItemByName', 'GetItem', 'getItem' }, source, item))
    end,

    canCarry = function(resource, source, item, amount, metadata)
        return Utils.TryExports(resource, { 'CanCarryItem', 'CanAddItem', 'canCarryItem', 'canAddItem' }, source, item, amount or 1, metadata) == true
    end,

    items = function(resource)
        return Utils.TryExports(resource, { 'Items', 'GetItemList', 'GetItems', 'getItems' })
    end,

    registerStash = function(resource, data)
        data = Utils.NormaliseStash(data)
        return Utils.TryExportOk(resource, { 'RegisterStash', 'CreateStash', 'registerStash', 'createStash' }, data.id, data.label, data.slots, data.weight, data.owner, data.groups, data.coords)
    end,

    openInventory = function(resource, source, invType, data)
        return Utils.TryExportOk(resource, { 'OpenInventory', 'openInventory', 'OpenStash', 'openStash' }, source, invType, data)
    end,

    close = function(resource, source)
        return Utils.TryExportOk(resource, { 'CloseInventory', 'closeInventory' }, source)
    end,
}, 50)
