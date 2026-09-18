-- core_inventory adapter owned by the Inventory module.
local Utils = TSS.Inventory.Utils

TSS.Inventory.RegisterAdapter('core', TSS.Resources.CoreInventory, {
    -- This inventory uses the selected framework's usable-item registry.
    registerUsable = function(_, item, callback)
        return Utils.RegisterFrameworkUsable(item, callback)
    end,

    add = function(resource, source, item, amount, metadata)
        return Utils.TryExports(resource, { 'addItem', 'AddItem', 'AddInventoryItem' }, source, item, amount or 1, metadata)
    end,

    remove = function(resource, source, item, amount, metadata)
        return Utils.TryExports(resource, { 'removeItem', 'RemoveItem', 'RemoveInventoryItem' }, source, item, amount or 1, metadata)
    end,

    count = function(resource, source, item, metadata)
        local count = Utils.TryExports(resource, { 'getItemCount', 'GetItemCount', 'GetItemAmount' }, source, item, metadata)
        if count ~= nil then return count end

        return Utils.CountFromItem(Utils.TryExports(resource, { 'getItem', 'GetItem', 'GetItemByName' }, source, item))
    end,

    canCarry = function(resource, source, item, amount, metadata)
        return Utils.TryExports(resource, { 'canCarryItem', 'CanCarryItem', 'CanAddItem' }, source, item, amount or 1, metadata) == true
    end,

    items = function(resource)
        return Utils.TryExports(resource, { 'getItems', 'GetItems', 'Items' })
    end,

    registerStash = function(resource, data)
        data = Utils.NormaliseStash(data)
        return Utils.TryExportOk(resource, { 'RegisterStash', 'CreateStash', 'registerStash', 'createStash' }, data.id, data.label, data.slots, data.weight, data.owner)
    end,

    openInventory = function(resource, source, invType, data)
        return Utils.TryExportOk(resource, { 'openInventory', 'OpenInventory', 'openStash', 'OpenStash' }, source, invType, data)
    end,

    close = function(resource, source)
        return Utils.TryExportOk(resource, { 'closeInventory', 'CloseInventory' }, source)
    end,
}, 60)
