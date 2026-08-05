TSS = TSS or {}

local bridgeResource = GetCurrentResourceName()
local realm = IsDuplicityVersion() and 'server' or 'client'
local definitions = {}
local loaded = {}
local requestedBy = {}

TSSModuleLoader = {
    Realm = realm,
    InventoryFiles = {
        'shared/modules/inventory.lua',
        'shared/inventory/ox_inventory.lua',
        'shared/inventory/qb-inventory.lua',
        'shared/inventory/ps-inventory.lua',
        'shared/inventory/lj-inventory.lua',
        'shared/inventory/qs-inventory.lua',
        'shared/inventory/core_inventory.lua',
        'shared/inventory/codem-inventory.lua',
        'shared/inventory/origen_inventory.lua',
        'shared/inventory/tgiann-inventory.lua',
        'shared/inventory/ak47_inventory.lua',
        'shared/inventory/mf-inventory.lua',
        'shared/inventory/tss-inventory.lua',
        'shared/inventory/inventory.lua',
    },
}

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

function TSSModuleLoader.Define(name, files, build, dependencies)
    if type(name) ~= 'string' or name == '' then
        error('[tss_bridge] Cannot register a module without a name', 0)
    end

    if definitions[name:lower()] then
        error(('[tss_bridge] Module %s is already registered on the %s'):format(name, realm), 0)
    end

    definitions[name:lower()] = {
        name = name,
        files = files,
        build = build,
        dependencies = dependencies or {},
        ready = false,
    }
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

    for i = 1, #definition.dependencies do
        local dependency = definitions[definition.dependencies[i]:lower()]
        if not dependency then
            error(('[tss_bridge] %s module has unknown dependency %s'):format(definition.name, definition.dependencies[i]), 0)
        end
        initialise(dependency)
    end

    for i = 1, #definition.files do
        loadFile(definition.files[i])
    end

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

    local caller = GetInvokingResource()
    if not caller or caller == '' then caller = bridgeResource end

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
            public[definition.name] = definition.build(caller, options or {})
            seen[definition.name] = true
            requestedBy[caller][definition.name] = true
        end
    end

    return public
end

exports('GetModules', getModules)
