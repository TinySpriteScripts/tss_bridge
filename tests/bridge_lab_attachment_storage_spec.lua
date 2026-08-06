local root = assert(arg[1], 'expected resource root')
local contents = ''
local timer = 10000

function GetCurrentResourceName() return 'tss_bridge' end
function GetGameTimer() return timer end
function LoadResourceFile(resource, path)
    assert(resource == 'tss_bridge' and path == 'bridge_lab/created_prop_attatchments.lua')
    return contents
end
function SaveResourceFile(resource, path, value, length)
    assert(resource == 'tss_bridge' and path == 'bridge_lab/created_prop_attatchments.lua' and length == -1)
    contents = value
    return true
end
function AddEventHandler() end

assert(loadfile(root .. '/bridge_lab/attachment_storage.lua'))()

local valid = TSSBridgeLabAttachmentStorage.Save(1, {
    name = 'tablet_hand',
    model = 'prop_cs_tablet',
    bone = { name = 'Right hand', id = 0xDEAD },
    offset = { x = 0.12, y = -0.03, z = 0.01 },
    rotation = { x = 20.0, y = 180.0, z = -15.0 },
    animation = {
        dict = 'amb@world_human_clipboard@male@idle_a',
        clip = 'idle_c',
        flag = 49,
    },
})
assert(valid.success)
assert(contents:find('name = "tablet_hand"', 1, true))
assert(contents:find('model = "prop_cs_tablet"', 1, true))
assert(contents:find('id = 57005', 1, true))
assert(contents:find('offset = vec3(0.1200, -0.0300, 0.0100)', 1, true))
assert(contents:find('dict = "amb@world_human_clipboard@male@idle_a"', 1, true))
assert(contents:find('clip = "idle_c", flag = 49', 1, true))

timer = 12000
local invalidModel = TSSBridgeLabAttachmentStorage.Save(1, {
    name = 'bad', model = 'prop"; os.execute("bad")',
    bone = { name = 'Right hand', id = 0xDEAD },
    offset = { x = 0.0, y = 0.0, z = 0.0 },
    rotation = { x = 0.0, y = 0.0, z = 0.0 },
})
assert(invalidModel.success == false)

timer = 14000
local invalidOffset = TSSBridgeLabAttachmentStorage.Save(1, {
    name = 'far_away', model = 'prop_cs_tablet',
    bone = { name = 'Right hand', id = 0xDEAD },
    offset = { x = 9999.0, y = 0.0, z = 0.0 },
    rotation = { x = 0.0, y = 0.0, z = 0.0 },
})
assert(invalidOffset.success == false)

print('bridge lab prop attachment storage tests passed')
