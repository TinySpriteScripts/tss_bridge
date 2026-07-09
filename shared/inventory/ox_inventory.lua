local Utils = TSS.Inventory.Utils

TSS.Inventory.RegisterAdapter('ox', TSS.Resources.OxInventory, {
    add = function(resource, source, item, amount, metadata, slot)
        return Utils.TryExports(resource, { 'AddItem' }, source, item, amount or 1, metadata, slot)
    end,

    remove = function(resource, source, item, amount, metadata, slot)
        return Utils.TryExports(resource, { 'RemoveItem' }, source, item, amount or 1, metadata, slot)
    end,

    count = function(resource, source, item, metadata)
        if TSS.IsClient() then
            return Utils.TryExports(resource, { 'GetItemCount' }, item, metadata, true) or 0
        end

        return Utils.TryExports(resource, { 'GetItemCount' }, source, item, metadata, true) or 0
    end,

    canCarry = function(resource, source, item, amount, metadata)
        return Utils.TryExports(resource, { 'CanCarryItem' }, source, item, amount or 1, metadata) == true
    end,

    items = function(resource)
        return Utils.TryExports(resource, { 'Items' })
    end,

    inventory = function(resource, source)
        if TSS.IsClient() then
            return Utils.TryExports(resource, { 'GetPlayerItems' }) or {}
        end

        return Utils.TryExports(resource, { 'GetInventoryItems' }, source) or {}
    end,

    registerStash = function(resource, data)
        data = Utils.NormaliseStash(data)
        return Utils.TryExportOk(resource, { 'RegisterStash' }, data.id, data.label, data.slots, data.weight, data.owner, data.groups, data.coords)
    end,

    openInventory = function(resource, source, invType, data)
        if TSS.IsServer() then
            return Utils.TryExportOk(resource, { 'forceOpenInventory' }, source, invType, data)
        end

        return Utils.TryExportOk(resource, { 'openInventory' }, invType, data)
    end,

    close = function(resource, source)
        if TSS.IsServer() then
            TriggerClientEvent('ox_inventory:closeInventory', source)
            return true
        end

        return Utils.TryExportOk(resource, { 'closeInventory' })
    end,
}, 10)
