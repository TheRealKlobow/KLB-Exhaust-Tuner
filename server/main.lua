local localeKey = Config.Locale or 'en'

local VehicleStates = {}
local SavedProfiles = {}
local cleanupInterval = tonumber(Config.StateCleanupInterval) or 0

if cleanupInterval > 0 and type(NetworkDoesEntityExistWithNetworkId) == 'function' then
    CreateThread(function()
        local delay = math.max(1000, cleanupInterval)
        while true do
            Wait(delay)
            local expired = {}
            for netId in pairs(VehicleStates) do
                local numericId = tonumber(netId) or netId
                if not NetworkDoesEntityExistWithNetworkId(numericId) then
                    expired[#expired + 1] = netId
                end
            end
            if #expired > 0 then
                for _, id in ipairs(expired) do
                    VehicleStates[id] = nil
                end
                print(('[klb_exhaustaudio] Pruned %d stale vehicle state(s).'):format(#expired))
            end
        end
    end)
end

local function copyState(state)
    local result = {}
    for key, defaultValue in pairs(Config.DefaultState) do
        local value = state and state[key]
        if value == nil then
            value = defaultValue
        end
        result[key] = value
    end
    return result
end

local function clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

local function sanitizeSettings(data)
    local sanitized = {}
    local trimmed = {}

    for key, defaultValue in pairs(Config.DefaultState) do
        local incoming = data and data[key]
        if type(defaultValue) == 'number' then
            local limits = Config.Limits[key] or { min = 0, max = 100 }
            local numberValue = tonumber(incoming)
            if not numberValue then numberValue = defaultValue end
            numberValue = clamp(numberValue, limits.min or 0, limits.max or 100)
            if limits.cap and numberValue > limits.cap then
                numberValue = limits.cap
                trimmed[#trimmed + 1] = key
            end
            sanitized[key] = math.floor(numberValue + 0.5)
        else
            local value = incoming
            if key == 'valveMode' then
                if not Config.ValveModes.labels[value] then
                    value = defaultValue
                end
            elseif key == 'autoStrategy' then
                if not Config.AutoStrategies.labels[value] then
                    value = defaultValue
                end
            end
            sanitized[key] = value or defaultValue
        end
    end

    return sanitized, trimmed
end

local function getVehicleFromNetId(netId, playerPed)
    if not netId then return 0 end
    if type(netId) ~= 'number' then netId = tonumber(netId) end
    if not netId then return 0 end

    if NetworkGetEntityFromNetworkId and NetworkDoesEntityExistWithNetworkId then
        if not NetworkDoesEntityExistWithNetworkId(netId) then return 0 end
        return NetworkGetEntityFromNetworkId(netId)
    end

    if playerPed and playerPed ~= 0 then
        local vehicle = GetVehiclePedIsIn(playerPed, false)
        if vehicle ~= 0 and NetworkGetNetworkIdFromEntity and NetworkGetNetworkIdFromEntity(vehicle) == netId then
            return vehicle
        end
    end

    return 0
end

local function ensureDriver(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false, nil, nil end
    if not DoesEntityExist(ped) then return false, nil, nil end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then
        TriggerClientEvent('klb_exhaustaudio:notify', source, KLocale.notify(localeKey, 'noVehicle'))
        return false, nil, nil
    end
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        TriggerClientEvent('klb_exhaustaudio:notify', source, KLocale.notify(localeKey, 'driverOnly'))
        return false, nil, nil
    end
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    return true, vehicle, netId
end

local function sendSync(target, netId, state, driverSource)
    TriggerClientEvent('klb_exhaustaudio:syncVehicle', target, netId, state, driverSource)
end

RegisterNetEvent('klb_exhaustaudio:requestOpen', function(netId)
    local src = source
    local success, vehicle, vehicleNet = ensureDriver(src)
    if not success then return end

    netId = netId or vehicleNet
    if not netId or netId == 0 then
        netId = vehicleNet
    end

    local state = VehicleStates[netId] or SavedProfiles[src] or Config.DefaultState
    TriggerClientEvent('klb_exhaustaudio:openUI', src, {
        state = copyState(state),
        netId = netId,
        hasSaved = SavedProfiles[src] ~= nil
    })
end)

RegisterNetEvent('klb_exhaustaudio:applySettings', function(data)
    local src = source
    local success, vehicle, netId = ensureDriver(src)
    if not success then return end

    local state, trimmed = sanitizeSettings(data)
    VehicleStates[netId] = copyState(state)

    sendSync(-1, netId, state, src)
    TriggerClientEvent('klb_exhaustaudio:notify', src, KLocale.notify(localeKey, 'applied'))

    if trimmed and #trimmed > 0 then
        local labels = {}
        for _, key in ipairs(trimmed) do
            local label = KLocale.text(localeKey, 'ui.labels.' .. key) or key
            labels[#labels + 1] = label
        end
        TriggerClientEvent('klb_exhaustaudio:notify', src, KLocale.notify(localeKey, 'valuesTrimmed', { fields = table.concat(labels, ', ') }))
    end
end)

RegisterNetEvent('klb_exhaustaudio:saveProfile', function(data)
    local src = source
    local state = select(1, sanitizeSettings(data))
    SavedProfiles[src] = copyState(state)
    TriggerClientEvent('klb_exhaustaudio:notify', src, KLocale.notify(localeKey, 'profileSaved'))
end)

RegisterNetEvent('klb_exhaustaudio:onDriverEntered', function(netId)
    local src = source
    local id = tonumber(netId)
    if not id then return end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end
    local vehicle = getVehicleFromNetId(id, ped)
    if vehicle == 0 then return end
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then return end

    local state = VehicleStates[id]
    if not state and Config.AutoApplySavedProfile and SavedProfiles[src] then
        state = copyState(SavedProfiles[src])
        VehicleStates[id] = copyState(state)
        sendSync(-1, id, state, src)
        TriggerClientEvent('klb_exhaustaudio:notify', src, KLocale.notify(localeKey, 'applied'))
        return
    end

    if state then
        sendSync(src, id, state)
    end
end)

RegisterNetEvent('klb_exhaustaudio:onDriverLeft', function(netId)
    -- Hook reserved for future cleanup – keeping state allows the next driver to retain the profile.
end)

RegisterNetEvent('klb_exhaustaudio:requestSync', function()
    local src = source
    local export = {}
    for netId, state in pairs(VehicleStates) do
        export[netId] = copyState(state)
    end
    TriggerClientEvent('klb_exhaustaudio:bulkSync', src, export)
end)

AddEventHandler('playerDropped', function()
    local src = source
    SavedProfiles[src] = nil
end)
