TSS = TSS or {}

--- Shared adapter registry used by every bridge module.
---
--- Modules own their public API while integrations register independently in
--- `modules/<module>/adapters/*.lua`. This keeps detection and configuration
--- behaviour identical across the bridge.
TSS.Adapters = TSS.Adapters or {}

local registries = {}

local function normalise(value)
    return type(value) == 'string' and value:lower() or value
end

local function defaultAvailable(entry)
    return entry.resource == nil or TSS.IsStarted(entry.resource)
end

--- Creates or returns a named adapter registry.
---@param moduleName string Human-readable module name.
---@param options? table Registry options (`config`, `fallback`).
---@return table registry
function TSS.Adapters.Create(moduleName, options)
    assert(type(moduleName) == 'string' and moduleName ~= '', 'Adapter registry needs a module name')

    local registryName = moduleName:lower()
    if registries[registryName] then return registries[registryName] end

    options = options or {}
    local registry = {
        name = moduleName,
        config = options.config or moduleName,
        fallback = normalise(options.fallback),
        entries = {},
        aliases = {},
        order = {},
        warned = {},
    }

    --- Registers one integration with this module.
    ---@param key string Normalized adapter name.
    ---@param resource? string Resource providing the integration.
    ---@param adapter table Adapter implementation.
    ---@param registration? integer|table Priority number or registration options.
    ---@return table adapter
    function registry:Register(key, resource, adapter, registration)
        key = normalise(key)
        assert(type(key) == 'string' and key ~= '', ('%s adapter needs a key'):format(self.name))
        assert(type(adapter) == 'table', ('%s adapter %s must be a table'):format(self.name, key))

        if type(registration) == 'number' then registration = { priority = registration } end
        registration = registration or {}

        local existing = self.entries[key]
        local entry = existing or { key = key }
        entry.resource = resource
        entry.adapter = adapter
        entry.priority = tonumber(registration.priority) or 100
        entry.available = registration.available
        entry.auto = registration.auto ~= false
        self.entries[key] = entry

        if not existing then self.order[#self.order + 1] = entry end

        self.aliases[key] = key
        if type(resource) == 'string' then self.aliases[normalise(resource)] = key end
        for i = 1, #(registration.aliases or {}) do
            local alias = normalise(registration.aliases[i])
            if type(alias) == 'string' and alias ~= '' then self.aliases[alias] = key end
        end

        table.sort(self.order, function(left, right)
            if left.priority == right.priority then return left.key < right.key end
            return left.priority < right.priority
        end)

        return adapter
    end

    function registry:IsAvailable(entry)
        if not entry then return false end
        if type(entry.available) == 'function' then
            local ok, result = pcall(entry.available, entry.resource, entry.adapter)
            return ok and result == true
        end
        return defaultAvailable(entry)
    end

    function registry:Fallback()
        local entry = self.fallback and self.entries[self.fallback] or nil
        if entry and self:IsAvailable(entry) then
            return entry.key, entry.resource, entry.adapter
        end
    end

    --- Resolves a configured or automatically detected adapter.
    ---@param preferred? string Per-call adapter override.
    ---@return string? system
    ---@return string? resource
    ---@return table? adapter
    function registry:Resolve(preferred)
        local configured = normalise(preferred or TSS.Config[self.config] or 'auto')

        if configured ~= 'auto' then
            local key = self.aliases[configured] or configured
            local entry = self.entries[key]
            if entry and self:IsAvailable(entry) then
                return entry.key, entry.resource, entry.adapter
            end

            local warningKey = tostring(configured)
            if not self.warned[warningKey] then
                local target = entry and (entry.resource or entry.key) or configured
                TSS.Warn(('Configured %s adapter is not available: %s'):format(self.name, tostring(target)))
                self.warned[warningKey] = true
            end
            return self:Fallback()
        end

        for i = 1, #self.order do
            local entry = self.order[i]
            if entry.auto and entry.key ~= self.fallback and self:IsAvailable(entry) then
                return entry.key, entry.resource, entry.adapter
            end
        end

        return self:Fallback()
    end

    --- Reports a capability declared by the selected adapter.
    ---@param feature string
    ---@param preferred? string
    ---@return boolean supported
    function registry:Supports(feature, preferred)
        local _, _, adapter = self:Resolve(preferred)
        if not adapter then return false end

        feature = tostring(feature or ''):lower()
        if type(adapter.supports) == 'function' then return adapter.supports(feature) == true end
        if type(adapter.supports) == 'table' then return adapter.supports[feature] == true end
        return type(adapter[feature]) == 'function'
    end

    function registry:List()
        local result = {}
        for i = 1, #self.order do
            local entry = self.order[i]
            result[#result + 1] = {
                key = entry.key,
                resource = entry.resource,
                priority = entry.priority,
                available = self:IsAvailable(entry),
            }
        end
        return result
    end

    registries[registryName] = registry
    return registry
end

function TSS.Adapters.Get(moduleName)
    return type(moduleName) == 'string' and registries[moduleName:lower()] or nil
end
