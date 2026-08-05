TSSModuleLoader.Define({
    name = 'Framework',
    files = { 'modules/framework/shared.lua' },
    server = function(context)
        return context.CopyFunctions(TSS.Framework, {
            'System', 'Object', 'Player', 'PlayerData', 'Jobs', 'Gangs', 'Supports',
        })
    end,
})
