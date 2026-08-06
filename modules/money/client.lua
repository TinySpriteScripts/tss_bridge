TSSModuleLoader.Define({
    name = 'Money',
    dependencies = { 'Framework' },
    files = {
        'modules/money/shared.lua',
        'modules/money/adapters/qbox.lua',
        'modules/money/adapters/qb.lua',
        'modules/money/adapters/esx.lua',
    },
    client = function(context)
        return context.CopyFunctions(TSS.Money, { 'Balance', 'Has' })
    end,
})
