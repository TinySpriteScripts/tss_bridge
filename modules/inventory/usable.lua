-- Server-only usable-item registration and consumer ownership.
local Utils = TSS.Inventory.Utils
local registrations = {}

local function cleanupRegistration(entry)
    if not entry or not entry.cleanup then return end
    local cleanup = entry.cleanup
    entry.cleanup = nil
    local ok, err = pcall(cleanup)
    if not ok then TSS.Warn(('Usable item cleanup failed: %s'):format(tostring(err))) end
end

-- Registration exports commonly return nothing. Only explicit false is rejection.
-- Invoke once: retrying a registration can overwrite a provider callback twice.
function Utils.RegisterUsableExport(resource, exportName, item, callback)
    if not TSS.IsStarted(resource) then return false, 'inventory_not_started' end
    local ok, result = pcall(function()
        return exports[resource][exportName](exports[resource], item, callback)
    end)
    if not ok then return false, tostring(result) end
    if result == false then return false, 'provider_rejected_registration' end
    return true
end

local function normalizeItem(name, item, extra)
    -- ESX may pass (source, itemName, slotData), QB passes (source, slotData).
    local raw = type(item) == 'table' and not TSS.IsCallable(item) and item
        or type(extra) == 'table' and not TSS.IsCallable(extra) and extra or {}
    local result = {}
    for key, value in pairs(raw) do result[key] = value end
    result.name = name
    result.metadata = type(raw.metadata) == 'table' and raw.metadata
        or type(raw.info) == 'table' and raw.info or {}
    result.info = result.metadata
    result.count = raw.count or raw.amount or raw.quantity
    result.amount = result.count
    return result
end

function TSS.Inventory._CreateUseableItem(owner, item, callback)
    if type(item) ~= 'string' or item == '' or item:find('%s') then
        return false, 'invalid_item_name'
    end
    item = item:lower()
    if not TSS.IsCallable(callback) then return false, 'invalid_callback' end
    local previous = registrations[item]
    if previous and previous.owner ~= owner then
        return false, ('item_already_registered_by:%s'):format(previous.owner)
    end
    local _, resource, adapter = TSS.Inventory._GetAdapter()
    if not adapter then return false, 'inventory_unavailable' end
    if type(adapter.registerUsable) ~= 'function' then return false, 'usable_items_unsupported' end

    local entry = { owner = owner, callback = callback }
    local function dispatch(source, itemData, ...)
        if registrations[item] ~= entry or not entry.callback then return false end
        source = tonumber(source)
        if not source or source <= 0 or source % 1 ~= 0 then return false end
        local normalized = normalizeItem(item, itemData, select(1, ...))
        local result = table.pack(pcall(entry.callback, source, normalized, ...))
        if not result[1] then
            TSS.Warn(('Usable item %s in %s failed: %s'):format(item, owner, tostring(result[2])))
            return false
        end
        return table.unpack(result, 2, result.n)
    end
    -- Reserve before entering provider code, which may yield.
    registrations[item] = entry
    local ok, registered, err, cleanup = pcall(adapter.registerUsable, resource, item, dispatch)
    if not ok or registered ~= true then
        if TSS.IsCallable(cleanup) then pcall(cleanup) end
        if registrations[item] == entry then registrations[item] = previous end
        entry.callback = nil
        return false, not ok and tostring(registered) or err or 'provider_rejected_registration'
    end
    entry.cleanup = TSS.IsCallable(cleanup) and cleanup or nil
    if registrations[item] ~= entry then
        cleanupRegistration(entry)
        entry.callback = nil
        return false, 'registration_superseded_or_consumer_stopped'
    end
    if previous then
        previous.callback = nil
        cleanupRegistration(previous)
    end
    return true
end

function TSS.Inventory._ClearUseableItems(owner)
    for item, entry in pairs(registrations) do
        if entry.owner == owner then
            entry.callback = nil
            cleanupRegistration(entry)
            registrations[item] = nil
        end
    end
end
