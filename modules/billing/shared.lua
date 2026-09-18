TSS = TSS or {}
TSS.Billing = TSS.Billing or {}

local registry = TSS.Adapters.Create('Billing', { config = 'Billing' })

function TSS.Billing.RegisterAdapter(key, resource, adapter, options)
    return registry:Register(key, resource, adapter, options)
end

function TSS.Billing.System(preferred)
    local system, resource = registry:Resolve(preferred)
    return system, resource
end

function TSS.Billing.Supports(feature, preferred)
    return registry:Supports(feature, preferred)
end

function TSS.Billing.Open(data, preferred)
    if TSS.IsServer() or type(data) ~= 'table' then return false end
    local _, resource, adapter = registry:Resolve(preferred)
    return adapter and adapter.open and adapter.open(resource, data) == true or false
end
