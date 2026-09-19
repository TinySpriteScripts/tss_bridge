-- qb-inventory adapter owned by the Inventory module.
local Utils = TSS.Inventory.Utils

TSS.Inventory.RegisterAdapter('qb', TSS.Resources.QbInventory, {
    -- This inventory uses the selected framework's usable-item registry.
    registerUsable = function(_, item, callback)
        return Utils.RegisterFrameworkUsable(item, callback)
    end,

    registerShop = function(resource, data)
        return Utils.TryExportOk(resource, { 'CreateShop' }, {
            name = data.id, label = data.label, items = data.items, coords = data.coords,
        })
    end,
    openShop = function(resource, source, id)
        return Utils.TryExportOk(resource, { 'OpenShop' }, source, id)
    end,
    setMetadata = function(resource, source, slot, metadata)
        local item = Utils.TryExports(resource, { 'GetItemBySlot' }, source, slot)
        if not item then return false end
        return Utils.TryExports(resource, { 'SetItemData' }, source, item.name, 'info', metadata, slot) == true
    end,

    add = function(resource, source, item, amount, metadata, slot, reason)
        return Utils.TryExports(resource, { 'AddItem' }, source, item, amount or 1, slot or false, metadata or false, reason or 'tss_inventory')
    end,

    remove = function(resource, source, item, amount, metadata, slot, reason)
        return Utils.TryExports(resource, { 'RemoveItem' }, source, item, amount or 1, slot or false, reason or 'tss_inventory')
    end,

    count = function(resource, source, item)
        if TSS.IsClient() then
            local inventory = TSS.Inventory.Player()
            local total = 0

            for _, invItem in pairs(inventory) do
                if invItem and invItem.name == item then
                    total = total + (invItem.amount or invItem.count or 1)
                end
            end

            return total
        end

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

    inventory = function(resource, source)
        if TSS.IsClient() then
            if not TSS.IsStarted(TSS.Resources.QBCore) then return {} end

            local ok, core = pcall(function()
                return exports[TSS.Resources.QBCore]:GetCoreObject()
            end)

            if ok and core and core.Functions then
                local player = core.Functions.GetPlayerData()
                return player and player.items or {}
            end

            return {}
        end

        local inventory = Utils.TryExports(resource, { 'GetInventory', 'GetPlayerItems' }, source)
        if inventory and inventory.items then return inventory.items end
        if inventory then return inventory end

        if TSS.IsStarted(TSS.Resources.QBCore) then
            local ok, core = pcall(function()
                return exports[TSS.Resources.QBCore]:GetCoreObject()
            end)

            if ok and core and core.Functions then
                local player = core.Functions.GetPlayer(source)
                return player and player.PlayerData and player.PlayerData.items or {}
            end
        end

        return {}
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
        if TSS.IsClient() then
            local id = data and (data.id or data.name or data.stash) or invType
            TriggerServerEvent('inventory:server:OpenInventory', invType, id, data)
            if invType == 'stash' then
                TriggerEvent('inventory:client:SetCurrentStash', id)
            end
            return true
        end

        if invType == 'player' then
            return Utils.TryExportOk(resource, { 'OpenInventoryById' }, source, data)
        end

        return Utils.TryExportOk(resource, { 'OpenInventory' }, source, data and (data.id or data.name) or invType, data)
    end,

    close = function(resource, source)
        return Utils.TryExportOk(resource, { 'CloseInventory' }, source)
    end,
}, 20)
