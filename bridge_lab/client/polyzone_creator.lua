-- Standalone Bridge Lab zone editor. The reference PolyZone resource is not loaded or required.
TSSBridgeLabPolyZoneCreator = {}

local Creator = TSSBridgeLabPolyZoneCreator
local editor = { active = false }
local minimumSize = 0.1
-- Requesting the module also loads its shared implementation. Reading
-- TSS.Gizmo directly here is too early because bridge modules are lazy-loaded.
local Gizmo = TSSModuleLoader.GetModules({ 'Gizmo' }).Gizmo

local function vector(x, y, z)
    return vec3(x + 0.0, y + 0.0, z + 0.0)
end

local function copy(value)
    return vector(value.x, value.y, value.z)
end

local function add(a, b)
    return vector(a.x + b.x, a.y + b.y, a.z + b.z)
end

local function subtract(a, b)
    return vector(a.x - b.x, a.y - b.y, a.z - b.z)
end

local function multiply(value, scalar)
    return vector(value.x * scalar, value.y * scalar, value.z * scalar)
end

local function dot(a, b)
    return (a.x * b.x) + (a.y * b.y) + (a.z * b.z)
end

local function magnitude(value)
    return math.sqrt(dot(value, value))
end

local function normalized(value)
    local length = magnitude(value)
    if length < 0.00001 then return vector(0.0, 0.0, 0.0) end
    return multiply(value, 1.0 / length)
end

local function cameraBasis(rotation)
    local pitch = math.rad(rotation.x)
    local yaw = math.rad(rotation.z)
    local cosPitch = math.cos(pitch)
    local forward = vector(-math.sin(yaw) * cosPitch, math.cos(yaw) * cosPitch, math.sin(pitch))
    local right = vector(math.cos(yaw), math.sin(yaw), 0.0)
    local up = vector(math.sin(yaw) * math.sin(pitch), -math.cos(yaw) * math.sin(pitch), cosPitch)
    return normalized(forward), normalized(right), normalized(up)
end

local function boxBasis(heading)
    local angle = math.rad(heading or 0.0)
    return vector(math.cos(angle), math.sin(angle), 0.0), vector(-math.sin(angle), math.cos(angle), 0.0)
end

local function project(coords)
    local visible, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    return visible, x, y
end

local function marker(coords, size, r, g, b, a)
    DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        size, size, size, r, g, b, a or 210, false, false, 2, false, nil, nil, false)
end

local function line(from, to, r, g, b, a)
    DrawLine(from.x, from.y, from.z, to.x, to.y, to.z, r, g, b, a or 230)
end

local function drawCircle(center, radius, axis, r, g, b, a)
    local previous
    for i = 0, 48 do
        local angle = (math.pi * 2.0) * (i / 48)
        local point
        if axis == 'x' then
            point = vector(center.x, center.y + math.cos(angle) * radius, center.z + math.sin(angle) * radius)
        elseif axis == 'y' then
            point = vector(center.x + math.cos(angle) * radius, center.y, center.z + math.sin(angle) * radius)
        else
            point = vector(center.x + math.cos(angle) * radius, center.y + math.sin(angle) * radius, center.z)
        end
        if previous then line(previous, point, r, g, b, a) end
        previous = point
    end
end

local function drawQuad(a, b, c, d, r, g, blue, alpha)
    DrawPoly(a.x, a.y, a.z, b.x, b.y, b.z, c.x, c.y, c.z, r, g, blue, alpha)
    DrawPoly(a.x, a.y, a.z, c.x, c.y, c.z, d.x, d.y, d.z, r, g, blue, alpha)
    DrawPoly(c.x, c.y, c.z, b.x, b.y, b.z, a.x, a.y, a.z, r, g, blue, alpha)
    DrawPoly(d.x, d.y, d.z, c.x, c.y, c.z, a.x, a.y, a.z, r, g, blue, alpha)
end

local function boxVertices(zone)
    local right, forward = boxBasis(zone.heading)
    local halfWidth, halfLength, halfHeight = zone.width / 2.0, zone.length / 2.0, zone.height / 2.0
    local bottom, top = zone.coords.z - halfHeight, zone.coords.z + halfHeight
    local corners = {}

    local signs = { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } }
    for i = 1, 4 do
        local offset = add(multiply(right, signs[i][1] * halfWidth), multiply(forward, signs[i][2] * halfLength))
        corners[i] = vector(zone.coords.x + offset.x, zone.coords.y + offset.y, bottom)
        corners[i + 4] = vector(zone.coords.x + offset.x, zone.coords.y + offset.y, top)
    end
    return corners
end

local function drawBox(zone)
    local vertices = boxVertices(zone)
    for i = 1, 4 do
        local nextIndex = i == 4 and 1 or i + 1
        line(vertices[i], vertices[nextIndex], 50, 205, 255, 235)
        line(vertices[i + 4], vertices[nextIndex + 4], 50, 205, 255, 235)
        line(vertices[i], vertices[i + 4], 50, 205, 255, 235)
    end

    drawQuad(vertices[1], vertices[2], vertices[3], vertices[4], 25, 145, 210, 30)
    drawQuad(vertices[5], vertices[8], vertices[7], vertices[6], 25, 145, 210, 30)
    drawQuad(vertices[1], vertices[5], vertices[6], vertices[2], 25, 145, 210, 24)
    drawQuad(vertices[2], vertices[6], vertices[7], vertices[3], 25, 145, 210, 24)
    drawQuad(vertices[3], vertices[7], vertices[8], vertices[4], 25, 145, 210, 24)
    drawQuad(vertices[4], vertices[8], vertices[5], vertices[1], 25, 145, 210, 24)
end

local function drawSphere(zone)
    drawCircle(zone.coords, zone.radius, 'x', 50, 205, 255, 220)
    drawCircle(zone.coords, zone.radius, 'y', 50, 205, 255, 220)
    drawCircle(zone.coords, zone.radius, 'z', 50, 205, 255, 220)
end

local function gizmoLength()
    local cameraCoords = GetCamCoord(editor.camera)
    local zone = editor.zone
    local extent = editor.type == 'circle' and zone.radius
        or math.max(zone.width or 0.0, zone.length or 0.0, zone.height or 0.0) / 2.0
    local padding = math.max(0.25, math.min(0.65, magnitude(subtract(zone.coords, cameraCoords)) * 0.035))
    return math.min(4.0, extent + padding)
end

local function rotationRadius()
    return gizmoLength() * 0.9
end

local function screenDistance(x1, y1, x2, y2)
    local dx, dy = x1 - x2, y1 - y2
    return math.sqrt((dx * dx) + (dy * dy))
end

local function zoneGizmoHandles()
    local zone, center = editor.zone, editor.zone.coords
    local world = Gizmo.WorldAxes()
    local handles, length = {}, gizmoLength()
    for _, axis in ipairs({ 'x', 'y', 'z' }) do
        handles[#handles + 1] = Gizmo.AxisHandle('move_' .. axis, center, world[axis], length, axis,
            { size = 0.04, hoverSize = 0.06, data = { kind = 'move', distance = length } })
    end

    if editor.type == 'circle' then
        local position = add(center, multiply(world.x, zone.radius))
        handles[#handles + 1] = Gizmo.PointHandle('radius', position, {
            direction = world.x,
            data = { kind = 'radius', distance = zone.radius },
        })
        return handles
    end

    local right, forward = boxBasis(zone.heading)
    local dimensions = {
        { name = 'width', direction = right, distance = zone.width / 2.0 },
        { name = 'length', direction = forward, distance = zone.length / 2.0 },
        { name = 'height', direction = world.z, distance = zone.height / 2.0 },
    }
    for i = 1, #dimensions do
        local dimension = dimensions[i]
        for _, sign in ipairs({ -1.0, 1.0 }) do
            local direction = multiply(dimension.direction, sign)
            handles[#handles + 1] = Gizmo.PointHandle(
                ('resize_%s_%s'):format(dimension.name, sign < 0 and 'negative' or 'positive'),
                add(center, multiply(direction, dimension.distance)), {
                    direction = direction,
                    data = { kind = 'resize', dimension = dimension.name, distance = dimension.distance },
                })
        end
    end
    handles[#handles + 1] = Gizmo.RingHandle('heading', center, world.x, world.y, rotationRadius(),
        { axis = 'z', color = { 255, 190, 40 }, hitRadius = 0.014 })
    return handles
end

local function createZoneGizmo()
    return Gizmo.Create({
        mode = 'transform',
        handles = zoneGizmoHandles,
        onDragStart = function(handle, mouseX, mouseY)
            local zone = editor.zone
            local state = {
                center = copy(zone.coords), width = zone.width, length = zone.length,
                height = zone.height, radius = zone.radius, heading = zone.heading,
            }
            if handle.kind == 'ring' then
                local visible, centerX, centerY = project(zone.coords)
                if not visible then return false end
                state.centerX, state.centerY = centerX, centerY
                state.angle = math.atan(mouseY - centerY, mouseX - centerX)
            else
                state.linear = Gizmo.LinearDrag(zone.coords, handle.position, mouseX, mouseY,
                    handle.data and handle.data.distance)
                if not state.linear then return false end
            end
            return state
        end,
        onDrag = function(handle, state, mouseX, mouseY, precision)
            if handle.kind == 'ring' then
                local angle = math.atan(mouseY - state.centerY, mouseX - state.centerX)
                editor.zone.heading = (state.heading + math.deg(angle - state.angle)) % 360.0
                return
            end
            local displacement = Gizmo.LinearDisplacement(state.linear, mouseX, mouseY, precision)
            local kind = handle.data and handle.data.kind
            if kind == 'move' then
                editor.zone.coords = add(state.center, multiply(handle.direction, displacement))
            elseif kind == 'radius' then
                editor.zone.radius = math.max(minimumSize, state.radius + displacement)
            elseif kind == 'resize' then
                local dimension = handle.data.dimension
                local original = state[dimension]
                local nextValue = math.max(minimumSize, original + displacement)
                local applied = nextValue - original
                editor.zone[dimension] = nextValue
                editor.zone.coords = add(state.center, multiply(handle.direction, applied / 2.0))
            end
        end,
    })
end

local disabledControls = { 1, 2, 14, 15, 16, 17, 24, 25, 30, 31, 32, 33, 34, 35, 36, 37, 38, 44, 140, 141, 142, 177, 191, 200, 201, 239, 240 }

local function blockControls()
    for i = 1, #disabledControls do DisableControlAction(0, disabledControls[i], true) end
    DisablePlayerFiring(PlayerId(), true)
end

local function updateCamera(polyMode)
    local rotation = GetCamRot(editor.camera, 2)
    local coords = GetCamCoord(editor.camera)
    local looking = polyMode or IsDisabledControlPressed(0, 25)

    if looking then
        rotation = vector(
            math.max(-89.0, math.min(89.0, rotation.x - (GetDisabledControlNormal(0, 2) * 7.5))),
            0.0,
            rotation.z - (GetDisabledControlNormal(0, 1) * 7.5)
        )
    end

    if not polyMode then
        if IsDisabledControlJustPressed(0, 15) then editor.speed = math.min(40.0, editor.speed * 1.35) end
        if IsDisabledControlJustPressed(0, 14) then editor.speed = math.max(0.5, editor.speed / 1.35) end
    end

    local forward, right = cameraBasis(rotation)
    local speed = editor.speed * math.max(GetFrameTime(), 0.001)
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

local function raycastFromCamera()
    if editor.rayHandle then
        local status, hit, endCoords, normal = GetShapeTestResult(editor.rayHandle)
        if status ~= 1 then
            editor.rayHandle = nil
            if hit == 1 then
                editor.rayHit = copy(endCoords)
                editor.rayNormal = normal
            else
                editor.rayHit = nil
            end
        end
    end

    if not editor.rayHandle then
        local coords = GetCamCoord(editor.camera)
        local forward = cameraBasis(GetCamRot(editor.camera, 2))
        local destination = add(coords, multiply(forward, 1000.0))
        editor.rayHandle = StartShapeTestLosProbe(coords.x, coords.y, coords.z,
            destination.x, destination.y, destination.z, 1, PlayerPedId(), 7)
    end
end

local function recalculatePolygonGround()
    local zone = editor.zone
    local minZ, groundZ
    for i = 1, #zone.points do
        local z = zone.points[i].z
        minZ = not minZ and z or math.min(minZ, z)
        groundZ = not groundZ and z or math.max(groundZ, z)
    end

    zone.minZ = minZ
    zone.groundZ = groundZ
    zone.height = math.max(0.0, zone.height or 0.0)
    zone.maxZ = groundZ and (groundZ + zone.height) or nil
end

local function updatePolygonHeight()
    local zone = editor.zone
    if not zone.groundZ then return end

    local step = IsDisabledControlPressed(0, 36) and 0.05 or 0.25
    if IsDisabledControlPressed(0, 21) then step = 1.0 end
    if IsDisabledControlJustPressed(0, 15) then zone.height = zone.height + step end
    if IsDisabledControlJustPressed(0, 14) then zone.height = math.max(0.0, zone.height - step) end
    zone.maxZ = zone.groundZ + zone.height
end

local function polygonPointAtCrosshair()
    local closest, closestDistance = nil, 0.018
    for i = 1, #editor.zone.points do
        local visible, x, y = project(editor.zone.points[i])
        if visible then
            local distance = screenDistance(0.5, 0.5, x, y)
            if distance < closestDistance then
                closest, closestDistance = i, distance
            end
        end
    end
    return closest
end

local function drawPolygon(hoveredPoint)
    local zone = editor.zone
    local points = zone.points
    for i = 1, #points do
        local selected = editor.polyDrag == i
        local hovered = hoveredPoint == i
        marker(points[i], selected and 0.08 or (hovered and 0.07 or 0.055),
            255,
            (hovered or selected) and 205 or 65,
            65,
            240)
        if i > 1 then line(points[i - 1], points[i], 50, 205, 255, 240) end
    end
    if #points > 2 then line(points[#points], points[1], 50, 205, 255, 150) end

    if zone.height and zone.height > 0.001 and #points >= 2 then
        local edgeCount = #points > 2 and #points or (#points - 1)
        for i = 1, edgeCount do
            local nextIndex = i == #points and 1 or i + 1
            local bottomA, bottomB = points[i], points[nextIndex]
            local topA = vector(bottomA.x, bottomA.y, zone.maxZ)
            local topB = vector(bottomB.x, bottomB.y, zone.maxZ)
            line(bottomA, topA, 50, 205, 255, 185)
            line(topA, topB, 50, 205, 255, 225)
            drawQuad(bottomA, bottomB, topB, topA, 25, 145, 210, 32)
        end
    end

    if editor.rayHit and not editor.polyDrag then
        marker(editor.rayHit, 0.065, 255, 65, 65, 245)
        if #points > 0 then line(points[#points], editor.rayHit, 255, 205, 65, 190) end
    end

    local crosshairR, crosshairG, crosshairB = 255, hoveredPoint and 205 or 255, hoveredPoint and 65 or 255
    DrawRect(0.5, 0.5, 0.002, 0.018, crosshairR, crosshairG, crosshairB, 210)
    DrawRect(0.5, 0.5, 0.010, 0.002, crosshairR, crosshairG, crosshairB, 210)
end

local function zonePayload()
    local zone = editor.zone
    if editor.type == 'box' then
        return {
            type = 'box', name = editor.name,
            coords = { x = zone.coords.x, y = zone.coords.y, z = zone.coords.z },
            width = zone.width, length = zone.length, height = zone.height, heading = zone.heading,
        }
    end
    if editor.type == 'circle' then
        return {
            type = 'circle', name = editor.name,
            coords = { x = zone.coords.x, y = zone.coords.y, z = zone.coords.z }, radius = zone.radius,
        }
    end

    local points = {}
    for i = 1, #zone.points do
        local point = zone.points[i]
        points[i] = { x = point.x, y = point.y, z = point.z }
    end
    return { type = 'poly', name = editor.name, points = points, minZ = zone.minZ, maxZ = zone.maxZ }
end

local function hudPayload(message)
    local zone = editor.zone
    local metrics
    if editor.type == 'box' then
        metrics = {
            { label = 'Position', value = ('%.2f, %.2f, %.2f'):format(zone.coords.x, zone.coords.y, zone.coords.z) },
            { label = 'Size', value = ('%.2f × %.2f × %.2f'):format(zone.width, zone.length, zone.height) },
            { label = 'Heading', value = ('%.1f°'):format(zone.heading) },
        }
    elseif editor.type == 'circle' then
        metrics = {
            { label = 'Position', value = ('%.2f, %.2f, %.2f'):format(zone.coords.x, zone.coords.y, zone.coords.z) },
            { label = 'Radius', value = ('%.2f'):format(zone.radius) },
            { label = 'Shape', value = '3D sphere' },
        }
    else
        metrics = {
            { label = 'Points', value = tostring(#zone.points) },
            { label = 'Max Z', value = zone.maxZ and ('%.2f'):format(zone.maxZ) or 'Place a point' },
            { label = 'Wall height', value = ('%.2f'):format(zone.height or 0.0) },
        }
    end

    return {
        visible = true,
        title = editor.name,
        zoneType = editor.type,
        mode = editor.type == 'poly' and (editor.polyDrag and 'MOVING POINT' or 'DRAW MODE')
            or (editor.gizmo and editor.gizmo:IsDragging() and 'DRAGGING' or 'GIZMO MODE'),
        metrics = metrics,
        message = message or editor.message,
        help = editor.type == 'poly' and {
            'WASD move · Q/E down/up · Mouse look · Wheel adjusts maxZ',
            'Left click place · Aim at a point and left-drag to move it',
            'Right click remove last point',
            'Enter save · Backspace cancel and delete draft',
        } or {
            'WASD move · Q/E down/up · Hold RMB to look · Wheel speed',
            'Left-drag axis to move · Drag red handles to resize',
            editor.type == 'box' and 'Drag yellow ring to rotate · Enter save · Backspace cancel'
                or 'Enter save · Backspace cancel',
        },
    }
end

local function sendHud(force, message)
    local now = GetGameTimer()
    if not force and now < (editor.nextHud or 0) then return end
    editor.nextHud = now + 100
    SendNUIMessage({ action = 'zoneCreator', payload = hudPayload(message) })
end

local function stopEditor(cancelled)
    if not editor.active then return end
    if editor.gizmo then editor.gizmo:FinishDrag(true) end
    local onCancel = editor.onCancel
    editor.active = false

    RenderScriptCams(false, true, 250, true, true)
    if editor.camera and DoesCamExist(editor.camera) then DestroyCam(editor.camera, false) end
    ClearFocus()

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, editor.wasFrozen == true)
    SetPlayerInvincible(PlayerId(), editor.wasInvincible == true)
    SendNUIMessage({ action = 'zoneCreator', payload = nil })

    editor = { active = false }
    if cancelled and onCancel then onCancel() end
end

local function saveEditor()
    if editor.type == 'poly' and #editor.zone.points < 3 then
        editor.message = 'Place at least three points before saving.'
        return sendHud(true, editor.message)
    end

    local payload = zonePayload()
    local onSave = editor.onSave
    stopEditor(false)
    if onSave then onSave(payload) end
end

local function editorLoop()
    while editor.active do
        Wait(0)
        blockControls()
        local polyMode = editor.type == 'poly'
        local looking = IsDisabledControlPressed(0, 25)
        if looking then
            -- RMB is also reported as frontend cancel (177) by GTA. Keep a
            -- short release grace period so camera look can never close the editor.
            editor.ignoreCancelUntil = GetGameTimer() + 150
        end
        updateCamera(polyMode)

        if polyMode then
            raycastFromCamera()
            updatePolygonHeight()
            local hoveredPoint = editor.polyDrag or polygonPointAtCrosshair()
            local rightClick = IsDisabledControlJustPressed(0, 25)

            if IsDisabledControlJustPressed(0, 24) then
                if hoveredPoint then
                    editor.polyDrag = hoveredPoint
                    editor.message = ('Moving point %d'):format(hoveredPoint)
                elseif editor.rayHit and #editor.zone.points < 128 then
                    editor.zone.points[#editor.zone.points + 1] = copy(editor.rayHit)
                    recalculatePolygonGround()
                    editor.message = nil
                end
            end
            if editor.polyDrag and IsDisabledControlPressed(0, 24) and editor.rayHit then
                editor.zone.points[editor.polyDrag] = copy(editor.rayHit)
                recalculatePolygonGround()
            end
            if editor.polyDrag and IsDisabledControlJustReleased(0, 24) then
                editor.polyDrag = nil
                editor.message = nil
            elseif editor.polyDrag and not IsDisabledControlPressed(0, 24) then
                editor.polyDrag = nil
                editor.message = nil
            end
            if rightClick and #editor.zone.points > 0 then
                editor.polyDrag = nil
                editor.zone.points[#editor.zone.points] = nil
                recalculatePolygonGround()
                editor.message = nil
            end
            drawPolygon(hoveredPoint)
        else
            if editor.type == 'box' then drawBox(editor.zone) else drawSphere(editor.zone) end
            editor.gizmo:Tick({ enabled = not looking, cursor = not looking })
        end

        if IsDisabledControlJustPressed(0, 191) or IsDisabledControlJustPressed(0, 201) then saveEditor() end
        if editor.active and not looking and IsDisabledControlJustPressed(0, 177)
            and GetGameTimer() > (editor.ignoreCancelUntil or 0) then
            stopEditor(true)
        end
        if editor.active then sendHud(false) end
    end
end

--- Starts a box, circle, or polygon editor in detached freecam mode.
---@param zoneType 'box'|'circle'|'poly'
---@param name string
---@param callbacks table
---@return boolean started
function Creator.Start(zoneType, name, callbacks)
    if editor.active then return false end
    if zoneType ~= 'box' and zoneType ~= 'circle' and zoneType ~= 'poly' then return false end

    if callbacks ~= nil and type(callbacks) ~= 'table' then return false end
    local initial = callbacks and callbacks.initialZone
    if initial ~= nil and type(initial) ~= 'table' then return false end
    local function validPoint(point)
        if type(point) ~= 'table' and type(point) ~= 'vector3' and type(point) ~= 'vector2' then return false end
        for _, axis in ipairs({ 'x', 'y' }) do
            if type(point[axis]) ~= 'number' or point[axis] ~= point[axis] or math.abs(point[axis]) > 100000 then return false end
        end
        if type(point) == 'vector2' then return true end
        return point.z == nil or type(point.z) == 'number' and point.z == point.z and math.abs(point.z) < 100000
    end
    if initial and zoneType == 'poly' then
        if type(initial.points) ~= 'table' or #initial.points > 128 then return false end
        for _, point in ipairs(initial.points) do if not validPoint(point) then return false end end
    end
    if callbacks and callbacks.cameraCoords and (not validPoint(callbacks.cameraCoords) or callbacks.cameraCoords.z == nil) then return false end
    if callbacks and callbacks.cameraRotation and (not validPoint(callbacks.cameraRotation) or callbacks.cameraRotation.z == nil) then return false end

    if initial then
        if initial.coords and (not validPoint(initial.coords) or initial.coords.z == nil) then return false end
        for _, field in ipairs({ 'minZ', 'maxZ', 'radius', 'width', 'length', 'height', 'heading' }) do
            local value = initial[field]
            if value ~= nil and (type(value) ~= 'number' or value ~= value or math.abs(value) > 100000) then return false end
        end
    end
    local ped = PlayerPedId()
    local camera = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local cameraCoords = GetGameplayCamCoord()
    local cameraRotation = GetGameplayCamRot(2)
    SetCamCoord(camera, cameraCoords.x, cameraCoords.y, cameraCoords.z)
    SetCamRot(camera, cameraRotation.x, 0.0, cameraRotation.z, 2)
    SetCamFov(camera, GetGameplayCamFov())
    RenderScriptCams(true, true, 250, true, true)

    local playerCoords = GetEntityCoords(ped)
    local zone
    if zoneType == 'box' then
        zone = {
            coords = vector(playerCoords.x, playerCoords.y, playerCoords.z + 0.5),
            width = 1.0, length = 1.0, height = 1.0, heading = GetEntityHeading(ped),
        }
    elseif zoneType == 'circle' then
        zone = { coords = vector(playerCoords.x, playerCoords.y, playerCoords.z + 1.0), radius = 1.0 }
    else
        zone = { points = {}, height = 0.0 }
    end

    if initial then
        if zoneType == 'poly' then
            for _, point in ipairs(initial.points or {}) do
                zone.points[#zone.points + 1] = vector(point.x, point.y, point.z or initial.minZ or playerCoords.z)
            end
            zone.height = math.max(0.0, (initial.maxZ or initial.minZ or playerCoords.z) - (initial.minZ or playerCoords.z))
        elseif zoneType == 'circle' then
            zone.coords = copy(initial.coords or zone.coords)
            zone.radius = math.max(minimumSize, initial.radius or zone.radius)
        elseif zoneType == 'box' then
            zone.coords = copy(initial.coords or zone.coords)
            zone.width = math.max(minimumSize, initial.width or zone.width)
            zone.length = math.max(minimumSize, initial.length or zone.length)
            zone.height = math.max(minimumSize, initial.height or zone.height)
            zone.heading = initial.heading or zone.heading
        end
    end
    if callbacks and callbacks.cameraCoords then
        local position = callbacks.cameraCoords
        SetCamCoord(camera, position.x, position.y, position.z)
    end
    if callbacks and callbacks.cameraRotation then
        local rotation = callbacks.cameraRotation
        SetCamRot(camera, rotation.x, rotation.y, rotation.z, 2)
    end

    editor = {
        active = true,
        type = zoneType,
        name = name,
        zone = zone,
        camera = camera,
        speed = 6.0,
        wasFrozen = type(IsEntityPositionFrozen) == 'function' and IsEntityPositionFrozen(ped) or false,
        wasInvincible = GetPlayerInvincible(PlayerId()),
        onSave = callbacks and callbacks.onSave,
        onCancel = callbacks and callbacks.onCancel,
        owner = callbacks and callbacks.owner,
    }
    if zoneType ~= 'poly' then editor.gizmo = createZoneGizmo() else recalculatePolygonGround() end

    FreezeEntityPosition(ped, true)
    SetPlayerInvincible(PlayerId(), true)
    sendHud(true)
    CreateThread(editorLoop)
    return true
end

function Creator.IsActive()
    return editor.active == true
end

function Creator.Stop()
    stopEditor(true)
end

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() and editor.active then stopEditor(false) end
end)

-- Consumer resources receive drafts through callbacks; only Bridge Lab chooses to write Lua files.
exports('StartZoneCreator', function(zoneType, name, options)
    if options ~= nil and type(options) ~= 'table' then return false end
    local settings = {}
    for key, value in pairs(options or {}) do settings[key] = value end
    settings.owner = GetInvokingResource() or GetCurrentResourceName()
    return Creator.Start(zoneType, name, settings)
end)

exports('IsZoneCreatorActive', function()
    return Creator.IsActive()
end)

exports('StopZoneCreator', function()
    local owner = GetInvokingResource() or GetCurrentResourceName()
    if editor.active and editor.owner ~= owner then return false end
    Creator.Stop()
    return true
end)

AddEventHandler('onClientResourceStop', function(resource)
    if editor.active and editor.owner == resource then stopEditor(false) end
end)
