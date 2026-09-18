TSS = TSS or {}

local currentGame = not IsDuplicityVersion() and GetCurrentGameName() or 'server'
local trackedCleanup = {}

function TSS.IsServer()
    return IsDuplicityVersion()
end

function TSS.IsClient()
    return not IsDuplicityVersion()
end

--- Reports whether a value can be invoked as a Lua or Cfx function.
--- Consumer functions crossing a resource boundary arrive as callable tables.
---@param value any
---@return boolean callable
function TSS.IsCallable(value)
    if type(value) == 'function' then return true end
    if type(value) ~= 'table' then return false end
    if rawget(value, '__cfx_functionReference') ~= nil then return true end
    local metatable = getmetatable(value)
    return metatable ~= nil and type(metatable.__call) == 'function'
end

function TSS.IsStarted(resource)
    return resource and GetResourceState(resource):find('start') ~= nil or false
end

function TSS.CallExport(resource, exportName, ...)
    if not TSS.IsStarted(resource) then return false, 'resource is not started' end

    local proxy = exports[resource]
    local export = proxy and proxy[exportName]
    if type(export) ~= 'function' then
        return false, ('missing export %s:%s'):format(resource, exportName)
    end

    -- FiveM resource exports are proxy methods. When the callable is obtained
    -- through __index and invoked later, the resource proxy must be supplied
    -- as self or the provider loses its first real argument.
    local ok, result, extra = pcall(export, proxy, ...)
    if ok then return true, result, extra end

    -- The provider was entered and raised its own error. Retrying without the
    -- proxy shifts the arguments and obscures the original failure.
    if type(result) == 'string' and result:find(('@%s/'):format(resource), 1, true) then
        return false, result
    end

    -- Retain compatibility with plain callable shims used by standalone tests.
    ok, result, extra = pcall(export, ...)
    if ok then return true, result, extra end
    return false, result
end

function TSS.Debug(...)
    if not TSS.Config.DebugPrints then return end
    print('^5[tss_bridge]^7', ...)
end

function TSS.Warn(...)
    print('^3[tss_bridge]^7', ...)
end

--- Enables or disables all bridge debug modes at runtime.
---@param state boolean New debug state.
function TSS.SetDebug(state)
    TSS.Config.Debug = state == true
    TSS.Config.DebugPrints = state == true
    TSS.Config.DebugPolyzones = state == true
    TSS.Config.DebugTools = state == true
end

function TSS.ShouldDebugPoly(value)
    if TSS.Config.DebugPolyzones then return true end
    return value == true
end

function TSS.Game()
    return currentGame
end

function TSS.ToHash(model)
    return type(model) == 'string' and joaat(model) or model
end

function TSS.LoadModel(model, timeout)
    local hash = TSS.ToHash(model)

    if not IsModelInCdimage(hash) then
        TSS.Warn(('Model does not exist: %s'):format(tostring(model)))
        return false, hash
    end

    RequestModel(hash)

    local expires = GetGameTimer() + (timeout or 5000)
    while not HasModelLoaded(hash) do
        Wait(0)
        if GetGameTimer() > expires then
            TSS.Warn(('Timed out loading model: %s'):format(tostring(model)))
            return false, hash
        end
    end

    return true, hash
end

function TSS.LoadAnimDict(dict, timeout)
    if not dict then return false end

    RequestAnimDict(dict)

    local expires = GetGameTimer() + (timeout or 5000)
    while not HasAnimDictLoaded(dict) do
        Wait(0)
        if GetGameTimer() > expires then
            TSS.Warn(('Timed out loading anim dict: %s'):format(dict))
            return false
        end
    end

    return true
end

function TSS.TrackEntity(entity, deleteFn)
    if entity and entity ~= 0 then
        trackedCleanup[entity] = deleteFn or DeleteEntity
    end

    return entity
end

function TSS.ForgetEntity(entity)
    trackedCleanup[entity] = nil
end

function TSS.DeleteEntity(entity)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    SetEntityAsMissionEntity(entity, true, true)
    DeleteEntity(entity)
    TSS.ForgetEntity(entity)

    return true
end

function TSS.FadeInEntity(entity, duration)
    if not TSS.Config.FadeEntities or currentGame == 'rdr3' then return end
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end

    duration = duration or 500
    local steps = 20
    local delay = math.floor(duration / steps)

    SetEntityAlpha(entity, 0, false)

    CreateThread(function()
        for i = 1, steps do
            if not DoesEntityExist(entity) then return end
            SetEntityAlpha(entity, math.floor(255 * (i / steps)), false)
            Wait(delay)
        end

        if DoesEntityExist(entity) then
            ResetEntityAlpha(entity)
        end
    end)
end

local function cleanupTrackedEntities()
    for entity, deleteFn in pairs(trackedCleanup) do
        if entity and entity ~= 0 and DoesEntityExist(entity) then
            deleteFn(entity)
        end
        trackedCleanup[entity] = nil
    end
end

AddEventHandler(TSS.IsServer() and 'onResourceStop' or 'onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        cleanupTrackedEntities()
    end
end)

function isStarted(resource)
    return TSS.IsStarted(resource)
end

function debugPrint(...)
    return TSS.Debug(...)
end

function setDebug(state)
    return TSS.SetDebug(state)
end

function debugPoly(value)
    return TSS.ShouldDebugPoly(value)
end
