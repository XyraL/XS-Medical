Equip = { held = nil, heldKind = nil, onIt = false, onNet = nil, carrying = false, carriedBy = nil }

local PUSH = { dict = 'anim@heists@box_carry@', clip = 'idle' }
local LIE = { dict = 'anim@gangops@morgue@table@', clip = 'body_search' }
local SIT = { dict = 'missfinale_c2leadinoutfin_c_int', clip = '_leadin_loop2_lester' }
local CARRIER = { dict = 'missfinale_c2mcs_1', clip = 'fin_c2_mcs_1_camman' }
local CARRIED = { dict = 'nm', clip = 'firemans_carry' }

local function shapes(kind)
    if kind == 'wheelchair' then
        local W = Config.Wheelchair or {}
        return W.push or { offset = vec3(0.0, -0.3, -0.73), rotation = vec3(195.0, 180.0, 180.0), bone = 28422 },
            W.seat or { offset = vec3(0.0, 0.0, 0.4), rotation = vec3(0.0, 0.0, 180.0) }
    end
    local S = Config.Stretcher or {}
    return S.push or { offset = vec3(0.0, 1.45, -0.98), rotation = vec3(0.0, 0.0, 90.0) },
        S.lie or { offset = vec3(0.0, 0.0, 1.0), rotation = vec3(0.0, 0.0, 90.0) }
end

local function entityFromNet(netId, timeoutMs)
    local untilAt = GetGameTimer() + (timeoutMs or 5000)
    while GetGameTimer() < untilAt do
        if NetworkDoesNetworkIdExist(netId) then
            local ent = NetworkGetEntityFromNetworkId(netId)
            if ent ~= 0 and DoesEntityExist(ent) then return ent end
        end
        Wait(50)
    end
    return 0
end

local function control(ent)
    local untilAt = GetGameTimer() + 2000
    while not NetworkHasControlOfEntity(ent) and GetGameTimer() < untilAt do
        NetworkRequestControlOfEntity(ent)
        Wait(20)
    end
    return NetworkHasControlOfEntity(ent)
end

function Equip.Hold(netId, kind)
    Equip.Drop()
    local ent = entityFromNet(netId)
    if ent == 0 then return Framework.Notify(Text('err_spawn_failed'), 'error') end
    control(ent)
    local ped = PlayerPedId()
    local push = shapes(kind)
    local o, r = push.offset, push.rotation
    local bone = push.bone and GetPedBoneIndex(ped, push.bone) or 0
    AttachEntityToEntity(ent, ped, bone, o.x, o.y, o.z, r.x, r.y, r.z, false, false, true, false, 2, true)
    Equip.held, Equip.heldKind = netId, kind
    lib.requestAnimDict(PUSH.dict, 3000)
    CreateThread(function()
        lib.showTextUI(Text('equipment_hint'), { position = 'right-center' })
        while Equip.held == netId do
            local p = PlayerPedId()
            if not IsEntityPlayingAnim(p, PUSH.dict, PUSH.clip, 3) then
                TaskPlayAnim(p, PUSH.dict, PUSH.clip, 8.0, -8.0, -1, 49, 0.0, false, false, false)
            end
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            if IsControlJustReleased(0, 73) then Equip.Drop() end
            if IsControlJustReleased(0, 47) then Equip.Store() end
            Wait(0)
        end
        lib.hideTextUI()
        StopAnimTask(PlayerPedId(), PUSH.dict, PUSH.clip, 1.0)
    end)
end

function Equip.Drop()
    if not Equip.held then return end
    local ent = entityFromNet(Equip.held, 500)
    Equip.held, Equip.heldKind = nil, nil
    if ent ~= 0 then
        DetachEntity(ent, true, true)
        PlaceObjectOnGroundProperly(ent)
    end
end

function Equip.Store()
    local netId = Equip.held
    if not netId then return end
    Equip.held, Equip.heldKind = nil, nil
    local ok, err = lib.callback.await('XS-Medical:server:equipmentStore', false, netId)
    if not ok and err then Framework.Notify(err, 'error') end
end

function Equip.PlaceOn(target)
    if not Equip.held then return Framework.Notify(Text('err_no_equipment'), 'error') end
    local ok, err = lib.callback.await('XS-Medical:server:placeOn', false, target, Equip.held)
    if not ok then Framework.Notify(err or Text('err_failed'), 'error') end
end

function Equip.LoadInto(target)
    local vehicle = lib.getClosestVehicle(GetEntityCoords(PlayerPedId()), 7.0, false)
    if not vehicle then return Framework.Notify(Text('err_no_vehicle'), 'error') end
    if Equip.held then
        local ent = entityFromNet(Equip.held, 300)
        Equip.held, Equip.heldKind = nil, nil
        if ent ~= 0 then DetachEntity(ent, true, true) end
    end
    local ok, err = lib.callback.await('XS-Medical:server:loadPatient', false, target, NetworkGetNetworkIdFromEntity(vehicle))
    if not ok then Framework.Notify(err or Text('err_failed'), 'error') end
end

function Equip.Unload(vehicle)
    for seat = -1, GetVehicleMaxNumberOfPassengers(vehicle) - 1 do
        local ped = GetPedInVehicleSeat(vehicle, seat)
        if ped ~= 0 and IsPedAPlayer(ped) then
            local id = Treat.ServerId(ped)
            if id and Treat.StatusOf(id) ~= 'alive' then
                local ok, err = lib.callback.await('XS-Medical:server:unloadPatient', false, id)
                if not ok then Framework.Notify(err or Text('err_failed'), 'error') end
                return
            end
        end
    end
    Framework.Notify(Text('err_no_patient_inside'), 'error')
end

function Equip.Carry(target)
    local ok, err = lib.callback.await('XS-Medical:server:carry', false, target, true)
    if not ok then return Framework.Notify(err or Text('err_failed'), 'error') end
    Equip.carrying = target
    lib.requestAnimDict(CARRIER.dict, 3000)
    CreateThread(function()
        lib.showTextUI(Text('carry_hint'), { position = 'right-center' })
        while Equip.carrying == target do
            local ped = PlayerPedId()
            if not IsEntityPlayingAnim(ped, CARRIER.dict, CARRIER.clip, 3) then
                TaskPlayAnim(ped, CARRIER.dict, CARRIER.clip, 8.0, -8.0, -1, 49, 0.0, false, false, false)
            end
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 24, true)
            if IsControlJustReleased(0, 73) then Equip.PutDown() end
            Wait(0)
        end
        lib.hideTextUI()
        StopAnimTask(PlayerPedId(), CARRIER.dict, CARRIER.clip, 1.0)
    end)
end

function Equip.PutDown()
    if not Equip.carrying then return end
    Equip.carrying = false
    lib.callback.await('XS-Medical:server:carry', false, nil, false)
end

function Equip.Release()
    local ped = PlayerPedId()
    if Equip.onIt or Equip.carriedBy then
        DetachEntity(ped, true, false)
        ClearPedTasks(ped)
    end
    Equip.onIt, Equip.onNet, Equip.carriedBy = false, nil, nil
    if Down.active then Down.carried = false end
end

RegisterNetEvent('XS-Medical:client:placeOn', function(netId, kind)
    local ent = entityFromNet(netId)
    if ent == 0 then return end
    local ped = PlayerPedId()
    local _, seat = shapes(kind)
    Equip.onIt, Equip.onNet = true, netId
    if Down.active then Down.carried = true end
    local anim = kind == 'wheelchair' and SIT or LIE
    lib.requestAnimDict(anim.dict, 3000)
    AttachEntityToEntity(ped, ent, 0, seat.offset.x, seat.offset.y, seat.offset.z, seat.rotation.x, seat.rotation.y, seat.rotation.z, false, false, false, false, 2, true)
    TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, 1, 0.0, false, false, false)
    CreateThread(function()
        while Equip.onIt and Equip.onNet == netId do
            local p = PlayerPedId()
            if not IsEntityPlayingAnim(p, anim.dict, anim.clip, 3) then TaskPlayAnim(p, anim.dict, anim.clip, 8.0, -8.0, -1, 1, 0.0, false, false, false) end
            if kind == 'wheelchair' and not Down.active and IsControlJustReleased(0, 73) then
                TriggerServerEvent('XS-Medical:server:leaveEquipment')
                Equip.Release()
            end
            Wait(250)
        end
    end)
end)

RegisterNetEvent('XS-Medical:client:takeOff', function()
    Equip.Release()
end)

RegisterNetEvent('XS-Medical:client:carried', function(carrier)
    local other = GetPlayerFromServerId(carrier)
    if other == -1 then return end
    local carrierPed = GetPlayerPed(other)
    local ped = PlayerPedId()
    Equip.carriedBy = carrier
    if Down.active then Down.carried = true end
    lib.requestAnimDict(CARRIED.dict, 3000)
    AttachEntityToEntity(ped, carrierPed, 0, 0.27, 0.15, 0.63, 0.5, 0.5, 180.0, false, false, false, false, 2, false)
    TaskPlayAnim(ped, CARRIED.dict, CARRIED.clip, 8.0, -8.0, -1, 33, 0.0, false, false, false)
    CreateThread(function()
        while Equip.carriedBy == carrier do
            local p = PlayerPedId()
            if not IsEntityPlayingAnim(p, CARRIED.dict, CARRIED.clip, 3) then TaskPlayAnim(p, CARRIED.dict, CARRIED.clip, 8.0, -8.0, -1, 33, 0.0, false, false, false) end
            Wait(300)
        end
    end)
end)

RegisterNetEvent('XS-Medical:client:intoVehicle', function(vehNetId)
    local vehicle = entityFromNet(vehNetId)
    if vehicle == 0 then return end
    Equip.Release()
    local ped = PlayerPedId()
    local seat = nil
    for _, s in ipairs({ 2, 1, 0 }) do
        if IsVehicleSeatFree(vehicle, s) then seat = s break end
    end
    if not seat then return Framework.Notify(Text('err_vehicle_full'), 'error') end
    TaskWarpPedIntoVehicle(ped, vehicle, seat)
end)

RegisterNetEvent('XS-Medical:client:outOfVehicle', function()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 then return end
    local c = GetOffsetFromEntityInWorldCoords(vehicle, 0.0, -4.6, 0.0)
    TaskLeaveVehicle(ped, vehicle, 16)
    Wait(300)
    SetEntityCoords(ped, c.x, c.y, c.z, false, false, false, false)
end)

RegisterNetEvent('hospital:client:SetEscortingState', function(state)
    Equip.escorting = state == true
end)

function Equip.RegisterTargets()
    local models = (Config.Stretcher or {}).fromVehicles or { 'ambulance' }
    Target.AddModels('ambulance', models, {
        {
            label = Text('opt_take_stretcher'), icon = 'fas fa-bed-pulse', distance = 4.0,
            canInteract = function() return Me.IsMedic() and not Equip.held end,
            onSelect = function(vehicle)
                local ok, info = lib.callback.await('XS-Medical:server:stretcherFromVehicle', false, NetworkGetNetworkIdFromEntity(vehicle))
                if not ok then return Framework.Notify(info or Text('err_failed'), 'error') end
                Equip.Hold(info.netId, info.kind)
            end,
        },
        {
            label = Text('opt_unload'), icon = 'fas fa-person-arrow-down-to-line', distance = 4.0,
            canInteract = function() return Me.IsMedic() end,
            onSelect = function(vehicle) Equip.Unload(vehicle) end,
        },
    })
end

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    Equip.Release()
end)
