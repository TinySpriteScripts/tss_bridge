TSSModuleLoader.Define({
    name = 'Framework',
    files = { 'modules/framework/shared.lua' },
    client = function(context)
        return context.CopyFunctions(TSS.Framework, {
            'System', 'Object', 'Player', 'PlayerData', 'Jobs', 'Gangs', 'Supports',
        })
    end,
})
