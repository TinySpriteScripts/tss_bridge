TSS = TSS or {}
TSS.Framework = TSS.Framework or {}

local cachedObjects = {}
local qboxPlayerData

local aliases = {
    ['qb'] = 'qb',
    ['qb-core'] = 'qb',
    ['qbcore'] = 'qb',
    ['qbox'] = 'qbox',
    ['qbx'] = 'qbox',
    ['qbx_core'] = 'qbox',
    ['esx'] = 'esx',
    ['es_extended'] = 'esx',
}

local resources = {
    qb = TSS.Resources.QBCore,
    qbox = TSS.Resources.Qbox,
    esx = TSS.Resources.ESX,
}

local function detect()
    local configured = tostring(TSS.Config.Framework or 'auto'):lower()

    if configured ~= 'auto' then
        local system = aliases[configured] or configured
        local resource = resources[system]
        if resource and TSS.IsStarted(resource) then return system, resource end
        TSS.Warn(('Configured framework is not started: %s'):format(tostring(resource or configured)))
        return nil, nil
    end

    if TSS.IsStarted(TSS.Resources.Qbox) then return 'qbox', TSS.Resources.Qbox end
    if TSS.IsStarted(TSS.Resources.QBCore) then return 'qb', TSS.Resources.QBCore end
    if TSS.IsStarted(TSS.Resources.ESX) then return 'esx', TSS.Resources.ESX end
    return nil, nil
end

local function getObject(system, resource)
    if cachedObjects[system] then return cachedObjects[system] end

    local ok, object
    if system == 'qb' then
        ok, object = pcall(function() return exports[resource]:GetCoreObject() end)
    elseif system == 'esx' then
        ok, object = pcall(function() return exports[resource]:getSharedObject() end)
    elseif system == 'qbox' then
        return nil
    end

    if ok then cachedObjects[system] = object end
    return cachedObjects[system]
end

function TSS.Framework.System()
    return detect()
end

function TSS.Framework.Object()
    local system, resource = detect()
    if not system then return nil end
    return getObject(system, resource)
end

function TSS.Framework.Player(source)
    local system, resource = detect()
    if not system then return nil end

    if system == 'qbox' then
        if TSS.IsServer() then
            if type(source) ~= 'number' then return nil end
            local ok, player = pcall(function() return exports[resource]:GetPlayer(source) end)
            return ok and player or nil
        end
        return qboxPlayerData
    end

    local object = getObject(system, resource)
    if not object then return nil end

    if system == 'qb' then
        if TSS.IsServer() then
            if type(source) ~= 'number' then return nil end
            return object.Functions.GetPlayer(source)
        end
        return object.Functions.GetPlayerData()
    end

    if TSS.IsServer() then
        if type(source) ~= 'number' then return nil end
        return object.GetPlayerFromId(source)
    end
    return object.GetPlayerData()
end

function TSS.Framework.PlayerData(source)
    local system = detect()
    local player = TSS.Framework.Player(source)
    if not player then return nil end

    if TSS.IsServer() and (system == 'qb' or system == 'qbox') then
        return player.PlayerData
    end

    return player
end

function TSS.Framework.Jobs()
    local system, resource = detect()
    if system == 'qbox' then
        local ok, jobs = pcall(function() return exports[resource]:GetJobs() end)
        return ok and jobs or {}
    end

    local object = TSS.Framework.Object()
    if system == 'qb' then return object and object.Shared and object.Shared.Jobs or {} end
    if system == 'esx' and object and object.GetJobs then return object.GetJobs() or {} end
    return {}
end

function TSS.Framework.Gangs()
    local system, resource = detect()
    if system == 'qbox' then
        local ok, gangs = pcall(function() return exports[resource]:GetGangs() end)
        return ok and gangs or {}
    end

    local object = TSS.Framework.Object()
    if system == 'qb' then return object and object.Shared and object.Shared.Gangs or {} end
    return {}
end

function TSS.Framework.Supports(feature)
    local system = detect()
    local supported = {
        player = system ~= nil,
        jobs = system ~= nil,
        gangs = system == 'qb' or system == 'qbox',
        money = system ~= nil,
        object = system == 'qb' or system == 'esx',
    }
    return supported[tostring(feature or ''):lower()] == true
end

AddEventHandler(TSS.IsServer() and 'onResourceStop' or 'onClientResourceStop', function(resource)
    for system, frameworkResource in pairs(resources) do
        if resource == frameworkResource then cachedObjects[system] = nil end
    end
    if resource == TSS.Resources.Qbox then qboxPlayerData = nil end
end)

if not TSS.IsServer() then
    RegisterNetEvent('QBCore:Player:SetPlayerData', function(data)
        qboxPlayerData = data
    end)

    RegisterNetEvent('qbx_core:client:playerLoggedOut', function()
        qboxPlayerData = nil
    end)
end
