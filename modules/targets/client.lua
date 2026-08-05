TSSModuleLoader.Define({
    name = 'Targets',
    files = { 'modules/targets/shared.lua' },
    client = function(context)
        local entities = {}
        local models = {}
        local zones = {}
        ---@type TSSTargetsModule
        local public = {
            System = TSS.Target.System,
            Supports = TSS.Target.Supports,
        }

        function public.Entity(entity, options, distance)
            entities[entity] = true
            return TSS.Target.Entity(entity, options, distance)
        end

        function public.Model(modelList, options, distance)
            models[#models + 1] = modelList
            return TSS.Target.Model(modelList, options, distance)
        end

        function public.Box(data, options, distance)
            local zone = TSS.Target.Box(data, options, distance)
            if zone then zones[zone] = true end
            return zone
        end

        function public.Circle(data, options, distance)
            local zone = TSS.Target.Circle(data, options, distance)
            if zone then zones[zone] = true end
            return zone
        end

        function public.RemoveEntity(entity)
            entities[entity] = nil
            return TSS.Target.RemoveEntity(entity)
        end

        function public.RemoveModel(modelList)
            for i = #models, 1, -1 do
                if models[i] == modelList then table.remove(models, i) end
            end
            return TSS.Target.RemoveModel(modelList)
        end

        function public.RemoveZone(zone)
            zones[zone] = nil
            return TSS.Target.RemoveZone(zone)
        end

        function public.Clear()
            for entity in pairs(entities) do
                TSS.Target.RemoveEntity(entity)
                entities[entity] = nil
            end

            for i = 1, #models do TSS.Target.RemoveModel(models[i]) end
            models = {}

            for zone in pairs(zones) do
                TSS.Target.RemoveZone(zone)
                zones[zone] = nil
            end
        end

        context.OnStop(public.Clear)
        return public
    end,
})
