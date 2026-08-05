TSSModuleLoader.Define({
    name = 'Blips',
    files = { 'modules/blips/shared.lua' },
    client = function(context)
        local owned = {}
        ---@type TSSBlipsModule
        local public = {}

        function public.Create(data)
            local blip = TSS.CreateBlip(data)
            if blip then owned[blip] = true end
            return blip
        end

        public.CreateEntity = public.Create

        function public.Remove(blip)
            owned[blip] = nil
            return TSS.RemoveBlip(blip)
        end

        function public.Clear()
            for blip in pairs(owned) do
                TSS.RemoveBlip(blip)
                owned[blip] = nil
            end
        end

        context.OnStop(public.Clear)
        return public
    end,
})
