-- Multi-ped placement editor with world-space move and heading gizmos.
TSSBridgeLabPedSpawner = {}

local Creator = TSSBridgeLabPedSpawner
local editor = { active = false }
local hud

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
local function project(point)
    local visible, x, y = GetScreenCoordFromWorldCoord(point.x, point.y, point.z)
    return visible, x, y
end
local function screenDistance(ax, ay, bx, by) return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2) end

local axes = {
    { component = 'x', direction = vec(1, 0, 0), color = { 255, 65, 65 } },
    { component = 'y', direction = vec(0, 1, 0), color = { 65, 220, 105 } },
    { component = 'z', direction = vec(0, 0, 1), color = { 65, 135, 255 } },
}

local function gizmoSize()
    return math.max(0.6, math.min(2.0, distance(GetCamCoord(editor.camera), GetEntityCoords(editor.ped)) * 0.09))
end

local function drawGizmo(hovered)
    local center, size = GetEntityCoords(editor.ped), gizmoSize()
    if editor.mode == 'rotate' then
        local previous
        for i = 0, 64 do
            local angle = math.pi * 2 * (i / 64)
            local point = add(center, vec(math.cos(angle) * size * 0.65, math.sin(angle) * size * 0.65, 0.05))
            if previous then DrawLine(previous.x, previous.y, previous.z, point.x, point.y, point.z, 255, 190, 40, hovered and 255 or 210) end
            previous = point
        end
        return
    end
    for i = 1, #axes do
        local axis = axes[i]
        local endpoint = add(center, mul(axis.direction, size))
        DrawLine(center.x, center.y, center.z, endpoint.x, endpoint.y, endpoint.z, axis.color[1], axis.color[2], axis.color[3], 250)
        DrawMarker(28, endpoint.x, endpoint.y, endpoint.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
            hovered == axis and 0.13 or 0.09, hovered == axis and 0.13 or 0.09, hovered == axis and 0.13 or 0.09,
            axis.color[1], axis.color[2], axis.color[3], 245, false, false, 2, false, nil, nil, false)
    end
end

local function findHandle(mouseX, mouseY)
    local center, size = GetEntityCoords(editor.ped), gizmoSize()
    if editor.mode == 'rotate' then
        local best = 0.018
        for i = 0, 63 do
            local angle = math.pi * 2 * (i / 64)
            local point = add(center, vec(math.cos(angle) * size * 0.65, math.sin(angle) * size * 0.65, 0.05))
            local visible, x, y = project(point)
            if visible then best = math.min(best, screenDistance(mouseX, mouseY, x, y)) end
        end
        return best < 0.018 and { component = 'heading' } or nil
    end
    local closest, best = nil, 0.035
    for i = 1, #axes do
        local endpoint = add(center, mul(axes[i].direction, size))
        local visible, x, y = project(endpoint)
        if visible then
            local d = screenDistance(mouseX, mouseY, x, y)
            if d < best then closest, best = axes[i], d end
        end
    end
    return closest
end

local function startDrag(handle, mouseX, mouseY)
    if not handle then return end
    local coords = GetEntityCoords(editor.ped)
    editor.drag = { handle = handle, mouseX = mouseX, mouseY = mouseY, coords = coords, heading = GetEntityHeading(editor.ped) }
    if handle.component ~= 'heading' then
        local endpoint = add(coords, mul(handle.direction, gizmoSize()))
        local cv, cx, cy = project(coords)
        local ev, ex, ey = project(endpoint)
        if not cv or not ev then editor.drag = nil return end
        local dx, dy = ex - cx, ey - cy
        local length = math.sqrt(dx * dx + dy * dy)
        if length < 0.002 then editor.drag = nil return end
        editor.drag.screenX, editor.drag.screenY, editor.drag.screenLength = dx / length, dy / length, length
    end
end

local function updateDrag(mouseX, mouseY)
    local drag = editor.drag
    if not drag then return end
    local precision = IsDisabledControlPressed(0, 36) and 0.2 or 1.0
    if drag.handle.component == 'heading' then
        SetEntityHeading(editor.ped, (drag.heading + ((mouseX - drag.mouseX) - (mouseY - drag.mouseY)) * 360 * precision) % 360)
        return
    end
    local movement = ((mouseX - drag.mouseX) * drag.screenX) + ((mouseY - drag.mouseY) * drag.screenY)
    local amount = movement / drag.screenLength * gizmoSize() * precision
    local nextCoords = add(drag.coords, mul(drag.handle.direction, amount))
    SetEntityCoordsNoOffset(editor.ped, nextCoords.x, nextCoords.y, nextCoords.z, false, false, false)
end

local function applyIdle(ped)
    ClearPedTasksImmediately(ped)
    if editor.dict ~= '' and editor.clip ~= '' then
        RequestAnimDict(editor.dict)
        local expires = GetGameTimer() + 5000
        while editor.active and not HasAnimDictLoaded(editor.dict) and GetGameTimer() < expires do Wait(0) end
        if HasAnimDictLoaded(editor.dict) then TaskPlayAnim(ped, editor.dict, editor.clip, 8.0, -8.0, -1, editor.flag or 1, 0.0, false, false, false) end
    elseif editor.scenario ~= '' then
        if editor.animationEditor then
            local c = GetEntityCoords(ped)
            TaskStartScenarioAtPosition(ped, editor.scenario, c.x, c.y, c.z, GetEntityHeading(ped), 0, false, true)
        else
            TaskStartScenarioInPlace(ped, editor.scenario, 0, true)
        end
    end
end

local function spawnPed(coords, heading)
    local ped = CreatePed(4, editor.modelHash, coords.x, coords.y, coords.z, heading, false, false)
    if not ped or ped == 0 then return nil end
    SetEntityAsMissionEntity(ped, true, true)
    if editor.animationEditor then
        SetPedDefaultComponentVariation(ped)
        SetEntityAlpha(ped, 150, false)
        SetEntityCollision(ped, false, false)
        SetPedCanRagdoll(ped, false)
    end
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    applyIdle(ped)
    return ped
end

hud = function(message)
    local coords = GetEntityCoords(editor.ped)
    SendNUIMessage({ action = 'pedSpawner', payload = {
        visible = true, animationEditor = editor.animationEditor, settingsOpen = editor.settingsOpen,
        title = editor.animationEditor and 'Ped Animation Editor' or 'Ped Spawner',
        pose = { dict = editor.dict, clip = editor.clip, scenario = editor.scenario, flag = editor.flag or 1 },
        output = editor.output or '', model = editor.model, mode = editor.drag and 'DRAGGING' or editor.mode:upper(),
        behaviour = editor.dict ~= '' and ('Anim: ' .. editor.dict .. ' / ' .. editor.clip) or (editor.scenario ~= '' and ('Scenario: ' .. editor.scenario) or 'No idle behaviour'),
        count = #editor.entries, message = message,
        metrics = {
            { label = 'X / Y / Z', value = ('%.3f  %.3f  %.3f'):format(coords.x, coords.y, coords.z) },
            { label = 'Heading', value = ('%.2f degrees'):format(GetEntityHeading(editor.ped)) },
        },
        help = editor.animationEditor and {
            'Tab Move/Rotate - Left-drag gizmo - Ctrl precision',
            'Hold RMB to look - WASD camera - Q/E down/up',
            'Enter captures placement - G prints batch (keeps editing)',
            'F opens pose settings and Exit editor',
        } or {
            'Tab switches Move/Rotate - Left-drag gizmo - Ctrl precision',
            'Hold RMB to look - WASD camera - Q/E down/up',
            'Enter adds another ped - G saves all - Backspace cancels',
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
    local callback = cancelled and editor.onCancel or editor.onSave
    local entries, entities, camera, player = editor.entries, editor.entities, editor.camera, editor.player
    editor.active = false
    RenderScriptCams(false, true, 250, true, true)
    if camera and DoesCamExist(camera) then DestroyCam(camera, false) end
    ClearFocus()
    if editor.animationEditor then SetNuiFocus(false, false) end
    for i = 1, #entities do if DoesEntityExist(entities[i]) then DeleteEntity(entities[i]) end end
    FreezeEntityPosition(player, editor.wasFrozen == true)
    SetPlayerInvincible(PlayerId(), editor.wasInvincible == true)
    SendNUIMessage({ action = 'pedSpawner', payload = nil })
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

local function exportPoses()
    local rows = { '-- Ped animation placements; coords are the ped origin (no seat-height offset).', 'local placements = {' }
    for _, entry in ipairs(editor.entries) do rows[#rows + 1] = formatPose(entry) end
    rows[#rows + 1] = '}'
    editor.output = table.concat(rows, '\n')
    print(editor.output)
    hud('Batch printed to F8. Continue placing, or open settings to copy it.')
end

local function addPed()
    local coords, heading = GetEntityCoords(editor.ped), GetEntityHeading(editor.ped)
    local entry = { model = editor.model, coords = { x = coords.x, y = coords.y, z = coords.z, w = heading } }
    if editor.dict ~= '' and editor.clip ~= '' then entry.anim = { dict = editor.dict, clip = editor.clip, flag = editor.flag or 1 }
    elseif editor.scenario ~= '' then entry.scenario = editor.scenario end
    if #editor.entries >= 100 then hud('100 placements captured. Print/copy the batch, then clear captures in settings.') return end
    editor.entries[#editor.entries + 1] = entry
    if editor.animationEditor then
        editor.output = formatPose(entry)
        print(editor.output)
        hud(('Placement %d printed to F8. Move this ghost to the next seat.'):format(#editor.entries))
        return
    end
    local nextCoords = add(coords, vec(1, 0, 0))
    local nextPed = spawnPed(nextCoords, heading)
    if nextPed then editor.entities[#editor.entities + 1] = nextPed; editor.ped = nextPed end
    hud(('Ped %d added. Position the next one or press G to save.'):format(#editor.entries))
end

local function loop()
    while editor.active do
        Wait(0)
        if not editor.active then break end
        controls()
        if not editor.settingsOpen then
        cameraUpdate()
        local hovered
        if not IsDisabledControlPressed(0, 25) then
            SetMouseCursorActiveThisFrame()
            local mx, my = GetDisabledControlNormal(0, 239), GetDisabledControlNormal(0, 240)
            hovered = editor.drag and editor.drag.handle or findHandle(mx, my)
            if IsDisabledControlJustPressed(0, 24) then startDrag(hovered, mx, my) end
            if editor.drag and IsDisabledControlPressed(0, 24) then updateDrag(mx, my) end
            if editor.drag and IsDisabledControlJustReleased(0, 24) then
                editor.drag = nil
                if editor.animationEditor and editor.scenario ~= '' then applyIdle(editor.ped) end
            end
        end
        drawGizmo(hovered)
        if IsDisabledControlJustPressed(0, 37) then editor.mode = editor.mode == 'move' and 'rotate' or 'move'; editor.drag = nil; hud() end
        if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 201) then addPed() end
        if IsDisabledControlJustPressed(0, 47) then
            if #editor.entries == 0 then addPed() end
            if editor.animationEditor then exportPoses() else cleanup(false) end
        elseif IsDisabledControlJustPressed(0, 177) and not editor.animationEditor then cleanup(true) end
        if editor.animationEditor and IsDisabledControlJustPressed(0, 23) then
            editor.settingsOpen = true; editor.drag = nil; SetNuiFocus(true, true); hud()
        end
        end
        if editor.active and GetGameTimer() > (editor.nextHud or 0) then editor.nextHud = GetGameTimer() + 100; hud() end
    end
end

function Creator.Start(options, callbacks)
    if editor.active then return false, 'The Ped Spawner is already active' end
    options = type(options) == 'table' and options or {}
    local model, scenario = trim(options.model, 80), trim(options.scenario, 96)
    local dict, clip = trim(options.dict, 128), trim(options.clip, 96)
    if model == '' then return false, 'Enter a ped model' end
    if (dict == '') ~= (clip == '') then return false, 'Animation dictionary and clip must both be supplied' end
    if options.animationEditor and model ~= 'mp_m_freemode_01' and model ~= 'mp_f_freemode_01' then return false, 'Choose mp_m_freemode_01 or mp_f_freemode_01' end
    local hash = joaat(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return false, ('Invalid ped model %s'):format(model) end
    RequestModel(hash)
    local expires = GetGameTimer() + 7000
    while not HasModelLoaded(hash) and GetGameTimer() < expires do Wait(0) end
    if not HasModelLoaded(hash) then return false, ('Unable to load ped model %s'):format(model) end
    if options.animationEditor then
        if dict ~= '' then
            RequestAnimDict(dict)
            local deadline = GetGameTimer() + 5000
            while not HasAnimDictLoaded(dict) and GetGameTimer() < deadline do Wait(0) end
            if not HasAnimDictLoaded(dict) or GetAnimDuration(dict, clip) <= 0 then
                SetModelAsNoLongerNeeded(hash)
                return false, 'Animation dictionary or clip could not be loaded'
            end
        end
    end
    local player = PlayerPedId()
    local start = GetOffsetFromEntityInWorldCoords(player, 0.0, 2.0, 0.0)
    local camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local cameraCoords, cameraRot = GetGameplayCamCoord(), GetGameplayCamRot(2)
    SetCamCoord(camera, cameraCoords.x, cameraCoords.y, cameraCoords.z); SetCamRot(camera, cameraRot.x, 0, cameraRot.z, 2)
    SetCamFov(camera, GetGameplayCamFov()); RenderScriptCams(true, true, 250, true, true)
    editor = {
        active = true, animationEditor = options.animationEditor == true, flag = 1, settingsOpen = false, model = model, modelHash = hash, scenario = scenario, dict = dict, clip = clip,
        player = player, camera = camera, entries = {}, entities = {}, mode = 'move',
        wasFrozen = type(IsEntityPositionFrozen) == 'function' and IsEntityPositionFrozen(player) or false,
        wasInvincible = GetPlayerInvincible(PlayerId()), onSave = callbacks and callbacks.onSave, onCancel = callbacks and callbacks.onCancel,
    }
    editor.ped = spawnPed(start, GetEntityHeading(player))
    if not editor.ped then RenderScriptCams(false, false, 0, true, true); DestroyCam(camera, false); editor = { active = false }; return false, 'Unable to create ped' end
    editor.entities[1] = editor.ped
    FreezeEntityPosition(player, true); SetPlayerInvincible(PlayerId(), true); SetModelAsNoLongerNeeded(hash)
    hud()
    CreateThread(function()
        local ok, err = xpcall(loop, function(message) return debug.traceback(tostring(message), 2) end)
        if not ok then print(('^1[bridge_lab] Ped Spawner error: %s^7'):format(err)); if editor.active then cleanup(true) end end
    end)
    return true
end

RegisterNUICallback('pedAnimationAction', function(data, reply)
    if not editor.active or not editor.animationEditor or not editor.settingsOpen then reply({ ok = false }) return end
    if data.action == 'exit' then reply({ ok = true }); cleanup(true); return end
    if data.action == 'resume' then
        editor.settingsOpen = false; SetNuiFocus(false, false); hud(); reply({ ok = true }); return
    end
    if data.action == 'export' then exportPoses(); reply({ ok = true }); return end
    if data.action == 'clear' then editor.entries = {}; editor.output = ''; hud('Captured placements cleared.'); reply({ ok = true }); return end
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

function Creator.IsActive() return editor.active == true end
function Creator.Stop() cleanup(true) end

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() and editor.active then editor.onCancel = nil; cleanup(true) end
end)
