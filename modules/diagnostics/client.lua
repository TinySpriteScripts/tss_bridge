TSSModuleLoader.Define({
    name = 'Diagnostics',
    dependencies = { 'Capabilities' },
    files = { 'modules/diagnostics/shared.lua' },
    client = function(context)
        return context.CopyFunctions(TSS.Diagnostics, { 'Lines', 'Print' })
    end,
})
