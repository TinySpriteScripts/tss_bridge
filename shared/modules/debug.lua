TSS = TSS or {}
TSS.DebugTools = TSS.DebugTools or {}

local function round(value)
    return math.floor((value * 1000) + 0.5) / 1000
end

local function formatVec3(coords)
    if not coords then return 'vec3(0.000, 0.000, 0.000)' end
    return ('vec3(%.3f, %.3f, %.3f)'):format(round(coords.x), round(coords.y), round(coords.z))
end

local function formatVec4(coords)
    if not coords then return 'vec4(0.000, 0.000, 0.000, 0.000)' end
    return ('vec4(%.3f, %.3f, %.3f, %.3f)'):format(round(coords.x), round(coords.y), round(coords.z), round(coords.w or 0.0))
end

local function notify(text)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, false)
end

local function drawText2d(x, y, text, scale, r, g, b, a)
    SetTextFont(4)
    SetTextScale(scale or 0.32, scale or 0.32)
    SetTextColour(r or 255, g or 255, b or 255, a or 255)
    SetTextDropshadow(0, 0, 0, 0, 0)
    SetTextEdge(1, 0, 0, 0, 180)
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end

local function drawPanel(lines)
    local x = 0.016
    local y = 0.032
    local width = 0.295
    local lineHeight = 0.024
    local height = 0.034 + (#lines * lineHeight)

    DrawRect(x + (width / 2), y + (height / 2), width, height, 8, 8, 8, 218)
    DrawRect(x + (width / 2), y + 0.004, width, 0.004, 255, 26, 26, 230)
    DrawRect(x + 0.003, y + (height / 2), 0.006, height, 255, 26, 26, 175)
    DrawRect(x + width - 0.003, y + (height / 2), 0.006, height, 255, 26, 26, 130)
    DrawRect(x + (width / 2), y + height - 0.004, width, 0.004, 110, 0, 0, 160)

    for i = 1, #lines do
        local line = lines[i]
        drawText2d(x + 0.014, y + 0.009 + ((i - 1) * lineHeight), line.text, line.scale, line.r, line.g, line.b, line.a)
    end
end

local function drawMarkerAt(coords)
    if not coords then return end
    DrawMarker(28, coords.x, coords.y, coords.z + 0.05, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.15, 0.15, 0.15, 80, 200, 255, 170, false, false, 2, false, nil, nil, false)
end

local function drawCircle(center, radius, axis)
    local lastPoint

    for i = 0, 32 do
        local angle = (math.pi * 2.0) * (i / 32)
        local point

        if axis == 'x' then
            point = vec3(center.x, center.y + math.cos(angle) * radius, center.z + math.sin(angle) * radius)
        elseif axis == 'y' then
            point = vec3(center.x + math.cos(angle) * radius, center.y, center.z + math.sin(angle) * radius)
        else
            point = vec3(center.x + math.cos(angle) * radius, center.y + math.sin(angle) * radius, center.z)
        end

        if lastPoint then
            local r = axis == 'x' and 255 or 40
            local g = axis == 'y' and 255 or 40
            local b = axis == 'z' and 255 or 40
            DrawLine(lastPoint.x, lastPoint.y, lastPoint.z, point.x, point.y, point.z, r, g, b, 220)
        end

        lastPoint = point
    end
end

local function drawAxisGizmo(coords, rotationMode)
    if not coords then return end

    local origin = vec3(coords.x, coords.y, coords.z + 0.45)
    local length = 0.55
    local heading = math.rad(coords.w or 0.0)
    local forward = vec3(-math.sin(heading), math.cos(heading), 0.0)
    local right = vec3(math.cos(heading), math.sin(heading), 0.0)

    DrawLine(origin.x, origin.y, origin.z, origin.x + (right.x * length), origin.y + (right.y * length), origin.z, 255, 45, 45, 230)
    DrawLine(origin.x, origin.y, origin.z, origin.x + (forward.x * length), origin.y + (forward.y * length), origin.z, 45, 255, 45, 230)
    DrawLine(origin.x, origin.y, origin.z, origin.x, origin.y, origin.z + length, 45, 95, 255, 230)

    if rotationMode then
        drawCircle(origin, 0.42, 'x')
        drawCircle(origin, 0.42, 'y')
        drawCircle(origin, 0.42, 'z')
    end
end

local function drawZoneBox(coords, length, width, minZ, maxZ, r, g, b, a)
    if not coords then return end

    local heading = math.rad(coords.w or 0.0)
    local forward = vec3(-math.sin(heading), math.cos(heading), 0.0)
    local right = vec3(math.cos(heading), math.sin(heading), 0.0)
    local halfL = (length or 0.6) / 2.0
    local halfW = (width or 0.6) / 2.0
    local bottom = minZ or (coords.z - 0.5)
    local top = maxZ or (coords.z + 0.5)
    local colorR = r or 80
    local colorG = g or 200
    local colorB = b or 255
    local alpha = a or 220

    local corners = {
        vec3(coords.x + (forward.x * halfL) + (right.x * halfW), coords.y + (forward.y * halfL) + (right.y * halfW), 0.0),
        vec3(coords.x + (forward.x * halfL) - (right.x * halfW), coords.y + (forward.y * halfL) - (right.y * halfW), 0.0),
        vec3(coords.x - (forward.x * halfL) - (right.x * halfW), coords.y - (forward.y * halfL) - (right.y * halfW), 0.0),
        vec3(coords.x - (forward.x * halfL) + (right.x * halfW), coords.y - (forward.y * halfL) + (right.y * halfW), 0.0),
    }

    for i = 1, 4 do
        local nextIndex = i == 4 and 1 or i + 1
        local from = corners[i]
        local to = corners[nextIndex]

        DrawLine(from.x, from.y, bottom, to.x, to.y, bottom, colorR, colorG, colorB, alpha)
        DrawLine(from.x, from.y, top, to.x, to.y, top, colorR, colorG, colorB, alpha)
        DrawLine(from.x, from.y, bottom, from.x, from.y, top, colorR, colorG, colorB, alpha)
    end
end

local function formatChairEntry(coords, stand)
    return ('            { coords = %s, stand = %s },'):format(formatVec4(coords), formatVec3(stand))
end

local locationTableProfiles = {
    Chairs = {
        kind = 'chair',
        label = 'Loc[Config.Lan].target["Chairs"]',
        icon = 'fas fa-chair',
        entry = function(entry)
            return ('            { coords = %s, stand = %s },'):format(formatVec4(entry.coords), formatVec3(entry.stand))
        end,
    },
    WashHands = {
        kind = 'zone',
        label = 'Loc[Config.Lan].target["WashHands"]',
        icon = 'fas fa-sink',
        entry = function(entry)
            return ('            { coords = %s, l=%.1f, w=%.1f },'):format(formatVec4(entry.coords), entry.l or 0.6, entry.w or 0.6)
        end,
    },
    Poles = {
        kind = 'zone',
        label = 'Loc[Config.Lan].target["Poles"]',
        icon = 'fas fa-child',
        entry = function(entry, index)
            return ('            { coords = %s, l=%.1f, w=%.1f, pole = %s },'):format(formatVec4(entry.coords), entry.l or 0.7, entry.w or 0.7, entry.pole or index)
        end,
    },
    Peds = {
        kind = 'ped',
        entry = function(entry)
            local scenario = entry.scenario and entry.scenario ~= '' and (', scenario = "%s"'):format(entry.scenario) or ''
            return ('        { model = "%s", coords = %s%s },'):format(entry.model or 'a_m_m_business_01', formatVec4(entry.coords), scenario)
        end,
    },
}

local directZoneProfiles = {
    Outfit = { label = 'Loc[Config.Lan].target["Outfit"]', icon = 'fas fa-list' },
    BossMenus = { label = 'Loc[Config.Lan].target["BossMenus"]', icon = 'fas fa-list' },
    Payments = { label = 'Loc[Config.Lan].target["Payments"]', icon = 'fas fa-credit-card', extra = 'maxZ=%.1f,' },
    Shop = { label = 'Loc[Config.Lan].target["Shop"]', icon = 'fas fa-box-open', extra = 'maxZ=%.1f, shopName = "CHANGE_ME", items = Shops.CHANGE_ME,' },
    Stash = { label = 'Loc[Config.Lan].target["Stash"]', icon = 'fas fa-temperature-low', extra = 'maxZ=%.1f, stashName = "CHANGE_ME", stashLabel = "CHANGE_ME", slots = 100, weight = 200000,' },
    PublicStash = { label = 'Loc[Config.Lan].target["PublicStash"]', icon = 'fas fa-box-open', extra = 'maxZ=%.1f, stashName = "CHANGE_ME", stashLabel = "CHANGE_ME", slots = 10, weight = 20000,' },
    PlayerStash = { label = 'Loc[Config.Lan].target["PlayerStash"]', icon = 'fas fa-box-open', extra = 'stashName = "CHANGE_ME", stashLabel = "CHANGE_ME", slots = 10, weight = 40000,' },
    Crafting = { label = 'Loc[Config.Lan].target["Crafting"]', icon = 'fas fa-copy', extra = 'craftable = Crafting.CHANGE_ME,' },
}

for tableName, profile in pairs(directZoneProfiles) do
    locationTableProfiles[tableName] = {
        kind = 'directZone',
        label = profile.label,
        icon = profile.icon,
        entry = function(entry)
            local line = ('        { coords = %s, l=%.1f, w=%.1f, label = %s, icon = "%s",'):format(formatVec4(entry.coords), entry.l or 0.6, entry.w or 0.6, profile.label, profile.icon)
            if profile.extra then
                line = line .. ' ' .. profile.extra:format(entry.maxZ or ((entry.coords and entry.coords.z or 0.0) + 1.0))
            end
            return line .. ' },'
        end,
    }
end

function TSS.DebugTools.FormatLocationTable(entries, tableName)
    local profile = locationTableProfiles[tableName or 'Chairs'] or locationTableProfiles.Chairs
    tableName = locationTableProfiles[tableName] and tableName or 'Chairs'

    if profile.kind == 'directZone' or profile.kind == 'ped' then
        local output = {
            ('%s = {'):format(tableName),
        }

        for i = 1, #entries do
            output[#output + 1] = profile.entry(entries[i], i)
        end

        output[#output + 1] = '    },'

        return table.concat(output, '\n')
    end

    local output = {
        ('%s = {'):format(tableName),
        ('        label = %s,'):format(profile.label),
        ('        icon = "%s",'):format(profile.icon),
        '        list = {',
    }

    for i = 1, #entries do
        output[#output + 1] = profile.entry(entries[i], i)
    end

    output[#output + 1] = '        }'
    output[#output + 1] = '    },'

    return table.concat(output, '\n')
end

function TSS.DebugTools.FormatLocationTables(tables, order)
    local output = {}

    for i = 1, #(order or {}) do
        local tableName = order[i]
        local entries = tables and tables[tableName]

        if entries and #entries > 0 then
            output[#output + 1] = TSS.DebugTools.FormatLocationTable(entries, tableName)
        end
    end

    return table.concat(output, '\n\n')
end

function TSS.DebugTools.FormatChairTable(entries, label, icon)
    if label or icon then
        local output = {
            'Chairs = {',
            ('        label = %s,'):format(label or 'Loc[Config.Lan].target["Chairs"]'),
            ('        icon = "%s",'):format(icon or 'fas fa-chair'),
            '        list = {',
        }

        for i = 1, #entries do
            output[#output + 1] = formatChairEntry(entries[i].coords, entries[i].stand)
        end

        output[#output + 1] = '        }'
        output[#output + 1] = '    },'

        return table.concat(output, '\n')
    end

    return TSS.DebugTools.FormatLocationTable(entries, 'Chairs')
end

if TSS.IsServer() then
    local lastSaveAt = {}

    RegisterNetEvent('tss_bridge:server:saveChairTable', function(output)
        local src = source

        if not TSS.Config.DebugTools or not IsPlayerAceAllowed(src, 'tss_bridge.debug') then
            TriggerClientEvent('tss_bridge:client:chairTableSaved', src, false, 'You are not allowed to save debug tables')
            return
        end

        local now = GetGameTimer()
        if lastSaveAt[src] and now - lastSaveAt[src] < 5000 then
            TriggerClientEvent('tss_bridge:client:chairTableSaved', src, false, 'Please wait before saving another debug table')
            return
        end
        lastSaveAt[src] = now

        if type(output) ~= 'string' or output == '' or #output > 50000 then
            TriggerClientEvent('tss_bridge:client:chairTableSaved', src, false, 'Invalid chair table output')
            return
        end

        local resource = GetCurrentResourceName()
        local filename = ('debug/locations_%s_%s.txt'):format(os.date('%Y%m%d_%H%M%S'), tostring(src))
        local saved = SaveResourceFile(resource, filename, output, #output)

        if saved == true and LoadResourceFile(resource, filename) ~= output then
            saved = false
        end

        if saved ~= true then
            filename = ('locations_%s_%s.txt'):format(os.date('%Y%m%d_%H%M%S'), tostring(src))
            saved = SaveResourceFile(resource, filename, output, #output)

            if saved == true and LoadResourceFile(resource, filename) ~= output then
                saved = false
            end
        end

        TriggerClientEvent('tss_bridge:client:chairTableSaved', src, saved == true, filename)
        TSS.Debug(('%s table %s to %s'):format(saved == true and 'Location' or 'Failed saving location', saved == true and 'saved' or 'output', filename))
    end)

    AddEventHandler('playerDropped', function()
        lastSaveAt[source] = nil
    end)
end

if TSS.IsClient() then
    local chairAnimDict = 'amb@prop_human_seat_chair_mp@male@generic@base'
    local chairAnimName = 'base'
    local pedModelOptions = {
        'a_m_m_business_01',
        'a_m_m_farmer_01',
        'a_m_m_genfat_01',
        'a_m_m_hillbilly_01',
        'a_m_m_indian_01',
        'a_m_m_ktown_01',
        'a_m_m_mexlabor_01',
        'a_m_m_og_boss_01',
        'a_m_m_polynesian_01',
        'a_m_m_skater_01',
        'a_m_m_socenlat_01',
        'a_m_m_soucent_01',
        'a_m_m_tourist_01',
        'a_m_y_beach_01',
        'a_m_y_business_01',
        'a_m_y_business_02',
        'a_m_y_business_03',
        'a_m_y_clubcust_01',
        'a_m_y_downtown_01',
        'a_m_y_hipster_01',
        'a_m_y_indian_01',
        'a_m_y_ktown_01',
        'a_m_y_mexthug_01',
        'a_m_y_runner_01',
        'a_m_y_skater_01',
        'a_m_y_smartcaspat_01',
        'a_f_y_business_01',
        'a_f_y_business_02',
        'a_f_y_business_03',
        'a_f_y_clubcust_01',
        'a_f_y_hipster_01',
        'a_f_y_tourist_01',
        'a_f_y_vinewood_01',
        'a_f_m_beach_01',
        'a_f_m_business_02',
        'a_f_m_ktown_01',
        'a_f_m_soucent_01',
        'a_f_m_tourist_01',
        's_m_m_security_01',
        's_m_m_bouncer_01',
        's_m_m_doctor_01',
        's_m_m_highsec_01',
        's_m_m_migrant_01',
        's_m_m_paramedic_01',
        's_m_y_ammucity_01',
        's_m_y_barman_01',
        's_m_y_cop_01',
        's_m_y_dealer_01',
        's_m_y_doorman_01',
        's_m_y_garbage',
        's_m_y_marine_01',
        's_m_y_shop_mask',
        's_f_y_bartender_01',
        's_f_y_cop_01',
        's_f_y_hooker_01',
        's_f_y_shop_low',
        's_f_y_shop_mid',
        's_f_y_stripper_01',
        'g_m_y_lost_01',
        'g_m_y_lost_02',
        'g_m_y_lost_03',
        'g_m_y_ballaorig_01',
        'g_m_y_famca_01',
        'g_m_y_mexgoon_01',
        'g_m_y_salvaboss_01',
        'ig_bankman',
        'ig_barry',
        'ig_benny',
        'ig_bestmen',
        'ig_car3guy1',
        'ig_casey',
        'ig_chef',
        'ig_chengsr',
        'ig_clay',
        'ig_dale',
        'ig_dreyfuss',
        'ig_fbisuit_01',
        'ig_floyd',
        'ig_jimmyboston',
        'ig_josef',
        'ig_lestercrest',
        'ig_lifeinvad_01',
        'ig_malc',
        'ig_manuel',
        'ig_marnie',
        'ig_maryann',
        'ig_maude',
        'ig_michelle',
        'ig_milton',
        'ig_molly',
        'ig_money',
        'ig_nervousron',
        'ig_ortega',
        'ig_priest',
        'ig_ramp_gang',
        'ig_roccopelosi',
        'ig_talina',
        'ig_taocheng',
        'ig_tonya',
        'ig_tylerdix',
        'ig_wade',
        'mp_m_freemode_01',
        'mp_f_freemode_01',
    }
    local pedScenarioOptions = {
        { label = 'None', value = nil },
        { label = 'Stand Impatient', value = 'WORLD_HUMAN_STAND_IMPATIENT' },
        { label = 'Clipboard', value = 'WORLD_HUMAN_CLIPBOARD' },
        { label = 'Smoking', value = 'WORLD_HUMAN_SMOKING' },
        { label = 'Hang Out', value = 'WORLD_HUMAN_HANG_OUT_STREET' },
        { label = 'Guard Stand', value = 'WORLD_HUMAN_GUARD_STAND' },
        { label = 'Leaning', value = 'WORLD_HUMAN_LEANING' },
        { label = 'Drinking', value = 'WORLD_HUMAN_DRINKING' },
        { label = 'Coffee', value = 'WORLD_HUMAN_AA_COFFEE' },
        { label = 'Mobile', value = 'WORLD_HUMAN_MOBILE_FILM_SHOCKING' },
        { label = 'Binoculars', value = 'WORLD_HUMAN_BINOCULARS' },
        { label = 'Bum Freeway', value = 'WORLD_HUMAN_BUM_FREEWAY' },
        { label = 'Bum Slumped', value = 'WORLD_HUMAN_BUM_SLUMPED' },
        { label = 'Cheering', value = 'WORLD_HUMAN_CHEERING' },
        { label = 'Drug Dealer', value = 'WORLD_HUMAN_DRUG_DEALER' },
        { label = 'Golf Player', value = 'WORLD_HUMAN_GOLF_PLAYER' },
        { label = 'Hammering', value = 'WORLD_HUMAN_HAMMERING' },
        { label = 'Human Statue', value = 'WORLD_HUMAN_HUMAN_STATUE' },
        { label = 'Janitor', value = 'WORLD_HUMAN_JANITOR' },
        { label = 'Jog Standing', value = 'WORLD_HUMAN_JOG_STANDING' },
        { label = 'Muscle Flex', value = 'WORLD_HUMAN_MUSCLE_FLEX' },
        { label = 'Paparazzi', value = 'WORLD_HUMAN_PAPARAZZI' },
        { label = 'Picnic', value = 'WORLD_HUMAN_PICNIC' },
        { label = 'Prostitute High Class', value = 'WORLD_HUMAN_PROSTITUTE_HIGH_CLASS' },
        { label = 'Prostitute Low Class', value = 'WORLD_HUMAN_PROSTITUTE_LOW_CLASS' },
        { label = 'Push Ups', value = 'WORLD_HUMAN_PUSH_UPS' },
        { label = 'Seat Steps', value = 'WORLD_HUMAN_SEAT_STEPS' },
        { label = 'Sit Ups', value = 'WORLD_HUMAN_SIT_UPS' },
        { label = 'Stand Fire', value = 'WORLD_HUMAN_STAND_FIRE' },
        { label = 'Strip Watch Stand', value = 'WORLD_HUMAN_STRIP_WATCH_STAND' },
        { label = 'Sunbathe Back', value = 'WORLD_HUMAN_SUNBATHE_BACK' },
        { label = 'Tourist Map', value = 'WORLD_HUMAN_TOURIST_MAP' },
        { label = 'Vehicle Mechanic', value = 'WORLD_HUMAN_VEHICLE_MECHANIC' },
        { label = 'Welding', value = 'WORLD_HUMAN_WELDING' },
        { label = 'Window Shop', value = 'WORLD_HUMAN_WINDOW_SHOP_BROWSE' },
    }

    local chairTool = {
        active = false,
        selecting = false,
        ghost = nil,
        savedGhosts = {},
        tempPeds = {},
        allEntries = {},
        entries = {},
        coords = nil,
        stand = nil,
        freePlayer = false,
        mode = 'position',
        tableName = 'Chairs',
        tableOptions = { 'Chairs', 'Peds', 'WashHands', 'Poles', 'Payments', 'Shop', 'Stash', 'PublicStash', 'PlayerStash', 'Crafting', 'BossMenus', 'Outfit' },
        tableOption = 1,
        model = 'mp_m_freemode_01',
        pedModel = 'a_m_m_business_01',
        pedScenario = 'WORLD_HUMAN_STAND_IMPATIENT',
        pedModelOption = 1,
        pedScenarioOption = 2,
        pedSelect = nil,
        moveSpeed = 0.01,
        sizeSpeed = 0.02,
        rotateSpeed = 2.5,
        scrollHeightStep = 0.025,
        scrollHeadingStep = 2.5,
        nextScenarioCheck = 0,
        l = 0.6,
        w = 0.6,
        minZ = nil,
        maxZ = nil,
        uiNextUpdate = 0,
    }

    local function getCurrentProfile()
        return locationTableProfiles[chairTool.tableName or 'Chairs'] or locationTableProfiles.Chairs
    end

    local function isChairProfile()
        return getCurrentProfile().kind == 'chair'
    end

    local function isPedProfile()
        return getCurrentProfile().kind == 'ped'
    end

    local function getDefaultZoneSize(tableName)
        if tableName == 'Poles' then return 0.7, 0.7 end
        if tableName == 'WashHands' then return 0.5, 0.5 end
        if tableName == 'Shop' then return 0.8, 1.2 end
        if tableName == 'Stash' then return 0.8, 1.2 end
        if tableName == 'PublicStash' then return 0.6, 0.6 end
        if tableName == 'Payments' then return 0.5, 0.5 end
        if tableName == 'Crafting' then return 1.2, 1.2 end

        return 0.6, 0.6
    end

    local function deleteGhost()
        if chairTool.ghost and DoesEntityExist(chairTool.ghost) then
            SetEntityAsMissionEntity(chairTool.ghost, true, true)
            DeleteEntity(chairTool.ghost)
        end
        chairTool.ghost = nil
    end

    local function deleteSavedGhosts()
        for i = 1, #chairTool.savedGhosts do
            local ped = chairTool.savedGhosts[i]
            if ped and DoesEntityExist(ped) then
                SetEntityAsMissionEntity(ped, true, true)
                DeleteEntity(ped)
            end
        end

        chairTool.savedGhosts = {}
    end

    local function deleteTempPeds()
        for i = 1, #chairTool.tempPeds do
            local temp = chairTool.tempPeds[i]
            local ped = type(temp) == 'table' and temp.entity or temp
            if ped and DoesEntityExist(ped) then
                SetEntityAsMissionEntity(ped, true, true)
                DeleteEntity(ped)
            end
        end

        chairTool.tempPeds = {}
    end

    local function getLocalAxes(coords)
        local heading = math.rad(coords.w)
        local forward = vec3(-math.sin(heading), math.cos(heading), 0.0)
        local right = vec3(math.cos(heading), math.sin(heading), 0.0)

        return forward, right
    end

    local function isDebugChairPed(ped)
        if not ped or ped == 0 or not DoesEntityExist(ped) or IsPedAPlayer(ped) then return false end

        local model = GetEntityModel(ped)
        local chairModel = TSS.ToHash(chairTool.model)

        return model == chairModel and GetEntityAlpha(ped) < 200
    end

    local function cleanupOrphanDebugPeds(radius)
        local playerPed = PlayerPedId()
        if not playerPed or playerPed == 0 then return end

        local playerCoords = GetEntityCoords(playerPed)
        local peds = GetGamePool('CPed')

        for i = 1, #peds do
            local ped = peds[i]
            if isDebugChairPed(ped) then
                local coords = GetEntityCoords(ped)
                if #(playerCoords - coords) <= (radius or 80.0) then
                    SetEntityAsMissionEntity(ped, true, true)
                    DeleteEntity(ped)
                end
            end
        end
    end

    local function applyChairScenario(ped, coords)
        if not ped or not DoesEntityExist(ped) or not coords then return end

        SetEntityAsMissionEntity(ped, true, true)
        ClearPedTasksImmediately(ped)
        FreezeEntityPosition(ped, false)
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
        SetEntityHeading(ped, coords.w)

        local loaded = TSS.LoadAnimDict(chairAnimDict, 1500)
        if loaded then
            TaskPlayAnimAdvanced(ped, chairAnimDict, chairAnimName, coords.x, coords.y, coords.z, 0.0, 0.0, coords.w, 8.0, 8.0, -1, 1, 0.0, false, false)
        end

        FreezeEntityPosition(ped, true)
    end

    local function moveChairPed(ped, coords)
        if not ped or not DoesEntityExist(ped) or not coords then return end

        FreezeEntityPosition(ped, false)
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
        SetEntityHeading(ped, coords.w)

        if IsEntityPlayingAnim(ped, chairAnimDict, chairAnimName, 3) then
            TaskPlayAnimAdvanced(ped, chairAnimDict, chairAnimName, coords.x, coords.y, coords.z, 0.0, 0.0, coords.w, 8.0, 8.0, -1, 1, 0.0, false, false)
        else
            applyChairScenario(ped, coords)
            return
        end

        FreezeEntityPosition(ped, true)
    end

    local function keepChairScenarioAlive()
        local now = GetGameTimer()
        if now < chairTool.nextScenarioCheck then return end

        chairTool.nextScenarioCheck = now + 1000

        if chairTool.ghost
            and DoesEntityExist(chairTool.ghost)
            and not IsEntityPlayingAnim(chairTool.ghost, chairAnimDict, chairAnimName, 3)
        then
            applyChairScenario(chairTool.ghost, chairTool.coords)
        end

        for i = 1, #chairTool.savedGhosts do
            local ped = chairTool.savedGhosts[i]
            local entry = chairTool.entries[i]

            if ped
                and entry
                and DoesEntityExist(ped)
                and not IsEntityPlayingAnim(ped, chairAnimDict, chairAnimName, 3)
            then
                applyChairScenario(ped, entry.coords)
            end
        end
    end

    local function spawnGhost(coords)
        deleteGhost()

        local loaded, model = TSS.LoadModel(chairTool.model)
        if not loaded then return false end

        chairTool.ghost = CreatePed(4, model, coords.x, coords.y, coords.z, coords.w, false, false)
        SetEntityAsMissionEntity(chairTool.ghost, true, true)
        SetEntityAlpha(chairTool.ghost, 150, false)
        SetEntityCollision(chairTool.ghost, false, false)
        SetEntityInvincible(chairTool.ghost, true)
        SetPedDefaultComponentVariation(chairTool.ghost)
        SetPedCanRagdoll(chairTool.ghost, false)
        SetBlockingOfNonTemporaryEvents(chairTool.ghost, true)
        SetModelAsNoLongerNeeded(model)
        applyChairScenario(chairTool.ghost, coords)

        return true
    end

    local function spawnSavedGhost(coords)
        local loaded, model = TSS.LoadModel(chairTool.model)
        if not loaded then return end

        local ped = CreatePed(4, model, coords.x, coords.y, coords.z, coords.w, false, false)
        chairTool.savedGhosts[#chairTool.savedGhosts + 1] = ped

        SetEntityAsMissionEntity(ped, true, true)
        SetEntityAlpha(ped, 95, false)
        SetEntityCollision(ped, false, false)
        SetEntityInvincible(ped, true)
        SetPedDefaultComponentVariation(ped)
        SetPedCanRagdoll(ped, false)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetModelAsNoLongerNeeded(model)
        applyChairScenario(ped, coords)
    end

    local function applyPedScenario(ped, coords)
        if not ped or not DoesEntityExist(ped) or not coords then return end

        ClearPedTasksImmediately(ped)
        FreezeEntityPosition(ped, false)
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
        SetEntityHeading(ped, coords.w)
        TaskStandStill(ped, -1)

        FreezeEntityPosition(ped, true)
    end

    local function movePedGhost(ped, coords)
        if not ped or not DoesEntityExist(ped) or not coords then return end

        ClearPedTasksImmediately(ped)
        FreezeEntityPosition(ped, false)
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
        SetEntityHeading(ped, coords.w)
        TaskStandStill(ped, -1)
        FreezeEntityPosition(ped, true)
    end

    local function spawnPedGhost(coords)
        deleteGhost()

        local loaded, model = TSS.LoadModel(chairTool.pedModel)
        if not loaded then return false end

        chairTool.ghost = CreatePed(4, model, coords.x, coords.y, coords.z, coords.w, false, false)
        SetEntityAsMissionEntity(chairTool.ghost, true, true)
        SetEntityAlpha(chairTool.ghost, 150, false)
        SetEntityCollision(chairTool.ghost, false, false)
        SetEntityInvincible(chairTool.ghost, true)
        SetPedDefaultComponentVariation(chairTool.ghost)
        SetPedCanRagdoll(chairTool.ghost, false)
        SetBlockingOfNonTemporaryEvents(chairTool.ghost, true)
        SetModelAsNoLongerNeeded(model)
        applyPedScenario(chairTool.ghost, coords)

        return true
    end

    local function applyTempPedScenario(ped, coords, scenario)
        if not ped or not DoesEntityExist(ped) or not coords then return end

        ClearPedTasksImmediately(ped)
        FreezeEntityPosition(ped, false)
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
        SetEntityHeading(ped, coords.w)

        if scenario then
            TaskStartScenarioAtPosition(ped, scenario, coords.x, coords.y, coords.z, coords.w, -1, false, true)
            SetPedKeepTask(ped, true)
        else
            TaskStandStill(ped, -1)
            FreezeEntityPosition(ped, true)
        end
    end

    local function spawnTemporaryPed()
        if not isPedProfile() or not chairTool.coords then return false end

        local coords = vec4(chairTool.coords.x, chairTool.coords.y, chairTool.coords.z, chairTool.coords.w)
        local loaded, model = TSS.LoadModel(chairTool.pedModel)
        if not loaded then return false end

        local ped = CreatePed(4, model, coords.x, coords.y, coords.z, coords.w, false, false)
        if not ped or ped == 0 then return false end

        chairTool.tempPeds[#chairTool.tempPeds + 1] = {
            entity = ped,
            coords = coords,
            scenario = chairTool.pedScenario,
        }
        SetEntityAsMissionEntity(ped, true, true)
        SetEntityAlpha(ped, 255, false)
        SetEntityCollision(ped, true, true)
        SetEntityInvincible(ped, true)
        SetPedDefaultComponentVariation(ped)
        SetPedCanRagdoll(ped, false)
        SetBlockingOfNonTemporaryEvents(ped, true)
        SetModelAsNoLongerNeeded(model)
        applyTempPedScenario(ped, coords, chairTool.pedScenario)

        notify(('Temporary ped spawned: %s #%s'):format(chairTool.pedModel, #chairTool.tempPeds))
        return true
    end

    local function keepTempPedScenariosAlive()
        local now = GetGameTimer()

        for i = 1, #chairTool.tempPeds do
            local temp = chairTool.tempPeds[i]
            local ped = temp and temp.entity

            if ped
                and DoesEntityExist(ped)
                and temp.scenario
                and now >= (temp.nextScenarioCheck or 0)
                and not IsPedUsingScenario(ped, temp.scenario)
            then
                temp.nextScenarioCheck = now + 1500
                applyTempPedScenario(ped, temp.coords, temp.scenario)
            end
        end
    end

    local function setPlayerLocked(locked)
        local ped = PlayerPedId()
        if ped and ped ~= 0 then
            FreezeEntityPosition(ped, locked)
            if locked then
                ClearPedTasks(ped)
            end
        end
    end

    local function disablePlacementControls(lockMovement)
        local controls = {
            14, 15, 16, 17, 20, 21, 22, 24, 25, 37, 38, 44, 45, 47, 73, 75,
            140, 141, 142, 143, 177, 200, 257, 263, 264,
        }
        local movementControls = {
            30, 31, 32, 33, 34, 35,
        }

        for i = 1, #controls do
            DisableControlAction(0, controls[i], true)
            DisableControlAction(1, controls[i], true)
            DisableControlAction(2, controls[i], true)
        end

        if lockMovement then
            for i = 1, #movementControls do
                DisableControlAction(0, movementControls[i], true)
                DisableControlAction(1, movementControls[i], true)
                DisableControlAction(2, movementControls[i], true)
            end

            local ped = PlayerPedId()
            if ped and ped ~= 0 then
                SetPedDesiredMoveBlendRatio(ped, 0.0)
                SetPedMoveRateOverride(ped, 0.0)
                if IsPedWalking(ped) or IsPedRunning(ped) or IsPedSprinting(ped) then
                    ClearPedTasks(ped)
                end
            end
        end

        DisablePlayerFiring(PlayerId(), true)
    end

    RegisterNetEvent('tss_bridge:client:chairTableSaved', function(saved, value)
        if saved then
            notify(('Location table saved: tss_bridge/%s'):format(value))
        else
            notify(('Location table was not saved: %s'):format(value or 'unknown error'))
        end
    end)

    local startChairTool
    local updateSelectorUi
    local updatePlacementUi
    local setDebugFocus

    local function getProfileFromArg(value)
        if type(value) ~= 'string' then return nil end
        local normalized = value:lower():gsub('[^%w]', '')

        for i = 1, #chairTool.tableOptions do
            local option = chairTool.tableOptions[i]
            if normalized == option:lower():gsub('[^%w]', '') then
                return option, i
            end
        end

        return nil
    end

    local function openTableSelector()
        if chairTool.active or chairTool.selecting then return end

        if not TSS.Config.DebugTools then
            notify('TSS debug tools are disabled. Set tss_debug true.')
            return
        end

        chairTool.selecting = true
        chairTool.pedSelect = nil
        setDebugFocus(false)
        chairTool.tableOption = chairTool.tableOption or 1
        updateSelectorUi(true)
    end

    local function closeTableSelector()
        chairTool.selecting = false
        if not chairTool.pedSelect then
            setDebugFocus(false)
        end
    end

    setDebugFocus = function(focused)
        SetNuiFocus(focused, focused)
        if SetNuiFocusKeepInput then
            SetNuiFocusKeepInput(false)
        end
    end

    local function sendDebugUi(payload, force)
        local now = GetGameTimer()
        if not force and now < chairTool.uiNextUpdate then return end

        chairTool.uiNextUpdate = now + 100
        SendNUIMessage({
            action = 'debugUi',
            payload = payload,
        })
    end

    local function hideDebugUi()
        setDebugFocus(false)
        SendNUIMessage({
            action = 'debugUi',
            payload = { visible = false },
        })
    end

    local function getSavedEntryCount()
        local count = 0

        for i = 1, #chairTool.tableOptions do
            local entries = chairTool.allEntries[chairTool.tableOptions[i]]
            count = count + (entries and #entries or 0)
        end

        return count
    end

    local function saveAllTables()
        if getSavedEntryCount() == 0 then
            notify('No location entries to save')
            return
        end

        local output = TSS.DebugTools.FormatLocationTables(chairTool.allEntries, chairTool.tableOptions)
        TriggerServerEvent('tss_bridge:server:saveChairTable', output)

        chairTool.allEntries = {}
        chairTool.entries = {}
        chairTool.tableOption = 1
        chairTool.tableName = 'Chairs'
        chairTool.freePlayer = false
        chairTool.mode = 'position'
        chairTool.coords = nil
        chairTool.stand = nil
        chairTool.l = 0.6
        chairTool.w = 0.6
        chairTool.minZ = nil
        chairTool.maxZ = nil
        chairTool.pedSelect = nil
        chairTool.pedModelOption = 1
        chairTool.pedScenarioOption = 2
        chairTool.pedModel = pedModelOptions[1]
        chairTool.pedScenario = pedScenarioOptions[2].value

        deleteGhost()
        deleteSavedGhosts()
        setPlayerLocked(false)
        updateSelectorUi(true)
        notify('Location debug cleared')
    end

    local function startSelectedTable()
        if chairTool.tableOption == #chairTool.tableOptions + 1 then
            saveAllTables()
            return
        end

        local option = chairTool.tableOptions[chairTool.tableOption] or 'Chairs'

        if option == 'Peds' then
            chairTool.pedSelect = 'model'
            setDebugFocus(true)
            updateSelectorUi(true)
            return
        end

        closeTableSelector()
        setDebugFocus(false)
        startChairTool(option)
    end

    local function buildSelectorItems()
        local items = {}

        for i = 1, #chairTool.tableOptions do
            local tableName = chairTool.tableOptions[i]
            local entries = chairTool.allEntries[tableName]

            items[#items + 1] = {
                label = tableName,
                count = entries and #entries or 0,
                selected = chairTool.tableOption == i,
                kind = 'table',
            }
        end

        items[#items + 1] = {
            label = 'Save File',
            count = getSavedEntryCount(),
            selected = chairTool.tableOption == #chairTool.tableOptions + 1,
            kind = 'save',
        }

        return items
    end

    local function buildPedSelectorItems()
        local items = {}

        if chairTool.pedSelect == 'model' then
            for i = 1, #pedModelOptions do
                items[#items + 1] = {
                    label = pedModelOptions[i],
                    count = 0,
                    selected = chairTool.pedModelOption == i,
                    kind = 'table',
                }
            end
        else
            for i = 1, #pedScenarioOptions do
                local option = pedScenarioOptions[i]
                items[#items + 1] = {
                    label = option.value or option.label,
                    count = 0,
                    selected = chairTool.pedScenarioOption == i,
                    kind = 'table',
                }
            end
        end

        return items
    end

    updateSelectorUi = function(force)
        if chairTool.pedSelect then
            setDebugFocus(true)
            sendDebugUi({
                visible = true,
                screen = 'selector',
                title = 'TSS Ped Spawner',
                subtitle = chairTool.pedSelect == 'model' and 'Choose ped model' or ('Choose scenario for %s'):format(chairTool.pedModel),
                items = buildPedSelectorItems(),
                pedPicker = {
                    modelIndex = chairTool.pedModelOption,
                    scenarioIndex = chairTool.pedScenarioOption,
                    models = pedModelOptions,
                    scenarios = pedScenarioOptions,
                },
                footer = 'Select model/scenario with mouse | Place Ped starts placement | ESC table menu',
                totalEntries = getSavedEntryCount(),
            }, force)
            return
        end

        setDebugFocus(false)
        sendDebugUi({
            visible = true,
            screen = 'selector',
            title = 'TSS Location Debug',
            subtitle = 'Choose the locations table to create',
            items = buildSelectorItems(),
            footer = 'W/S choose | E start/save | ESC cancel',
            totalEntries = getSavedEntryCount(),
        }, force)
    end

    local function formatNumber(value, decimals)
        return ('%.' .. (decimals or 3) .. 'f'):format(value or 0.0)
    end

    updatePlacementUi = function(force)
        if not chairTool.coords or not chairTool.stand then return end

        local chairMode = isChairProfile()
        local pedMode = isPedProfile()
        local editMode = chairTool.mode == 'rotation' and 'Rotation' or (chairTool.mode == 'size' and 'Size' or 'Position')
        local mode = chairTool.freePlayer and 'Stand position: player unlocked' or 'Placement: player locked'
        local scrollMode = chairTool.mode == 'rotation' and 'heading' or 'height'
        local metrics = {
            { label = 'X', value = formatNumber(chairTool.coords.x) },
            { label = 'Y', value = formatNumber(chairTool.coords.y) },
            { label = 'Z', value = formatNumber(chairTool.coords.z) },
            { label = 'Heading', value = formatNumber(chairTool.coords.w, 2) },
        }

        if chairMode then
            metrics[#metrics + 1] = { label = 'Stand', value = ('%s %s %s'):format(formatNumber(chairTool.stand.x), formatNumber(chairTool.stand.y), formatNumber(chairTool.stand.z)) }
        elseif pedMode then
            metrics[#metrics + 1] = { label = 'Model', value = chairTool.pedModel }
            metrics[#metrics + 1] = { label = 'Scenario', value = chairTool.pedScenario or 'None' }
        else
            metrics[#metrics + 1] = { label = 'Length', value = formatNumber(chairTool.l, 2) }
            metrics[#metrics + 1] = { label = 'Width', value = formatNumber(chairTool.w, 2) }
        end

        sendDebugUi({
            visible = true,
            screen = 'placement',
            title = ('TSS Location Debug: %s'):format(chairTool.tableName),
            subtitle = mode,
            modeLabel = editMode,
            savedLabel = pedMode and ('%s saved: %s | Temp: %s'):format(chairTool.tableName, #chairTool.entries, #chairTool.tempPeds) or ('%s saved: %s'):format(chairTool.tableName, #chairTool.entries),
            metrics = metrics,
            help = {
                (chairMode or pedMode) and 'Position: W/S forward, A/D side | Rotation: W/S red axis, A/D rotate' or 'Position: move box | Size: W/S length, A/D width | Rotation: A/D rotate',
                ('Mouse wheel: %s | LShift mode'):format(scrollMode),
                chairMode and 'Z stand move | E save | ESC/BKSP menu' or (pedMode and 'E save to file | G temp spawn | ESC/BKSP menu' or 'E save | ESC/BKSP menu'),
            },
            footer = 'Backspace returns to table menu. Save File writes all tables.',
            totalEntries = getSavedEntryCount(),
        }, force)
    end

    startChairTool = function(tableName)
        if chairTool.active then return end
        if not TSS.Config.DebugTools then
            notify('TSS debug tools are disabled. Set tss_debug true.')
            return
        end

        cleanupOrphanDebugPeds(80.0)

        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local heading = GetEntityHeading(ped)

        chairTool.active = true
        chairTool.stand = vec3(coords.x, coords.y, coords.z)
        chairTool.freePlayer = false
        chairTool.mode = 'position'
        chairTool.tableName = tableName or chairTool.tableName or 'Chairs'
        chairTool.coords = vec4(coords.x, coords.y, isPedProfile() and coords.z or (coords.z - 1.0), heading)
        chairTool.allEntries[chairTool.tableName] = chairTool.allEntries[chairTool.tableName] or {}
        chairTool.entries = chairTool.allEntries[chairTool.tableName]
        chairTool.l, chairTool.w = getDefaultZoneSize(chairTool.tableName)
        chairTool.minZ = chairTool.coords.z - 0.5
        chairTool.maxZ = chairTool.coords.z + 0.5
        chairTool.nextScenarioCheck = 0
        deleteSavedGhosts()

        if isChairProfile() then
            if spawnGhost(chairTool.coords) then
                for i = 1, #chairTool.entries do
                    spawnSavedGhost(chairTool.entries[i].coords)
                end
                setPlayerLocked(true)
                updatePlacementUi(true)
                notify('Chair debug started')
            else
                chairTool.active = false
            end
        elseif isPedProfile() then
            if spawnPedGhost(chairTool.coords) then
                setPlayerLocked(true)
                updatePlacementUi(true)
                notify(('Ped spawner started: %s'):format(chairTool.pedModel))
            else
                chairTool.active = false
            end
        else
            setPlayerLocked(true)
            deleteGhost()
            updatePlacementUi(true)
            notify(('Location debug started: %s'):format(chairTool.tableName))
        end
    end

    local function stopChairTool(returnToSelector)
        if not chairTool.active then return end

        deleteGhost()
        deleteSavedGhosts()
        setPlayerLocked(false)
        chairTool.active = false
        chairTool.coords = nil
        chairTool.stand = nil
        chairTool.freePlayer = false
        chairTool.mode = 'position'
        chairTool.tableName = 'Chairs'
        chairTool.entries = {}
        chairTool.l = 0.6
        chairTool.w = 0.6
        chairTool.minZ = nil
        chairTool.maxZ = nil
        chairTool.nextScenarioCheck = 0
        chairTool.pedSelect = nil

        if returnToSelector then
            chairTool.selecting = true
            updateSelectorUi(true)
            notify('Returned to location table menu')
        else
            hideDebugUi()
            notify('Location debug stopped')
        end
    end

    local function saveChair()
        if not chairTool.coords or not chairTool.stand then return end

        local savedCoords = vec4(chairTool.coords.x, chairTool.coords.y, chairTool.coords.z, chairTool.coords.w)

        chairTool.entries[#chairTool.entries + 1] = {
            coords = savedCoords,
            stand = vec3(chairTool.stand.x, chairTool.stand.y, chairTool.stand.z),
            pole = #chairTool.entries + 1,
            l = chairTool.l,
            w = chairTool.w,
            minZ = chairTool.minZ,
            maxZ = chairTool.maxZ,
            model = chairTool.pedModel,
            scenario = chairTool.pedScenario,
        }

        if isChairProfile() then
            spawnSavedGhost(savedCoords)
        end

        notify(('Saved %s #%s'):format(chairTool.tableName, #chairTool.entries))
    end

    local function updateChairPlacement()
        disablePlacementControls(not chairTool.freePlayer)

        local speed = chairTool.moveSpeed
        local forward, right = getLocalAxes(chairTool.coords)
        local moved = false

        local function moveBy(x, y, z, h)
            chairTool.coords = vec4(
                chairTool.coords.x + x,
                chairTool.coords.y + y,
                chairTool.coords.z + z,
                chairTool.coords.w + h
            )
            moved = true
        end

        if isChairProfile() and IsDisabledControlJustPressed(0, 20) then
            chairTool.freePlayer = not chairTool.freePlayer
            setPlayerLocked(not chairTool.freePlayer)
            notify(chairTool.freePlayer and 'Player movement unlocked' or 'Player movement locked')
        end

        if IsDisabledControlJustPressed(0, 21) then
            if isChairProfile() or isPedProfile() then
                chairTool.mode = chairTool.mode == 'position' and 'rotation' or 'position'
            elseif chairTool.mode == 'position' then
                chairTool.mode = 'size'
            elseif chairTool.mode == 'size' then
                chairTool.mode = 'rotation'
            else
                chairTool.mode = 'position'
            end
            notify(('Location debug mode: %s'):format(chairTool.mode))
        end

        if not chairTool.freePlayer then
            if chairTool.mode == 'position' then
                if IsDisabledControlPressed(0, 32) then moveBy(forward.x * speed, forward.y * speed, 0.0, 0.0) end
                if IsDisabledControlPressed(0, 33) then moveBy(-forward.x * speed, -forward.y * speed, 0.0, 0.0) end
                if IsDisabledControlPressed(0, 35) then moveBy(right.x * speed, right.y * speed, 0.0, 0.0) end
                if IsDisabledControlPressed(0, 34) then moveBy(-right.x * speed, -right.y * speed, 0.0, 0.0) end
            elseif chairTool.mode == 'size' then
                if IsDisabledControlPressed(0, 32) then chairTool.l = math.max(0.1, chairTool.l + chairTool.sizeSpeed); moved = true end
                if IsDisabledControlPressed(0, 33) then chairTool.l = math.max(0.1, chairTool.l - chairTool.sizeSpeed); moved = true end
                if IsDisabledControlPressed(0, 35) then chairTool.w = math.max(0.1, chairTool.w + chairTool.sizeSpeed); moved = true end
                if IsDisabledControlPressed(0, 34) then chairTool.w = math.max(0.1, chairTool.w - chairTool.sizeSpeed); moved = true end
            else
                if IsDisabledControlPressed(0, 35) then moveBy(0.0, 0.0, 0.0, chairTool.rotateSpeed) end
                if IsDisabledControlPressed(0, 34) then moveBy(0.0, 0.0, 0.0, -chairTool.rotateSpeed) end
                if IsDisabledControlPressed(0, 32) then moveBy(right.x * speed, right.y * speed, 0.0, 0.0) end
                if IsDisabledControlPressed(0, 33) then moveBy(-right.x * speed, -right.y * speed, 0.0, 0.0) end
            end
        end

        if IsDisabledControlJustPressed(0, 15) then
            if chairTool.mode == 'rotation' then
                moveBy(0.0, 0.0, 0.0, chairTool.scrollHeadingStep)
            else
                moveBy(0.0, 0.0, chairTool.scrollHeightStep, 0.0)
                chairTool.minZ = chairTool.coords.z - 0.5
                chairTool.maxZ = chairTool.coords.z + 0.5
            end
        end

        if IsDisabledControlJustPressed(0, 14) then
            if chairTool.mode == 'rotation' then
                moveBy(0.0, 0.0, 0.0, -chairTool.scrollHeadingStep)
            else
                moveBy(0.0, 0.0, -chairTool.scrollHeightStep, 0.0)
                chairTool.minZ = chairTool.coords.z - 0.5
                chairTool.maxZ = chairTool.coords.z + 0.5
            end
        end

        if chairTool.freePlayer then
            local standCoords = GetEntityCoords(PlayerPedId())
            chairTool.stand = vec3(standCoords.x, standCoords.y, standCoords.z)
        end

        if IsDisabledControlJustPressed(0, 38) then saveChair() end
        if isPedProfile() and IsDisabledControlJustPressed(0, 47) then spawnTemporaryPed() end
        if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then stopChairTool(true) end

        if moved and isChairProfile() then
            moveChairPed(chairTool.ghost, chairTool.coords)
            chairTool.nextScenarioCheck = GetGameTimer() + 250
        elseif moved and isPedProfile() then
            movePedGhost(chairTool.ghost, chairTool.coords)
        end
    end

    local function drawChairToolUi()
        if not chairTool.coords or not chairTool.stand then return end

        local mode = chairTool.freePlayer and 'Stand position: player unlocked' or 'Placement: player locked'
        local editMode = chairTool.mode == 'rotation' and 'Rotation' or (chairTool.mode == 'size' and 'Size' or 'Position')
        local scrollMode = chairTool.mode == 'rotation' and 'heading' or 'height'
        local ghost = chairTool.coords
        local stand = chairTool.stand
        local chairMode = isChairProfile()

        drawPanel({
            { text = ('TSS Location Debug: %s'):format(chairTool.tableName), scale = 0.36, r = 255, g = 26, b = 26 },
            { text = mode .. ' | ' .. editMode, scale = 0.30, r = 255, g = 255, b = 255 },
            { text = ('%s saved: %s'):format(chairTool.tableName, #chairTool.entries), scale = 0.27, r = 210, g = 210, b = 210 },
            { text = chairMode and 'Position: W/S forward, A/D side | Rotation: W/S red axis, A/D rotate' or 'Position: move box | Size: W/S length, A/D width | Rotation: A/D rotate', scale = 0.24, r = 225, g = 225, b = 225 },
            { text = 'Wheel ' .. scrollMode .. ' | LShift mode | ' .. (chairMode and 'Z stand move | ' or '') .. 'E save | ESC exit', scale = 0.24, r = 225, g = 225, b = 225 },
            { text = ('x %.3f   y %.3f   z %.3f'):format(ghost.x, ghost.y, ghost.z), scale = 0.25, r = 180, g = 205, b = 255 },
            { text = chairMode and ('heading %.2f   stand %.3f %.3f %.3f'):format(ghost.w, stand.x, stand.y, stand.z) or ('heading %.2f   l %.2f   w %.2f'):format(ghost.w, chairTool.l, chairTool.w), scale = 0.25, r = 180, g = 205, b = 255 },
        })
    end

    RegisterNUICallback('debugPedPicker', function(data, cb)
        data = type(data) == 'table' and data or {}

        if data.modelIndex then
            chairTool.pedModelOption = math.max(1, math.min(#pedModelOptions, tonumber(data.modelIndex) or chairTool.pedModelOption))
            chairTool.pedModel = pedModelOptions[chairTool.pedModelOption]
        end

        if data.scenarioIndex then
            chairTool.pedScenarioOption = math.max(1, math.min(#pedScenarioOptions, tonumber(data.scenarioIndex) or chairTool.pedScenarioOption))
            local scenario = pedScenarioOptions[chairTool.pedScenarioOption]
            chairTool.pedScenario = scenario and scenario.value or nil
        end

        if data.start == true then
            chairTool.pedSelect = nil
            closeTableSelector()
            setDebugFocus(false)
            startChairTool('Peds')
        else
            chairTool.pedSelect = 'model'
            updateSelectorUi(true)
        end

        cb({ ok = true })
    end)

    local function updateTableSelector()
        disablePlacementControls(true)

        if chairTool.pedSelect then
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(0, 106, true)
            DisableControlAction(1, 1, true)
            DisableControlAction(1, 2, true)
            DisableControlAction(1, 106, true)
            DisableControlAction(2, 1, true)
            DisableControlAction(2, 2, true)
            DisableControlAction(2, 106, true)

            local totalOptions = chairTool.pedSelect == 'model' and #pedModelOptions or #pedScenarioOptions
            local currentOption = chairTool.pedSelect == 'model' and chairTool.pedModelOption or chairTool.pedScenarioOption

            if IsDisabledControlJustPressed(0, 32) or IsDisabledControlJustPressed(0, 172) then
                currentOption = currentOption - 1
                if currentOption < 1 then currentOption = totalOptions end
            end

            if IsDisabledControlJustPressed(0, 33) or IsDisabledControlJustPressed(0, 173) then
                currentOption = currentOption + 1
                if currentOption > totalOptions then currentOption = 1 end
            end

            if chairTool.pedSelect == 'model' then
                chairTool.pedModelOption = currentOption
            else
                chairTool.pedScenarioOption = currentOption
            end

            if IsDisabledControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 191) then
                if chairTool.pedSelect == 'model' then
                    chairTool.pedModel = pedModelOptions[chairTool.pedModelOption]
                    chairTool.pedSelect = 'scenario'
                    updateSelectorUi(true)
                else
                    local scenario = pedScenarioOptions[chairTool.pedScenarioOption]
                    chairTool.pedScenario = scenario and scenario.value or nil
                    chairTool.pedSelect = nil
                    closeTableSelector()
                    setDebugFocus(false)
                    startChairTool('Peds')
                end
                return
            end

            if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then
                if chairTool.pedSelect == 'scenario' then
                    chairTool.pedSelect = 'model'
                    updateSelectorUi(true)
                else
                    chairTool.pedSelect = nil
                    setDebugFocus(false)
                    updateSelectorUi(true)
                end
            end

            return
        end

        local totalOptions = #chairTool.tableOptions + 1

        if IsDisabledControlJustPressed(0, 32) or IsDisabledControlJustPressed(0, 172) then
            chairTool.tableOption = chairTool.tableOption - 1
            if chairTool.tableOption < 1 then chairTool.tableOption = totalOptions end
        end

        if IsDisabledControlJustPressed(0, 33) or IsDisabledControlJustPressed(0, 173) then
            chairTool.tableOption = chairTool.tableOption + 1
            if chairTool.tableOption > totalOptions then chairTool.tableOption = 1 end
        end

        if IsDisabledControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 191) then
            startSelectedTable()
            return
        end

        if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then
            closeTableSelector()
            hideDebugUi()
            notify('Location debug cancelled')
        end
    end

    local function drawTableSelectorUi()
        updateSelectorUi(false)
    end

    CreateThread(function()
        cleanupOrphanDebugPeds(80.0)

        while true do
            if #chairTool.tempPeds > 0 then
                keepTempPedScenariosAlive()
            end

            if chairTool.selecting then
                updateTableSelector()
                if chairTool.selecting then
                    drawTableSelectorUi()
                end
                Wait(0)
            elseif chairTool.active then
                updateChairPlacement()
                if chairTool.active and chairTool.coords and chairTool.stand then
                    if isChairProfile() then
                        keepChairScenarioAlive()
                        drawMarkerAt(chairTool.stand)
                        drawAxisGizmo(chairTool.coords, chairTool.mode == 'rotation')
                    elseif isPedProfile() then
                        drawAxisGizmo(chairTool.coords, chairTool.mode == 'rotation')
                        for i = 1, #chairTool.entries do
                            local entry = chairTool.entries[i]
                            drawMarkerAt(vec3(entry.coords.x, entry.coords.y, entry.coords.z))
                        end
                    else
                        drawZoneBox(chairTool.coords, chairTool.l, chairTool.w, chairTool.minZ, chairTool.maxZ, 80, 200, 255, 235)
                        for i = 1, #chairTool.entries do
                            local entry = chairTool.entries[i]
                            drawZoneBox(entry.coords, entry.l, entry.w, entry.minZ, entry.maxZ, 80, 255, 120, 160)
                        end
                    end
                    updatePlacementUi(false)
                end
                Wait(0)
            else
                Wait(500)
            end
        end
    end)

    AddEventHandler('onClientResourceStop', function(resource)
        if resource ~= GetCurrentResourceName() then return end

        deleteGhost()
        deleteSavedGhosts()
        deleteTempPeds()
        cleanupOrphanDebugPeds(120.0)
        setPlayerLocked(false)
        hideDebugUi()
    end)

    RegisterCommand('tsschairdebug', function()
        if chairTool.active then
            stopChairTool(true)
        elseif chairTool.selecting then
            closeTableSelector()
            hideDebugUi()
        else
            openTableSelector()
        end
    end, false)

    RegisterCommand('tsslocdebug', function(_, args)
        if chairTool.active then
            stopChairTool(true)
            return
        end

        if chairTool.selecting then
            closeTableSelector()
            hideDebugUi()
            return
        end

        local tableName, index = getProfileFromArg(args and args[1])
        if tableName then
            chairTool.tableOption = index
            if tableName == 'Peds' then
                chairTool.selecting = true
                chairTool.pedSelect = 'model'
                updateSelectorUi(true)
            else
                startChairTool(tableName)
            end
        else
            openTableSelector()
        end
    end, false)

    RegisterCommand('tsspeddebug', function()
        if chairTool.active then
            stopChairTool(true)
            return
        end

        if chairTool.selecting then
            closeTableSelector()
            hideDebugUi()
            return
        end

        chairTool.tableOption = 2
        chairTool.selecting = true
        chairTool.pedSelect = 'model'
        updateSelectorUi(true)
    end, false)

    RegisterCommand('tsscleartemppeds', function()
        local count = #chairTool.tempPeds
        deleteTempPeds()
        notify(('Cleared %s temporary peds'):format(count))
        if chairTool.active and isPedProfile() then
            updatePlacementUi(true)
        end
    end, false)

    RegisterCommand('tssdebug', function(_, args)
        local value = args[1]
        local state = value == 'true' or value == '1' or value == 'on'

        if value == 'true' or value == '1' or value == 'on' or value == 'false' or value == '0' or value == 'off' then
            TSS.SetDebug(state)
            notify(('TSS debug: %s'):format(tostring(state)))
        else
            notify('Usage: /tssdebug true|false')
        end
    end, false)
end
