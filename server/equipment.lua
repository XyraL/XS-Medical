Equipment = { owned = {}, carrying = {} }

local function modelFor(kind)
    if kind == 'wheelchair' then return (Config.Wheelchair or {}).model or 'prop_wheelchair_01' end
    return (Config.Stretcher or {}).model or 'v_med_emptybed'
end

local function near(src, coords, max)
    local ped = GetPlayerPed(src)
    if ped == 0 then return false end
    return #(GetEntityCoords(ped) - coords) <= (max or 3.0)
end

local function clearOwned(src, kind)
    for netId, entry in pairs(Equipment.owned) do
        if entry.owner == src and (not kind or entry.kind == kind) then
            local ent = NetworkGetEntityFromNetworkId(netId)
            if ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
            Equipment.owned[netId] = nil
        end
    end
end

local function spawn(src, kind, x, y, z, heading)
    clearOwned(src, kind)
    local hash = joaat(modelFor(kind))
    local obj = CreateObjectNoOffset(hash, x, y, z, true, true, false)
    local waited = 0
    while (obj == 0 or not DoesEntityExist(obj)) and waited < 2000 do
        Wait(50)
        waited = waited + 50
    end
    if obj == 0 or not DoesEntityExist(obj) then return nil end
    SetEntityHeading(obj, heading or 0.0)
    FreezeEntityPosition(obj, false)
    local netId = NetworkGetNetworkIdFromEntity(obj)
    Equipment.owned[netId] = { owner = src, kind = kind }
    Entity(obj).state:set('xsmEquipment', kind, true)
    return netId
end

lib.callback.register('XS-Medical:server:equipmentTake', function(src, placeId, pointId)
    local place = Hospitals.Get(placeId)
    local point = place and Hospitals.Point(place, 'equipment', tostring(pointId or ''))
    if not point or not Hospitals.Near(src, point, 3.5) then return false, Text('err_too_far') end
    if point.kind == 'stretcher' and not Framework.IsMedicSource(src) then return false, Text('err_medics_only') end
    local netId = spawn(src, point.kind, point.x, point.y, point.z, point.w)
    if not netId then return false, Text('err_spawn_failed') end
    return true, { netId = netId, kind = point.kind }
end)

lib.callback.register('XS-Medical:server:stretcherFromVehicle', function(src, vehNetId)
    if not Framework.IsMedicSource(src) then return false, Text('err_medics_only') end
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(vehNetId) or 0)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false, Text('err_no_vehicle') end
    local coords = GetEntityCoords(vehicle)
    if not near(src, coords, 8.0) then return false, Text('err_too_far') end
    local heading = GetEntityHeading(vehicle)
    local rad = math.rad(heading)
    local back = vector3(coords.x + math.sin(rad) * 4.2, coords.y - math.cos(rad) * 4.2, coords.z - 0.4)
    local netId = spawn(src, 'stretcher', back.x, back.y, back.z, heading)
    if not netId then return false, Text('err_spawn_failed') end
    return true, { netId = netId, kind = 'stretcher' }
end)

lib.callback.register('XS-Medical:server:equipmentStore', function(src, netId)
    netId = tonumber(netId)
    local entry = netId and Equipment.owned[netId]
    if not entry then return false end
    if entry.owner ~= src and not Framework.IsMedicSource(src) then return false end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent ~= 0 and DoesEntityExist(ent) then
        if not near(src, GetEntityCoords(ent), 6.0) then return false, Text('err_too_far') end
        for patient, info in pairs(Equipment.carrying) do
            if info.netId == netId then
                TriggerClientEvent('XS-Medical:client:takeOff', patient)
                Equipment.carrying[patient] = nil
            end
        end
        DeleteEntity(ent)
    end
    Equipment.owned[netId] = nil
    return true
end)

lib.callback.register('XS-Medical:server:placeOn', function(src, target, netId)
    target, netId = tonumber(target), tonumber(netId)
    local entry = netId and Equipment.owned[netId]
    local ent = netId and NetworkGetEntityFromNetworkId(netId) or 0
    if not entry or ent == 0 then return false, Text('err_no_equipment') end
    if not target or not GetPlayerName(target) then return false, Text('err_no_patient') end
    local c = GetEntityCoords(ent)
    if not near(src, c, 4.0) or not near(target, c, 4.0) then return false, Text('err_too_far') end
    if entry.kind == 'stretcher' and not Framework.IsMedicSource(src) then return false, Text('err_medics_only') end
    for patient, info in pairs(Equipment.carrying) do
        if info.netId == netId and patient ~= target then return false, Text('err_equipment_used') end
    end
    Equipment.carrying[target] = { netId = netId, kind = entry.kind, by = src }
    TriggerClientEvent('XS-Medical:client:placeOn', target, netId, entry.kind)
    return true
end)

lib.callback.register('XS-Medical:server:takeOff', function(src, target)
    target = tonumber(target)
    if not target or not Equipment.carrying[target] then return false end
    if not near(src, GetEntityCoords(GetPlayerPed(target)), 4.0) then return false, Text('err_too_far') end
    Equipment.carrying[target] = nil
    TriggerClientEvent('XS-Medical:client:takeOff', target)
    return true
end)

lib.callback.register('XS-Medical:server:loadPatient', function(src, target, vehNetId)
    target = tonumber(target)
    local vehicle = NetworkGetEntityFromNetworkId(tonumber(vehNetId) or 0)
    if not target or not GetPlayerName(target) then return false, Text('err_no_patient') end
    if vehicle == 0 or not DoesEntityExist(vehicle) then return false, Text('err_no_vehicle') end
    local c = GetEntityCoords(vehicle)
    if not near(src, c, 8.0) or not near(target, c, 9.0) then return false, Text('err_too_far') end
    local info = Equipment.carrying[target]
    if info then
        local ent = NetworkGetEntityFromNetworkId(info.netId)
        if ent ~= 0 and DoesEntityExist(ent) then DeleteEntity(ent) end
        Equipment.owned[info.netId] = nil
        Equipment.carrying[target] = nil
    end
    TriggerClientEvent('XS-Medical:client:intoVehicle', target, tonumber(vehNetId))
    local place = Hospitals.Nearest(c, 'hospital')
    if Framework.IsMedicSource(src) and place then
        local v = Patients.Get(target, true)
        if v.status == 'field' then
            v.hospital = place.id
            v.room = Text('room_incoming')
            v.status = 'incoming'
            Patients.Changed(v)
        end
    end
    return true
end)

lib.callback.register('XS-Medical:server:unloadPatient', function(src, target)
    target = tonumber(target)
    if not target or not GetPlayerName(target) then return false, Text('err_no_patient') end
    local ped = GetPlayerPed(target)
    if not near(src, GetEntityCoords(ped), 8.0) then return false, Text('err_too_far') end
    TriggerClientEvent('XS-Medical:client:outOfVehicle', target)
    return true
end)

lib.callback.register('XS-Medical:server:carry', function(src, target, start)
    target = tonumber(target)
    if start == false then
        for patient, info in pairs(Equipment.carrying) do
            if info.by == src and info.kind == 'carry' then
                Equipment.carrying[patient] = nil
                TriggerClientEvent('XS-Medical:client:takeOff', patient)
            end
        end
        return true
    end
    if not target or not GetPlayerName(target) then return false, Text('err_no_patient') end
    if not near(src, GetEntityCoords(GetPlayerPed(target)), 3.0) then return false, Text('err_too_far') end
    if not State.IsDown(target) then return false, Text('err_carry_awake') end
    if Equipment.carrying[target] then return false, Text('err_equipment_used') end
    Equipment.carrying[target] = { kind = 'carry', by = src }
    TriggerClientEvent('XS-Medical:client:carried', target, src)
    return true
end)

RegisterNetEvent('XS-Medical:server:leaveEquipment', function()
    local src = source
    local info = Equipment.carrying[src]
    if info and info.kind == 'wheelchair' then Equipment.carrying[src] = nil end
end)

AddEventHandler('playerDropped', function()
    local src = source
    clearOwned(src)
    if Equipment.carrying[src] then Equipment.carrying[src] = nil end
    for patient, info in pairs(Equipment.carrying) do
        if info.by == src then
            TriggerClientEvent('XS-Medical:client:takeOff', patient)
            Equipment.carrying[patient] = nil
        end
    end
end)
