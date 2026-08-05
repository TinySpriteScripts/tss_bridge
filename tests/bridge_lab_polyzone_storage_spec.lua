local root = assert(arg[1], 'expected resource root')
local contents = ''
local timer = 10000

function GetCurrentResourceName()
    return 'tss_bridge'
end

function GetGameTimer()
    return timer
end

function LoadResourceFile(resource, path)
    assert(resource == 'tss_bridge')
    assert(path == 'bridge_lab/created_zones.lua')
    return contents
end

function SaveResourceFile(resource, path, value, length)
    assert(resource == 'tss_bridge')
    assert(path == 'bridge_lab/created_zones.lua')
    assert(length == -1)
    contents = value
    return true
end

function AddEventHandler() end

assert(loadfile(root .. '/bridge_lab/polyzone_storage.lua'))()

local box = TSSBridgeLabZoneStorage.Save(1, {
    type = 'box',
    name = 'garage_box',
    coords = { x = 10.0, y = 20.0, z = 30.0 },
    width = 4.0,
    length = 6.0,
    height = 2.0,
    heading = 90.0,
})
assert(box.success)
assert(contents:find('TSSBridgeLabCreatedZones', 1, true))
assert(contents:find('name = "garage_box"', 1, true))
assert(contents:find('size = vec3(4.000, 6.000, 2.000)', 1, true))

timer = 12000
local circle = TSSBridgeLabZoneStorage.Save(1, {
    type = 'circle',
    name = 'garage_radius',
    coords = { x = 10.0, y = 20.0, z = 30.0 },
    radius = 5.0,
})
assert(circle.success and contents:find('radius = 5.000', 1, true))

timer = 14000
local polygon = TSSBridgeLabZoneStorage.Save(1, {
    type = 'poly',
    name = 'garage_poly',
    points = {
        { x = 0.0, y = 0.0, z = 10.0 },
        { x = 4.0, y = 0.0, z = 10.1 },
        { x = 4.0, y = 4.0, z = 10.2 },
    },
    minZ = 9.5,
    maxZ = 12.5,
})
assert(polygon.success)
assert(contents:find('vec2(4.000, 4.000)', 1, true))
assert(contents:find('minZ = 9.500', 1, true))

timer = 16000
local flatPolygon = TSSBridgeLabZoneStorage.Save(1, {
    type = 'poly',
    name = 'flat_poly',
    points = {
        { x = 10.0, y = 10.0, z = 5.0 },
        { x = 12.0, y = 10.0, z = 5.0 },
        { x = 12.0, y = 12.0, z = 5.0 },
    },
    minZ = 5.0,
    maxZ = 5.0,
})
assert(flatPolygon.success)
assert(contents:find('name = "flat_poly"', 1, true))
assert(contents:find('maxZ = 5.000', 1, true))

timer = 18000
local injection = TSSBridgeLabZoneStorage.Save(1, {
    type = 'circle',
    name = 'bad"; os.execute("no")',
    coords = { x = 0.0, y = 0.0, z = 0.0 },
    radius = 2.0,
})
assert(injection.success == false)

local invalidPoly = TSSBridgeLabZoneStorage.Save(2, {
    type = 'poly', name = 'line',
    points = {
        { x = 0.0, y = 0.0, z = 0.0 },
        { x = 1.0, y = 1.0, z = 0.0 },
        { x = 2.0, y = 2.0, z = 0.0 },
    },
})
assert(invalidPoly.success == false)

print('bridge lab PolyZone storage tests passed')
