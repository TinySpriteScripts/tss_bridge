TSSModuleLoader.Define({
    name = 'Diagnostics',
    dependencies = { 'Capabilities' },
    files = { 'modules/diagnostics/shared.lua' },
    server = function(context)
        return context.CopyFunctions(TSS.Diagnostics, { 'Lines', 'Print' })
    end,
})

TSSModuleLoader.Ensure('Diagnostics')
