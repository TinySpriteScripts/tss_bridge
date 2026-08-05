TSSModuleLoader.Define({
    name = 'World',
    dependencies = { 'Peds', 'Props' },
    files = { 'modules/world/shared.lua' },
    client = function(context)
        local controllers = {}
        ---@type TSSWorldModule
        local public = context.CopyFunctions(TSS.World, { 'Face' })

        function public.ResourceName()
            return context.Caller
        end

        function public.CreateDistanceProp(data, options)
            local controller = TSS.World.CreateDistanceProp(data, options)
            if controller then controllers[#controllers + 1] = controller end
            return controller
        end

        function public.CreateDistancePed(data, coords, options)
            local controller = TSS.World.CreateDistancePed(data, coords, options)
            if controller then controllers[#controllers + 1] = controller end
            return controller
        end

        context.OnStop(function()
            for i = 1, #controllers do controllers[i].remove() end
            controllers = {}
        end)
        return public
    end,
})
