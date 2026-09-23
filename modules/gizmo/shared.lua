-- Reusable client gizmo engine. Consumers provide dynamic handle descriptors
-- and receive drag callbacks; the engine owns drawing, hit testing and input.
TSS = TSS or {}
TSS.Gizmo = TSS.Gizmo or {}

local Gizmo = TSS.Gizmo

local function isCallable(value)
    if type(value) == 'function' then return true end
    if type(value) ~= 'table' then return false end
    if rawget(value, '__cfx_functionReference') ~= nil then return true end
    local metatable = getmetatable(value)
    return metatable ~= nil and type(metatable.__call) == 'function'
end

local colors = {
    x = { 255, 65, 65 },
    y = { 65, 220, 105 },
    z = { 65, 135, 255 },
    rotate = { 255, 190, 40 },
    resize = { 235, 45, 45 },
}

local function vector(x, y, z) return vec3(x + 0.0, y + 0.0, z + 0.0) end
local function copy(value) return vector(value.x, value.y, value.z) end
local function add(a, b) return vector(a.x + b.x, a.y + b.y, a.z + b.z) end
local function subtract(a, b) return vector(a.x - b.x, a.y - b.y, a.z - b.z) end
local function multiply(value, scalar) return vector(value.x * scalar, value.y * scalar, value.z * scalar) end
local function dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end
local function magnitude(value) return math.sqrt(dot(value, value)) end
local function normalise(value)
    local length = magnitude(value)
    return length > 0.00001 and multiply(value, 1.0 / length) or vector(0.0, 0.0, 0.0)
end
local function project(coords)
    local visible, x, y = GetScreenCoordFromWorldCoord(coords.x, coords.y, coords.z)
    return visible, x, y
end
local function screenDistance(ax, ay, bx, by)
    return math.sqrt((ax - bx) ^ 2 + (ay - by) ^ 2)
end
local function pointToSegmentDistance(px, py, ax, ay, bx, by)
    local dx, dy = bx - ax, by - ay
    local lengthSquared = dx * dx + dy * dy
    if lengthSquared <= 0.000001 then return screenDistance(px, py, ax, ay) end
    local t = math.max(0.0, math.min(1.0, ((px - ax) * dx + (py - ay) * dy) / lengthSquared))
    return screenDistance(px, py, ax + dx * t, ay + dy * t)
end

local function line(a, b, color, alpha)
    DrawLine(a.x, a.y, a.z, b.x, b.y, b.z, color[1], color[2], color[3], alpha or 235)
end

local function marker(coords, size, color, alpha)
    DrawMarker(28, coords.x, coords.y, coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        size, size, size, color[1], color[2], color[3], alpha or 235,
        false, false, 2, false, nil, nil, false)
end

local function ringPoint(handle, angle)
    return add(handle.center, add(
        multiply(handle.first, math.cos(angle) * handle.radius),
        multiply(handle.second, math.sin(angle) * handle.radius)
    ))
end

local function sameHandle(a, b)
    return a ~= nil and b ~= nil and a.id ~= nil and a.id == b.id
end

local function hitTest(handles, mouseX, mouseY)
    local closest, best, bestPriority = nil, math.huge, -1
    for i = 1, #handles do
        local handle = handles[i]
        local hitRadius = handle.hitRadius or (handle.kind == 'ring' and 0.015 or 0.025)
        local distance
        if handle.kind == 'ring' then
            distance = math.huge
            for segment = 0, (handle.segments or 48) - 1 do
                local visible, x, y = project(ringPoint(handle, (math.pi * 2.0) * (segment / (handle.segments or 48))))
                if visible then distance = math.min(distance, screenDistance(mouseX, mouseY, x, y)) end
            end
        elseif handle.kind == 'axis' then
            local originVisible, originX, originY = project(handle.origin)
            local endVisible, endX, endY = project(handle.position)
            if originVisible and endVisible then
                distance = pointToSegmentDistance(mouseX, mouseY, originX, originY, endX, endY)
            end
        else
            local visible, x, y = project(handle.position)
            if visible then distance = screenDistance(mouseX, mouseY, x, y) end
        end
        local priority = handle.priority or (handle.kind == 'point' and 2 or (handle.kind == 'ring' and 1 or 0))
        if distance and distance <= hitRadius
            and (priority > bestPriority or (priority == bestPriority and distance < best)) then
            closest, best, bestPriority = handle, distance, priority
        end
    end
    return closest
end

local function drawHandles(handles, selected)
    for i = 1, #handles do
        local handle = handles[i]
        local active = sameHandle(selected, handle)
        local color = handle.color or colors[handle.axis] or colors.resize
        if handle.kind == 'ring' then
            local previous
            for segment = 0, (handle.segments or 48) do
                local point = ringPoint(handle, (math.pi * 2.0) * (segment / (handle.segments or 48)))
                if previous then line(previous, point, color, active and 255 or (handle.alpha or 190)) end
                previous = point
            end
        elseif handle.kind == 'axis' then
            line(handle.origin, handle.position, color, handle.alpha or 245)
            marker(handle.position, active and (handle.hoverSize or 0.075) or (handle.size or 0.045), color, 245)
        else
            marker(handle.position, active and (handle.hoverSize or 0.075) or (handle.size or 0.05),
                active and (handle.hoverColor or { 255, 210, 45 }) or color, 245)
        end
    end
end

--- Creates a screen-space linear drag mapped onto a world-space handle.
---@param origin vector3
---@param endpoint vector3
---@param mouseX number
---@param mouseY number
---@param reference? number World-space distance represented by the handle.
---@return table? drag
function Gizmo.LinearDrag(origin, endpoint, mouseX, mouseY, reference)
    local originVisible, originX, originY = project(origin)
    local endVisible, endX, endY = project(endpoint)
    if not originVisible or not endVisible then return nil end
    local screenX, screenY = endX - originX, endY - originY
    local screenLengthSquared = screenX * screenX + screenY * screenY
    if screenLengthSquared < 0.000001 then return nil end
    return {
        mouseX = mouseX,
        mouseY = mouseY,
        screenX = screenX,
        screenY = screenY,
        screenLengthSquared = screenLengthSquared,
        reference = reference or magnitude(subtract(endpoint, origin)),
    }
end

--- Converts cursor movement into signed world-space movement along a linear handle.
function Gizmo.LinearDisplacement(drag, mouseX, mouseY, precision)
    local dx, dy = mouseX - drag.mouseX, mouseY - drag.mouseY
    return (((dx * drag.screenX) + (dy * drag.screenY)) / drag.screenLengthSquared)
        * drag.reference * (precision or 1.0)
end

function Gizmo.CameraBasis(rotation)
    local pitch, yaw = math.rad(rotation.x), math.rad(rotation.z)
    local cosPitch = math.cos(pitch)
    return normalise(vector(-math.sin(yaw) * cosPitch, math.cos(yaw) * cosPitch, math.sin(pitch))),
        normalise(vector(math.cos(yaw), math.sin(yaw), 0.0)),
        normalise(vector(math.sin(yaw) * math.sin(pitch), -math.cos(yaw) * math.sin(pitch), cosPitch))
end

function Gizmo.WorldAxes()
    return { x = vector(1, 0, 0), y = vector(0, 1, 0), z = vector(0, 0, 1) }
end

function Gizmo.EntityAxes(entity)
    if not entity or not DoesEntityExist(entity) then return Gizmo.WorldAxes() end
    local forward, right, up = GetEntityMatrix(entity)
    return { x = normalise(right), y = normalise(forward), z = normalise(up) }
end

function Gizmo.RingBasis(component, axes)
    if component == 'x' then return axes.y, axes.z end
    if component == 'y' then return axes.x, axes.z end
    return axes.x, axes.y
end

function Gizmo.AxisHandle(id, origin, direction, distance, axis, options)
    options = options or {}
    return {
        id = id, kind = 'axis', axis = axis, origin = origin, direction = direction,
        distance = distance, position = add(origin, multiply(direction, distance)),
        color = options.color or colors[axis], size = options.size, hoverSize = options.hoverSize,
        hitRadius = options.hitRadius, alpha = options.alpha, priority = options.priority, data = options.data,
    }
end

function Gizmo.PointHandle(id, position, options)
    options = options or {}
    return {
        id = id, kind = 'point', position = position, direction = options.direction,
        color = options.color or colors.resize, hoverColor = options.hoverColor,
        size = options.size, hoverSize = options.hoverSize, hitRadius = options.hitRadius,
        priority = options.priority, data = options.data,
    }
end

function Gizmo.RingHandle(id, center, first, second, radius, options)
    options = options or {}
    return {
        id = id, kind = 'ring', center = center, first = first, second = second,
        radius = radius, color = options.color or colors.rotate, hitRadius = options.hitRadius,
        segments = options.segments, alpha = options.alpha, priority = options.priority,
        axis = options.axis, data = options.data,
    }
end

--- Creates an embedded gizmo controller.
---@param options table Dynamic handles and drag callbacks.
---@return table controller
function Gizmo.Create(options)
    assert(type(options) == 'table', 'Gizmo.Create expects options')
    assert(isCallable(options.handles), 'Gizmo.Create expects a handles callback')
    local controller = { mode = options.mode or 'move', drag = nil, hovered = nil, enabled = true }

    function controller:SetMode(mode)
        self:FinishDrag(true)
        self.mode = mode
    end

    function controller:GetMode() return self.mode end
    function controller:IsDragging() return self.drag ~= nil end
    function controller:GetHandle() return self.drag and self.drag.handle or self.hovered end
    function controller:SetEnabled(state) self.enabled = state ~= false end

    function controller:FinishDrag(cancelled)
        local drag = self.drag
        if not drag then return end
        self.drag = nil
        if options.onDragEnd then options.onDragEnd(drag.handle, drag.state, cancelled == true) end
    end

    function controller:Tick(input)
        input = input or {}
        local enabled = self.enabled and input.enabled ~= false
        local handles = options.handles(self.mode) or {}
        local mouseX = input.mouseX or GetDisabledControlNormal(0, 239)
        local mouseY = input.mouseY or GetDisabledControlNormal(0, 240)

        if enabled and input.cursor ~= false then SetMouseCursorActiveThisFrame() end
        self.hovered = self.drag and self.drag.handle or (enabled and hitTest(handles, mouseX, mouseY) or nil)

        local pressed = input.pressed
        if pressed == nil then pressed = IsDisabledControlJustPressed(0, 24) end
        local held = input.held
        if held == nil then held = IsDisabledControlPressed(0, 24) end
        local released = input.released
        if released == nil then released = IsDisabledControlJustReleased(0, 24) end

        if enabled and pressed and self.hovered and not self.drag then
            local state = options.onDragStart and options.onDragStart(self.hovered, mouseX, mouseY)
            if state ~= false then self.drag = { handle = self.hovered, state = state } end
        end
        if enabled and self.drag and held and options.onDrag then
            local precision = input.precision
            if precision == nil then precision = IsDisabledControlPressed(0, 36) and (options.precision or 0.2) or 1.0 end
            options.onDrag(self.drag.handle, self.drag.state, mouseX, mouseY, precision)
        end
        if self.drag and (released or not held) then self:FinishDrag(false) end

        if input.draw ~= false then drawHandles(handles, self.drag and self.drag.handle or self.hovered) end
        return self.hovered, self.drag ~= nil
    end

    function controller:Draw()
        local handles = options.handles(self.mode) or {}
        drawHandles(handles, self.drag and self.drag.handle or self.hovered)
    end

    return controller
end

Gizmo.Vector = vector
Gizmo.Copy = copy
Gizmo.Add = add
Gizmo.Subtract = subtract
Gizmo.Multiply = multiply
Gizmo.Dot = dot
Gizmo.Magnitude = magnitude
Gizmo.Normalise = normalise
Gizmo.Project = project
Gizmo.ScreenDistance = screenDistance
Gizmo.Colors = colors
