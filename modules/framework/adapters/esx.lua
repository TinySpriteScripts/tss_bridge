local cachedObject

local function object(resource)
    if cachedObject then return cachedObject end
    local ok, core = TSS.CallExport(resource, 'getSharedObject')
    if ok then cachedObject = core end
    return cachedObject
end

TSS.Framework.RegisterAdapter('esx', TSS.Resources.ESX, {
    supports = { player = true, jobs = true, money = true, object = true },
    object = object,
    player = function(resource, source)
        local core = object(resource)
        if not core then return nil end
        if TSS.IsServer() then
            return type(source) == 'number' and core.GetPlayerFromId(source) or nil
        end
        return core.GetPlayerData()
    end,
    playerData = function(resource, source)
        local core = object(resource)
        if not core then return nil end
        if TSS.IsServer() then
            return type(source) == 'number' and core.GetPlayerFromId(source) or nil
        end
        return core.GetPlayerData()
    end,
    jobs = function(resource)
        local core = object(resource)
        return core and core.GetJobs and core.GetJobs() or {}
    end,
}, { priority = 30, aliases = { 'es_extended' } })

AddEventHandler(TSS.IsServer() and 'onResourceStop' or 'onClientResourceStop', function(resource)
    if resource == TSS.Resources.ESX then cachedObject = nil end
end)
