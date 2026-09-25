TSS = TSS or {}

local DEFAULT_REPOSITORY = 'https://github.com/TinySpriteScripts/version_check'
local VERSION_EVENT = 'tss_bridge:server:registerVersionConsumer'
local checks = {}

local TSS_BANNER = [[
^2  _______   _____   _____ ^7
^2 |__   __| / ____| / ____|^7
^2    | |   | (___  | (___  ^7
^2    | |    \___ \  \___ \ ^7
^2    | |    ____) | ____) |^7
^2    |_|   |_____/ |_____/ ^7]]

local function trim(value)
    return type(value) == 'string' and value:match('^%s*(.-)%s*$') or nil
end

local function metadata(resource, key)
    return trim(GetResourceMetadata(resource, key, 0))
end

local function isTrue(value)
    value = value and value:lower()
    return value == 'true' or value == '1' or value == 'yes'
end

local function versionFileUrl(resource, configuredRepository)
    local repository = trim(configuredRepository) or DEFAULT_REPOSITORY
    if repository == '' then repository = DEFAULT_REPOSITORY end

    if not repository:match('^https://') then
        return nil, 'version_check_repo must be a public HTTPS URL'
    end

    repository = repository:gsub('/+$', ''):gsub('%.git$', '')
    repository = repository:gsub('{resource}', resource)
    repository = repository:gsub('%%s', resource)

    local owner, repo, branch, path = repository:match(
        '^https://github%.com/([^/]+)/([^/]+)/tree/([^/]+)/(.*)$'
    )
    if not owner then
        owner, repo, branch = repository:match(
            '^https://github%.com/([^/]+)/([^/]+)/tree/([^/]+)$'
        )
        path = ''
    end
    if owner then
        local suffix = path ~= '' and ('/' .. path) or ''
        return ('https://raw.githubusercontent.com/%s/%s/%s%s/%s-version.txt')
            :format(owner, repo, branch, suffix, resource)
    end

    local blobOwner, blobRepo, blobBranch, blobPath = repository:match(
        '^https://github%.com/([^/]+)/([^/]+)/blob/([^/]+)/(.+)$'
    )
    if blobOwner then
        return ('https://raw.githubusercontent.com/%s/%s/%s/%s')
            :format(blobOwner, blobRepo, blobBranch, blobPath)
    end

    if repository:match('%.txt$') or repository:match('%.txt[?#]') then return repository end

    owner, repo = repository:match('^https://github%.com/([^/]+)/([^/]+)$')
    if owner then
        return ('https://raw.githubusercontent.com/%s/%s/main/%s-version.txt')
            :format(owner, repo, resource)
    end

    return ('%s/%s-version.txt'):format(repository, resource)
end

local function safeRemoteLine(value)
    value = trim(value)
    if not value or value == '' or #value > 512 then return nil end
    return value:gsub('[%c]', '')
end

local function printBanner(resource)
    print('^5------------------------------------------------------------^7')
    print(TSS_BANNER)
    print(('^2TinySprite Scripts^7 | ^5Version Check^7 | %s'):format(resource))
end

local function printCheckError(resource, message)
    printBanner(resource)
    print(('^1ERROR:^7 %s'):format(message))
    print('^5------------------------------------------------------------^7')
end

local function printResult(resource, currentVersion, latestVersion, supportLink)
    printBanner(resource)

    if currentVersion == latestVersion then
        print(('^2Up to date:^7 %s'):format(currentVersion))
    else
        print(('^1Update available:^7 %s -> %s'):format(currentVersion, latestVersion))
        print('^3Updates:^7 https://portal.cfx.re/assets/granted-assets')
    end

    if supportLink then print(('^3Support:^7 %s'):format(supportLink)) end

    print('^5------------------------------------------------------------^7')
end

local function register(resource)
    if type(resource) ~= 'string' or not resource:match('^[%w_.%-]+$') then return false end
    if checks[resource] then return false end

    local state = GetResourceState(resource)
    if state ~= 'started' and state ~= 'starting' then return false end

    checks[resource] = true
    if isTrue(metadata(resource, 'suppress_updates')) then return false end

    local currentVersion = metadata(resource, 'version')
    if not currentVersion or currentVersion == '' then
        printCheckError(resource, 'No version was found in the fxmanifest; check skipped.')
        return false
    end

    local url, urlError = versionFileUrl(resource, metadata(resource, 'version_check_repo'))
    if not url then
        printCheckError(resource, urlError .. '.')
        return false
    end

    PerformHttpRequest(url, function(status, body)
        if status ~= 200 or type(body) ~= 'string' or #body > 16384 then
            printCheckError(resource, ('Could not retrieve version information (HTTP %s).'):format(tostring(status)))
            return
        end

        local lines = {}
        for line in (body:gsub('\r\n', '\n') .. '\n'):gmatch('(.-)\n') do
            local clean = safeRemoteLine(line)
            if clean then lines[#lines + 1] = clean end
        end

        local latestVersion, expectedName, supportLink = lines[1], lines[2], lines[3]
        if not latestVersion or not expectedName then
            printCheckError(resource, 'The repository returned an invalid version file.')
            return
        end

        if expectedName ~= resource then
            printCheckError(resource, ('Resource is named %s but the version file expects %s. Rename it for updates and support.')
                :format(resource, expectedName))
            return
        end

        printResult(resource, currentVersion, latestVersion, supportLink)
    end, 'GET', '', { ['Accept'] = 'text/plain' })

    return true
end

TSS.VersionCheck = {
    Register = register,
    ResolveUrl = versionFileUrl,
}

RegisterNetEvent(VERSION_EVENT, function(resource)
    -- Clients may only nominate a real resource on this server. The URL itself
    -- always comes from that resource's server-owned manifest metadata.
    register(resource)
end)

AddEventHandler('onResourceStop', function(resource)
    checks[resource] = nil
end)

CreateThread(function()
    Wait(0)
    register(GetCurrentResourceName())
end)
