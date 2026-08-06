-- Searchable Bridge Lab API and shared-item browsers.
TSSBridgeLabToolBrowser = {}

local Browser = TSSBridgeLabToolBrowser
local activeClose

local function isCallable(value)
    if type(value) == 'function' then return true end
    if type(value) ~= 'table' then return false end
    if rawget(value, '__cfx_functionReference') ~= nil then return true end
    local metatable = getmetatable(value)
    return metatable ~= nil and type(metatable.__call) == 'function'
end

local function closeBrowser()
    if not activeClose then return end
    local callback = activeClose
    activeClose = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'bridgeLabBrowser', payload = nil })
    callback()
end

local function splitFunctionType(definition)
    local startAt = definition:find('fun%(')
    if not startAt then return definition, '', '' end

    local openAt = definition:find('(', startAt, true)
    local depth, closeAt = 0, nil
    for index = openAt, #definition do
        local character = definition:sub(index, index)
        if character == '(' then depth = depth + 1 end
        if character == ')' then
            depth = depth - 1
            if depth == 0 then
                closeAt = index
                break
            end
        end
    end

    if not closeAt then return definition, '', '' end
    local params = definition:sub(openAt + 1, closeAt - 1)
    local returns = definition:sub(closeAt + 1):match('^%s*:%s*(.-)%s*$') or ''
    return definition, params, returns
end

local function parseApiCatalog()
    local source = LoadResourceFile(GetCurrentResourceName(), 'shared/types.lua')
    if type(source) ~= 'string' or source == '' then return nil, 'Unable to read shared/types.lua' end

    local classes, current = {}, nil
    for line in source:gmatch('[^\r\n]+') do
        local className = line:match('^%-%-%-@class%s+([%w_]+)')
        if className then
            current = className
            classes[current] = classes[current] or {}
        elseif current then
            local field, definition = line:match('^%-%-%-@field%s+([%w_]+)%??%s+(.+)$')
            if field and definition then
                classes[current][#classes[current] + 1] = { name = field, definition = definition }
            end
        end
    end

    local modules = {}
    local function addRealm(containerName, realm)
        for _, moduleField in ipairs(classes[containerName] or {}) do
            local moduleName = moduleField.name
            local className = moduleField.definition:match('^([%w_]+)')
            local entry = modules[moduleName] or { name = moduleName, functions = {} }
            modules[moduleName] = entry

            for _, field in ipairs(classes[className] or {}) do
                if field.definition:match('^fun%(') then
                    local api = entry.functions[field.name] or { name = field.name, realms = {} }
                    local signature, params, returns = splitFunctionType(field.definition)
                    api.realms[realm] = { signature = signature, params = params, returns = returns }
                    entry.functions[field.name] = api
                end
            end
        end
    end

    addRealm('TSSClientModules', 'client')
    addRealm('TSSServerModules', 'server')

    local result, functionCount = {}, 0
    for _, module in pairs(modules) do
        local functions = {}
        for _, api in pairs(module.functions) do functions[#functions + 1] = api end
        table.sort(functions, function(a, b) return a.name < b.name end)
        module.functions = functions
        functionCount = functionCount + #functions
        result[#result + 1] = module
    end
    table.sort(result, function(a, b) return a.name < b.name end)
    return { modules = result, moduleCount = #result, functionCount = functionCount }
end

local function valueString(value)
    local valueType = type(value)
    if valueType == 'string' then return value end
    if valueType == 'number' or valueType == 'boolean' then return tostring(value) end
    if valueType == 'nil' then return 'nil' end
    if valueType == 'table' and json and json.encode then
        local ok, encoded = pcall(json.encode, value)
        if ok and encoded then return #encoded > 4096 and encoded:sub(1, 4096) .. '…' or encoded end
    end
    return ('<%s>'):format(valueType)
end

local fieldPriority = { name = 1, label = 2, image = 3, weight = 4, type = 5, unique = 6, useable = 7 }

local function itemImage(item, name, resource)
    local image = item.image
    if not image and type(item.client) == 'table' then image = item.client.image end
    image = type(image) == 'string' and image or (name .. '.png')
    local filename = image:match('([^/\\]+)$') or image
    local candidates = {}
    if image:match('^https?://') or image:match('^nui://') then candidates[#candidates + 1] = image end
    if type(resource) == 'string' and resource:match('^[%w_%-]+$') then
        candidates[#candidates + 1] = ('https://cfx-nui-%s/html/images/%s'):format(resource, filename)
        candidates[#candidates + 1] = ('https://cfx-nui-%s/web/images/%s'):format(resource, filename)
        candidates[#candidates + 1] = ('https://cfx-nui-%s/images/%s'):format(resource, filename)
    end
    return image, candidates
end

local function normaliseItems(rawItems, resource)
    local items = {}
    for key, item in pairs(rawItems) do
        if type(item) == 'table' and #items < 5000 then
            local name = tostring(item.name or (type(key) == 'string' and key) or item.id or ('item_%s'):format(key))
            local label = tostring(item.label or item.title or name)
            local image, imageCandidates = itemImage(item, name, resource)
            local fields = {}
            for field, value in pairs(item) do
                if type(field) == 'string' and type(value) ~= 'function' and type(value) ~= 'userdata'
                    and type(value) ~= 'thread' then
                    fields[#fields + 1] = {
                        name = field,
                        value = valueString(value),
                        valueType = type(value),
                    }
                end
            end
            local hasName = false
            for i = 1, #fields do if fields[i].name == 'name' then hasName = true break end end
            if not hasName then fields[#fields + 1] = { name = 'name', value = name, valueType = 'string' } end
            table.sort(fields, function(a, b)
                local aPriority, bPriority = fieldPriority[a.name] or 100, fieldPriority[b.name] or 100
                return aPriority == bPriority and a.name < b.name or aPriority < bPriority
            end)
            items[#items + 1] = {
                name = name,
                label = label,
                image = image,
                imageCandidates = imageCandidates,
                fields = fields,
            }
        end
    end
    table.sort(items, function(a, b) return a.label:lower() < b.label:lower() end)
    return items
end

local function open(payload, onClose)
    if activeClose then return false, 'Another Bridge Lab browser is already open' end
    activeClose = onClose or function() end
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'bridgeLabBrowser', payload = payload })
    return true
end

function Browser.OpenApi(onClose)
    local catalog, catalogError = parseApiCatalog()
    if not catalog then return false, catalogError end
    catalog.visible = true
    catalog.kind = 'api'
    catalog.title = 'Bridge API Explorer'
    return open(catalog, onClose)
end

function Browser.OpenItems(inventory, onClose)
    if type(inventory) ~= 'table' or not isCallable(inventory.Items) then
        return false, 'Inventory module is unavailable'
    end

    local system, resource = inventory.System()
    local ok, rawItems = pcall(function() return inventory.Items() end)
    if not ok or type(rawItems) ~= 'table' then return false, 'The active inventory did not return an item database' end
    local items = normaliseItems(rawItems, resource)
    return open({
        visible = true,
        kind = 'items',
        title = 'Inventory Item Browser',
        system = system or 'none',
        resource = resource or 'none',
        itemCount = #items,
        items = items,
    }, onClose)
end

RegisterNUICallback('bridgeLabBrowserClose', function(_, callback)
    callback({ ok = true })
    closeBrowser()
end)

AddEventHandler('onClientResourceStop', function(resource)
    if resource == GetCurrentResourceName() and activeClose then
        activeClose = nil
        SetNuiFocus(false, false)
    end
end)
