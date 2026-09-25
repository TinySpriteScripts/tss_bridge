-- ps-inventory v1.1 adapter owned by the Inventory module.
local Utils = TSS.Inventory.Utils
local server = TSS.IsServer()

TSS.Inventory.RegisterAdapter('ps', TSS.Resources.PsInventory, {
    registerUsable = server and function(resource, item, callback)
        return Utils.RegisterUsableExport(resource, 'CreateUsableItem', item, callback)
    end or nil,
    add = server and function(resource, source, item, amount, metadata, slot, reason)
        return Utils.TryExports(resource, { 'AddItem' }, source, item, amount, slot or false, metadata or false,
            reason or 'tss_inventory') == true
    end or nil,
    remove = server and function(resource, source, item, amount, _, slot)
        return Utils.TryExports(resource, { 'RemoveItem' }, source, item, amount, slot or false) == true
    end or nil,
    count = server and function(resource, source, item, metadata)
        return Utils.CountItems(Utils.TryExports(resource, { 'GetItemsByName' }, source, item), item, metadata)
    end or function(_, _, item, metadata)
        return Utils.CountItems(Utils.QBPlayerItems(), item, metadata)
    end,
    items = function() return Utils.QBItems() end,
    inventory = function(_, source) return Utils.QBPlayerItems(source) end,
    getSlot = server and function(resource, source, slot)
        return Utils.TryExports(resource, { 'GetItemBySlot' }, source, slot)
    end or nil,
    find = server and function(resource, source, item, metadata)
        return Utils.FindItems(Utils.TryExports(resource, { 'GetItemsByName' }, source, item), item, metadata)
    end or function(_, _, item, metadata)
        return Utils.FindItems(Utils.QBPlayerItems(), item, metadata)
    end,
    weight = function(resource, source)
        local items = Utils.QBPlayerItems(source)
        if server then return Utils.TryExports(resource, { 'GetTotalWeight' }, items) end
        return Utils.CalculateUnitWeight(items)
    end,
    registerShop = server and function(resource, data)
        if type(data) ~= 'table' or type(data.id) ~= 'string' or type(data.items) ~= 'table' then
            return false, 'invalid_shop'
        end
        return Utils.TryExportOk(resource, { 'CreateShop' }, {
            name = data.id, label = data.label or data.id, coords = data.coords, items = data.items,
        })
    end or nil,
    openShop = server and function(resource, source, id)
        return Utils.TryExportOk(resource, { 'OpenShop' }, source, id)
    end or nil,
    setMetadata = server and function(resource, source, slot, metadata)
        local target = Utils.TryExports(resource, { 'GetItemBySlot' }, source, slot)
        if type(target) ~= 'table' then return false, 'slot_not_found' end
        local first = Utils.TryExports(resource, { 'GetItemByName' }, source, target.name)
        if type(first) ~= 'table' or tonumber(first.slot) ~= tonumber(slot) then
            return false, 'provider_cannot_update_nonfirst_stack'
        end
        return Utils.TryExports(resource, { 'SetItemData' }, source, target.name, 'info', metadata) == true
    end or nil,
    openInventory = server and function(resource, source, invType, data)
        if invType == 'player' then
            return Utils.TryExportOk(resource, { 'OpenInventoryById' }, source, data)
        end
        local id = type(data) == 'table' and (data.id or data.name or data.stash) or data
        return Utils.TryExportOk(resource, { 'OpenInventory' }, invType, id, data, source)
    end or nil,
}, 30)
