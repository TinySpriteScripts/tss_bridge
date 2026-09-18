TSSModuleLoader.Define({
    name = 'ProgressBar',
    dependencies = { 'UI' },
    files = {
        'modules/progressbar/shared.lua',
        'modules/progressbar/adapters/ox.lua',
        'modules/progressbar/adapters/qb.lua',
        'modules/progressbar/adapters/tss.lua',
        'modules/progressbar/adapters/native.lua',
    },
    client = function(context)
        local public = context.ProviderAPI(TSS.Progress, 'ProgressBar')
        function public.Start(data)
            return TSS.Progress.Start(context.ProviderData('ProgressBar', data), context.Caller)
        end
        function public.Stop() return TSS.Progress.Stop(context.Caller) end
        context.OnStop(public.Stop)
        return public
    end,
})
