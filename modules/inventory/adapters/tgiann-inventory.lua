-- tgiann-inventory adapter. Export names intentionally follow the vendor API,
-- without aliases guessed from other inventory resources.
local Utils = TSS.Inventory.Utils
local server = TSS.IsServer()

TSS.Inventory.RegisterAdapter('tgiann', TSS.Resources.TgiannInventory, {
    add = server and function(resource, source, item, amount, metadata, slot)
        return Utils.TryExports(resource, { 'AddItem' }, source, item, amount, slot, metadata) == true
    end or nil,
    remove = server and function(resource, source, item, amount, _, slot)
        return Utils.TryExports(resource, { 'RemoveItem' }, source, item, amount, slot) == true
    end or nil,
    count = function(resource, source, item, metadata)
        if server then
            return Utils.CountItems(Utils.TryExports(resource, { 'GetPlayerItems' }, source), item, metadata)
        end
        return Utils.TryExports(resource, { 'GetItemCount' }, item, metadata, true) or 0
    end,
    canCarry = server and function(resource, source, item, amount)
        return Utils.TryExports(resource, { 'CanCarryItem' }, source, item, amount) == true
    end or nil,
    items = function(resource)
        return Utils.TryExports(resource, { 'GetItemList' }) or {}
    end,
    inventory = function(resource, source)
        if server then return Utils.UnwrapInventory(Utils.TryExports(resource, { 'GetPlayerItems' }, source)) end
        return Utils.UnwrapInventory(Utils.TryExports(resource, { 'GetPlayerItems' }))
    end,
    weight = function(resource, source)
        if not server then return Utils.TryExports(resource, { 'GetPlayerWeight' }) end
        return Utils.CalculateUnitWeight(Utils.TryExports(resource, { 'GetPlayerItems' }, source))
    end,
    maxWeight = not server and function(resource)
        return Utils.TryExports(resource, { 'GetPlayerMaxWeight' })
    end or nil,
    setMetadata = server and function(resource, source, slot, metadata)
        local item = Utils.TryExports(resource, { 'GetItemBySlot' }, source, slot)
        if type(item) ~= 'table' then return false, 'slot_not_found' end
        local ok, result = Utils.CallExport(resource, 'UpdateItemMetadata', source, item.name, slot, metadata)
        return ok and result ~= false
    end or nil,
    openInventory = function(resource, source, invType, data)
        local id = type(data) == 'table' and (data.id or data.name or data.stash) or data
        if server then
            if invType == 'player' then
                return Utils.TryExportOk(resource, { 'OpenInventoryById' }, source, id)
            end
            return Utils.TryExportOk(resource, { 'ForceOpenInventory' }, source, invType, id, data)
        end
        return Utils.TryExportOk(resource, { 'OpenInventory' }, invType, id, data)
    end,
    close = not server and function(resource)
        return Utils.TryExportOk(resource, { 'CloseInventory' })
    end or nil,
}, 90)
