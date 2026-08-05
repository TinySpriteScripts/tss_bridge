TSS = TSS or {}
TSS.Inventory = TSS.Inventory or {}

local adapters = {}
local inventoryOrder = {}
local aliases = {}

TSS.Inventory.Utils = TSS.Inventory.Utils or {}

function TSS.Inventory.Utils.CallExport(resource, exportName, ...)
    local export = exports[resource] and exports[resource][exportName]

    if type(export) ~= 'function' then
        return false, ('missing export %s:%s'):format(resource, exportName)
    end

    local ok, result, extra = pcall(export, ...)
    if ok then return true, result, extra end

    ok, result, extra = pcall(export, exports[resource], ...)
    if ok then return true, result, extra end

    return false, result
end

function TSS.Inventory.Utils.TryExports(resource, exportsToTry, ...)
    for i = 1, #exportsToTry do
        local ok, result, extra = TSS.Inventory.Utils.CallExport(resource, exportsToTry[i], ...)
        if ok then return result, extra, exportsToTry[i] end
    end
end

function TSS.Inventory.Utils.TryExportOk(resource, exportsToTry, ...)
    for i = 1, #exportsToTry do
        local ok = TSS.Inventory.Utils.CallExport(resource, exportsToTry[i], ...)
        if ok then return true, exportsToTry[i] end
    end

    return false
end

function TSS.Inventory.Utils.CountFromItem(item)
    if type(item) ~= 'table' then return tonumber(item) or 0 end
    return item.count or item.amount or item.quantity or 0
end

function TSS.Inventory.Utils.NormaliseStash(data)
    data = data or {}

    return {
        id = data.id or data.name,
        label = data.label or data.name or data.id,
        slots = data.slots or 50,
        weight = data.weight or data.maxWeight or data.maxweight or 100000,
        owner = data.owner,
        groups = data.groups,
        coords = data.coords,
    }
end

local function normaliseItemArgs(source, item, amount, metadata)
    if TSS.IsClient() and (type(source) == 'string' or type(source) == 'table') then
        return nil, source, item, amount
    end

    return source, item, amount, metadata
end

function TSS.Inventory.RegisterAdapter(key, resource, adapter, priority)
    if not key or not resource or not adapter then
        TSS.Warn('Inventory adapter registration is missing key, resource, or adapter')
        return
    end

    adapters[key] = adapter
    aliases[resource] = key
    inventoryOrder[#inventoryOrder + 1] = {
        key = key,
        resource = resource,
        priority = priority or 100,
    }

    table.sort(inventoryOrder, function(a, b)
        return a.priority < b.priority
    end)
end

local function detectInventory()
    local configured = TSS.Config.Inventory

    if configured ~= 'auto' then
        return aliases[configured] or configured
    end

    for i = 1, #inventoryOrder do
        if TSS.IsStarted(inventoryOrder[i].resource) then
            return inventoryOrder[i].key
        end
    end
end

local function getResource(system)
    for i = 1, #inventoryOrder do
        if inventoryOrder[i].key == system then
            return inventoryOrder[i].resource
        end
    end
end

local function getAdapter()
    local system = detectInventory()
    local resource = getResource(system)

    if not system or not resource then
        TSS.Warn('No supported inventory system found')
        return nil, nil, nil
    end

    if not TSS.IsStarted(resource) then
        TSS.Warn(('Configured inventory is not started: %s'):format(resource))
        return nil, nil, nil
    end

    return system, resource, adapters[system]
end

function TSS.Inventory.System()
    local system, resource = getAdapter()
    return system, resource
end

function TSS.Inventory.Supports(feature)
    local _, _, adapter = getAdapter()
    feature = tostring(feature or ''):lower()
    if TSS.IsClient() and (feature == 'add' or feature == 'remove' or feature == 'carry' or feature == 'stash') then
        return false
    end
    local methods = {
        add = 'add', remove = 'remove', count = 'count', has = 'count', carry = 'canCarry',
        player = 'inventory', items = 'items', stash = 'registerStash', open = 'openInventory', close = 'close',
    }
    local method = methods[feature]
    return adapter ~= nil and method ~= nil and type(adapter[method]) == 'function'
end

function TSS.Inventory.Add(source, item, amount, metadata, slot, reason)
    local _, resource, adapter = getAdapter()
    if not adapter then return false end
    return adapter.add(resource, source, item, amount, metadata, slot, reason) == true
end

function TSS.Inventory.Remove(source, item, amount, metadata, slot, reason)
    local _, resource, adapter = getAdapter()
    if not adapter then return false end
    return adapter.remove(resource, source, item, amount, metadata, slot, reason) == true
end

function TSS.Inventory.Count(source, item, metadata)
    source, item, metadata = normaliseItemArgs(source, item, metadata)

    local _, resource, adapter = getAdapter()
    if not adapter then return 0 end
    return tonumber(adapter.count(resource, source, item, metadata)) or 0
end

function TSS.Inventory.Has(source, item, amount, metadata)
    source, item, amount, metadata = normaliseItemArgs(source, item, amount, metadata)
    return TSS.Inventory.Count(source, item, metadata) >= (amount or 1)
end

function TSS.Inventory.CanCarry(source, item, amount, metadata)
    source, item, amount, metadata = normaliseItemArgs(source, item, amount, metadata)

    local _, resource, adapter = getAdapter()
    if not adapter then return false end
    return adapter.canCarry(resource, source, item, amount, metadata) == true
end

function TSS.Inventory.Player(source)
    local _, resource, adapter = getAdapter()
    if not adapter then return {} end

    if not adapter.inventory then
        local inventory = TSS.Inventory.Utils.TryExports(resource, {
            'GetPlayerInventory',
            'GetInventory',
            'GetInventoryItems',
            'GetPlayerItems',
            'getPlayerInventory',
            'getInventory',
            'getInventoryItems',
            'getPlayerItems',
        }, source)

        if inventory and inventory.items then return inventory.items end
        return inventory or {}
    end

    return adapter.inventory(resource, source) or {}
end

function TSS.Inventory.Items()
    local _, resource, adapter = getAdapter()
    if not adapter then return {} end
    return adapter.items(resource) or {}
end

function TSS.Inventory.RegisterStash(data)
    local _, resource, adapter = getAdapter()
    if not adapter then return false end
    data.weight = data.weight or data.maxWeight or data.maxweight
    return adapter.registerStash(resource, data) == true
end

function TSS.Inventory.Open(source, invType, data)
    local _, resource, adapter = getAdapter()
    if not adapter then return false end
    return adapter.openInventory(resource, source, invType, data) == true
end

function TSS.Inventory.OpenStash(source, id, data)
    if type(source) == 'table' then
        data = source
        id = data.id or data.name or data.stash
        source = nil
    end

    data = data or {}
    data.id = data.id or id
    data.name = data.name or id
    data.stash = data.stash or id
    return TSS.Inventory.Open(source, 'stash', data)
end

function TSS.Inventory.Close(source)
    local _, resource, adapter = getAdapter()
    if not adapter then return false end
    return adapter.close(resource, source) == true
end

function addItem(source, item, amount, metadata, slot, reason)
    return TSS.Inventory.Add(source, item, amount, metadata, slot, reason)
end

function removeItem(source, item, amount, metadata, slot, reason)
    return TSS.Inventory.Remove(source, item, amount, metadata, slot, reason)
end

function getItemCount(source, item, metadata)
    return TSS.Inventory.Count(source, item, metadata)
end

function hasItem(source, item, amount, metadata)
    return TSS.Inventory.Has(source, item, amount, metadata)
end

function canCarryItem(source, item, amount, metadata)
    return TSS.Inventory.CanCarry(source, item, amount, metadata)
end

function getPlayerInventory(source)
    return TSS.Inventory.Player(source)
end

TSS.GetPlayerInventory = TSS.Inventory.Player

function getItems()
    return TSS.Inventory.Items()
end

function createStash(data)
    return TSS.Inventory.RegisterStash(data)
end

function openInventory(source, invType, data)
    return TSS.Inventory.Open(source, invType, data)
end

function openStash(source, id, data)
    return TSS.Inventory.OpenStash(source, id, data)
end

function closeInventory(source)
    return TSS.Inventory.Close(source)
end
