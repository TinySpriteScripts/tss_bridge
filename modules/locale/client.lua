TSSModuleLoader.Define({
    name = 'Locale',
    files = { 'shared/locales/en.lua', 'modules/locale/shared.lua' },
    client = function(context)
        return context.CopyFunctions(TSS.Locale, { 'Language', 'Translate', 'Exists', 'T' })
    end,
})
