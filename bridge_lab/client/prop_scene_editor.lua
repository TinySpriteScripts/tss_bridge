-- Multi-prop scene layout editor with move, rotate, and non-uniform scale gizmos.
TSSBridgeLabPropSceneEditor = {}

local Creator = TSSBridgeLabPropSceneEditor
local editor = { active = false }
local modules = TSSModuleLoader.GetModules({ 'Gizmo', 'Props' })
local Gizmo, Props = modules.Gizmo, modules.Props
local propLibrary = type(TSSBridgeLabPropLibrary) == 'table' and TSSBridgeLabPropLibrary or {}
local commitHistory
local selectEntry

local function vec(x, y, z) return vector3(x + 0.0, y + 0.0, z + 0.0) end
local function transform(x, y, z) return { x = x + 0.0, y = y + 0.0, z = z + 0.0 } end
local function copy(value) return transform(value.x, value.y, value.z) end
local function add(a, b) return vec(a.x + b.x, a.y + b.y, a.z + b.z) end
local function mul(a, amount) return vec(a.x * amount, a.y * amount, a.z * amount) end
local function length(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
local function normalise(a)
    local magnitude = length(a)
    return magnitude > 0.00001 and vec(a.x / magnitude, a.y / magnitude, a.z / magnitude) or vec(0, 0, 0)
end
local function cameraBasis(rotation)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    local cosPitch = math.cos(pitch)
    return normalise(vec(-math.sin(yaw) * cosPitch, math.cos(yaw) * cosPitch, math.sin(pitch))),
        normalise(vec(math.cos(yaw), math.sin(yaw), 0.0)),
        normalise(vec(math.sin(yaw) * math.sin(pitch), -math.cos(yaw) * math.sin(pitch), cosPitch))
end
local function trim(value, maximum)
    value = tostring(value or ''):match('^%s*(.-)%s*$')
    if value == '' or #value > maximum or value:find('[%c]') then return nil end
    return value
end
local function activeEntry() return editor.entries and editor.entries[editor.activeIndex] end

local function applyScaleMatrix(entry)
    if not entry or not DoesEntityExist(entry.entity) then return end
    local forward, right, up = GetEntityMatrix(entry.entity)
    forward, right, up = normalise(forward), normalise(right), normalise(up)
    local coords, scale = entry.coords, entry.scale
    SetEntityMatrix(entry.entity,
        forward.x * scale.y, forward.y * scale.y, forward.z * scale.y,
        right.x * scale.x, right.y * scale.x, right.z * scale.x,
        up.x * scale.z, up.y * scale.z, up.z * scale.z,
        coords.x, coords.y, coords.z)
end

local function applyTransform(entry)
    if not entry or not DoesEntityExist(entry.entity) then return end
    local coords, rotation = entry.coords, entry.rotation
    SetEntityCoordsNoOffset(entry.entity, coords.x, coords.y, coords.z, false, false, false)
    SetEntityRotation(entry.entity, rotation.x, rotation.y, rotation.z, 2, true)
    applyScaleMatrix(entry)
end

local function modelValid(model)
    local hash = joaat(model)
    return IsModelInCdimage(hash) and IsModelValid(hash), hash
end

local function createEntry(model, coords, rotation, scale)
    model = trim(model, 80)
    if not model then return nil, 'Enter a prop model name.' end
    local valid = modelValid(model)
    if not valid then return nil, ('Invalid prop model %s'):format(model) end
    local entity = Props.Create(model, coords, { freeze = true, collision = true, fade = false })
    if not entity then return nil, ('Unable to create prop %s'):format(model) end
    local entry = {
        entity = entity,
        model = model,
        coords = vec(coords.x, coords.y, coords.z),
        rotation = copy(rotation or { x = 0, y = 0, z = 0 }),
        scale = copy(scale or { x = 1, y = 1, z = 1 }),
    }
    SetEntityCollision(entity, true, false)
    FreezeEntityPosition(entity, true)
    applyTransform(entry)
    return entry
end

local function gizmoSize()
    local entry = activeEntry()
    if not entry then return 1.0 end
    local cameraCoords = GetCamCoord(editor.camera)
    local distance = length(vec(
        cameraCoords.x - entry.coords.x,
        cameraCoords.y - entry.coords.y,
        cameraCoords.z - entry.coords.z
    ))
    local fovScale = math.tan(math.rad(GetCamFov(editor.camera)) * 0.5) / math.tan(math.rad(25.0))
    return math.max(0.65, math.min(8.0, distance * 0.11 * fovScale))
end

local function axesFor(entry, kind)
    if kind == 'scale' or editor.space == 'local' then return Gizmo.EntityAxes(entry.entity) end
    return Gizmo.WorldAxes()
end

local function createGizmo()
    return Gizmo.Create({
        mode = editor.mode,
        uiOverlay = true,
        handles = function(mode)
            local entry = activeEntry()
            if not entry then return {} end
            local center, size, handles = entry.coords, gizmoSize(), {}
            local moveHeadSize = math.max(0.085, math.min(0.24, size * 0.105))
            local scaleHandleSize = math.max(0.105, math.min(0.28, size * 0.125))
            if mode == 'rotate' or mode == 'combined' then
                local axes = axesFor(entry, 'rotate')
                for _, component in ipairs({ 'x', 'y', 'z' }) do
                    local first, second = Gizmo.RingBasis(component, axes)
                    handles[#handles + 1] = Gizmo.RingHandle('rotate_' .. component, center,
                        first, second, size * 0.72,
                        { axis = component, hitRadius = 0.018, segments = 64,
                            data = { transform = 'rotate' } })
                end
            end
            if mode == 'move' or mode == 'combined' then
                local axes = axesFor(entry, 'move')
                for _, component in ipairs({ 'x', 'y', 'z' }) do
                    handles[#handles + 1] = Gizmo.AxisHandle('move_' .. component, center,
                        axes[component], size, component,
                        { size = moveHeadSize, hoverSize = moveHeadSize * 1.45,
                            data = { transform = 'move' } })
                end
            end
            if mode == 'scale' or mode == 'combined' then
                local axes = axesFor(entry, 'scale')
                for _, component in ipairs({ 'x', 'y', 'z' }) do
                    handles[#handles + 1] = Gizmo.AxisHandle('scale_' .. component, center,
                        axes[component], size * 0.58, component,
                        { shape = 'cube', size = scaleHandleSize, hoverSize = scaleHandleSize * 1.4,
                            priority = 2, data = { transform = 'scale' } })
                end
            end
            return handles
        end,
        onDragStart = function(handle, mouseX, mouseY)
            local entry = activeEntry()
            if not entry then return false end
            local state = {
                entry = entry, coords = vec(entry.coords.x, entry.coords.y, entry.coords.z),
                rotation = copy(entry.rotation), scale = copy(entry.scale),
                mouseX = mouseX, mouseY = mouseY,
            }
            if handle.kind == 'axis' then
                state.linear = Gizmo.LinearDrag(handle.origin, handle.position, mouseX, mouseY, handle.distance)
                if not state.linear then return false end
            end
            return state
        end,
        onDrag = function(handle, state, mouseX, mouseY, precision)
            if activeEntry() ~= state.entry then return end
            local transformKind = handle.data and handle.data.transform
            if transformKind == 'rotate' then
                local movement = ((mouseX - state.mouseX) - (mouseY - state.mouseY)) * 360.0 * precision
                state.entry.rotation = copy(state.rotation)
                state.entry.rotation[handle.axis] = (state.entry.rotation[handle.axis] + movement) % 360.0
            elseif transformKind == 'scale' then
                local movement = Gizmo.LinearDisplacement(state.linear, mouseX, mouseY, precision)
                state.entry.scale = copy(state.scale)
                state.entry.scale[handle.axis] = math.max(0.05,
                    math.min(10.0, state.scale[handle.axis] + movement / math.max(handle.distance, 0.001)))
            else
                local movement = Gizmo.LinearDisplacement(state.linear, mouseX, mouseY, precision)
                state.entry.coords = add(state.coords, mul(handle.direction, movement))
            end
            applyTransform(state.entry)
        end,
        onDragEnd = function(_, _, cancelled)
            if not cancelled and commitHistory then commitHistory() end
        end,
    })
end

local disabled = {
    1,2,14,15,16,17,20,21,23,24,25,29,30,31,32,33,34,35,36,37,38,44,47,
    140,141,142,143,166,170,174,175,177,178,191,200,201,239,240,246,257,263,264,289,
}

local function blockControls()
    for i = 1, #disabled do DisableControlAction(0, disabled[i], true) end
    DisablePlayerFiring(PlayerId(), true)
end

local function updateCamera()
    local rotation, coords = GetCamRot(editor.camera, 2), GetCamCoord(editor.camera)
    if IsDisabledControlPressed(0, 25) then
        rotation = vec(math.max(-89.0, math.min(89.0,
            rotation.x - GetDisabledControlNormal(0, 2) * 7.5)), 0.0,
            rotation.z - GetDisabledControlNormal(0, 1) * 7.5)
    end
    if IsDisabledControlJustPressed(0, 15) then editor.speed = math.min(30.0, editor.speed * 1.35) end
    if IsDisabledControlJustPressed(0, 14) then editor.speed = math.max(0.25, editor.speed / 1.35) end
    local forward, right = cameraBasis(rotation)
    local speed = editor.speed * math.max(GetFrameTime(), 0.001)
    if IsDisabledControlPressed(0, 21) then speed = speed * 3.0 end
    if IsDisabledControlPressed(0, 36) then speed = speed * 0.25 end
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

local function scenePayload(message)
    local entry = activeEntry()
    local props = {}
    for i = 1, #editor.entries do
        props[i] = { index = i, model = editor.entries[i].model }
    end
    local payload = {
        visible = true, settingsOpen = editor.settingsOpen == true,
        libraryOpen = editor.libraryOpen == true,
        title = 'Prop Scene Editor', sceneName = editor.name,
        mode = editor.gizmo and editor.gizmo:IsDragging() and 'DRAGGING'
            or ('%s · %s'):format(editor.mode:upper(), editor.space:upper()),
        activeIndex = editor.activeIndex, props = props, count = #props,
        activeModel = entry and entry.model or '', output = editor.output or '', message = message,
        metrics = entry and {
            { key = 'coords', label = 'Position', value = ('%.3f  %.3f  %.3f'):format(entry.coords.x, entry.coords.y, entry.coords.z), components = copy(entry.coords) },
            { key = 'rotation', label = 'Rotation', value = ('%.1f°  %.1f°  %.1f°'):format(entry.rotation.x, entry.rotation.y, entry.rotation.z), components = copy(entry.rotation) },
            { key = 'scale', label = 'Scale', value = ('%.3f  %.3f  %.3f'):format(entry.scale.x, entry.scale.y, entry.scale.z), components = copy(entry.scale) },
        } or {},
        help = {
            'F2 Move/Rotate/Scale/Combined · F3 World/Local',
            'Click a prop to select · Ctrl+Z undo · Ctrl+Y redo',
            'Left/Right select · G duplicate · F manager · F5 library',
            'Visual scaling does not resize GTA collision bounds',
        },
    }
    if editor.libraryOpen and not editor.librarySent then payload.library = propLibrary end
    return payload
end

local function sendHud(force, message)
    local now = GetGameTimer()
    if not force and now < (editor.nextHud or 0) then return end
    editor.nextHud = now + 100
    SendNUIMessage({ action = 'propSceneEditor', payload = scenePayload(message) })
    if editor.libraryOpen then editor.librarySent = true end
end

local function serialiseEntries()
    local result = {}
    for i = 1, #editor.entries do
        local entry = editor.entries[i]
        result[i] = {
            model = entry.model,
            coords = copy(entry.coords), rotation = copy(entry.rotation), scale = copy(entry.scale),
        }
    end
    return result
end

local function formatScene()
    local rows = { ('local scene = { -- %s'):format(editor.name) }
    for _, entry in ipairs(editor.entries) do
        rows[#rows + 1] = ('    { model = %q, coords = vector3(%.3f, %.3f, %.3f),'):format(
            entry.model, entry.coords.x, entry.coords.y, entry.coords.z)
        rows[#rows + 1] = ('      rotation = vector3(%.3f, %.3f, %.3f), scale = vector3(%.3f, %.3f, %.3f) },'):format(
            entry.rotation.x, entry.rotation.y, entry.rotation.z,
            entry.scale.x, entry.scale.y, entry.scale.z)
    end
    rows[#rows + 1] = '}'
    return table.concat(rows, '\n')
end

local function historySnapshot()
    local entries = serialiseEntries()
    return {
        entries = entries,
        activeIndex = editor.activeIndex,
        signature = json.encode({ entries = entries, activeIndex = editor.activeIndex }),
    }
end

commitHistory = function(reset)
    local snapshot = historySnapshot()
    if reset then
        editor.history, editor.historyIndex = { snapshot }, 1
        return
    end
    local current = editor.history and editor.history[editor.historyIndex]
    if current and current.signature == snapshot.signature then return end
    for i = #(editor.history or {}), (editor.historyIndex or 0) + 1, -1 do
        table.remove(editor.history, i)
    end
    editor.history[#editor.history + 1] = snapshot
    editor.historyIndex = #editor.history
    if #editor.history > 100 then
        table.remove(editor.history, 1)
        editor.historyIndex = editor.historyIndex - 1
    end
end

local function restoreHistory(snapshot)
    if not snapshot then return false end
    if editor.gizmo then editor.gizmo:FinishDrag(true) end
    for i = #editor.entries, #snapshot.entries + 1, -1 do
        local removed = table.remove(editor.entries, i)
        if removed and DoesEntityExist(removed.entity) then Props.Delete(removed.entity) end
    end
    for i = 1, #snapshot.entries do
        local saved, current = snapshot.entries[i], editor.entries[i]
        if current and current.model ~= saved.model then
            if DoesEntityExist(current.entity) then Props.Delete(current.entity) end
            current = nil
        end
        if not current then
            local created, createError = createEntry(saved.model, saved.coords, saved.rotation, saved.scale)
            if not created then sendHud(true, createError); return false end
            editor.entries[i] = created
            current = created
        else
            current.coords, current.rotation, current.scale = vec(saved.coords.x, saved.coords.y, saved.coords.z),
                copy(saved.rotation), copy(saved.scale)
            applyTransform(current)
        end
    end
    editor.activeIndex = math.max(1, math.min(snapshot.activeIndex, #editor.entries))
    editor.output = formatScene()
    selectEntry(editor.activeIndex)
    return true
end

local function undoHistory()
    if not editor.history or editor.historyIndex <= 1 then return sendHud(true, 'Nothing left to undo.') end
    editor.historyIndex = editor.historyIndex - 1
    if restoreHistory(editor.history[editor.historyIndex]) then sendHud(true, 'Undo.') end
end

local function redoHistory()
    if not editor.history or editor.historyIndex >= #editor.history then return sendHud(true, 'Nothing left to redo.') end
    editor.historyIndex = editor.historyIndex + 1
    if restoreHistory(editor.history[editor.historyIndex]) then sendHud(true, 'Redo.') end
end

local function screenRay(screenX, screenY, flags)
    local cameraCoords, cameraRotation = GetCamCoord(editor.camera), GetCamRot(editor.camera, 2)
    local forward, right, up = cameraBasis(cameraRotation)
    local tangent = math.tan(math.rad(GetCamFov(editor.camera)) * 0.5)
    local horizontal = ((screenX or 0.5) - 0.5) * 2.0 * GetAspectRatio(false) * tangent
    local vertical = ((screenY or 0.5) - 0.5) * -2.0 * tangent
    local direction = normalise(add(forward, add(mul(right, horizontal), mul(up, vertical))))
    local destination = add(cameraCoords, mul(direction, 1000.0))
    local ray = StartExpensiveSynchronousShapeTestLosProbe(
        cameraCoords.x, cameraCoords.y, cameraCoords.z,
        destination.x, destination.y, destination.z,
        flags or 16, editor.player, 7)
    local _, hit, endCoords, _, entity = GetShapeTestResult(ray)
    return hit == 1, endCoords, entity
end

local function selectEntity(entity)
    if not entity or entity == 0 then return false end
    for i = 1, #editor.entries do
        if editor.entries[i].entity == entity then return selectEntry(i, ('Selected %s.'):format(editor.entries[i].model)) end
    end
    return false
end

selectEntry = function(index, message)
    index = math.floor(tonumber(index) or editor.activeIndex)
    if not editor.entries[index] then return false end
    if editor.gizmo then editor.gizmo:FinishDrag(false) end
    for i = 1, #editor.entries do
        if DoesEntityExist(editor.entries[i].entity) then pcall(SetEntityDrawOutline, editor.entries[i].entity, false) end
    end
    editor.activeIndex = index
    local selected = activeEntry()
    if selected and DoesEntityExist(selected.entity) then
        pcall(SetEntityDrawOutlineColor, 255, 45, 45, 220)
        pcall(SetEntityDrawOutline, selected.entity, true)
    end
    sendHud(true, message)
    return true
end

local function addProp(model, duplicate, dropCoords)
    if #editor.entries >= 200 then return false, 'A scene can contain at most 200 props.' end
    local source = activeEntry()
    local coords, rotation, scale
    if dropCoords then
        coords = vec(dropCoords.x, dropCoords.y, dropCoords.z)
        rotation, scale = transform(0, 0, source and source.rotation.z or 0), transform(1, 1, 1)
    elseif source then
        coords = add(source.coords, vec(0.35, 0.35, 0.0))
        rotation = source.rotation
        scale = duplicate and source.scale or transform(1, 1, 1)
        if duplicate then model = source.model end
    else
        local player = PlayerPedId()
        coords = GetOffsetFromEntityInWorldCoords(player, 0.0, 2.0, 0.0)
        rotation, scale = transform(0, 0, GetEntityHeading(player)), transform(1, 1, 1)
    end
    local entry, createError = createEntry(model, coords, rotation, scale)
    if not entry then return false, createError end
    editor.entries[#editor.entries + 1] = entry
    editor.activeIndex = #editor.entries
    editor.output = formatScene()
    commitHistory()
    selectEntry(editor.activeIndex)
    return true
end

local function deleteActive()
    if #editor.entries <= 1 then return false, 'A scene must keep at least one prop.' end
    if editor.gizmo then editor.gizmo:FinishDrag(false) end
    local entry = table.remove(editor.entries, editor.activeIndex)
    if entry and DoesEntityExist(entry.entity) then Props.Delete(entry.entity) end
    editor.activeIndex = math.min(editor.activeIndex, #editor.entries)
    editor.output = formatScene()
    commitHistory()
    selectEntry(editor.activeIndex)
    return true
end

local function setNuiInteractive(state, keepInput)
    state = state == true
    keepInput = keepInput == true
    if editor.nuiInteractive == state and editor.nuiKeepInput == keepInput then return end
    editor.nuiInteractive, editor.nuiKeepInput = state, keepInput
    SetNuiFocus(state, state)
    if type(SetNuiFocusKeepInput) == 'function' then SetNuiFocusKeepInput(keepInput) end
end

local function setSettingsOpen(state)
    if editor.gizmo then editor.gizmo:FinishDrag(false) end
    editor.settingsOpen = state == true
    editor.libraryOpen = false
    editor.librarySent = false
    editor.uiFocus = false
    setNuiInteractive(true, not editor.settingsOpen)
    editor.output = formatScene()
    sendHud(true)
end

local function stopEditor(cancelled)
    if not editor.active then return end
    if editor.gizmo then editor.gizmo:FinishDrag(true) end
    if editor.gizmo then editor.gizmo:ClearOverlay() end
    local callback = cancelled and editor.onCancel or editor.onSave
    local payload = cancelled and nil or { name = editor.name, props = serialiseEntries() }
    local camera, entries, player = editor.camera, editor.entries, editor.player
    editor.active = false
    setNuiInteractive(false, false)
    RenderScriptCams(false, true, 250, true, true)
    if camera and DoesCamExist(camera) then DestroyCam(camera, false) end
    ClearFocus()
    for i = 1, #entries do
        if entries[i].entity and DoesEntityExist(entries[i].entity) then Props.Delete(entries[i].entity) end
    end
    FreezeEntityPosition(player, editor.wasFrozen == true)
    SetPlayerInvincible(PlayerId(), editor.wasInvincible == true)
    SendNUIMessage({ action = 'propSceneEditor', payload = nil })
    editor = { active = false }
    if callback then callback(payload) end
end

local function editorLoop()
    while editor.active do
        Wait(0)
        -- A NUI callback can stop and reset the editor while this thread is waiting.
        if not editor.active then break end
        blockControls()
        for i = 1, #editor.entries do applyScaleMatrix(editor.entries[i]) end
        if not editor.settingsOpen then
            updateCamera()
            local looking = IsDisabledControlPressed(0, 25)
            setNuiInteractive(not looking, not looking and not editor.libraryOpen and not editor.uiFocus)
            local hovered, dragging = editor.gizmo:Tick({ enabled = not looking, cursor = not looking })
            if IsDisabledControlPressed(0, 36) and IsDisabledControlJustPressed(0, 20) then
                undoHistory()
            elseif IsDisabledControlPressed(0, 36) and IsDisabledControlJustPressed(0, 246) then
                redoHistory()
            end
            if IsDisabledControlJustPressed(0, 166) then
                editor.libraryOpen = not editor.libraryOpen
                editor.librarySent = false
                sendHud(true, editor.libraryOpen and 'Prop library opened.' or 'Prop library closed.')
            end
            if not looking and IsDisabledControlJustPressed(0, 170) then
                editor.gizmo:FinishDrag(false)
                editor.space = editor.space == 'world' and 'local' or 'world'
                sendHud(true, ('Axes switched to %s space.'):format(editor.space))
            end
            if IsDisabledControlJustPressed(0, 289) then
                editor.gizmo:FinishDrag(false)
                editor.mode = editor.mode == 'move' and 'rotate'
                    or (editor.mode == 'rotate' and 'scale'
                    or (editor.mode == 'scale' and 'combined' or 'move'))
                editor.gizmo:SetMode(editor.mode)
                sendHud(true)
            end
            if IsDisabledControlJustPressed(0, 174) then
                selectEntry(((editor.activeIndex - 2) % #editor.entries) + 1)
            elseif IsDisabledControlJustPressed(0, 175) then
                selectEntry((editor.activeIndex % #editor.entries) + 1)
            end
            if IsDisabledControlJustPressed(0, 47) then
                local ok, message = addProp(nil, true)
                sendHud(true, ok and 'Prop duplicated.' or message)
            end
            local mouseX, mouseY = GetDisabledControlNormal(0, 239), GetDisabledControlNormal(0, 240)
            local overHud = (mouseX > 0.60 and mouseY < 0.62)
                or (editor.libraryOpen and mouseY > 0.64)
            if not looking and not hovered and not dragging and not overHud
                and IsDisabledControlJustPressed(0, 24) then
                local hit, _, entity = screenRay(mouseX, mouseY, 16)
                if hit then selectEntity(entity) end
            end
            if IsDisabledControlJustPressed(0, 23) then setSettingsOpen(true) end
        else
            editor.gizmo:Draw()
        end
        if editor.active then sendHud(false) end
    end
end

function Creator.Start(options, callbacks)
    if editor.active then return false, 'The Prop Scene Editor is already active' end
    options = type(options) == 'table' and options or {}
    local name, model = trim(options.name, 64), trim(options.model, 80)
    if not name then return false, 'Enter a scene name.' end
    if not name:match('^[%w_%-]+$') then return false, 'Scene names may use letters, numbers, underscores and hyphens.' end
    if not model then return false, 'Enter an initial prop model.' end

    local player = PlayerPedId()
    local camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local cameraCoords, cameraRotation = GetGameplayCamCoord(), GetGameplayCamRot(2)
    SetCamCoord(camera, cameraCoords.x, cameraCoords.y, cameraCoords.z)
    SetCamRot(camera, cameraRotation.x, 0.0, cameraRotation.z, 2)
    SetCamFov(camera, GetGameplayCamFov())
    RenderScriptCams(true, true, 250, true, true)

    editor = {
        active = true, name = name, player = player, camera = camera, entries = {},
        activeIndex = 1, mode = 'move', space = 'world', settingsOpen = false,
        speed = 3.0, output = '', history = {}, historyIndex = 0,
        onSave = callbacks and callbacks.onSave,
        onCancel = callbacks and callbacks.onCancel,
        wasFrozen = type(IsEntityPositionFrozen) == 'function' and IsEntityPositionFrozen(player) or false,
        wasInvincible = GetPlayerInvincible(PlayerId()),
    }
    local started, startError = addProp(model, false)
    if not started then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(camera, false)
        editor = { active = false }
        return false, startError
    end
    editor.gizmo = createGizmo()
    commitHistory(true)
    selectEntry(1)
    FreezeEntityPosition(player, true)
    SetPlayerInvincible(PlayerId(), true)
    setNuiInteractive(true, true)
    sendHud(true)
    CreateThread(function()
        local ok, runtimeError = xpcall(editorLoop, function(message)
            return debug and debug.traceback and debug.traceback(tostring(message), 2) or tostring(message)
        end)
        if not ok then
            print(('^1[bridge_lab] Prop Scene Editor stopped after an error: %s^7'):format(runtimeError))
            if editor.active then stopEditor(true) end
        end
    end)
    return true
end

function Creator.IsActive() return editor.active == true end
function Creator.Stop() stopEditor(true) end

RegisterNUICallback('propSceneAction', function(data, reply)
    if not editor.active or type(data) ~= 'table' then
        reply({ ok = false, error = 'Editor is not available.' })
        return
    end
    local action = data.action
    if action == 'uiFocus' then editor.uiFocus = data.focused == true; reply({ ok = true }); return end
    if action == 'toggleLibrary' then
        editor.libraryOpen = not editor.libraryOpen
        editor.librarySent = false
        editor.uiFocus = false
        sendHud(true, editor.libraryOpen and 'Prop library opened.' or 'Prop library closed.')
        reply({ ok = true }); return
    end
    if action == 'undo' then undoHistory(); reply({ ok = true }); return end
    if action == 'redo' then redoHistory(); reply({ ok = true }); return end
    if action == 'transform' then
        local entry, kind = activeEntry(), data.kind
        local x, y, z = tonumber(data.x), tonumber(data.y), tonumber(data.z)
        if not entry or (kind ~= 'coords' and kind ~= 'rotation' and kind ~= 'scale')
            or not x or not y or not z or x ~= x or y ~= y or z ~= z then
            reply({ ok = false, error = 'Enter valid X, Y, and Z values.' }); return
        end
        if kind == 'coords' and (math.abs(x) > 10000 or math.abs(y) > 10000 or math.abs(z) > 10000) then
            reply({ ok = false, error = 'Coordinates are outside the supported range.' }); return
        end
        if kind == 'scale' and (x < 0.05 or y < 0.05 or z < 0.05 or x > 10 or y > 10 or z > 10) then
            reply({ ok = false, error = 'Scale values must be between 0.05 and 10.' }); return
        end
        -- Coordinates participate in FiveM vector operations elsewhere in the editor.
        entry[kind] = kind == 'coords' and vec(x, y, z) or transform(x, y, z)
        applyTransform(entry)
        commitHistory()
        editor.output = formatScene()
        sendHud(true, ('%s updated.'):format(kind == 'coords' and 'Position' or kind:gsub('^%l', string.upper)))
        reply({ ok = true }); return
    end
    if action == 'libraryAdd' then
        local ok, message = addProp(data.model, false)
        sendHud(true, ok and 'Library prop added.' or message)
        reply({ ok = ok, error = ok and nil or message }); return
    end
    if action == 'libraryDrop' then
        local screenX, screenY = tonumber(data.screenX), tonumber(data.screenY)
        if not screenX or not screenY then reply({ ok = false, error = 'Invalid drop position.' }); return end
        local hit, coords = screenRay(screenX, screenY, -1)
        if not hit then reply({ ok = false, error = 'Drop the prop onto visible world geometry.' }); return end
        local ok, message = addProp(data.model, false, coords)
        sendHud(true, ok and 'Library prop placed.' or message)
        reply({ ok = ok, error = ok and nil or message }); return
    end
    if action == 'resume' then
        setSettingsOpen(false); reply({ ok = true }); return
    end
    if action == 'exit' then reply({ ok = true }); stopEditor(true); return end
    if action == 'save' then
        reply({ ok = true }); stopEditor(false); return
    end
    if action == 'export' then
        editor.output = formatScene(); sendHud(true, 'Scene Lua is ready to copy.'); reply({ ok = true }); return
    end
    if action == 'select' then
        local ok = selectEntry(data.index); reply({ ok = ok, error = ok and nil or 'Invalid prop selection.' }); return
    end
    if action == 'add' then
        local ok, message = addProp(data.model, false)
        sendHud(true, ok and 'Prop added.' or message); reply({ ok = ok, error = ok and nil or message }); return
    end
    if action == 'duplicate' then
        local ok, message = addProp(nil, true)
        sendHud(true, ok and 'Prop duplicated.' or message); reply({ ok = ok, error = ok and nil or message }); return
    end
    if action == 'delete' then
        local ok, message = deleteActive()
        sendHud(true, ok and 'Prop removed.' or message); reply({ ok = ok, error = ok and nil or message }); return
    end
    reply({ ok = false, error = 'Unknown scene action.' })
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() and editor.active then
        editor.onCancel = nil
        stopEditor(true)
    end
end)
