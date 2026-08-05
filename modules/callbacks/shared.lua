-- Lazy realm-aware implementation owned by the Callbacks module.
TSS = TSS or {}
TSS.Callbacks = TSS.Callbacks or {}

local handlers = {}
local pending = {}
local counter = 0
local rateLimits = {}

local function validName(value)
    return type(value) == 'string' and #value > 0 and #value <= 100 and value:match('^[%w_:%-%.]+$') ~= nil
end

local function nextId(namespace)
    counter = counter + 1
    return ('%s:%s:%s'):format(namespace, GetGameTimer(), counter)
end

local function pack(...)
    return { n = select('#', ...), ... }
end

local function unpackValues(values)
    if type(values) ~= 'table' then return end
    local count = math.floor(tonumber(values.n) or #values)
    count = math.max(0, math.min(32, count))
    return table.unpack(values, 1, count)
end

local function callbackKey(namespace, name)
    return ('%s:%s'):format(namespace, name)
end

local function awaitResponse(key, trigger, timeout)
    local deferred = promise.new()
    pending[key] = deferred
    trigger()

    timeout = math.max(1000, math.min(120000, tonumber(timeout) or TSS.Config.CallbackTimeout))
    SetTimeout(timeout, function()
        if pending[key] == deferred then
            pending[key] = nil
            deferred:resolve({ ok = false, error = TSS.Locale.T('callback_timeout', key) })
        end
    end)

    local response = Citizen.Await(deferred)
    if not response.ok then return nil, response.error end
    return unpackValues(response.values)
end

local function resolve(key, ok, values, err)
    local deferred = pending[key]
    if not deferred then return end
    pending[key] = nil
    deferred:resolve({ ok = ok == true, values = values, error = err })
end

local function register(namespace, name, handler)
    if not validName(namespace) or not validName(name) or type(handler) ~= 'function' then return false end
    local key = callbackKey(namespace, name)
    if handlers[key] then
        TSS.Warn(('Callback already registered: %s'):format(key))
        return false
    end
    handlers[key] = handler
    return true
end

--- Registers a namespaced callback handler in the current realm.
---@param namespace string Calling resource namespace.
---@param name string Callback name.
---@param handler function Handler; server handlers receive `source` first.
---@return boolean registered
function TSS.Callbacks.Register(namespace, name, handler)
    return register(namespace, name, handler)
end

--- Unregisters one callback owned by a resource namespace.
---@param namespace string Calling resource namespace.
---@param name string Callback name.
---@return boolean removed
function TSS.Callbacks.Unregister(namespace, name)
    if not validName(namespace) or not validName(name) then return false end
    handlers[callbackKey(namespace, name)] = nil
    return true
end

--- Clears handlers and pending calls owned by a resource namespace.
---@param namespace string Calling resource namespace.
---@return boolean cleared
function TSS.Callbacks.Clear(namespace)
    if not validName(namespace) then return false end
    local prefix = namespace .. ':'
    for key in pairs(handlers) do
        if key:sub(1, #prefix) == prefix then handlers[key] = nil end
    end

    for key, deferred in pairs(pending) do
        if key:sub(1, #prefix) == prefix or key:find(':' .. prefix, 1, true) then
            pending[key] = nil
            deferred:resolve({ ok = false, error = 'callback owner stopped' })
        end
    end
    return true
end

if TSS.IsServer() then
    local function allowed(source)
        local now = GetGameTimer()
        local limit = rateLimits[source]
        if not limit or now - limit.startedAt >= 10000 then
            rateLimits[source] = { startedAt = now, count = 1 }
            return true
        end
        limit.count = limit.count + 1
        return limit.count <= 50
    end

    RegisterNetEvent('tss_bridge:server:callback:request', function(namespace, name, id, args)
        local source = source
        if not allowed(source) or not validName(namespace) or not validName(name) or not validName(id) or type(args) ~= 'table' then return end

        local handler = handlers[callbackKey(namespace, name)]
        if not handler then
            TriggerClientEvent('tss_bridge:client:callback:response', source, id, false, nil,
                TSS.Locale.T('callback_missing', callbackKey(namespace, name)))
            return
        end

        CreateThread(function()
            local result = pack(pcall(handler, source, unpackValues(args)))
            local ok = result[1]
            table.remove(result, 1)
            result.n = result.n - 1
            TriggerClientEvent('tss_bridge:client:callback:response', source, id, ok, ok and result or nil, ok and nil or tostring(result[1]))
        end)
    end)

    RegisterNetEvent('tss_bridge:server:callback:response', function(id, ok, values, err)
        local source = source
        if not validName(id) then return end
        resolve(('%s:%s'):format(source, id), ok, values, err)
    end)

    AddEventHandler('playerDropped', function()
        rateLimits[source] = nil
        local prefix = ('%s:'):format(source)
        for key, deferred in pairs(pending) do
            if key:sub(1, #prefix) == prefix then
                pending[key] = nil
                deferred:resolve({ ok = false, error = 'player dropped' })
            end
        end
    end)

    --- Invokes a client callback from the server and awaits its response.
    ---@param namespace string Calling resource namespace.
    ---@param source integer Target player ID.
    ---@param name string Callback name.
    ---@param timeout? integer Timeout in milliseconds.
    ---@param ... any Arguments sent to the client handler.
    ---@return ...
    function TSS.Callbacks.Await(namespace, source, name, timeout, ...)
        if type(source) ~= 'number' or not validName(namespace) or not validName(name) then return nil, 'invalid callback request' end
        local id = nextId(namespace)
        local key = ('%s:%s'):format(source, id)
        local args = pack(...)
        return awaitResponse(key, function()
            TriggerClientEvent('tss_bridge:client:callback:request', source, namespace, name, id, args)
        end, timeout)
    end
else
    RegisterNetEvent('tss_bridge:client:callback:request', function(namespace, name, id, args)
        if not validName(namespace) or not validName(name) or not validName(id) or type(args) ~= 'table' then return end
        local handler = handlers[callbackKey(namespace, name)]

        if not handler then
            TriggerServerEvent('tss_bridge:server:callback:response', id, false, nil,
                TSS.Locale.T('callback_missing', callbackKey(namespace, name)))
            return
        end

        CreateThread(function()
            local result = pack(pcall(handler, unpackValues(args)))
            local ok = result[1]
            table.remove(result, 1)
            result.n = result.n - 1
            TriggerServerEvent('tss_bridge:server:callback:response', id, ok, ok and result or nil, ok and nil or tostring(result[1]))
        end)
    end)

    RegisterNetEvent('tss_bridge:client:callback:response', function(id, ok, values, err)
        if not validName(id) then return end
        resolve(id, ok, values, err)
    end)

    --- Invokes a server callback from the client and awaits its response.
    ---@param namespace string Calling resource namespace.
    ---@param name string Callback name.
    ---@param timeout? integer Timeout in milliseconds.
    ---@param ... any Arguments sent to the server handler.
    ---@return ...
    function TSS.Callbacks.Await(namespace, name, timeout, ...)
        if not validName(namespace) or not validName(name) then return nil, 'invalid callback request' end
        local id = nextId(namespace)
        local args = pack(...)
        return awaitResponse(id, function()
            TriggerServerEvent('tss_bridge:server:callback:request', namespace, name, id, args)
        end, timeout)
    end
end
