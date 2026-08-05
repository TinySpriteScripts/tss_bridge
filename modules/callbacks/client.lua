TSSModuleLoader.Define({
    name = 'Callbacks',
    dependencies = { 'Locale' },
    files = { 'modules/callbacks/shared.lua' },
    client = function(context)
        ---@type TSSCallbacksClientModule
        local public = {}

        function public.Register(name, handler)
            return TSS.Callbacks.Register(context.Caller, name, handler)
        end

        function public.Unregister(name)
            return TSS.Callbacks.Unregister(context.Caller, name)
        end

        function public.Await(name, timeout, ...)
            return TSS.Callbacks.Await(context.Caller, name, timeout, ...)
        end

        function public.Trigger(name, callback, ...)
            if not TSS.IsCallable(callback) then return false end
            local args = { n = select('#', ...), ... }
            CreateThread(function()
                local result = table.pack(public.Await(name, nil, table.unpack(args, 1, args.n)))
                callback(table.unpack(result, 1, result.n))
            end)
            return true
        end

        context.OnStop(function() TSS.Callbacks.Clear(context.Caller) end)
        return public
    end,
})
