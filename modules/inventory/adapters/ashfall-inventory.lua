-- ashfall-inventory adapter owned by the Inventory module.
local Utils = TSS.Inventory.Utils

TSS.Inventory.RegisterAdapter('ashfall', TSS.Resources.AshfallInventory, {
    add = function(resource, source, item, amount, metadata, slot, reason)
        return Utils.TryExports(resource, { 'AddItem', 'addItem' }, source, item, amount or 1, metadata, slot, reason)
    end,

    remove = function(resource, source, item, amount, metadata, slot, reason)
        return Utils.TryExports(resource, { 'RemoveItem', 'removeItem' }, source, item, amount or 1, metadata, slot, reason)
    end,

    count = function(resource, source, item, metadata)
        local count = Utils.TryExports(resource, { 'GetItemCount', 'getItemCount' }, source, item, metadata)
        if count ~= nil then return count end

        return Utils.CountFromItem(Utils.TryExports(resource, { 'GetItem', 'getItem', 'GetItemByName' }, source, item))
    end,

    canCarry = function(resource, source, item, amount, metadata)
        return Utils.TryExports(resource, { 'CanCarryItem', 'canCarryItem', 'CanAddItem' }, source, item, amount or 1, metadata) == true
    end,

    items = function(resource)
        return Utils.TryExports(resource, { 'Items', 'GetItems', 'getItems' })
    end,

    registerStash = function(resource, data)
        data = Utils.NormaliseStash(data)
        return Utils.TryExportOk(resource, { 'RegisterStash', 'registerStash', 'CreateStash' }, data.id, data.label, data.slots, data.weight, data.owner, data.groups, data.coords)
    end,

    openInventory = function(resource, source, invType, data)
        return Utils.TryExportOk(resource, { 'OpenInventory', 'openInventory' }, source, invType, data)
    end,

    close = function(resource, source)
        return Utils.TryExportOk(resource, { 'CloseInventory', 'closeInventory' }, source)
    end,
}, 115)
