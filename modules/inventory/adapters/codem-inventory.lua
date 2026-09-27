-- CodeM mInventory adapter using the documented export surface.
local Utils = TSS.Inventory.Utils
local server = TSS.IsServer()

TSS.Inventory.RegisterAdapter('codem', TSS.Resources.CodemInventory, {
    add = server and function(resource, source, item, amount, metadata, slot)
        return Utils.TryExports(resource, { 'AddItem' }, source, item, amount, slot, metadata) == true
    end or nil,
    remove = server and function(resource, source, item, amount, _, slot)
        return Utils.TryExports(resource, { 'RemoveItem' }, source, item, amount, slot) == true
    end or nil,
    count = server and function(resource, source, item, metadata)
        if metadata == nil then
            return Utils.TryExports(resource, { 'GetItemsTotalAmount' }, source, item) or 0
        end
        return Utils.CountItems(Utils.TryExports(resource, { 'GetItemsByName' }, source, item), item, metadata)
    end or function(resource, _, item, metadata)
        return Utils.CountItems(Utils.TryExports(resource, { 'GetClientPlayerInventory' }), item, metadata)
    end,
    items = function(resource)
        return Utils.TryExports(resource, { 'GetItemList' }) or {}
    end,
    inventory = function(resource, source)
        if server then
            return Utils.UnwrapInventory(Utils.TryExports(resource, { 'GetInventory' }, nil, source))
        end
        return Utils.UnwrapInventory(Utils.TryExports(resource, { 'GetClientPlayerInventory' }))
    end,
    stashItems = server and function(resource, id)
        return Utils.TryExports(resource, { 'GetStashItems' }, id)
    end or nil,
    setMetadata = server and function(resource, source, slot, metadata)
        return Utils.TryExports(resource, { 'SetItemMetadata' }, source, slot, metadata) == true
    end or nil,
}, 70)
