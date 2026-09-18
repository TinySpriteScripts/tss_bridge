-- lj-inventory adapter owned by the Inventory module.
local Utils = TSS.Inventory.Utils

TSS.Inventory.RegisterAdapter('lj', TSS.Resources.LjInventory, {
    registerUsable = function(resource, item, callback)
        return Utils.RegisterUsableExport(resource, 'CreateUsableItem', item, callback)
    end,

    add = function(resource, source, item, amount, metadata, slot, reason)
        return Utils.TryExports(resource, { 'AddItem' }, source, item, amount or 1, slot or false, metadata or false, reason or 'tss_inventory')
    end,

    remove = function(resource, source, item, amount, metadata, slot, reason)
        return Utils.TryExports(resource, { 'RemoveItem' }, source, item, amount or 1, slot or false, reason or 'tss_inventory')
    end,

    count = function(resource, source, item)
        local count = Utils.TryExports(resource, { 'GetItemCount' }, source, item)
        if count ~= nil then return count end

        return Utils.CountFromItem(Utils.TryExports(resource, { 'GetItemByName' }, source, item))
    end,

    canCarry = function(resource, source, item, amount)
        return Utils.TryExports(resource, { 'CanAddItem' }, source, item, amount or 1) == true
    end,

    items = function()
        if not TSS.IsStarted(TSS.Resources.QBCore) then return end

        local ok, core = pcall(function()
            return exports[TSS.Resources.QBCore]:GetCoreObject()
        end)

        if ok and core and core.Shared then
            return core.Shared.Items
        end
    end,

    registerStash = function(resource, data)
        data = Utils.NormaliseStash(data)
        return Utils.TryExportOk(resource, { 'CreateInventory' }, data.id, {
            label = data.label,
            maxweight = data.weight,
            slots = data.slots,
        })
    end,

    openInventory = function(resource, source, invType, data)
        if invType == 'player' then
            return Utils.TryExportOk(resource, { 'OpenInventoryById' }, source, data)
        end

        return Utils.TryExportOk(resource, { 'OpenInventory' }, source, data and (data.id or data.name) or invType, data)
    end,

    close = function(resource, source)
        return Utils.TryExportOk(resource, { 'CloseInventory' }, source)
    end,
}, 40)
