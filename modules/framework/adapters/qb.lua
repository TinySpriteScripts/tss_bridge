local cachedObject

local function object(resource)
    if cachedObject then return cachedObject end
    local ok, core = TSS.CallExport(resource, 'GetCoreObject')
    if ok then cachedObject = core end
    return cachedObject
end

TSS.Framework.RegisterAdapter('qb', TSS.Resources.QBCore, {
    supports = { player = true, jobs = true, gangs = true, money = true, object = true },
    object = object,
    player = function(resource, source)
        local core = object(resource)
        if not core or not core.Functions then return nil end
        if TSS.IsServer() then
            if type(source) ~= 'number' then return nil end
            return core.Functions.GetPlayer(source)
        end
        return core.Functions.GetPlayerData()
    end,
    playerData = function(resource, source)
        local core = object(resource)
        if not core or not core.Functions then return nil end
        if TSS.IsServer() then
            local player = type(source) == 'number' and core.Functions.GetPlayer(source) or nil
            return player and player.PlayerData or nil
        end
        return core.Functions.GetPlayerData()
    end,
    jobs = function(resource)
        local core = object(resource)
        return core and core.Shared and core.Shared.Jobs or {}
    end,
    gangs = function(resource)
        local core = object(resource)
        return core and core.Shared and core.Shared.Gangs or {}
    end,
}, { priority = 20, aliases = { 'qb-core', 'qbcore' } })

AddEventHandler(TSS.IsServer() and 'onResourceStop' or 'onClientResourceStop', function(resource)
    if resource == TSS.Resources.QBCore then cachedObject = nil end
end)
