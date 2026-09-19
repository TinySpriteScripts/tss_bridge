TSSModuleLoader.Define({
    name = 'Peds',
    files = { 'modules/peds/shared.lua' },
    client = function(context)
        local owned = {}
        ---@type TSSPedsModule
        local public = context.CopyFunctions(TSS.Peds, { 'LookAt' })

        function public.Create(data, coords, options)
            local ped = TSS.CreatePed(data, coords, options)
            if ped then owned[ped] = true end
            return ped
        end

        function public.CreateScenario(data, coords, scenario, options)
            options = options or {}
            options.scenario = options.scenario or scenario
            return public.Create(data, coords, options)
        end

        function public.CreateAnimated(data, coords, anim, options)
            options = options or {}
            options.anim = options.anim or anim
            return public.Create(data, coords, options)
        end

        function public.Delete(ped)
            owned[ped] = nil
            return TSS.DeletePed(ped)
        end

        function public.Clear()
            for ped in pairs(owned) do
                TSS.DeletePed(ped)
                owned[ped] = nil
            end
        end

        context.OnStop(public.Clear)
        return public
    end,
})
