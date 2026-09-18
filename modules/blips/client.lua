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

        --- Reports whether this consumer's blip still exists.
        function public.Exists(blip)
            return blip ~= nil and owned[blip] == true and DoesBlipExist(blip)
        end

        --- Updates supplied options without replacing the blip handle.
        function public.Update(blip, data)
            if not public.Exists(blip) then return false end
            return TSS.UpdateBlip(blip, data)
        end

        --- Returns coordinates for a blip owned by this consumer.
        function public.Coords(blip)
            if public.Exists(blip) then return GetBlipCoords(blip) end
        end

        --- Returns the colour ID for a blip owned by this consumer.
        function public.Colour(blip)
            if public.Exists(blip) then return GetBlipColour(blip) end
        end

        function public.Remove(blip)
            if blip == nil then return end
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
