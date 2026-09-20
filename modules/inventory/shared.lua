-- Lazy realm-aware implementation owned by the Inventory module.
TSS = TSS or {}
TSS.Inventory = TSS.Inventory or {}

local registry = TSS.Adapters.Create('Inventory', { config = 'Inventory' })

TSS.Inventory.Utils = TSS.Inventory.Utils or {}

function TSS.Inventory.Utils.CallExport(resource, exportName, ...)
    return TSS.CallExport(resource, exportName, ...)
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
    return registry:Register(key, resource, adapter, priority)
end

local function getAdapter()
    local system, resource, adapter = registry:Resolve()
    if not system or not resource or not adapter then
        TSS.Warn('No supported inventory system found')
        return nil, nil, nil
    end
    return system, resource, adapter
end

TSS.Inventory._GetAdapter = getAdapter

--- Detects the active inventory adapter.
---@return string? system Normalized adapter name.
---@return string? resource Started inventory resource.
function TSS.Inventory.System()
    local system, resource = getAdapter()
    return system, resource
end

--- Reports whether the active inventory supports a bridge feature in this realm.
---@param feature 'add'|'remove'|'count'|'has'|'carry'|'player'|'items'|'stash'|'open'|'close'|'usable'|string
---@return boolean supported
function TSS.Inventory.Supports(feature)
    local _, _, adapter = getAdapter()
    feature = tostring(feature or ''):lower()
    if TSS.IsClient() and (feature == 'stashitems' or feature == 'stashadd' or feature == 'stashremove' or feature == 'shop' or feature == 'metadata' or feature == 'add' or feature == 'remove' or feature == 'carry' or feature == 'stash' or feature == 'usable' or feature == 'useable') then
        return false
    end
    local methods = {
        stashitems = 'stashItems', stashadd = 'stashAdd', stashremove = 'stashRemove',
        shop = 'registerShop', metadata = 'setMetadata',
        usable = 'registerUsable', useable = 'registerUsable',
        add = 'add', remove = 'remove', count = 'count', has = 'count', carry = 'canCarry',
        player = 'inventory', items = 'items', stash = 'registerStash', open = 'openInventory', close = 'close',
    }
    local method = methods[feature]
    return adapter ~= nil and method ~= nil and type(adapter[method]) == 'function'
end

--- Counts matching items for a player.
---@param source integer|string Server player ID, or item name on the client.
---@param item? string|table Item name on the server, or metadata on the client.
---@param metadata? table|string Metadata filter on the server.
---@return integer count
function TSS.Inventory.Count(source, item, metadata)
    source, item, metadata = normaliseItemArgs(source, item, metadata)

    local _, resource, adapter = getAdapter()
    if not adapter then return 0 end
    return tonumber(adapter.count(resource, source, item, metadata)) or 0
end

--- Checks whether a player has at least the requested item amount.
---@param source integer|string Server player ID, or item name on the client.
---@param item? string|integer Item name on the server, or amount on the client.
---@param amount? integer|table Amount on the server, or metadata on the client.
---@param metadata? table|string Metadata filter on the server.
---@return boolean hasItem
---@usage
--- ```lua
--- if TSS.Inventory.Has(source, 'water', 2) then
---     TSS.Inventory.Remove(source, 'water', 2, nil, nil, 'recipe')
--- end
--- ```
function TSS.Inventory.Has(source, item, amount, metadata)
    source, item, amount, metadata = normaliseItemArgs(source, item, amount, metadata)
    return TSS.Inventory.Count(source, item, metadata) >= (amount or 1)
end

--- Returns the normalized player inventory.
---@param source? integer Server player ID; omit on the client.
---@return table inventory
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

--- Returns the active inventory's shared item definitions.
---@return table items
function TSS.Inventory.Items()
    local _, resource, adapter = getAdapter()
    if not adapter then return {} end
    return adapter.items(resource) or {}
end

--- Opens an inventory for the local player or a selected server player.
---@param source integer|string Server player ID, or inventory type on the client.
---@param invType? string|table Inventory type on the server, or data on the client.
---@param data? table|string|number Inventory-specific data on the server.
---@return boolean opened
function TSS.Inventory.Open(source, invType, data)
    if TSS.IsClient() and type(source) == 'string' then
        data = invType
        invType = source
        source = nil
    end

    local _, resource, adapter = getAdapter()
    if not adapter then return false end
    return adapter.openInventory(resource, source, invType, data) == true
end

--- Opens a stash for the local player or a selected server player.
---@param source integer|string|TSSStashData Server player ID, client stash ID, or client stash data.
---@param id? string|TSSStashData Stash ID on the server, or client stash data.
---@param data? TSSStashData Server stash data.
---@return boolean opened
function TSS.Inventory.OpenStash(source, id, data)
    if type(source) == 'table' then
        data = source
        id = data.id or data.name or data.stash
        source = nil
    elseif TSS.IsClient() and type(source) == 'string' then
        data = type(id) == 'table' and id or data
        id = source
        source = nil
    end

    data = data or {}
    data.id = data.id or id
    data.name = data.name or id
    data.stash = data.stash or id
    return TSS.Inventory.Open(source, 'stash', data)
end

--- Closes the local player's inventory or a selected server player's inventory.
---@param source? integer Server player ID; omit on the client.
---@return boolean closed
function TSS.Inventory.Close(source)
    local _, resource, adapter = getAdapter()
    if not adapter then return false end
    return adapter.close(resource, source) == true
end

--- Returns a provider-owned item image URL, or nil when unavailable.
function TSS.Inventory.Image(item)
    if type(item) ~= 'string' or item == '' then return nil end
    local _, resource, adapter = getAdapter()
    if not adapter then return nil end
    local definition = TSS.Inventory.Items()[item]
    if not definition then return nil end
    local image = definition.image or (definition.client and definition.client.image)
    if type(image) == 'string' and (image:match('^https?://') or image:match('^nui://')) then return image end
    if adapter.image then return adapter.image(resource, item, definition) end
    return nil
end
