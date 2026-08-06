-- Public fuel API. Fuel-resource calls live in adapters.
TSS = TSS or {}
TSS.Fuel = TSS.Fuel or {}

local registry = TSS.Adapters.Create('Fuel', { config = 'Fuel', fallback = 'native' })

function TSS.Fuel.RegisterAdapter(key, resource, adapter, options)
    return registry:Register(key, resource, adapter, options)
end

--- Detects the selected fuel adapter.
---@param preferred? string
---@return string system
---@return string? resource
function TSS.Fuel.System(preferred)
    local system, resource = registry:Resolve(preferred)
    return system, resource
end

--- Reports whether the fuel module supports a feature.
---@param feature 'get'|'set'|string
---@return boolean supported
function TSS.Fuel.Supports(feature)
    return registry:Supports(feature)
end

--- Reads a vehicle's fuel level through the selected adapter.
---@param vehicle TSSEntity
---@return number fuel
function TSS.Fuel.Get(vehicle)
    if type(vehicle) ~= 'number' or vehicle == 0 or not DoesEntityExist(vehicle) then return 0 end
    local _, resource, adapter = registry:Resolve()
    if not adapter or not adapter.get then return 0 end
    return tonumber(adapter.get(resource, vehicle)) or 0
end

--- Sets a vehicle's fuel level, clamped from 0 to 100.
---@param vehicle TSSEntity
---@param amount number
---@return boolean success
function TSS.Fuel.Set(vehicle, amount)
    if type(vehicle) ~= 'number' or vehicle == 0 or not DoesEntityExist(vehicle) then return false end
    amount = math.max(0.0, math.min(100.0, tonumber(amount) or 0.0))
    local _, resource, adapter = registry:Resolve()
    return adapter ~= nil and adapter.set ~= nil and adapter.set(resource, vehicle, amount) == true or false
end
