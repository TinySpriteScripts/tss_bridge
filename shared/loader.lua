TSS = TSS or {}

local bridgeResource = GetCurrentResourceName()
local realm = IsDuplicityVersion() and 'server' or 'client'
local definitions = {}
local loaded = {}
local requestedBy = {}
local versionCheckReported = {}

TSSModuleLoader = {
    Realm = realm,
}

--- Copies an explicit set of functions into an isolated public API table.
---@param source table Internal module implementation.
---@param names string[] Public function names.
---@return table<string, function> public
function TSSModuleLoader.CopyFunctions(source, names)
    local public = {}

    for i = 1, #names do
        local name = names[i]
        local fn = source and source[name]

        if type(fn) ~= 'function' then
            error(('[tss_bridge] %s module is missing function %s'):format(realm, name), 0)
        end

        public[name] = fn
    end

    return public
end


local function loadFile(path)
    if loaded[path] then return end

    local contents = LoadResourceFile(bridgeResource, path)
    if not contents then
        error(('[tss_bridge] Unable to load %s'):format(path), 0)
    end

    local chunk, loadError = load(contents, ('@@%s/%s'):format(bridgeResource, path))
    if not chunk then
        error(('[tss_bridge] Unable to compile %s: %s'):format(path, loadError), 0)
    end

    local ok, runtimeError = pcall(chunk)
    if not ok then
        error(('[tss_bridge] Unable to initialise %s: %s'):format(path, runtimeError), 0)
    end

    loaded[path] = true
end

--- Registers a self-contained module descriptor for the current realm.
---@param specification TSSModuleDefinition Module metadata and realm factories.
function TSSModuleLoader.Define(specification)
    if type(specification) ~= 'table' then
        error('[tss_bridge] Module definition must be a table', 0)
    end

    local name = specification.name
    if type(name) ~= 'string' or name == '' or not name:match('^[%w_%-]+$') then
        error('[tss_bridge] Cannot register a module without a name', 0)
    end

    local build = specification[realm]
    if build == nil then return false end
    if type(build) ~= 'function' then
        error(('[tss_bridge] Module %s has an invalid %s factory'):format(name, realm), 0)
    end

    if definitions[name:lower()] then
        error(('[tss_bridge] Module %s is already registered on the %s'):format(name, realm), 0)
    end

    local files = {}
    local function append(list)
        if list == nil then return end
        if type(list) ~= 'table' then
            error(('[tss_bridge] Module %s file list must be a table'):format(name), 0)
        end
        for i = 1, #list do
            if type(list[i]) ~= 'string' or list[i] == '' then
                error(('[tss_bridge] Module %s has an invalid file at index %d'):format(name, i), 0)
            end
            files[#files + 1] = list[i]
        end
    end

    append(specification.files)
    append(specification[realm .. 'Files'])

    local dependencies = specification.dependencies or {}
    if type(dependencies) ~= 'table' then
        error(('[tss_bridge] Module %s dependencies must be a table'):format(name), 0)
    end

    definitions[name:lower()] = {
        name = name,
        files = files,
        build = build,
        dependencies = dependencies,
        ready = false,
    }
    return true
end

function TSSModuleLoader.HasDefinition(name)
    return type(name) == 'string' and definitions[name:lower()] ~= nil or false
end

function TSSModuleLoader.ListAvailable()
    local names = {}
    for _, definition in pairs(definitions) do
        names[#names + 1] = definition.name
    end
    table.sort(names)
    return names
end

function TSSModuleLoader.ListLoaded()
    local names = {}
    for _, definition in pairs(definitions) do
        if definition.ready then names[#names + 1] = definition.name end
    end
    table.sort(names)
    return names
end

function TSSModuleLoader.RequestedBy()
    local snapshot = {}

    for resource, modules in pairs(requestedBy) do
        snapshot[resource] = {}
        for name in pairs(modules) do
            snapshot[resource][#snapshot[resource] + 1] = name
        end
        table.sort(snapshot[resource])
    end

    return snapshot
end

local function initialise(definition)
    if definition.ready then return end
    if definition.initialising then
        error(('[tss_bridge] Circular dependency detected while loading %s'):format(definition.name), 0)
    end

    definition.initialising = true

    local ok, initialiseError = pcall(function()
        for i = 1, #definition.dependencies do
            local dependencyName = definition.dependencies[i]
            if type(dependencyName) ~= 'string' or dependencyName == '' then
                error(('[tss_bridge] Module %s has an invalid dependency at index %d'):format(definition.name, i), 0)
            end

            local dependency = definitions[dependencyName:lower()]
            if not dependency then
                error(('[tss_bridge] %s module has unknown %s dependency %s'):format(definition.name, realm, dependencyName), 0)
            end
            initialise(dependency)
        end

        for i = 1, #definition.files do loadFile(definition.files[i]) end
    end)

    definition.initialising = false
    if not ok then error(initialiseError, 0) end
    definition.ready = true
end

function TSSModuleLoader.Ensure(name)
    local definition = type(name) == 'string' and definitions[name:lower()] or nil
    if not definition then return false end
    initialise(definition)
    return true
end

local function availableModules()
    return table.concat(TSSModuleLoader.ListAvailable(), ', ')
end

local function reportVersionConsumer(caller)
    if versionCheckReported[caller] then return end
    versionCheckReported[caller] = true

    if realm == 'server' then
        if TSS.VersionCheck and TSS.VersionCheck.Register then
            TSS.VersionCheck.Register(caller)
        end
        return
    end

    TriggerServerEvent('tss_bridge:server:registerVersionConsumer', caller)
end

local function createContext(caller, options)
    local function preference(key, preferred)
        return preferred or options[key]
    end
    return {
        Preference = preference,
        ProviderAPI = function(source, key)
            return {
                System = function(preferred) return source.System(preference(key, preferred)) end,
                Supports = function(feature, preferred) return source.Supports(feature, preference(key, preferred)) end,
            }
        end,
        ProviderData = function(key, data)
            local copy = {}
            if type(data) == 'table' then
                for field, value in pairs(data) do copy[field] = value end
            elseif data ~= nil then
                copy.text = tostring(data)
            end
            copy.adapter = preference(key, copy.adapter)
            return copy
        end,
        Caller = caller,
        Options = options,
        Realm = realm,
        CopyFunctions = TSSModuleLoader.CopyFunctions,
        OnStop = function(callback)
            if type(callback) ~= 'function' then
                error('[tss_bridge] Module cleanup callback must be a function', 0)
            end

            local cleaned = false
            local function cleanup(resource)
                if resource ~= caller or cleaned then return end
                cleaned = true
                callback()
            end
            AddEventHandler('onResourceStop', cleanup)
            if realm == 'client' then AddEventHandler('onClientResourceStop', cleanup) end
        end,
    }
end

local function buildModule(definition, caller, options)
    local public = definition.build(createContext(caller, options))
    if type(public) ~= 'table' then
        error(('[tss_bridge] Module %s %s factory must return a table'):format(definition.name, realm), 0)
    end

    for key, value in pairs(public) do
        if type(key) ~= 'string' or type(value) ~= 'function' then
            error(('[tss_bridge] Module %s public API may only contain named functions'):format(definition.name), 0)
        end
    end

    return public
end

--- Returns only the requested modules that are valid for the current realm.
---
--- Client and server module registries are separate. A client cannot request a
--- server-only method such as `Banking.RemoveMoney`, even if it asks for `Banking`.
---
---@param requested string[] Names of the modules to expose to the calling resource.
---@param options? TSSModuleOptions Per-resource presentation provider selections (for example Config.TSS).
---@return TSSClientModules|TSSServerModules modules A caller-scoped table containing only the requested modules.
---@usage
--- ```lua
--- local TSS = exports.tss_bridge:GetModules({ 'Framework', 'Inventory' })
--- print(TSS.Framework.System())
--- ```
local function getModules(requested, options)
    if type(requested) ~= 'table' then
        error(('[tss_bridge] GetModules expects an array of module names on the %s'):format(realm), 2)
    end

    local requestCount = 0
    for key in pairs(requested) do
        if type(key) ~= 'number' or key < 1 or key % 1 ~= 0 then
            error('[tss_bridge] GetModules expects a sequential array of module names', 2)
        end
        requestCount = requestCount + 1
    end

    if requestCount ~= #requested then
        error('[tss_bridge] GetModules expects a sequential array without gaps', 2)
    end

    if requestCount > 32 then
        error('[tss_bridge] GetModules accepts at most 32 module names', 2)
    end

    if options ~= nil and type(options) ~= 'table' then
        error('[tss_bridge] GetModules options must be a table when provided', 2)
    end

    -- Snapshot only the supported presentation settings; never override gameplay systems.
    local settings = {}
    for _, key in ipairs({ 'Target', 'Notify', 'ProgressBar', 'TextUI', 'Interaction' }) do
        local value = options and options[key]
        if value ~= nil then
            if type(value) ~= 'string' or value == '' then
                error(('[tss_bridge] GetModules option %s must be a non-empty adapter name'):format(key), 2)
            end
            settings[key] = value
        end
    end
    if options and options.Debug ~= nil then
        if type(options.Debug) ~= 'boolean' then
            error('[tss_bridge] GetModules option Debug must be a boolean', 2)
        end
        settings.Debug = options.Debug
    end
    if options and options.DebugProgressDuration ~= nil then
        local duration = tonumber(options.DebugProgressDuration)
        if not duration or duration < 1 or duration % 1 ~= 0 then
            error('[tss_bridge] GetModules option DebugProgressDuration must be a positive whole number', 2)
        end
        settings.DebugProgressDuration = duration
    end
    options = settings

    local caller = GetInvokingResource()
    if not caller or caller == '' then caller = bridgeResource end
    reportVersionConsumer(caller)

    local public = {}
    local seen = {}
    requestedBy[caller] = requestedBy[caller] or {}

    for index = 1, #requested do
        local requestedName = requested[index]
        if type(requestedName) ~= 'string' or requestedName == '' then
            error(('[tss_bridge] Module name at index %d must be a non-empty string'):format(index), 2)
        end

        local definition = definitions[requestedName:lower()]
        if not definition then
            error(('[tss_bridge] Module %q is not available on the %s. Available: %s')
                :format(requestedName, realm, availableModules()), 2)
        end

        if not seen[definition.name] then
            initialise(definition)
            public[definition.name] = buildModule(definition, caller, options or {})
            seen[definition.name] = true
            requestedBy[caller][definition.name] = true
        end
    end

    return public
end

TSSModuleLoader.GetModules = getModules

--- Publishes the consumer export after all realm descriptors have registered.
--- This must run from the final client/server manifest script.
function TSSModuleLoader.RegisterExport()
    if #TSSModuleLoader.ListAvailable() == 0 then
        error(('[tss_bridge] No %s modules were registered before GetModules export setup'):format(realm), 0)
    end

    exports('GetModules', getModules)
end
