-- mf-inventory adapter owned by the Inventory module.
local Utils = TSS.Inventory.Utils

TSS.Inventory.RegisterAdapter('mf', TSS.Resources.MfInventory, {
    registerUsable = function(_, item, callback)
        -- MF changes ESX's callback to (source, removeCallback, item).
        return Utils.RegisterFrameworkUsable(item, function(source, removeCallback, itemData)
            return callback(source, itemData, removeCallback)
        end, { esx = true })
    end,

    add = function(resource, source, item, amount, metadata, slot)
        return Utils.TryExports(resource, { 'AddItem', 'addItem', 'AddInventoryItem' }, source, item, amount or 1, slot, metadata)
    end,

    remove = function(resource, source, item, amount, metadata, slot)
        return Utils.TryExports(resource, { 'RemoveItem', 'removeItem', 'RemoveInventoryItem' }, source, item, amount or 1, slot, metadata)
    end,

    count = function(resource, source, item, metadata)
        local count = Utils.TryExports(resource, { 'GetItemCount', 'getItemCount', 'GetItemAmount' }, source, item, metadata)
        if count ~= nil then return count end

        return Utils.CountFromItem(Utils.TryExports(resource, { 'GetItemByName', 'GetItem', 'getItem' }, source, item))
    end,

    canCarry = function(resource, source, item, amount, metadata)
        return Utils.TryExports(resource, { 'CanCarryItem', 'CanAddItem', 'canCarryItem' }, source, item, amount or 1, metadata) == true
    end,

    items = function(resource)
        return Utils.TryExports(resource, { 'GetItemList', 'GetItems', 'Items' })
    end,

    registerStash = function(resource, data)
        data = Utils.NormaliseStash(data)
        return Utils.TryExportOk(resource, { 'RegisterStash', 'CreateStash', 'registerStash' }, data.id, data.label, data.slots, data.weight, data.owner)
    end,

    openInventory = function(resource, source, invType, data)
        return Utils.TryExportOk(resource, { 'OpenInventory', 'openInventory', 'OpenStash' }, source, invType, data)
    end,

    close = function(resource, source)
        return Utils.TryExportOk(resource, { 'CloseInventory', 'closeInventory' }, source)
    end,
}, 110)
