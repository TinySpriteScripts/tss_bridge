-- origen_inventory adapter using canonical exports from the current vendor API.
local Utils = TSS.Inventory.Utils
local server = TSS.IsServer()

TSS.Inventory.RegisterAdapter('origen', TSS.Resources.OrigenInventory, {
    add = server and function(resource, source, item, amount, metadata, slot)
        return Utils.TryExports(resource, { 'addItem' }, source, item, amount, slot, metadata) == true
    end or nil,
    remove = server and function(resource, source, item, amount, _, slot)
        return Utils.TryExports(resource, { 'removeItem' }, source, item, amount, slot) == true
    end or nil,
    count = function(resource, source, item, metadata)
        if metadata == nil then
            if server then return Utils.TryExports(resource, { 'getItemCount' }, source, item) or 0 end
            return Utils.CountItems(Utils.TryExports(resource, { 'getPlayerItems' }), item)
        end
        local items = server and Utils.TryExports(resource, { 'GetPlayerInventory' }, source)
            or Utils.TryExports(resource, { 'getPlayerItems' })
        return Utils.CountItems(Utils.UnwrapInventory(items), item, metadata)
    end,
    canCarry = server and function(resource, source, item, amount)
        return Utils.TryExports(resource, { 'canCarryItem' }, source, item, amount) == true
    end or nil,
    inventory = function(resource, source)
        local inventory = server and Utils.TryExports(resource, { 'GetPlayerInventory' }, source)
            or Utils.TryExports(resource, { 'getPlayerItems' })
        return Utils.UnwrapInventory(inventory)
    end,
    weight = function(resource, source)
        if server then return Utils.TryExports(resource, { 'GetTotalWeight' }, source) end
        local inventory = Utils.TryExports(resource, { 'getInventory' })
        local weight = Utils.InventoryWeights(inventory)
        return weight or Utils.CalculateUnitWeight(Utils.UnwrapInventory(inventory))
    end,
    stashItems = server and function(resource, id)
        return Utils.TryExports(resource, { 'getItems' }, id)
    end or nil,
    registerStash = server and function(resource, data)
        data = Utils.NormaliseStash(data)
        return Utils.TryExportOk(resource, { 'registerStash' }, data.id, {
            label = data.label, slots = data.slots, maxweight = data.weight, owner = data.owner,
        })
    end or nil,
    setMetadata = server and function(resource, source, slot, metadata)
        return Utils.TryExports(resource, { 'setMetadata' }, source, slot, metadata) == true
    end or nil,
    registerShop = server and function(resource, data)
        if type(data) ~= 'table' or type(data.id) ~= 'string' or type(data.items) ~= 'table' then
            return false, 'invalid_shop'
        end
        return Utils.TryExportOk(resource, { 'createShop' }, data.id, {
            label = data.label or data.id,
            slots = data.slots or #data.items,
            items = data.items,
            locations = data.locations or (data.coords and { data.coords } or nil),
        })
    end or nil,
    openInventory = function(resource, source, invType, data)
        local id = type(data) == 'table' and (data.id or data.name or data.stash) or data
        if server then return Utils.TryExportOk(resource, { 'OpenInventory' }, source, id or invType, data) end
        return Utils.TryExportOk(resource, { 'openInventory' }, id or invType, data)
    end,
}, 80)
