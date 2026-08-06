-- Ped prop attachment editor with local move and rotation gizmos.
TSSBridgeLabPropAttachmentCreator = {}

local Creator = TSSBridgeLabPropAttachmentCreator
local editor = { active = false }

local function isCallable(value)
    if type(value) == 'function' then return true end
    if type(value) ~= 'table' then return false end
    if rawget(value, '__cfx_functionReference') ~= nil then return true end
    local metatable = getmetatable(value)
    return metatable ~= nil and type(metatable.__call) == 'function'
end

local bones = {
    { name = 'Root', id = 0x0000 },
    { name = 'Pelvis', id = 0x2E28 },
    { name = 'Spine 0', id = 0x5C01 },
    { name = 'Spine 1', id = 0x60F0 },
    { name = 'Spine 2', id = 0x60F1 },
    { name = 'Spine 3', id = 0x60F2 },
    { name = 'Neck', id = 0x9995 },
    { name = 'Head', id = 0x796E },
    { name = 'Left clavicle', id = 0xFCD9 },
    { name = 'Left upper arm', id = 0xB1C5 },
    { name = 'Left forearm', id = 0xEEEB },
    { name = 'Left hand', id = 0x49D9 },
    { name = 'Left hand (physics)', id = 0xEB95 },
    { name = 'Right clavicle', id = 0x29D2 },
    { name = 'Right upper arm', id = 0x9D4D },
    { name = 'Right forearm', id = 0x6E5C },
    { name = 'Right hand', id = 0xDEAD },
    { name = 'Right hand (physics)', id = 0x6F06 },
    { name = 'Left thigh', id = 0xE39F },
    { name = 'Left calf', id = 0xF9BB },
    { name = 'Left foot', id = 0x3779 },
    { name = 'Right thigh', id = 0xCA72 },
    { name = 'Right calf', id = 0x9000 },
    { name = 'Right foot', id = 0xCC4D },
}

local function vector(x, y, z) return vec3(x + 0.0, y + 0.0, z + 0.0) end
local function transform(x, y, z) return { x = x + 0.0, y = y + 0.0, z = z + 0.0 } end
local function add(a, b) return vector(a.x + b.x, a.y + b.y, a.z + b.z) end
local function subtract(a, b) return vector(a.x - b.x, a.y - b.y, a.z - b.z) end
local function multiply(a, scalar) return vector(a.x * scalar, a.y * scalar, a.z * scalar) end
local function dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
local function magnitude(a) return math.sqrt(dot(a, a)) end
local function normalise(a)
    local length = magnitude(a)
    return length > 0.00001 and multiply(a, 1.0 / length) or vector(0.0, 0.0, 0.0)
end

local function project(coords)
    local visible, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    return visible, x, y
end

local function screenDistance(aX, aY, bX, bY)
    return math.sqrt(((aX - bX) ^ 2) + ((aY - bY) ^ 2))
end

local function line(a, b, r, g, blue, alpha)
    DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, r, g, blue, alpha or 240)
end

local function marker(coords, size, r, g, blue, alpha)
    DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        size, size, size, r, g, blue, alpha or 230, false, false, 2, false, nil, nil, false)
end

local function cameraBasis(rotation)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    local cosPitch = math.cos(pitch)
    local forward = vector(-math.sin(yaw) * cosPitch, math.cos(yaw) * cosPitch, math.sin(pitch))
    local right = vector(math.cos(yaw), math.sin(yaw), 0.0)
    local up = vector(math.sin(yaw) * math.sin(pitch), -math.cos(yaw) * math.sin(pitch), cosPitch)
    return normalise(forward), normalise(right), normalise(up)
end

local function currentBone() return bones[editor.boneIndex] end

local function animationValue(value, maximum)
    value = tostring(value or ''):match('^%s*(.-)%s*$')
    if #value > maximum or value:find('[%c]') then return '' end
    return value
end

local function boneAxes()
    local bone = currentBone()
    local ped = editor.ped
    local center = GetPedBoneCoords(ped, bone.id, 0.0, 0.0, 0.0)
    local x = normalise(subtract(GetPedBoneCoords(ped, bone.id, 1.0, 0.0, 0.0), center))
    local y = normalise(subtract(GetPedBoneCoords(ped, bone.id, 0.0, 1.0, 0.0), center))
    local z = normalise(subtract(GetPedBoneCoords(ped, bone.id, 0.0, 0.0, 1.0), center))
    return { x = x, y = y, z = z }
end

local axisData = {
    { component = 'x', color = { 255, 65, 65 } },
    { component = 'y', color = { 65, 220, 105 } },
    { component = 'z', color = { 65, 135, 255 } },
}

local function applyAttachment()
    local bone = currentBone()
    local boneIndex = GetPedBoneIndex(editor.ped, bone.id)
    local offset, rotation = editor.offset, editor.rotation
    AttachEntityToEntity(editor.prop, editor.ped, boneIndex,
        offset.x, offset.y, offset.z, rotation.x, rotation.y, rotation.z,
        false, false, false, true, 1, true)
end

local function gizmoSize()
    local distance = magnitude(subtract(GetCamCoord(editor.camera), GetEntityCoords(editor.prop)))
    return math.max(0.18, math.min(0.52, distance * 0.055))
end

local function ringPoint(center, first, second, radius, angle)
    return add(center, add(multiply(first, math.cos(angle) * radius), multiply(second, math.sin(angle) * radius)))
end

local function ringBasis(component, axes)
    if component == 'x' then return axes.y, axes.z end
    if component == 'y' then return axes.x, axes.z end
    return axes.x, axes.y
end

local function drawRing(center, first, second, radius, color, selected)
    local previous
    for i = 0, 48 do
        local point = ringPoint(center, first, second, radius, (math.pi * 2.0) * (i / 48))
        if previous then line(previous, point, color[1], color[2], color[3], selected and 255 or 190) end
        previous = point
    end
end

local function rotationHandle(mouseX, mouseY, center, axes, radius)
    local closest, best = nil, 0.015
    for i = 1, #axisData do
        local axis = axisData[i]
        local first, second = ringBasis(axis.component, axes)
        for segment = 0, 47 do
            local point = ringPoint(center, first, second, radius, (math.pi * 2.0) * (segment / 48))
            local visible, x, y = project(point)
            if visible then
                local distance = screenDistance(mouseX, mouseY, x, y)
                if distance < best then closest, best = axis, distance end
            end
        end
    end
    return closest
end

local function findHandle(mouseX, mouseY)
    local center = GetEntityCoords(editor.prop)
    local axes, size = boneAxes(), gizmoSize()
    if editor.mode == 'rotate' then return rotationHandle(mouseX, mouseY, center, axes, size * 0.82) end

    local closest, best = nil, 0.025
    for i = 1, #axisData do
        local axis = axisData[i]
        local endpoint = add(center, multiply(axes[axis.component], size))
        local visible, x, y = project(endpoint)
        if visible then
            local distance = screenDistance(mouseX, mouseY, x, y)
            if distance < best then closest, best = axis, distance end
        end
    end
    return closest
end

local function drawGizmo(hovered)
    local center = GetEntityCoords(editor.prop)
    local axes, size = boneAxes(), gizmoSize()
    for i = 1, #axisData do
        local axis = axisData[i]
        local selected = hovered and hovered.component == axis.component
        if editor.mode == 'move' then
            local endpoint = add(center, multiply(axes[axis.component], size))
            line(center, endpoint, axis.color[1], axis.color[2], axis.color[3], 250)
            marker(endpoint, selected and 0.055 or 0.038, axis.color[1], axis.color[2], axis.color[3], 245)
        else
            local first, second = ringBasis(axis.component, axes)
            drawRing(center, first, second, size * 0.82, axis.color, selected)
        end
    end
end

local function startDrag(handle, mouseX, mouseY)
    if not handle then return end
    local original = editor.mode == 'move' and editor.offset[handle.component] or editor.rotation[handle.component]
    local drag = { handle = handle, mouseX = mouseX, mouseY = mouseY, original = original }
    if editor.mode == 'move' then
        local center = GetEntityCoords(editor.prop)
        local direction = boneAxes()[handle.component]
        local endpoint = add(center, multiply(direction, gizmoSize()))
        local centerVisible, centerX, centerY = project(center)
        local endVisible, endX, endY = project(endpoint)
        if not centerVisible or not endVisible then return end
        local x, y = endX - centerX, endY - centerY
        local length = math.sqrt(x * x + y * y)
        if length < 0.002 then return end
        drag.screenX, drag.screenY, drag.screenLength = x / length, y / length, length
    end
    editor.drag = drag
end

local function updateDrag(mouseX, mouseY)
    local drag = editor.drag
    if not drag then return end
    local precision = IsDisabledControlPressed(0, 36) and 0.2 or 1.0
    if editor.mode == 'move' then
        local screenMovement = ((mouseX - drag.mouseX) * drag.screenX) + ((mouseY - drag.mouseY) * drag.screenY)
        local nextValue = drag.original + ((screenMovement / drag.screenLength) * gizmoSize() * precision)
        local offset = editor.offset
        editor.offset = transform(
            drag.handle.component == 'x' and nextValue or offset.x,
            drag.handle.component == 'y' and nextValue or offset.y,
            drag.handle.component == 'z' and nextValue or offset.z
        )
    else
        local movement = (mouseX - drag.mouseX) - (mouseY - drag.mouseY)
        local nextValue = (drag.original + movement * 360.0 * precision) % 360.0
        local rotation = editor.rotation
        editor.rotation = transform(
            drag.handle.component == 'x' and nextValue or rotation.x,
            drag.handle.component == 'y' and nextValue or rotation.y,
            drag.handle.component == 'z' and nextValue or rotation.z
        )
    end
    applyAttachment()
end

local disabledControls = {
    1, 2, 14, 15, 16, 17, 24, 25, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 44,
    140, 141, 142, 143, 174, 175, 177, 191, 200, 201, 239, 240, 257, 263, 264,
}

local function blockControls()
    for i = 1, #disabledControls do DisableControlAction(0, disabledControls[i], true) end
    DisablePlayerFiring(PlayerId(), true)
end

local function updateCamera()
    local rotation = GetCamRot(editor.camera, 2)
    local coords = GetCamCoord(editor.camera)
    if IsDisabledControlPressed(0, 25) then
        rotation = vector(
            math.max(-89.0, math.min(89.0, rotation.x - GetDisabledControlNormal(0, 2) * 7.5)),
            0.0,
            rotation.z - GetDisabledControlNormal(0, 1) * 7.5
        )
    end
    if IsDisabledControlJustPressed(0, 15) then editor.speed = math.min(20.0, editor.speed * 1.35) end
    if IsDisabledControlJustPressed(0, 14) then editor.speed = math.max(0.25, editor.speed / 1.35) end
    local forward, right = cameraBasis(rotation)
    local speed = editor.speed * GetFrameTime()
    if IsDisabledControlPressed(0, 21) then speed = speed * 3.0 end
    if IsDisabledControlPressed(0, 36) then speed = speed * 0.25 end
    if IsDisabledControlPressed(0, 32) then coords = add(coords, multiply(forward, speed)) end
    if IsDisabledControlPressed(0, 33) then coords = add(coords, multiply(forward, -speed)) end
    if IsDisabledControlPressed(0, 35) then coords = add(coords, multiply(right, speed)) end
    if IsDisabledControlPressed(0, 34) then coords = add(coords, multiply(right, -speed)) end
    if IsDisabledControlPressed(0, 38) then coords = add(coords, vector(0.0, 0.0, speed)) end
    if IsDisabledControlPressed(0, 44) then coords = add(coords, vector(0.0, 0.0, -speed)) end
    SetCamCoord(editor.camera, coords.x, coords.y, coords.z)
    SetCamRot(editor.camera, rotation.x, 0.0, rotation.z, 2)
    SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
end

local function hudPayload(message)
    local bone = currentBone()
    local boneOptions = {}
    for i = 1, #bones do
        boneOptions[i] = { index = i, name = bones[i].name, id = bones[i].id }
    end
    return {
        visible = true,
        title = editor.name,
        model = editor.model,
        mode = editor.drag and 'DRAGGING' or editor.mode:upper(),
        bone = ('%s · 0x%04X'):format(bone.name, bone.id),
        boneIndex = editor.boneIndex,
        bones = boneOptions,
        settingsOpen = editor.settingsOpen == true,
        animation = {
            dict = editor.animation.dict,
            clip = editor.animation.clip,
            flag = editor.animation.flag,
            playing = editor.playingAnimation ~= nil,
        },
        metrics = {
            { label = 'Offset X/Y/Z', value = ('%.3f  %.3f  %.3f'):format(editor.offset.x, editor.offset.y, editor.offset.z) },
            { label = 'Rotation X/Y/Z', value = ('%.1f°  %.1f°  %.1f°'):format(editor.rotation.x, editor.rotation.y, editor.rotation.z) },
        },
        message = message,
        help = {
            'B opens bone and animation settings · Tab switches Move/Rotate',
            'Left-drag gizmo · Ctrl precision · Hold RMB to look',
            'WASD move camera · Q/E down/up · Enter save · Backspace cancel',
        },
    }
end

local sendHud

local function setSettingsOpen(state)
    if not editor.active then return end
    editor.settingsOpen = state == true
    editor.drag = nil
    SetNuiFocus(editor.settingsOpen, editor.settingsOpen)
    sendHud(true)
end

local function stopAttachmentAnimation()
    local playing = editor.playingAnimation
    if not playing then return end
    if editor.ped and DoesEntityExist(editor.ped) then
        pcall(StopAnimTask, editor.ped, playing.dict, playing.clip, 1.0)
    end
    if HasAnimDictLoaded(playing.dict) then RemoveAnimDict(playing.dict) end
    editor.playingAnimation = nil
end

local function updateAnimation(data)
    editor.animation.dict = animationValue(data.dict, 128)
    editor.animation.clip = animationValue(data.clip, 96)
    editor.animation.flag = math.max(0, math.min(1024, math.floor(tonumber(data.flag) or 49)))
end

local function playAttachmentAnimation()
    local animation = editor.animation
    if animation.dict == '' or animation.clip == '' then
        return sendHud(true, 'Enter both an animation dictionary and clip name.')
    end
    stopAttachmentAnimation()
    local dict, clip, flag = animation.dict, animation.clip, animation.flag
    editor.message = ('Loading %s…'):format(dict)
    sendHud(true, editor.message)
    CreateThread(function()
        RequestAnimDict(dict)
        local expires = GetGameTimer() + 5000
        while editor.active and not HasAnimDictLoaded(dict) and GetGameTimer() < expires do Wait(0) end
        if not editor.active then return end
        if not HasAnimDictLoaded(dict) then
            editor.message = ('Unable to load animation dictionary %s'):format(dict)
            return sendHud(true, editor.message)
        end
        TaskPlayAnim(editor.ped, dict, clip, 8.0, -8.0, -1, flag, 0.0, false, false, false)
        editor.playingAnimation = { dict = dict, clip = clip }
        editor.message = ('Playing %s / %s'):format(dict, clip)
        sendHud(true, editor.message)
    end)
end

sendHud = function(force, message)
    local now = GetGameTimer()
    if not force and now < (editor.nextHud or 0) then return end
    editor.nextHud = now + 100
    SendNUIMessage({ action = 'attachmentCreator', payload = hudPayload(message) })
end

local function stopEditor(cancelled)
    if not editor.active then return end
    local onCancel, props, prop = editor.onCancel, editor.props, editor.prop
    local camera, ped = editor.camera, editor.ped
    local wasFrozen, wasInvincible = editor.wasFrozen, editor.wasInvincible
    stopAttachmentAnimation()
    editor.active = false

    pcall(SetNuiFocus, false, false)
    pcall(RenderScriptCams, false, true, 250, true, true)
    if camera and DoesCamExist(camera) then pcall(DestroyCam, camera, false) end
    pcall(ClearFocus)
    if prop and DoesEntityExist(prop) then
        pcall(DetachEntity, prop, true, true)
        local deleted = pcall(function() props.Delete(prop) end)
        if (not deleted or DoesEntityExist(prop)) and DeleteEntity then pcall(DeleteEntity, prop) end
    end
    if ped and DoesEntityExist(ped) then pcall(FreezeEntityPosition, ped, wasFrozen == true) end
    pcall(SetPlayerInvincible, PlayerId(), wasInvincible == true)
    pcall(SendNUIMessage, { action = 'attachmentCreator', payload = nil })
    editor = { active = false }
    if cancelled and onCancel then pcall(onCancel) end
end

local function saveEditor()
    local bone = currentBone()
    local payload = {
        name = editor.name,
        model = editor.model,
        bone = { name = bone.name, id = bone.id },
        offset = { x = editor.offset.x, y = editor.offset.y, z = editor.offset.z },
        rotation = { x = editor.rotation.x, y = editor.rotation.y, z = editor.rotation.z },
    }
    if editor.animation.dict ~= '' and editor.animation.clip ~= '' then
        payload.animation = {
            dict = editor.animation.dict,
            clip = editor.animation.clip,
            flag = editor.animation.flag,
        }
    end
    local onSave = editor.onSave
    stopEditor(false)
    if onSave then onSave(payload) end
end

local function cycleBone(direction)
    editor.boneIndex = ((editor.boneIndex - 1 + direction) % #bones) + 1
    editor.drag = nil
    applyAttachment()
    sendHud(true, ('Bone changed to %s'):format(currentBone().name))
end

local function editorLoop()
    while editor.active do
        Wait(0)
        blockControls()
        local hovered
        if not editor.settingsOpen then
            updateCamera()
            local rightClick = IsDisabledControlJustPressed(0, 25)
            if rightClick then editor.ignoreCancelUntil = GetGameTimer() + 250 end

            if IsDisabledControlJustPressed(0, 29) then setSettingsOpen(true) end
            if IsDisabledControlJustPressed(0, 174) then cycleBone(-1) end
            if IsDisabledControlJustPressed(0, 175) then cycleBone(1) end
            if IsDisabledControlJustPressed(0, 37) then
                editor.mode = editor.mode == 'move' and 'rotate' or 'move'
                editor.drag = nil
                sendHud(true)
            end

            local looking = IsDisabledControlPressed(0, 25)
            if not looking and not editor.settingsOpen then
                SetMouseCursorActiveThisFrame()
                local mouseX, mouseY = GetDisabledControlNormal(0, 239), GetDisabledControlNormal(0, 240)
                hovered = editor.drag and editor.drag.handle or findHandle(mouseX, mouseY)
                if IsDisabledControlJustPressed(0, 24) then startDrag(hovered, mouseX, mouseY) end
                if editor.drag and IsDisabledControlPressed(0, 24) then updateDrag(mouseX, mouseY) end
                if editor.drag and IsDisabledControlJustReleased(0, 24) then editor.drag = nil end
            end
            if editor.drag and not IsDisabledControlPressed(0, 24) then editor.drag = nil end
        end
        drawGizmo(hovered)

        if not editor.settingsOpen then
            if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 201) then saveEditor() end
            if editor.active and IsDisabledControlJustPressed(0, 177)
                and GetGameTimer() > (editor.ignoreCancelUntil or 0) then stopEditor(true) end
        end
        if editor.active then sendHud(false) end
    end
end

function Creator.Start(name, model, props, callbacks)
    if editor.active then return false, 'The prop attachment editor is already active' end
    if type(props) ~= 'table' or not isCallable(props.Create) or not isCallable(props.Delete) then
        local ok, modules = pcall(function()
            return exports.tss_bridge:GetModules({ 'Props' })
        end)
        props = ok and type(modules) == 'table' and modules.Props or nil
        if type(props) ~= 'table' or not isCallable(props.Create) or not isCallable(props.Delete) then
            return false, ('Props module is unavailable%s'):format(ok and '' or (': ' .. tostring(modules)))
        end
    end
    local ped = PlayerPedId()
    local pedCoords = GetEntityCoords(ped)
    local prop = props.Create(model, pedCoords, { collision = false, freeze = false })
    if not prop then return false, ('Unable to load prop model %s'):format(tostring(model)) end

    local camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local cameraCoords, cameraRotation = GetGameplayCamCoord(), GetGameplayCamRot(2)
    SetCamCoord(camera, cameraCoords.x, cameraCoords.y, cameraCoords.z)
    SetCamRot(camera, cameraRotation.x, 0.0, cameraRotation.z, 2)
    SetCamFov(camera, GetGameplayCamFov())
    RenderScriptCams(true, true, 250, true, true)

    editor = {
        active = true,
        name = name,
        model = model,
        props = props,
        prop = prop,
        ped = ped,
        camera = camera,
        boneIndex = 17,
        -- Attachment transforms must stay mutable; FiveM vector3 values are immutable.
        offset = transform(0.0, 0.0, 0.0),
        rotation = transform(0.0, 0.0, 0.0),
        animation = { dict = '', clip = '', flag = 49 },
        settingsOpen = false,
        mode = 'move',
        speed = 3.0,
        wasFrozen = type(IsEntityPositionFrozen) == 'function' and IsEntityPositionFrozen(ped) or false,
        wasInvincible = GetPlayerInvincible(PlayerId()),
        onSave = callbacks and callbacks.onSave,
        onCancel = callbacks and callbacks.onCancel,
    }
    FreezeEntityPosition(ped, true)
    SetPlayerInvincible(PlayerId(), true)
    SetEntityCollision(prop, false, false)
    applyAttachment()
    sendHud(true)
    CreateThread(function()
        local ok, runtimeError = xpcall(editorLoop, function(message)
            return debug and debug.traceback and debug.traceback(tostring(message), 2) or tostring(message)
        end)
        if not ok then
            print(('^1[bridge_lab] Prop Attachment Creator stopped after an error: %s^7'):format(runtimeError))
            if editor.active then stopEditor(true) end
        end
    end)
    return true
end

function Creator.IsActive() return editor.active == true end
function Creator.Stop() stopEditor(true) end

RegisterNUICallback('attachmentCreatorAction', function(data, callback)
    callback({ ok = true })
    if not editor.active or type(data) ~= 'table' then return end
    updateAnimation(data)

    if data.action == 'bone' then
        local index = math.floor(tonumber(data.boneIndex) or editor.boneIndex)
        if bones[index] then
            editor.boneIndex = index
            editor.drag = nil
            applyAttachment()
            editor.message = ('Bone changed to %s'):format(currentBone().name)
            sendHud(true, editor.message)
        end
        return
    end
    if data.action == 'play' then return playAttachmentAnimation() end
    if data.action == 'stop' then
        stopAttachmentAnimation()
        editor.message = 'Animation stopped.'
        return sendHud(true, editor.message)
    end
    if data.action == 'close' then
        editor.message = nil
        setSettingsOpen(false)
    end
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() and editor.active then stopEditor(false) end
end)
