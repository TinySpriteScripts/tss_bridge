TSSModuleLoader.Define({
    name = 'Billing',
    files = {
        'modules/billing/shared.lua',
        'modules/billing/adapters/jim.lua',
        'modules/billing/adapters/tss.lua',
        'modules/billing/adapters/okok.lua',
        'modules/billing/adapters/tgg.lua',
        'modules/billing/adapters/codem.lua',
    },
    client = function(context)
        return context.CopyFunctions(TSS.Billing, { 'System', 'Supports', 'Open' })
    end,
})
