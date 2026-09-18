TSSModuleLoader.Define({
    name = 'Banking',
    dependencies = { 'Framework' },
    files = {
        'modules/banking/shared.lua',
        'modules/banking/adapters/players.lua',
        'modules/banking/adapters/renewed.lua',
        'modules/banking/adapters/fd.lua',
        'modules/banking/adapters/okok.lua',
        'modules/banking/adapters/tgiann.lua',
        'modules/banking/adapters/qb.lua',
        'modules/banking/adapters/esx.lua',
        'modules/banking/adapters/wasabi.lua',
    },
    client = function(context)
        return context.CopyFunctions(TSS.Banking, { 'System', 'Supports', 'GetAccount' })
    end,
})
