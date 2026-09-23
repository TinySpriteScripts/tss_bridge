-- Freemode ped animation placement editor with world-space move and heading gizmos.
TSSBridgeLabPedAnimationEditor = {}

local Creator = TSSBridgeLabPedAnimationEditor
local editor = { active = false }
local hud
-- Requesting the module also loads its shared implementation. Reading
-- TSS.Gizmo directly here is too early because bridge modules are lazy-loaded.
local Gizmo = TSSModuleLoader.GetModules({ 'Gizmo' }).Gizmo

local function vec(x, y, z) return vector3(x + 0.0, y + 0.0, z + 0.0) end
local function add(a, b) return vec(a.x + b.x, a.y + b.y, a.z + b.z) end
local function mul(a, n) return vec(a.x * n, a.y * n, a.z * n) end
local function distance(a, b)
    local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
    return math.sqrt(x * x + y * y + z * z)
end
local function trim(value, maximum)
    value = tostring(value or ''):match('^%s*(.-)%s*$')
    if #value > maximum or value:find('[%c]') then return '' end
    return value
end
local function applyIdle(ped)
    ClearPedTasksImmediately(ped)
    if editor.dict ~= '' and editor.clip ~= '' then
        FreezeEntityPosition(ped, true)
        RequestAnimDict(editor.dict)
        local expires = GetGameTimer() + 5000
        while editor.active and not HasAnimDictLoaded(editor.dict) and GetGameTimer() < expires do Wait(0) end
        if HasAnimDictLoaded(editor.dict) then TaskPlayAnim(ped, editor.dict, editor.clip, 8.0, -8.0, -1, editor.flag or 1, 0.0, false, false, false) end
    elseif editor.scenario ~= '' then
        -- A scenario must be allowed to establish its authored seated offset.
        -- Collision and gravity are disabled on editor ghosts.
        FreezeEntityPosition(ped, false)
        local c = GetEntityCoords(ped)
        TaskStartScenarioAtPosition(ped, editor.scenario, c.x, c.y, c.z, GetEntityHeading(ped), 0, false, true)
    else
        FreezeEntityPosition(ped, true)
    end
end

local function gizmoSize()
    local coords = editor.dragTransform and editor.dragTransform.coords or GetEntityCoords(editor.ped)
    return math.max(0.6, math.min(2.0, distance(GetCamCoord(editor.camera), coords) * 0.09))
end

local function applyDragTransform(transform)
    if not transform or not DoesEntityExist(editor.ped) then return end

    if transform.attached and DoesEntityExist(editor.player) then
        -- A scenario owns the ped's world transform, so direct coordinate writes
        -- are visually overwritten until the task ends. During the drag, attach
        -- the ghost to the frozen player root and update its local offset. The
        -- scenario animation keeps playing while the attachment owns placement.
        local offset = GetOffsetFromEntityGivenWorldCoords(editor.player,
            transform.coords.x, transform.coords.y, transform.coords.z)
        local relativeHeading = (transform.heading - GetEntityHeading(editor.player)) % 360.0
        AttachEntityToEntity(editor.ped, editor.player, 0,
            offset.x, offset.y, offset.z, 0.0, 0.0, relativeHeading,
            false, false, false, true, 2, true)
        return
    end

    SetEntityCoordsNoOffset(editor.ped, transform.coords.x, transform.coords.y, transform.coords.z,
        false, false, false)
    SetEntityHeading(editor.ped, transform.heading)
end

local function createPedGizmo()
    local axes = Gizmo.WorldAxes()
    return Gizmo.Create({
        mode = editor.mode,
        handles = function(mode)
            local center = editor.dragTransform and editor.dragTransform.coords or GetEntityCoords(editor.ped)
            local size = gizmoSize()
            if mode == 'rotate' then
                return { Gizmo.RingHandle('heading', center, axes.x, axes.y, size * 0.65,
                    { axis = 'z', hitRadius = 0.018, segments = 64 }) }
            end
            return {
                Gizmo.AxisHandle('move_x', center, axes.x, size, 'x', { size = 0.09, hoverSize = 0.13 }),
                Gizmo.AxisHandle('move_y', center, axes.y, size, 'y', { size = 0.09, hoverSize = 0.13 }),
                Gizmo.AxisHandle('move_z', center, axes.z, size, 'z', { size = 0.09, hoverSize = 0.13 }),
            }
        end,
        onDragStart = function(handle, mouseX, mouseY)
            local coords = GetEntityCoords(editor.ped)
            local state = { coords = coords, heading = GetEntityHeading(editor.ped), mouseX = mouseX, mouseY = mouseY }
            if handle.kind == 'axis' then
                state.linear = Gizmo.LinearDrag(handle.origin, handle.position, mouseX, mouseY, handle.distance)
                if not state.linear then return false end
            end
            editor.dragTransform = {
                coords = vec(coords.x, coords.y, coords.z),
                heading = state.heading,
                attached = editor.dict == '' and editor.scenario ~= '',
            }
            -- The attached scenario preview must remain unfrozen so its parent
            -- transform can move it. Plain animation previews stay frozen.
            FreezeEntityPosition(editor.ped, not editor.dragTransform.attached)
            applyDragTransform(editor.dragTransform)
            return state
        end,
        onDrag = function(handle, state, mouseX, mouseY, precision)
            if handle.kind == 'ring' then
                local heading = (state.heading + ((mouseX - state.mouseX) - (mouseY - state.mouseY)) * 360 * precision) % 360
                editor.dragTransform.heading = heading
                applyDragTransform(editor.dragTransform)
                return
            end
            local amount = Gizmo.LinearDisplacement(state.linear, mouseX, mouseY, precision)
            local coords = add(state.coords, mul(handle.direction, amount))
            editor.dragTransform.coords = coords
            applyDragTransform(editor.dragTransform)
        end,
        onDragEnd = function(_, _, cancelled)
            local transform = editor.dragTransform
            editor.dragTransform = nil
            if transform and DoesEntityExist(editor.ped) then
                if transform.attached then DetachEntity(editor.ped, true, true) end
                SetEntityCoordsNoOffset(editor.ped, transform.coords.x, transform.coords.y, transform.coords.z,
                    false, false, false)
                SetEntityHeading(editor.ped, transform.heading)
            end
            if not cancelled and editor.dict == '' and editor.scenario ~= '' then applyIdle(editor.ped) end
        end,
    })
end

local function spawnPed(coords, heading)
    local ped = CreatePed(4, editor.modelHash, coords.x, coords.y, coords.z, heading, false, false)
    if not ped or ped == 0 then return nil end
    SetEntityAsMissionEntity(ped, true, true)
    SetPedDefaultComponentVariation(ped)
    SetEntityAlpha(ped, 150, false)
    SetEntityCollision(ped, false, false)
    SetEntityHasGravity(ped, false)
    SetPedCanRagdoll(ped, false)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    applyIdle(ped)
    return ped
end

hud = function(message)
    local coords = editor.dragTransform and editor.dragTransform.coords or GetEntityCoords(editor.ped)
    SendNUIMessage({ action = 'pedAnimationEditor', payload = {
        visible = true, settingsOpen = editor.settingsOpen,
        title = 'Ped Animation Editor',
        pose = { dict = editor.dict, clip = editor.clip, scenario = editor.scenario, flag = editor.flag or 1 },
        output = editor.output or '', model = editor.model,
        mode = editor.gizmo and editor.gizmo:IsDragging() and 'DRAGGING' or editor.mode:upper(),
        behaviour = editor.dict ~= '' and ('Anim: ' .. editor.dict .. ' / ' .. editor.clip) or (editor.scenario ~= '' and ('Scenario: ' .. editor.scenario) or 'No idle behaviour'),
        count = #editor.entries, message = message,
        metrics = {
            { label = 'X / Y / Z', value = ('%.3f  %.3f  %.3f'):format(coords.x, coords.y, coords.z) },
            { label = 'Heading', value = ('%.2f degrees'):format(GetEntityHeading(editor.ped)) },
        },
        help = {
            'Tab Move/Rotate - Left-drag gizmo - Ctrl precision',
            'Hold RMB to look - WASD camera - Q/E down/up',
            'G commits this ped and creates the next editable ghost',
            'F opens pose settings, file save, copy, and Exit editor',
        },
    } })
end

local disabled = { 23,21,1,2,14,15,16,17,24,25,29,30,31,32,33,34,35,36,37,38,44,47,140,141,142,143,177,191,200,201,239,240,257,263,264 }
local function controls()
    for i = 1, #disabled do DisableControlAction(0, disabled[i], true) end
    DisablePlayerFiring(PlayerId(), true)
end

local function cameraUpdate()
    local rotation, coords = GetCamRot(editor.camera, 2), GetCamCoord(editor.camera)
    if IsDisabledControlPressed(0, 25) then
        rotation = vec(math.max(-89, math.min(89, rotation.x - GetDisabledControlNormal(0, 2) * 7.5)), 0, rotation.z - GetDisabledControlNormal(0, 1) * 7.5)
    end
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    local forward = vec(-math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
    local right = vec(math.cos(yaw), math.sin(yaw), 0)
    local speed = 3.0 * GetFrameTime() * (IsDisabledControlPressed(0, 21) and 3 or 1)
    if IsDisabledControlPressed(0, 32) then coords = add(coords, mul(forward, speed)) end
    if IsDisabledControlPressed(0, 33) then coords = add(coords, mul(forward, -speed)) end
    if IsDisabledControlPressed(0, 35) then coords = add(coords, mul(right, speed)) end
    if IsDisabledControlPressed(0, 34) then coords = add(coords, mul(right, -speed)) end
    if IsDisabledControlPressed(0, 38) then coords = add(coords, vec(0, 0, speed)) end
    if IsDisabledControlPressed(0, 44) then coords = add(coords, vec(0, 0, -speed)) end
    SetCamCoord(editor.camera, coords.x, coords.y, coords.z)
    SetCamRot(editor.camera, rotation.x, 0.0, rotation.z, 2)
    SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
end

local function cleanup(cancelled)
    if not editor.active then return end
    if editor.gizmo then editor.gizmo:FinishDrag(true) end
    local callback = cancelled and editor.onCancel or editor.onSave
    local entries, entities, camera, player = editor.entries, editor.entities, editor.camera, editor.player
    editor.active = false
    RenderScriptCams(false, true, 250, true, true)
    if camera and DoesCamExist(camera) then DestroyCam(camera, false) end
    ClearFocus()
    SetNuiFocus(false, false)
    for i = 1, #entities do if DoesEntityExist(entities[i]) then DeleteEntity(entities[i]) end end
    FreezeEntityPosition(player, editor.wasFrozen == true)
    SetPlayerInvincible(PlayerId(), editor.wasInvincible == true)
    SendNUIMessage({ action = 'pedAnimationEditor', payload = nil })
    editor = { active = false }
    if callback then callback(entries) end
end

local function formatPose(entry)
    local c = entry.coords
    local lines = { '{', ('    model = %q,'):format(entry.model),
        ('    coords = vector4(%.3f, %.3f, %.3f, %.3f),'):format(c.x, c.y, c.z, c.w) }
    if entry.anim then
        lines[#lines + 1] = ('    anim = { dict = %q, clip = %q, flag = %d },'):format(entry.anim.dict, entry.anim.clip, entry.anim.flag)
    elseif entry.scenario then
        lines[#lines + 1] = ('    scenario = %q,'):format(entry.scenario)
        lines[#lines + 1] = '    useEnterAnim = false,'
    end
    lines[#lines + 1] = '},'
    return table.concat(lines, '\n')
end

local function exportPoses(printToConsole)
    local rows = { '-- Ped animation placements; coords are the ped origin (no seat-height offset).', 'local placements = {' }
    for _, entry in ipairs(editor.entries) do rows[#rows + 1] = formatPose(entry) end
    rows[#rows + 1] = '}'
    editor.output = table.concat(rows, '\n')
    if printToConsole ~= false then
        print(editor.output)
        hud('Committed placements printed to F8 and ready to copy.')
    end
end

local function addPed()
    if editor.gizmo then editor.gizmo:FinishDrag(false) end
    local coords, heading = GetEntityCoords(editor.ped), GetEntityHeading(editor.ped)
    local entry = { model = editor.model, coords = { x = coords.x, y = coords.y, z = coords.z, w = heading } }
    if editor.dict ~= '' and editor.clip ~= '' then entry.anim = { dict = editor.dict, clip = editor.clip, flag = editor.flag or 1 }
    elseif editor.scenario ~= '' then entry.scenario = editor.scenario end
    if #editor.entries >= 100 then hud('100 placements committed. Save or clear them from the F settings panel.') return end
    local placedPed = editor.ped
    local nextPed = spawnPed(coords, heading)
    if not nextPed then
        hud('Unable to create the next editable ghost. This placement was not committed.')
        return
    end
    editor.entries[#editor.entries + 1] = entry
    SetEntityAlpha(placedPed, 210, false)
    editor.entities[#editor.entities + 1] = nextPed
    editor.ped = nextPed
    exportPoses(false)
    hud(('Placement %d committed. Move the new ghost to the next seat or bed.'):format(#editor.entries))
end

local function finishDrag()
    if editor.gizmo then editor.gizmo:FinishDrag(false) end
end

local function loop()
    while editor.active do
        Wait(0)
        if not editor.active then break end
        controls()
        if not editor.settingsOpen then
        cameraUpdate()
        local looking = IsDisabledControlPressed(0, 25)
        if looking then editor.ignoreCancelUntil = GetGameTimer() + 150 end
        if editor.dragTransform then
            -- Scenario tasks remember their start position and may write it back
            -- every frame. The temporary attachment makes the authored transform
            -- win before hit-testing and drawing.
            applyDragTransform(editor.dragTransform)
        end
        editor.gizmo:Tick({ enabled = not looking, cursor = not looking })
        if IsDisabledControlJustPressed(0, 37) then
            finishDrag()
            editor.mode = editor.mode == 'move' and 'rotate' or 'move'
            editor.gizmo:SetMode(editor.mode)
            hud()
        end
        if IsDisabledControlJustPressed(0, 47) then
            addPed()
        end
        if IsDisabledControlJustPressed(0, 23) then
            finishDrag(); editor.settingsOpen = true; SetNuiFocus(true, true); hud()
        end
        end
        if editor.active and GetGameTimer() > (editor.nextHud or 0) then editor.nextHud = GetGameTimer() + 100; hud() end
    end
end

function Creator.Start(options, callbacks)
    if editor.active then return false, 'The Ped Animation Editor is already active' end
    options = type(options) == 'table' and options or {}
    local model, scenario = trim(options.model, 80), trim(options.scenario, 96)
    local dict, clip = trim(options.dict, 128), trim(options.clip, 96)
    if model == '' then return false, 'Enter a ped model' end
    if (dict == '') ~= (clip == '') then return false, 'Animation dictionary and clip must both be supplied' end
    if model ~= 'mp_m_freemode_01' and model ~= 'mp_f_freemode_01' then return false, 'Choose mp_m_freemode_01 or mp_f_freemode_01' end
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return false, ('Invalid ped model %s'):format(model) end
    RequestModel(hash)
    local expires = GetGameTimer() + 7000
    while not HasModelLoaded(hash) and GetGameTimer() < expires do Wait(0) end
    if not HasModelLoaded(hash) then return false, ('Unable to load ped model %s'):format(model) end
    if dict ~= '' then
        RequestAnimDict(dict)
        local deadline = GetGameTimer() + 5000
        while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(0) end
        if not HasAnimDictLoaded(dict) or GetAnimDuration(dict, clip) <= 0 then
            SetModelAsNoLongerNeeded(hash)
            return false, 'Animation dictionary or clip could not be loaded'
        end
    end
    local player = PlayerPedId()
    local start = GetOffsetFromEntityInWorldCoords(player, 0.0, 2.0, 0.0)
    local camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local cameraCoords, cameraRot = GetGameplayCamCoord(), GetGameplayCamRot(2)
    SetCamCoord(camera, cameraCoords.x, cameraCoords.y, cameraCoords.z); SetCamRot(camera, cameraRot.x, 0, cameraRot.z, 2)
    SetCamFov(camera, GetGameplayCamFov()); RenderScriptCams(true, true, 250, true, true)
    editor = {
        active = true, flag = 1, settingsOpen = false, model = model, modelHash = hash, scenario = scenario, dict = dict, clip = clip,
        player = player, camera = camera, entries = {}, entities = {}, mode = 'move',
        wasFrozen = type(IsEntityPositionFrozen) == 'function' and IsEntityPositionFrozen(player) or false,
        wasInvincible = GetPlayerInvincible(PlayerId()), onSave = callbacks and callbacks.onSave, onCancel = callbacks and callbacks.onCancel,
    }
    editor.ped = spawnPed(start, GetEntityHeading(player))
    if not editor.ped then RenderScriptCams(false, false, 0, true, true); DestroyCam(camera, false); editor = { active = false }; return false, 'Unable to create ped' end
    editor.entities[1] = editor.ped
    editor.gizmo = createPedGizmo()
    FreezeEntityPosition(player, true); SetPlayerInvincible(PlayerId(), true); SetModelAsNoLongerNeeded(hash)
    hud()
    CreateThread(function()
        local ok, err = xpcall(loop, function(message) return debug.traceback(tostring(message), 2) end)
        if not ok then print(('^1[bridge_lab] Ped Animation Editor error: %s^7'):format(err)); if editor.active then cleanup(true) end end
    end)
    return true
end

RegisterNUICallback('pedAnimationAction', function(data, reply)
    if not editor.active or not editor.settingsOpen then reply({ ok = false }) return end
    if data.action == 'exit' then reply({ ok = true }); cleanup(true); return end
    if data.action == 'resume' then
        editor.settingsOpen = false; SetNuiFocus(false, false); hud(); reply({ ok = true }); return
    end
    if data.action == 'save' then
        if #editor.entries == 0 then
            reply({ ok = false, error = 'Press G to commit at least one placement before saving.' })
            return
        end
        reply({ ok = true })
        cleanup(false)
        return
    end
    if data.action == 'export' then exportPoses(true); reply({ ok = true }); return end
    if data.action == 'clear' then
        local editablePed = editor.ped
        for i = 1, #editor.entities do
            local ped = editor.entities[i]
            if ped ~= editablePed and DoesEntityExist(ped) then DeleteEntity(ped) end
        end
        editor.entities = { editablePed }
        editor.entries = {}
        editor.output = ''
        hud('Committed placements cleared. The current ghost is still editable.')
        reply({ ok = true })
        return
    end
    if data.action ~= 'apply' and data.action ~= 'replay' then reply({ ok = false }) return end
    local session = editor
    local dict, clip, scenario = trim(data.dict, 128), trim(data.clip, 96), trim(data.scenario, 96)
    local flag = tonumber(data.flag)
    if (dict == '') ~= (clip == '') or not flag or flag % 1 ~= 0 or flag < 0 or flag > 51 then
        reply({ ok = false, error = 'Supply both dictionary and clip, and an integer flag between 0 and 51.' }); return
    end
    if dict ~= '' then
        RequestAnimDict(dict)
        local deadline = GetGameTimer() + 5000
        while editor.active and not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(0) end
        if editor ~= session or not editor.active then reply({ ok = false }); return end
        if not HasAnimDictLoaded(dict) or GetAnimDuration(dict, clip) <= 0 then
            reply({ ok = false, error = 'Animation dictionary or clip could not be loaded.' }); return
        end
    end
    editor.dict, editor.clip, editor.scenario, editor.flag = dict, clip, scenario, flag
    applyIdle(editor.ped)
    hud('Pose applied. Resume gizmo to keep placing.')
    reply({ ok = true })
end)

local animationDictionaries

local function getAnimationDictionaries()
    if animationDictionaries then return animationDictionaries end
    animationDictionaries = {}
    if type(animList) == 'table' then
        for dictionary, clips in pairs(animList) do
            if type(dictionary) == 'string' and type(clips) == 'table' then
                animationDictionaries[#animationDictionaries + 1] = dictionary
            end
        end
        table.sort(animationDictionaries)
    end
    return animationDictionaries
end

RegisterNUICallback('pedAnimationSearch', function(data, reply)
    local query = trim(data and data.query, 128):lower()
    local dictionaries = getAnimationDictionaries()
    local matches = {}

    if query ~= '' then
        for i = 1, #dictionaries do
            local dictionary = dictionaries[i]
            if dictionary:lower():find(query, 1, true) then
                matches[#matches + 1] = dictionary
                if #matches >= 60 then break end
            end
        end
    end

    local clips = {}
    local exact = type(animList) == 'table' and animList[query] or nil
    if type(exact) == 'table' then
        for i = 1, #exact do clips[i] = exact[i] end
        table.sort(clips)
    end

    reply({ ok = true, dictionaries = matches, clips = clips, exact = type(exact) == 'table' })
end)

function Creator.IsActive() return editor.active == true end
function Creator.Stop() cleanup(true) end

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() and editor.active then editor.onCancel = nil; cleanup(true) end
end)
