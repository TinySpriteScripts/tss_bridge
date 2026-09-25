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
        local ok, result = TSS.Inventory.Utils.CallExport(resource, exportsToTry[i], ...)
        if ok then return result ~= false, exportsToTry[i], result end
    end

    return false
end

function TSS.Inventory.Utils.MetadataMatches(value, filter)
    if filter == nil then return true end
    if type(filter) == 'string' then
        return type(value) == 'table' and value.type == filter
    end
    if type(filter) ~= 'table' then return false end
    if next(filter) == nil then return true end
    if type(value) ~= 'table' then return false end

    for key, expected in pairs(filter) do
        if value[key] ~= expected then return false end
    end
    return true
end

function TSS.Inventory.Utils.CountItems(items, itemName, metadata)
    if type(items) ~= 'table' then return 0 end
    local total = 0
    for _, item in pairs(items) do
        if type(item) == 'table'
            and (itemName == nil or item.name == itemName)
            and TSS.Inventory.Utils.MetadataMatches(item.metadata or item.info, metadata)
        then
            total = total + TSS.Inventory.Utils.CountFromItem(item)
        end
    end
    return total
end

function TSS.Inventory.Utils.FindItems(items, itemName, metadata)
    local found = {}
    if type(items) ~= 'table' then return found end
    for _, item in pairs(items) do
        if type(item) == 'table' and item.name == itemName
            and TSS.Inventory.Utils.MetadataMatches(item.metadata or item.info, metadata)
        then
            found[#found + 1] = item
        end
    end
    table.sort(found, function(left, right)
        return (tonumber(left.slot) or math.huge) < (tonumber(right.slot) or math.huge)
    end)
    return found
end

function TSS.Inventory.Utils.GetSlot(items, slot)
    if type(items) ~= 'table' then return end
    local direct = items[slot]
    if type(direct) == 'table' and (direct.slot == nil or tonumber(direct.slot) == slot) then return direct end
    for _, item in pairs(items) do
        if type(item) == 'table' and tonumber(item.slot) == slot then return item end
    end
end

function TSS.Inventory.Utils.CalculateUnitWeight(items)
    local weight = 0
    for _, item in pairs(type(items) == 'table' and items or {}) do
        if type(item) == 'table' then
            weight = weight + ((tonumber(item.weight) or 0) * TSS.Inventory.Utils.CountFromItem(item))
        end
    end
    return weight
end

function TSS.Inventory.Utils.InventoryWeights(inventory)
    if type(inventory) ~= 'table' then return nil, nil end
    local weight = tonumber(inventory.weight or inventory.totalWeight or inventory.totalweight)
    local maximum = tonumber(inventory.maxWeight or inventory.maxweight or inventory.maximumWeight)
    return weight, maximum
end

function TSS.Inventory.Utils.UnwrapInventory(inventory)
    if type(inventory) ~= 'table' then return {} end
    return inventory.items or inventory.content or inventory.inventory or inventory
end

function TSS.Inventory.Utils.QBCore()
    if not TSS.IsStarted(TSS.Resources.QBCore) then return end
    local ok, core = pcall(function()
        return exports[TSS.Resources.QBCore]:GetCoreObject()
    end)
    if ok then return core end
end

function TSS.Inventory.Utils.QBItems()
    local core = TSS.Inventory.Utils.QBCore()
    return core and core.Shared and core.Shared.Items or {}
end

function TSS.Inventory.Utils.QBPlayerItems(source)
    local core = TSS.Inventory.Utils.QBCore()
    if not core or not core.Functions then return {} end
    local player = TSS.IsClient() and core.Functions.GetPlayerData() or core.Functions.GetPlayer(source)
    return player and (player.items or (player.PlayerData and player.PlayerData.items)) or {}
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
        instance = data.instance,
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
        weight = 'weight', maxweight = 'maxWeight', maximumweight = 'maxWeight',
    }
    if feature == 'slot' then
        return adapter ~= nil and (type(adapter.getSlot) == 'function' or type(adapter.inventory) == 'function')
    end
    if feature == 'find' or feature == 'search' then
        return adapter ~= nil and (type(adapter.find) == 'function' or type(adapter.inventory) == 'function')
    end
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
    if type(item) ~= 'string' or item == '' then return 0 end
    if TSS.IsServer() and not tonumber(source) then return 0 end

    local _, resource, adapter = getAdapter()
    if not adapter or type(adapter.count) ~= 'function' then return 0 end
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
    amount = tonumber(amount) or 1
    if amount <= 0 then return false end
    return TSS.Inventory.Count(source, item, metadata) >= amount
end

--- Returns the normalized player inventory.
---@param source? integer Server player ID; omit on the client.
---@return table inventory
function TSS.Inventory.Player(source)
    local _, resource, adapter = getAdapter()
    if not adapter then return {} end

    if type(adapter.inventory) ~= 'function' then return {} end

    return adapter.inventory(resource, source) or {}
end

--- Returns one exact inventory slot.
---@param source? integer Server player ID, or slot on the client.
---@param slot? integer Slot on the server.
---@return table? item
function TSS.Inventory.GetSlot(source, slot)
    if TSS.IsClient() then slot, source = source, nil end
    slot = tonumber(slot)
    if not slot or slot < 1 or (TSS.IsServer() and not tonumber(source)) then return nil end
    local _, resource, adapter = getAdapter()
    if not adapter then return nil end
    if type(adapter.getSlot) == 'function' then return adapter.getSlot(resource, source, slot) end
    if type(adapter.inventory) ~= 'function' then return nil end
    return TSS.Inventory.Utils.GetSlot(adapter.inventory(resource, source), slot)
end

--- Returns every matching item stack, ordered by slot.
---@param source integer|string Server player ID, or item name on the client.
---@param item? string|table Item name on the server, or metadata on the client.
---@param metadata? table|string Metadata filter.
---@return table items
function TSS.Inventory.Find(source, item, metadata)
    source, item, metadata = normaliseItemArgs(source, item, metadata)
    if type(item) ~= 'string' or item == '' or (TSS.IsServer() and not tonumber(source)) then return {} end
    local _, resource, adapter = getAdapter()
    if not adapter then return {} end
    if type(adapter.find) == 'function' then
        return TSS.Inventory.Utils.FindItems(adapter.find(resource, source, item, metadata), item, metadata)
    end
    if type(adapter.inventory) ~= 'function' then return {} end
    return TSS.Inventory.Utils.FindItems(adapter.inventory(resource, source), item, metadata)
end

--- Returns current inventory weight when supported by the active provider.
---@param source? integer Server player ID; omit on the client.
---@return number? weight
function TSS.Inventory.Weight(source)
    if TSS.IsServer() and not tonumber(source) then return nil end
    local _, resource, adapter = getAdapter()
    if not adapter or type(adapter.weight) ~= 'function' then return nil end
    return tonumber(adapter.weight(resource, source))
end

--- Returns maximum inventory weight when supported by the active provider.
---@param source? integer Server player ID; omit on the client.
---@return number? maxWeight
function TSS.Inventory.MaxWeight(source)
    if TSS.IsServer() and not tonumber(source) then return nil end
    local _, resource, adapter = getAdapter()
    if not adapter or type(adapter.maxWeight) ~= 'function' then return nil end
    return tonumber(adapter.maxWeight(resource, source))
end

--- Returns the active inventory's shared item definitions.
---@return table items
function TSS.Inventory.Items()
    local _, resource, adapter = getAdapter()
    if not adapter or type(adapter.items) ~= 'function' then return {} end
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

    if type(invType) ~= 'string' or invType == '' then return false end
    if TSS.IsServer() and not tonumber(source) then return false end

    local _, resource, adapter = getAdapter()
    if not adapter or type(adapter.openInventory) ~= 'function' then return false end
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
    if not adapter or type(adapter.close) ~= 'function' then return false end
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
