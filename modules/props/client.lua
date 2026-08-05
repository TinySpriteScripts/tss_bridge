TSSModuleLoader.Define({
    name = 'Props',
    files = { 'modules/props/shared.lua' },
    client = function(context)
        local owned = {}
        ---@type TSSPropsModule
        local public = {}

        function public.Create(data, coords, options)
            local prop = TSS.CreateProp(data, coords, options)
            if prop then owned[prop] = true end
            return prop
        end

        function public.Delete(prop)
            owned[prop] = nil
            return TSS.DeleteProp(prop)
        end

        function public.Clear()
            for prop in pairs(owned) do
                TSS.DeleteProp(prop)
                owned[prop] = nil
            end
        end

        context.OnStop(public.Clear)
        return public
    end,
})
