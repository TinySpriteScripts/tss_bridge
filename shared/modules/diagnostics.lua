TSS = TSS or {}
TSS.Diagnostics = TSS.Diagnostics or {}

local function joined(values)
    return #values > 0 and table.concat(values, ', ') or '(none)'
end

function TSS.Diagnostics.Lines()
    local snapshot = TSS.Capabilities.Snapshot()
    local lines = {
        ('TSS Bridge diagnostics (%s)'):format(snapshot.realm),
        ('Available modules: %s'):format(joined(snapshot.available)),
        ('Loaded modules: %s'):format(joined(snapshot.loaded)),
    }

    for name, value in pairs(snapshot.config) do
        lines[#lines + 1] = ('Config %-12s %s'):format(name .. ':', tostring(value))
    end

    local started = {}
    for label, data in pairs(snapshot.resources) do
        if data.started then started[#started + 1] = ('%s=%s'):format(label, data.resource) end
    end
    table.sort(started)
    lines[#lines + 1] = ('Started adapters: %s'):format(joined(started))

    if TSS.IsServer() then
        local requests = TSSModuleLoader.RequestedBy()
        for resource, modules in pairs(requests) do
            lines[#lines + 1] = ('Consumer %s: %s'):format(resource, joined(modules))
        end
    end
    return lines
end

function TSS.Diagnostics.Print()
    local lines = TSS.Diagnostics.Lines()
    for i = 1, #lines do print(('^5[tss_bridge]^7 %s'):format(lines[i])) end
    return lines
end

if TSS.IsServer() then
    RegisterCommand('tssbridge', function(source)
        if source ~= 0 and not IsPlayerAceAllowed(source, 'tss_bridge.diagnostics') then
            return
        end
        TSS.Diagnostics.Print()
    end, false)
end
