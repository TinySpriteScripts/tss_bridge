TSSModuleLoader.Define({
    name = 'Fuel',
    files = {
        'modules/fuel/shared.lua',
        'modules/fuel/adapters/ox.lua',
        'modules/fuel/adapters/ps.lua',
        'modules/fuel/adapters/cdn.lua',
        'modules/fuel/adapters/legacy.lua',
        'modules/fuel/adapters/native.lua',
    },
    client = function(context)
        return context.CopyFunctions(TSS.Fuel, { 'System', 'Supports', 'Get', 'Set' })
    end,
})
