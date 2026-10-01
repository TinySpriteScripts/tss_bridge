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
            local request = context.ProviderData('ProgressBar', data)
            if context.Options.Debug == true then
                request.duration = context.Options.DebugProgressDuration or 1000
                request.time = request.duration
            end
            return TSS.Progress.Start(request, context.Caller)
        end
        function public.Stop() return TSS.Progress.Stop(context.Caller) end
        context.OnStop(public.Stop)
        return public
    end,
})
