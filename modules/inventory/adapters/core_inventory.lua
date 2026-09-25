-- core_inventory adapter using the vendor's documented canonical exports.
local Utils = TSS.Inventory.Utils
local server = TSS.IsServer()

TSS.Inventory.RegisterAdapter('core', TSS.Resources.CoreInventory, {
    registerUsable = server and function(_, item, callback)
        return Utils.RegisterFrameworkUsable(item, callback)
    end or nil,
    add = server and function(resource, source, item, amount, metadata)
        return Utils.TryExports(resource, { 'addItem' }, source, item, amount, metadata) == true
    end or nil,
    remove = server and function(resource, source, item, amount)
        return Utils.TryExports(resource, { 'removeItem' }, source, item, amount) == true
    end or nil,
    count = function(resource, source, item, metadata)
        if metadata == nil then
            if server then return Utils.TryExports(resource, { 'getItemCount' }, source, item) or 0 end
            return Utils.TryExports(resource, { 'getItemCount' }, item) or 0
        end
        local items = server and Utils.TryExports(resource, { 'getItems' }, source, item)
            or Utils.TryExports(resource, { 'getPlayerItems' })
        return Utils.CountItems(items, item, metadata)
    end,
    canCarry = server and function(resource, source, item, amount, metadata)
        return Utils.TryExports(resource, { 'canCarry' }, source, item, amount, metadata) == true
    end or nil,
    items = function(resource)
        return Utils.TryExports(resource, { 'getItemsList' }) or {}
    end,
    inventory = function(resource, source)
        local inventory = server and Utils.TryExports(resource, { 'getInventory' }, source)
            or Utils.TryExports(resource, { 'getPlayerItems' })
        return Utils.UnwrapInventory(inventory)
    end,
    openInventory = function(resource, source, invType, data)
        if server then
            local id = type(data) == 'table' and (data.id or data.name or data.stash) or data
            local label = type(data) == 'table' and data.label or nil
            local groups = type(data) == 'table' and data.groups or nil
            return Utils.TryExportOk(resource, { 'openInventory' }, source, id, invType, label, groups, true)
        end
        if invType and invType ~= 'player' then return false end
        return Utils.TryExportOk(resource, { 'openInventory' })
    end,
    close = not server and function(resource)
        return Utils.TryExportOk(resource, { 'closeInventory' })
    end or nil,
}, 60)
