local root = assert(arg[1], 'expected resource root')
local nuiCallbacks = {}
local lastMessage
local focused = false

function GetCurrentResourceName() return 'tss_bridge' end
function LoadResourceFile(resource, path)
    assert(resource == 'tss_bridge')
    local file = assert(io.open(root .. '/' .. path, 'rb'))
    local source = file:read('*a')
    file:close()
    return source
end
function RegisterNUICallback(name, callback) nuiCallbacks[name] = callback end
function AddEventHandler() end
function SetNuiFocus(keyboard, mouse) focused = keyboard and mouse end
function SendNUIMessage(message) lastMessage = message end

assert(loadfile(root .. '/bridge_lab/client/tool_browser.lua'))()

local returned = false
local opened, openError = TSSBridgeLabToolBrowser.OpenApi(function() returned = true end)
assert(opened, openError)
assert(focused and lastMessage.action == 'bridgeLabBrowser')
assert(lastMessage.payload.kind == 'api' and lastMessage.payload.moduleCount > 10)

local money
for _, module in ipairs(lastMessage.payload.modules) do
    if module.name == 'Banking' then money = module break end
end
assert(money)
local add
for _, api in ipairs(money.functions) do if api.name == 'Add' then add = api break end end
assert(add and add.realms.server and not add.realms.client)
assert(add.realms.server.params:find('source: integer', 1, true))

local ui
for _, module in ipairs(lastMessage.payload.modules) do if module.name == 'UI' then ui = module break end end
assert(ui)
local menu, notify
for _, api in ipairs(ui.functions) do
    if api.name == 'Menu' then menu = api end
    if api.name == 'Notify' then notify = api end
end
assert(menu and menu.realms.client and not menu.realms.server)
assert(notify and notify.realms.client and notify.realms.server)

nuiCallbacks.bridgeLabBrowserClose({}, function() end)
assert(returned and not focused)

local playerInventoryCalled = false
local function callableProxy(callback)
    return setmetatable({}, { __call = function(_, ...) return callback(...) end })
end
local inventory = {
    System = callableProxy(function() return 'qb', 'qb-inventory' end),
    Items = callableProxy(function()
        return {
            water = { name = 'water', label = 'Water Bottle', image = 'water.png', weight = 500 },
            sandwich = { label = 'Sandwich', weight = 200 },
        }
    end),
    Player = function()
        playerInventoryCalled = true
        error('Item Browser must not inspect a player inventory')
    end,
}

opened, openError = TSSBridgeLabToolBrowser.OpenItems(inventory, function() end)
assert(opened, openError)
assert(lastMessage.payload.kind == 'items' and lastMessage.payload.itemCount == 2)
assert(lastMessage.payload.system == 'qb' and lastMessage.payload.resource == 'qb-inventory')
assert(not playerInventoryCalled)
assert(lastMessage.payload.items[1].imageCandidates[1]:find('cfx%-nui%-qb%-inventory'))

print('bridge lab API and item browser tests passed')
