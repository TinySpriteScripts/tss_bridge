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

local function formatChairEntry(coords, stand)
    return ('            { coords = %s, stand = %s },'):format(formatVec4(coords), formatVec3(stand))
end

local locationTableProfiles = {
    Chairs = {
        label = 'Loc[Config.Lan].target["Chairs"]',
        icon = 'fas fa-chair',
        entry = function(entry)
            return ('            { coords = %s, stand = %s },'):format(formatVec4(entry.coords), formatVec3(entry.stand))
        end,
    },
    WashHands = {
        label = 'Loc[Config.Lan].target["WashHands"]',
        icon = 'fas fa-sink',
        entry = function(entry)
            return ('            { coords = %s, l=0.5, w=0.5 },'):format(formatVec4(entry.coords))
        end,
    },
    Poles = {
        label = 'Loc[Config.Lan].target["Poles"]',
        icon = 'fas fa-child',
        entry = function(entry, index)
            return ('            { coords = %s, l=0.7, w=0.7, pole = %s },'):format(formatVec4(entry.coords), entry.pole or index)
        end,
    },
}

function TSS.DebugTools.FormatLocationTable(entries, tableName)
    local profile = locationTableProfiles[tableName or 'Chairs'] or locationTableProfiles.Chairs
    tableName = locationTableProfiles[tableName] and tableName or 'Chairs'

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
    RegisterNetEvent('tss_bridge:server:saveChairTable', function(output)
        local src = source

        if type(output) ~= 'string' or output == '' or #output > 50000 then
            TriggerClientEvent('tss_bridge:client:chairTableSaved', src, false, 'Invalid chair table output')
            return
        end

        local filename = ('debug/chairs_%s_%s.txt'):format(os.date('%Y%m%d_%H%M%S'), tostring(src))
        local saved = SaveResourceFile('tss_bridge', filename, output, #output)

        TriggerClientEvent('tss_bridge:client:chairTableSaved', src, saved == true, filename)
        TSS.Debug(('Chair table saved to %s'):format(filename))
    end)
end

if TSS.IsClient() then
    local chairScenario = 'PROP_HUMAN_SEAT_CHAIR_MP_PLAYER'
    local chairAnimDict = 'amb@prop_human_seat_chair_mp@male@generic@base'
    local chairAnimName = 'base'

    local chairTool = {
        active = false,
        selecting = false,
        ghost = nil,
        savedGhosts = {},
        entries = {},
        coords = nil,
        stand = nil,
        freePlayer = false,
        mode = 'position',
        tableName = 'Chairs',
        tableOptions = { 'Chairs', 'WashHands', 'Poles' },
        tableOption = 1,
        model = 'mp_m_freemode_01',
        moveSpeed = 0.01,
        rotateSpeed = 2.5,
        scrollHeightStep = 0.025,
        scrollHeadingStep = 2.5,
        nextScenarioCheck = 0,
    }

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
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
        SetEntityHeading(ped, coords.w)
        FreezeEntityPosition(ped, false)
        TaskStartScenarioAtPosition(
            ped,
            chairScenario,
            coords.x,
            coords.y,
            coords.z,
            coords.w,
            -1,
            true,
            true
        )
        Wait(0)

        if not IsPedUsingScenario(ped, chairScenario) then
            local loaded = TSS.LoadAnimDict(chairAnimDict, 1500)
            if loaded then
                TaskPlayAnim(ped, chairAnimDict, chairAnimName, 8.0, 8.0, -1, 1, 0.0, false, false, false)
            end
        end

        CreateThread(function()
            Wait(650)
            if ped and DoesEntityExist(ped) then
                FreezeEntityPosition(ped, true)
            end
        end)
    end

    local function moveChairPed(ped, coords)
        if not ped or not DoesEntityExist(ped) or not coords then return end

        FreezeEntityPosition(ped, true)
        SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
        SetEntityHeading(ped, coords.w)
    end

    local function keepChairScenarioAlive()
        local now = GetGameTimer()
        if now < chairTool.nextScenarioCheck then return end

        chairTool.nextScenarioCheck = now + 1000

        if chairTool.ghost
            and DoesEntityExist(chairTool.ghost)
            and not IsPedUsingScenario(chairTool.ghost, chairScenario)
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
                and not IsPedUsingScenario(ped, chairScenario)
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
        chairTool.tableOption = chairTool.tableOption or 1
    end

    local function closeTableSelector()
        chairTool.selecting = false
    end

    local function startSelectedTable()
        local option = chairTool.tableOptions[chairTool.tableOption] or 'Chairs'

        closeTableSelector()
        startChairTool(option)
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
        chairTool.entries = {}
        chairTool.coords = vec4(coords.x, coords.y, coords.z - 1.0, heading)
        chairTool.stand = vec3(coords.x, coords.y, coords.z)
        chairTool.freePlayer = false
        chairTool.mode = 'position'
        chairTool.tableName = tableName or chairTool.tableName or 'Chairs'
        chairTool.nextScenarioCheck = 0
        deleteSavedGhosts()

        if spawnGhost(chairTool.coords) then
            setPlayerLocked(true)
            notify('Chair debug started')
        else
            chairTool.active = false
        end
    end

    local function saveChairTable()
        if #chairTool.entries == 0 then return end

        local output = TSS.DebugTools.FormatLocationTable(chairTool.entries, chairTool.tableName)
        TriggerServerEvent('tss_bridge:server:saveChairTable', output)
    end

    local function stopChairTool(saveResult)
        if not chairTool.active then return end

        if saveResult then
            saveChairTable()
        end

        deleteGhost()
        deleteSavedGhosts()
        setPlayerLocked(false)
        chairTool.active = false
        chairTool.coords = nil
        chairTool.stand = nil
        chairTool.freePlayer = false
        chairTool.mode = 'position'
        chairTool.tableName = 'Chairs'
        chairTool.nextScenarioCheck = 0
        notify('Chair debug stopped')
    end

    local function saveChair()
        if not chairTool.coords or not chairTool.stand then return end

        local savedCoords = vec4(chairTool.coords.x, chairTool.coords.y, chairTool.coords.z, chairTool.coords.w)

        chairTool.entries[#chairTool.entries + 1] = {
            coords = savedCoords,
            stand = vec3(chairTool.stand.x, chairTool.stand.y, chairTool.stand.z),
            pole = #chairTool.entries + 1,
        }
        spawnSavedGhost(savedCoords)
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

        if IsDisabledControlJustPressed(0, 20) then
            chairTool.freePlayer = not chairTool.freePlayer
            setPlayerLocked(not chairTool.freePlayer)
            notify(chairTool.freePlayer and 'Player movement unlocked' or 'Player movement locked')
        end

        if IsDisabledControlJustPressed(0, 21) then
            chairTool.mode = chairTool.mode == 'position' and 'rotation' or 'position'
            notify(('Chair debug mode: %s'):format(chairTool.mode))
        end

        if not chairTool.freePlayer then
            if chairTool.mode == 'position' then
                if IsDisabledControlPressed(0, 32) then moveBy(forward.x * speed, forward.y * speed, 0.0, 0.0) end
                if IsDisabledControlPressed(0, 33) then moveBy(-forward.x * speed, -forward.y * speed, 0.0, 0.0) end
                if IsDisabledControlPressed(0, 35) then moveBy(right.x * speed, right.y * speed, 0.0, 0.0) end
                if IsDisabledControlPressed(0, 34) then moveBy(-right.x * speed, -right.y * speed, 0.0, 0.0) end
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
            end
        end

        if IsDisabledControlJustPressed(0, 14) then
            if chairTool.mode == 'rotation' then
                moveBy(0.0, 0.0, 0.0, -chairTool.scrollHeadingStep)
            else
                moveBy(0.0, 0.0, -chairTool.scrollHeightStep, 0.0)
            end
        end

        if chairTool.freePlayer then
            local standCoords = GetEntityCoords(PlayerPedId())
            chairTool.stand = vec3(standCoords.x, standCoords.y, standCoords.z)
        end

        if IsDisabledControlJustPressed(0, 38) then saveChair() end
        if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then stopChairTool(true) end

        if moved then
            moveChairPed(chairTool.ghost, chairTool.coords)
            chairTool.nextScenarioCheck = GetGameTimer() + 250
        end
    end

    local function drawChairToolUi()
        if not chairTool.coords or not chairTool.stand then return end

        local mode = chairTool.freePlayer and 'Stand position: player unlocked' or 'Placement: player locked'
        local editMode = chairTool.mode == 'rotation' and 'Rotation' or 'Position'
        local scrollMode = chairTool.mode == 'rotation' and 'heading' or 'height'
        local ghost = chairTool.coords
        local stand = chairTool.stand

        drawPanel({
            { text = ('TSS Location Debug: %s'):format(chairTool.tableName), scale = 0.36, r = 255, g = 26, b = 26 },
            { text = mode .. ' | ' .. editMode, scale = 0.30, r = 255, g = 255, b = 255 },
            { text = ('%s saved: %s'):format(chairTool.tableName, #chairTool.entries), scale = 0.27, r = 210, g = 210, b = 210 },
            { text = 'Position: W/S forward, A/D side | Rotation: W/S red axis, A/D rotate', scale = 0.24, r = 225, g = 225, b = 225 },
            { text = 'Wheel ' .. scrollMode .. ' | LShift mode | Z stand move | E save | ESC exit', scale = 0.24, r = 225, g = 225, b = 225 },
            { text = ('x %.3f   y %.3f   z %.3f'):format(ghost.x, ghost.y, ghost.z), scale = 0.25, r = 180, g = 205, b = 255 },
            { text = ('heading %.2f   stand %.3f %.3f %.3f'):format(ghost.w, stand.x, stand.y, stand.z), scale = 0.25, r = 180, g = 205, b = 255 },
        })
    end

    local function updateTableSelector()
        disablePlacementControls(true)

        if IsDisabledControlJustPressed(0, 32) or IsDisabledControlJustPressed(0, 172) then
            chairTool.tableOption = chairTool.tableOption - 1
            if chairTool.tableOption < 1 then chairTool.tableOption = #chairTool.tableOptions end
        end

        if IsDisabledControlJustPressed(0, 33) or IsDisabledControlJustPressed(0, 173) then
            chairTool.tableOption = chairTool.tableOption + 1
            if chairTool.tableOption > #chairTool.tableOptions then chairTool.tableOption = 1 end
        end

        if IsDisabledControlJustPressed(0, 38) or IsDisabledControlJustPressed(0, 191) then
            startSelectedTable()
            return
        end

        if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then
            closeTableSelector()
            notify('Location debug cancelled')
        end
    end

    local function drawTableSelectorUi()
        local lines = {
            { text = 'TSS Location Debug', scale = 0.39, r = 255, g = 26, b = 26 },
            { text = 'Choose the locations table to create', scale = 0.28, r = 255, g = 255, b = 255 },
        }

        for i = 1, #chairTool.tableOptions do
            local prefix = i == chairTool.tableOption and '> ' or '  '
            local color = i == chairTool.tableOption and 255 or 190

            lines[#lines + 1] = {
                text = prefix .. chairTool.tableOptions[i],
                scale = 0.29,
                r = color,
                g = color,
                b = color,
            }
        end

        lines[#lines + 1] = { text = 'W/S choose | E start | ESC cancel', scale = 0.25, r = 225, g = 225, b = 225 }
        drawPanel(lines)
    end

    CreateThread(function()
        cleanupOrphanDebugPeds(80.0)

        while true do
            if chairTool.selecting then
                updateTableSelector()
                if chairTool.selecting then
                    drawTableSelectorUi()
                end
                Wait(0)
            elseif chairTool.active then
                updateChairPlacement()
                if chairTool.active and chairTool.coords and chairTool.stand then
                    keepChairScenarioAlive()
                    drawMarkerAt(chairTool.stand)
                    drawAxisGizmo(chairTool.coords, chairTool.mode == 'rotation')
                    drawChairToolUi()
                end
                Wait(0)
            else
                Wait(500)
            end
        end
    end)

    AddEventHandler('onResourceStop', function(resource)
        if resource ~= GetCurrentResourceName() then return end

        deleteGhost()
        deleteSavedGhosts()
        cleanupOrphanDebugPeds(120.0)
        setPlayerLocked(false)
    end)

    RegisterCommand('tsschairdebug', function()
        if chairTool.active then
            stopChairTool(true)
        elseif chairTool.selecting then
            closeTableSelector()
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
            return
        end

        local tableName, index = getProfileFromArg(args and args[1])
        if tableName then
            chairTool.tableOption = index
            startChairTool(tableName)
        else
            openTableSelector()
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
