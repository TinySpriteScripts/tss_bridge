TSSModuleLoader.Define({
    name = 'Targets',
    dependencies = { 'World' },
    files = {
        'modules/targets/shared.lua',
        'modules/targets/adapters/ox.lua',
        'modules/targets/adapters/qb.lua',
        'modules/targets/adapters/tgiann.lua',
        'modules/targets/adapters/bt.lua',
    },
    client = function(context)
        local target = TSS.Target.CreateAPI(context.Preference('Target'))
        local groups = {}
        ---@type TSSTargetsModule
        local public = context.CopyFunctions(target, {
            'System', 'Supports', 'Entity', 'Model', 'Box', 'Circle',
            'RemoveEntity', 'RemoveModel', 'RemoveZone',
        })

        local function removeGroup(name)
            local group = groups[name]
            if not group then return end

            if group.zone then public.RemoveZone(group.zone) end
            if group.models then public.RemoveModel(group.models) end

            for i = 1, #group.controllers do
                group.controllers[i].remove()
            end

            groups[name] = nil
        end

        local function namedOptions(name, options)
            if type(options) ~= 'table' then return options end

            local source = options
            if #source == 0 and (source.label or source.event or source.action or source.onSelect) then
                source = { source }
            end

            local result = {}
            for i = 1, #source do
                result[i] = {}
                for key, value in pairs(source[i]) do result[i][key] = value end
                result[i].name = result[i].name or ('%s_%d'):format(name, i)
            end
            return result
        end

        --- Creates a named target together with distance-spawned props and peds.
        --- Calling this again with the same name replaces the previous group.
        function public.CreateZoneAndProps(name, coords, radius, length, width, heading, minZ, maxZ,
            model1, model2, kind, options, props, peds, debug)
            assert(type(name) == 'string' and name ~= '', 'CreateZoneAndProps requires a name')

            removeGroup(name)
            options = namedOptions(name, options)

            local group = { controllers = {} }
            groups[name] = group
            local hasTargetOptions = type(options) == 'table' and #options > 0

            if not hasTargetOptions then
                -- ox_target requires a non-empty array. Keep processing the
                -- group's props and peds when a disabled feature returns {}.
            elseif kind == 'circle' then
                group.zone = public.Circle({
                    name = name,
                    coords = coords,
                    radius = radius,
                    debug = debug,
                }, options, 2.0)
            elseif kind == 'model' then
                group.models = {}
                if model1 then group.models[#group.models + 1] = model1 end
                if model2 then group.models[#group.models + 1] = model2 end

                if #group.models > 0 then
                    public.Model(group.models, options, 2.0)
                end
            else
                group.zone = public.Box({
                    name = name,
                    coords = coords,
                    length = length,
                    width = width,
                    heading = heading,
                    minZ = minZ,
                    maxZ = maxZ,
                    debug = debug,
                }, options, 2.0)
            end

            for _, prop in pairs(props or {}) do
                local controller = TSS.World.CreateDistanceProp({
                    model = prop.model or prop.prop,
                    coords = prop.coords,
                    heading = prop.heading,
                    freeze = prop.freeze,
                    collision = prop.collision,
                    range = prop.range,
                    despawnRange = prop.despawnRange,
                }, prop)
                if controller then group.controllers[#group.controllers + 1] = controller end
            end

            for _, ped in pairs(peds or {}) do
                local freeze = ped.freeze
                local collision = ped.collision
                if freeze == nil then freeze = true end
                if collision == nil then collision = false end

                local controller = TSS.World.CreateDistancePed({
                    model = ped.model or 'ig_bankman',
                    coords = ped.coords,
                    scenario = ped.scenario or (not ped.anim and 'WORLD_HUMAN_STAND_IMPATIENT'),
                    anim = ped.anim,
                    heading = ped.heading,
                    freeze = freeze,
                    collision = collision,
                    range = ped.range,
                    despawnRange = ped.despawnRange,
                }, ped.coords, ped)
                if controller then group.controllers[#group.controllers + 1] = controller end
            end

            return group.zone or group.models
        end

        function public.RemoveZoneAndProps(name)
            removeGroup(name)
        end

        function public.Clear()
            local names = {}
            for name in pairs(groups) do names[#names + 1] = name end
            for i = 1, #names do removeGroup(names[i]) end

            target.Clear()
        end

        context.OnStop(public.Clear)
        return public
    end,
})
