TSSModuleLoader.Define({
    name = 'Gizmo',
    files = { 'modules/gizmo/shared.lua' },
    client = function(context)
        local controllers = {}
        local session
        local controls = { 1, 2, 14, 15, 16, 17, 21, 24, 25, 30, 31, 32, 33, 34, 35, 36, 37, 38, 44,
            140, 141, 142, 143, 177, 191, 200, 201, 239, 240, 257, 263, 264 }

        local function create(options)
            local controller = TSS.Gizmo.Create(options)
            controllers[#controllers + 1] = controller
            return controller
        end

        local function snapshot(current)
            return {
                entity = current.entity,
                coords = { x = current.coords.x, y = current.coords.y, z = current.coords.z },
                rotation = { x = current.rotation.x, y = current.rotation.y, z = current.rotation.z },
                heading = current.rotation.z,
                mode = current.mode,
            }
        end

        local function finishSession(cancelled)
            local current = session
            if not current then return false end
            session = nil
            current.active = false
            current.gizmo:FinishDrag(true)

            if current.camera and DoesCamExist(current.camera) then
                RenderScriptCams(false, true, 250, true, true)
                DestroyCam(current.camera, false)
                ClearFocus()
            end
            if current.entity and DoesEntityExist(current.entity) then
                if cancelled and current.restoreOnCancel then
                    local coords, rotation = current.original.coords, current.original.rotation
                    SetEntityCoordsNoOffset(current.entity, coords.x, coords.y, coords.z, false, false, false)
                    SetEntityRotation(current.entity, rotation.x, rotation.y, rotation.z, 2, true)
                end
                FreezeEntityPosition(current.entity, current.wasFrozen == true)
            end

            local result = cancelled and nil or snapshot(current)
            if current.callback then current.callback(result, cancelled == true) end
            return true
        end

        local function updateCamera(current)
            local rotation, coords = GetCamRot(current.camera, 2), GetCamCoord(current.camera)
            if IsDisabledControlPressed(0, 25) then
                rotation = TSS.Gizmo.Vector(
                    math.max(-89.0, math.min(89.0, rotation.x - GetDisabledControlNormal(0, 2) * 7.5)),
                    0.0, rotation.z - GetDisabledControlNormal(0, 1) * 7.5)
            end
            if IsDisabledControlJustPressed(0, 15) then current.speed = math.min(40.0, current.speed * 1.35) end
            if IsDisabledControlJustPressed(0, 14) then current.speed = math.max(0.25, current.speed / 1.35) end
            local forward, right = TSS.Gizmo.CameraBasis(rotation)
            local speed = current.speed * math.max(GetFrameTime(), 0.001)
            if IsDisabledControlPressed(0, 21) then speed = speed * 3.0 end
            if IsDisabledControlPressed(0, 36) then speed = speed * 0.25 end
            if IsDisabledControlPressed(0, 32) then coords = TSS.Gizmo.Add(coords, TSS.Gizmo.Multiply(forward, speed)) end
            if IsDisabledControlPressed(0, 33) then coords = TSS.Gizmo.Add(coords, TSS.Gizmo.Multiply(forward, -speed)) end
            if IsDisabledControlPressed(0, 35) then coords = TSS.Gizmo.Add(coords, TSS.Gizmo.Multiply(right, speed)) end
            if IsDisabledControlPressed(0, 34) then coords = TSS.Gizmo.Add(coords, TSS.Gizmo.Multiply(right, -speed)) end
            if IsDisabledControlPressed(0, 38) then coords = TSS.Gizmo.Add(coords, TSS.Gizmo.Vector(0, 0, speed)) end
            if IsDisabledControlPressed(0, 44) then coords = TSS.Gizmo.Add(coords, TSS.Gizmo.Vector(0, 0, -speed)) end
            SetCamCoord(current.camera, coords.x, coords.y, coords.z)
            SetCamRot(current.camera, rotation.x, 0.0, rotation.z, 2)
            SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
        end

        local function start(options, callback)
            if session then return false, 'This resource already has an active gizmo' end
            options = type(options) == 'table' and options or {}
            local entity = tonumber(options.entity)
            if entity and (entity == 0 or not DoesEntityExist(entity)) then return false, 'Invalid gizmo entity' end
            local suppliedCoords = options.coords
            if not entity and type(suppliedCoords) ~= 'table' and type(suppliedCoords) ~= 'vector3' then
                return false, 'Gizmo.Start needs an entity or coords'
            end

            local entityCoords = entity and GetEntityCoords(entity) or suppliedCoords
            local entityRotation = entity and GetEntityRotation(entity, 2) or (options.rotation or {})
            local current = {
                active = true,
                entity = entity,
                coords = TSS.Gizmo.Vector(entityCoords.x, entityCoords.y, entityCoords.z),
                rotation = { x = tonumber(entityRotation.x) or 0.0, y = tonumber(entityRotation.y) or 0.0,
                    z = tonumber(entityRotation.z or options.heading) or 0.0 },
                mode = options.mode == 'rotate' and 'rotate' or 'move',
                modes = options.modes or { 'move', 'rotate' },
                space = options.space == 'local' and 'local' or 'world',
                rotationAxes = options.rotationAxes or (options.headingOnly and { 'z' } or { 'x', 'y', 'z' }),
                speed = tonumber(options.cameraSpeed) or 3.0,
                restoreOnCancel = options.restoreOnCancel ~= false,
                callback = callback,
                onChange = options.onChange,
            }
            current.original = {
                coords = TSS.Gizmo.Copy(current.coords),
                rotation = { x = current.rotation.x, y = current.rotation.y, z = current.rotation.z },
            }

            local function apply()
                if current.entity and DoesEntityExist(current.entity) then
                    SetEntityCoordsNoOffset(current.entity, current.coords.x, current.coords.y, current.coords.z,
                        false, false, false)
                    SetEntityRotation(current.entity, current.rotation.x, current.rotation.y, current.rotation.z, 2, true)
                end
                if current.onChange then current.onChange(snapshot(current)) end
            end

            local function axes()
                return current.space == 'local' and current.entity and TSS.Gizmo.EntityAxes(current.entity)
                    or TSS.Gizmo.WorldAxes()
            end

            local function size()
                if tonumber(options.size) then return tonumber(options.size) end
                local cameraCoords = current.camera and GetCamCoord(current.camera) or GetGameplayCamCoord()
                return math.max(0.5, math.min(2.0,
                    TSS.Gizmo.Magnitude(TSS.Gizmo.Subtract(cameraCoords, current.coords)) * 0.08))
            end

            current.gizmo = TSS.Gizmo.Create({
                mode = current.mode,
                handles = function(mode)
                    local center, basis, length = current.coords, axes(), size()
                    local handles = {}
                    if mode == 'rotate' then
                        for i = 1, #current.rotationAxes do
                            local axis = current.rotationAxes[i]
                            local first, second = TSS.Gizmo.RingBasis(axis, basis)
                            handles[#handles + 1] = TSS.Gizmo.RingHandle('rotate_' .. axis, center,
                                first, second, length * 0.82, { axis = axis })
                        end
                    else
                        for _, axis in ipairs({ 'x', 'y', 'z' }) do
                            handles[#handles + 1] = TSS.Gizmo.AxisHandle('move_' .. axis, center,
                                basis[axis], length, axis)
                        end
                    end
                    return handles
                end,
                onDragStart = function(handle, mouseX, mouseY)
                    local state = {
                        coords = TSS.Gizmo.Copy(current.coords),
                        rotation = { x = current.rotation.x, y = current.rotation.y, z = current.rotation.z },
                        mouseX = mouseX, mouseY = mouseY,
                    }
                    if handle.kind == 'axis' then
                        state.linear = TSS.Gizmo.LinearDrag(handle.origin, handle.position, mouseX, mouseY, handle.distance)
                        if not state.linear then return false end
                    end
                    return state
                end,
                onDrag = function(handle, state, mouseX, mouseY, precision)
                    if handle.kind == 'axis' then
                        local amount = TSS.Gizmo.LinearDisplacement(state.linear, mouseX, mouseY, precision)
                        current.coords = TSS.Gizmo.Add(state.coords, TSS.Gizmo.Multiply(handle.direction, amount))
                    else
                        local movement = (mouseX - state.mouseX) - (mouseY - state.mouseY)
                        current.rotation[handle.axis] = (state.rotation[handle.axis] + movement * 360.0 * precision) % 360.0
                    end
                    apply()
                end,
            })

            if entity then
                current.wasFrozen = type(IsEntityPositionFrozen) == 'function' and IsEntityPositionFrozen(entity) or false
                if options.freeze ~= false then FreezeEntityPosition(entity, true) end
            end
            if options.camera ~= false then
                local camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
                local cameraCoords, cameraRotation = GetGameplayCamCoord(), GetGameplayCamRot(2)
                SetCamCoord(camera, cameraCoords.x, cameraCoords.y, cameraCoords.z)
                SetCamRot(camera, cameraRotation.x, 0.0, cameraRotation.z, 2)
                SetCamFov(camera, GetGameplayCamFov())
                RenderScriptCams(true, true, 250, true, true)
                current.camera = camera
            end
            session = current

            CreateThread(function()
                while session == current and current.active do
                    Wait(0)
                    for i = 1, #controls do DisableControlAction(0, controls[i], true) end
                    DisablePlayerFiring(PlayerId(), true)
                    if current.camera then updateCamera(current) end
                    local looking = IsDisabledControlPressed(0, 25)
                    if looking then current.ignoreCancelUntil = GetGameTimer() + 150 end
                    current.gizmo:Tick({ enabled = not looking, cursor = not looking })
                    if IsDisabledControlJustPressed(0, 37) and #current.modes > 1 then
                        local index = 1
                        for i = 1, #current.modes do if current.modes[i] == current.mode then index = i break end end
                        current.mode = current.modes[(index % #current.modes) + 1]
                        current.gizmo:SetMode(current.mode)
                    end
                    if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 201) then
                        finishSession(false)
                    elseif not looking and IsDisabledControlJustPressed(0, 177)
                        and GetGameTimer() > (current.ignoreCancelUntil or 0) then
                        finishSession(true)
                    end
                end
            end)
            return true
        end

        local function stopAll(cancelled)
            if session then finishSession(cancelled ~= false) end
            for i = 1, #controllers do controllers[i]:FinishDrag(cancelled == true) end
            controllers = {}
        end

        context.OnStop(function() stopAll(true) end)

        return {
            Create = create,
            Start = start,
            Finish = function() return finishSession(false) end,
            Stop = function(cancelled) return finishSession(cancelled ~= false) end,
            IsActive = function() return session ~= nil end,
            GetState = function() return session and snapshot(session) or nil end,
            StopAll = stopAll,
            LinearDrag = TSS.Gizmo.LinearDrag,
            LinearDisplacement = TSS.Gizmo.LinearDisplacement,
            WorldAxes = TSS.Gizmo.WorldAxes,
            EntityAxes = TSS.Gizmo.EntityAxes,
            RingBasis = TSS.Gizmo.RingBasis,
            AxisHandle = TSS.Gizmo.AxisHandle,
            PointHandle = TSS.Gizmo.PointHandle,
            RingHandle = TSS.Gizmo.RingHandle,
        }
    end,
})
