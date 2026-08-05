TSSModuleLoader.Define({
    name = 'Fuel',
    files = { 'modules/fuel/shared.lua' },
    client = function(context)
        return context.CopyFunctions(TSS.Fuel, { 'System', 'Supports', 'Get', 'Set' })
    end,
})
