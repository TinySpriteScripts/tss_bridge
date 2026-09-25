-- lj-inventory is tied to QB-Core player inventories. Use the framework's
-- supported player methods instead of inventing modern qb-inventory exports.
local Utils = TSS.Inventory.Utils
local server = TSS.IsServer()

local function player(source)
    return TSS.Framework and TSS.Framework.Player and TSS.Framework.Player(source)
end

TSS.Inventory.RegisterAdapter('lj', TSS.Resources.LjInventory, {
    registerUsable = server and function(_, item, callback)
        return Utils.RegisterFrameworkUsable(item, callback, { qb = true })
    end or nil,
    add = server and function(_, source, item, amount, metadata, slot, reason)
        local target = player(source)
        local add = target and target.Functions and target.Functions.AddItem
        return type(add) == 'function' and add(item, amount, slot or false, metadata or false,
            reason or 'tss_inventory') == true
    end or nil,
    remove = server and function(_, source, item, amount, _, slot, reason)
        local target = player(source)
        local remove = target and target.Functions and target.Functions.RemoveItem
        return type(remove) == 'function' and remove(item, amount, slot or false,
            reason or 'tss_inventory') == true
    end or nil,
    count = function(_, source, item, metadata)
        return Utils.CountItems(Utils.QBPlayerItems(source), item, metadata)
    end,
    items = function() return Utils.QBItems() end,
    inventory = function(_, source) return Utils.QBPlayerItems(source) end,
    weight = function(_, source)
        return Utils.CalculateUnitWeight(Utils.QBPlayerItems(source))
    end,
    close = not server and function()
        TriggerEvent('qb-inventory:client:closeinv')
        return true
    end or nil,
}, 40)
