TSSModuleLoader.Define({
    name = 'Capabilities',
    files = { 'modules/capabilities/shared.lua' },
    server = function(context)
        return context.CopyFunctions(TSS.Capabilities, {
            'Resource', 'Module', 'Modules', 'LoadedModules', 'Config', 'Resources', 'Snapshot',
        })
    end,
})
