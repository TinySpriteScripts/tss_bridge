-- Chezza Inventory v4 adapter. This resource is intentionally named `inventory`.
local Utils = TSS.Inventory.Utils
local server = TSS.IsServer()

local function player(source)
    return TSS.Framework and TSS.Framework.Player and TSS.Framework.Player(source)
end

TSS.Inventory.RegisterAdapter('chezza', TSS.Resources.ChezzaInventory, {
    registerUsable = server and function(_, item, callback)
        return Utils.RegisterFrameworkUsable(item, callback, { esx = true })
    end or nil,
    add = server and function(resource, source, item, amount, metadata, slot)
        if metadata ~= nil or slot ~= nil then return false, 'metadata_and_slot_unsupported' end
        return Utils.TryExports(resource, { 'AddItemToPlayer' }, source, item, amount) == true
    end or nil,
    remove = server and function(resource, source, item, amount, metadata, slot)
        if metadata ~= nil or slot ~= nil then return false, 'metadata_and_slot_unsupported' end
        return Utils.TryExports(resource, { 'RemoveItemFromPlayer' }, source, item, amount) == true
    end or nil,
    count = server and function(resource, source, item, metadata)
        local xPlayer = player(source)
        if not xPlayer then return 0 end
        local inventory = Utils.TryExports(resource, { 'getInventory' }, xPlayer)
        return Utils.CountItems(Utils.UnwrapInventory(inventory), item, metadata)
    end or function()
        return 0
    end,
    canCarry = server and function(resource, source, item, amount)
        local xPlayer = player(source)
        if not xPlayer then return false end
        return Utils.TryExports(resource, { 'CanPlayerCarry' }, xPlayer, {
            type = 'item_standard', name = item,
        }, amount) == true
    end or nil,
    inventory = server and function(resource, source)
        local xPlayer = player(source)
        if not xPlayer then return {} end
        return Utils.UnwrapInventory(Utils.TryExports(resource, { 'getInventory' }, xPlayer))
    end or nil,
    weight = server and function(resource, source)
        local xPlayer = player(source)
        if not xPlayer then return nil end
        return Utils.TryExports(resource, { 'getPlayerWeight' }, xPlayer)
    end or nil,
    openInventory = function(_, source, invType, data)
        local secondary
        if invType and invType ~= 'player' then
            secondary = {
                type = invType,
                id = type(data) == 'table' and (data.id or data.name or data.stash) or data,
                title = type(data) == 'table' and data.label or nil,
                weight = type(data) == 'table' and (data.weight or data.maxweight) or nil,
                slots = type(data) == 'table' and data.slots or nil,
                save = true,
            }
        end
        if server then
            TriggerClientEvent('inventory:openInventory', source, secondary)
        else
            TriggerEvent('inventory:openInventory', secondary)
        end
        return true
    end,
    close = not server and function(resource)
        return Utils.TryExportOk(resource, { 'CloseInventory' })
    end or nil,
}, 120)
