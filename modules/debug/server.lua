TSSModuleLoader.Define({
    name = 'Debug',
    files = { 'modules/debug/shared.lua' },
    server = function(context)
        local public = context.CopyFunctions(TSS.DebugTools, {
            'FormatLocationTable', 'FormatLocationTables', 'FormatChairTable',
        })
        public.SetEnabled = TSS.SetDebug
        return public
    end,
})
