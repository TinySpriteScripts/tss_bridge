TSSModuleLoader.Define({
    name = 'Framework',
    files = {
        'modules/framework/shared.lua',
        'modules/framework/adapters/qbox.lua',
        'modules/framework/adapters/qb.lua',
        'modules/framework/adapters/esx.lua',
    },
    client = function(context)
        return context.CopyFunctions(TSS.Framework, {
            'System', 'Object', 'Player', 'PlayerData', 'Jobs', 'Gangs', 'Supports',
        })
    end,
})
