local localeKey = Config.Locale or 'en'
local localePayload = nil

local ActiveVehicleStates = {}
local lastDriverNetId = nil

local function callNative(fn, ...)
    if type(fn) == 'function' then
        return fn(...)
    end
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

local function mapSlider(value)
    value = tonumber(value) or 0
    if value < 0 then value = 0 end
    if value > 100 then value = 100 end
    return value / 100.0
end

local function isLocalPlayer(serverId)
    if not serverId then return false end
    return serverId == GetPlayerServerId(PlayerId())
end

local function showToast(text)
    if not text or text == '' then return end
    SendNUIMessage({ action = 'toast', text = text })
end

local function netToVehicle(netId)
    if not netId then return 0 end
    if type(netId) ~= 'number' then netId = tonumber(netId) end
    if not netId then return 0 end
    if not NetworkDoesEntityExistWithNetworkId(netId) then return 0 end
    local entity = NetToVeh(netId)
    if entity == 0 or not DoesEntityExist(entity) then
        return 0
    end
    return entity
end

local function entityIsNetworked(entity)
    if not entity or entity == 0 then return false end
    if NetworkGetEntityIsNetworked then
        return NetworkGetEntityIsNetworked(entity)
    elseif NetworkIsEntityNetworked then
        return NetworkIsEntityNetworked(entity)
    end
    return true
end

local function ensureEntityNetworked(entity)
    if not entity or entity == 0 then return false end
    if not entityIsNetworked(entity) then
        if NetworkRegisterEntityAsNetworked then
            NetworkRegisterEntityAsNetworked(entity)
        end
        return entityIsNetworked(entity)
    end
    return true
end

local function applyVehicleAudio(netId, settings)
    local vehicle = netToVehicle(netId)
    if vehicle == 0 then return end
    if not IsEntityAVehicle(vehicle) then return end

    ensureEntityNetworked(vehicle)

    if not NetworkHasControlOfEntity(vehicle) then
        NetworkRequestControlOfEntity(vehicle)
    end

    local toneValue = settings.tone or Config.DefaultState.tone
    local chosenSound = nil
    for _, profile in ipairs(Config.AudioProfiles) do
        if toneValue <= profile.maxTone then
            chosenSound = profile.sound
            break
        end
    end
    if chosenSound then
        callNative(ForceVehicleEngineAudio, vehicle, chosenSound)
        callNative(SetVehicleEngineSoundName, vehicle, chosenSound)
    end

    local pressureRange = Config.AudioTuning.volumePressure
    local finalPressure = 0.0
    local basePressure = nil
    if pressureRange then
        basePressure = pressureRange.min + (pressureRange.max - pressureRange.min) * mapSlider(settings.volume or Config.DefaultState.volume)
        finalPressure = basePressure
    end

    local burbleRange = Config.AudioTuning.burbleTurbo
    if burbleRange then
        local burblePressure = burbleRange.min + (burbleRange.max - burbleRange.min) * mapSlider(settings.burble or Config.DefaultState.burble)
        if burblePressure > 0.1 then
            callNative(SetVehicleBoostActive, vehicle, true)
        else
            callNative(SetVehicleBoostActive, vehicle, false)
        end
        if burblePressure > finalPressure then
            finalPressure = burblePressure
        end
    end

    local autoStrategy = settings.autoStrategy or Config.DefaultState.autoStrategy
    if basePressure then
        if autoStrategy == 'speed' then
            local speed = GetEntitySpeed(vehicle)
            local factor = math.min(1.0, speed / 40.0)
            finalPressure = math.max(finalPressure, basePressure + factor * 0.1)
        elseif autoStrategy == 'timed' then
            local phase = (GetGameTimer() % 6000) / 6000.0
            local oscillation = (math.sin(phase * 6.28318) + 1.0) * 0.5
            finalPressure = math.max(finalPressure, basePressure + oscillation * 0.08)
        end
    end

    if pressureRange or burbleRange then
        callNative(SetVehicleTurboPressure, vehicle, finalPressure)
    end

    local crackleRange = Config.AudioTuning.crackleIntensity
    if crackleRange then
        local pct = crackleRange.min + (crackleRange.max - crackleRange.min) * mapSlider(settings.crackle or Config.DefaultState.crackle)
        callNative(SetVehicleRocketBoostPercentage, vehicle, pct)
        callNative(SetVehicleRocketBoostActive, vehicle, pct > 0.2)
    end

    local valveMode = settings.valveMode or Config.DefaultState.valveMode
    if valveMode == 'closed' then
        callNative(SetVehicleBoostActive, vehicle, false)
    elseif valveMode == 'open' then
        callNative(SetVehicleBoostActive, vehicle, true)
    end

    ActiveVehicleStates[netId] = copyState(settings)
end

local function sendToServer(event, ...)
    TriggerServerEvent(('klb_exhaustaudio:%s'):format(event), ...)
end

local function openPanel(state)
    localePayload = KLocale.localePayload(localeKey)
    SendNUIMessage({
        action = 'open',
        locale = localePayload,
        state = copyState(state)
    })
    SetNuiFocus(true, true)
end

RegisterNetEvent('klb_exhaustaudio:openUI', function(payload)
    payload = payload or {}
    openPanel(payload.state or Config.DefaultState)
end)

RegisterNetEvent('klb_exhaustaudio:notify', function(message)
    showToast(message)
end)

RegisterNUICallback('close', function(_, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
    cb({ ok = true })
end)

RegisterNUICallback('apply', function(data, cb)
    sendToServer('applySettings', data or {})
    cb({ ok = true })
end)

RegisterNUICallback('saveProfile', function(data, cb)
    sendToServer('saveProfile', data or {})
    cb({ ok = true })
end)

local function validateDriver()
    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) then
        showToast(KLocale.notify(localeKey, 'noVehicle'))
        return
    end
    if not IsPedInAnyVehicle(ped, false) then
        showToast(KLocale.notify(localeKey, 'noVehicle'))
        return
    end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then
        showToast(KLocale.notify(localeKey, 'driverOnly'))
        return
    end
    ensureEntityNetworked(vehicle)
    local netId = NetworkGetNetworkIdFromEntity(vehicle)
    SetNetworkIdExistsOnAllMachines(netId, true)
    SetNetworkIdCanMigrate(netId, true)
    sendToServer('requestOpen', netId)
end

if Config.Command.enabled then
    RegisterCommand(Config.Command.name, validateDriver, false)
    if Config.Command.allowKeyMapping then
        RegisterKeyMapping(Config.Command.name, KLocale.commandDescription(localeKey), 'keyboard', Config.Command.defaultKey or 'F7')
    end
end

RegisterNetEvent('klb_exhaustaudio:syncVehicle', function(netId, state, driverSource)
    if not netId or not state then return end
    netId = tonumber(netId) or netId
    applyVehicleAudio(netId, state)
    if isLocalPlayer(driverSource) then
        SendNUIMessage({ action = 'updateState', state = copyState(state) })
    end
end)

RegisterNetEvent('klb_exhaustaudio:bulkSync', function(states)
    if type(states) ~= 'table' then return end
    for netId, state in pairs(states) do
        netId = tonumber(netId) or netId
        applyVehicleAudio(netId, state)
    end
end)

CreateThread(function()
    Wait(2500)
    sendToServer('requestSync')
end)

CreateThread(function()
    while true do
        Wait(1000)
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            if GetPedInVehicleSeat(vehicle, -1) == ped then
                local netId = NetworkGetNetworkIdFromEntity(vehicle)
                if netId ~= 0 then
                    if lastDriverNetId ~= netId then
                        ensureEntityNetworked(vehicle)
                        sendToServer('onDriverEntered', netId)
                        lastDriverNetId = netId
                    end
                end
            else
                if lastDriverNetId then
                    sendToServer('onDriverLeft', lastDriverNetId)
                    lastDriverNetId = nil
                end
            end
        else
            if lastDriverNetId then
                sendToServer('onDriverLeft', lastDriverNetId)
                lastDriverNetId = nil
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(800)
        local ped = PlayerPedId()
        if IsPedInAnyVehicle(ped, false) then
            local vehicle = GetVehiclePedIsIn(ped, false)
            if vehicle ~= 0 then
                local netId = NetworkGetNetworkIdFromEntity(vehicle)
                local state = ActiveVehicleStates[netId]
                if state then
                    local speed = GetEntitySpeed(vehicle)
                    if speed < 1.0 then
                        local idleRange = Config.AudioTuning.idleRpm
                        if idleRange then
                            local targetRpm = idleRange.min + (idleRange.max - idleRange.min) * mapSlider(state.idle or Config.DefaultState.idle)
                            callNative(SetVehicleCurrentRpm, vehicle, targetRpm)
                        end
                    end
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    SetNuiFocus(false, false)
end)
