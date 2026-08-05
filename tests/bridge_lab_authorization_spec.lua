local root = assert(arg[1], 'expected resource root')
assert(loadfile(root .. '/bridge_lab/authorization.lua'))()

local Authorization = assert(TSSBridgeLabAuthorization)
local allowed, count = Authorization.Build({
    AllowedDiscordIds = { ' 123456789012345678 ', 'discord:222', 'discord:222' },
    AllowedFiveMIds = { '7654321', 'fivem:999' },
})

assert(count == 4)
assert(allowed['discord:123456789012345678'])
assert(allowed['discord:222'])
assert(allowed['fivem:7654321'])
assert(allowed['fivem:999'])

local function identifiersFor(source)
    if source == 1 then return { 'license:abc', 'discord:123456789012345678' } end
    if source == 2 then return { 'license:def', 'fivem:999' } end
    if source == 3 then return { 'license:abc' } end
    return {}
end

assert(Authorization.IsAllowed(1, allowed, identifiersFor))
assert(Authorization.IsAllowed(2, allowed, identifiersFor))
assert(not Authorization.IsAllowed(3, allowed, identifiersFor))
assert(not Authorization.IsAllowed(0, allowed, identifiersFor))
assert(not Authorization.IsAllowed(1, {}, identifiersFor))

print('bridge lab authorization tests passed')
